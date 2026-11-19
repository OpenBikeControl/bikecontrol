import 'dart:async';

import 'package:bike_control/bluetooth/devices/wheeltop/wheeltop_eds.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/test_env.dart';

/// Quick-drop backoff through the REAL Connection class: a pod that connects
/// but drops within seconds (a WHEELTOP TX pod whose keepalive we can't
/// answer) is counted as a failure once the experiment is off, so the
/// reconnect loop quiets down instead of spamming forever. Only the BLE
/// platform is fake.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late StubActions stubActions;
  final notifications = <BaseNotification>[];
  late StreamSubscription<BaseNotification> notificationSub;
  StreamSubscription<Object?>? dropSub;
  Timer? advTimer;

  core.connection.initialize();

  void startAdvertising(FakePeripheral peripheral) {
    advTimer?.cancel();
    advTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => env.ble.updateScanResult(peripheral.scanResult),
    );
  }

  setUp(() async {
    // Experiment OFF → the pod opts back into quick-drop backoff.
    await env.resetState(prefs: {'wheeltop_probe_enabled': false});
    stubActions = StubActions();
    stubActions.supportedApp = Zwift();
    core.actionHandler = stubActions;
    notifications.clear();
    notificationSub = core.connection.actionStream.listen(notifications.add);
    // Any drop within the test window counts as a quick drop.
    core.connection.quickDropThreshold = const Duration(seconds: 30);
    core.connection.autoConnectBackoffCooldown = const Duration(seconds: 30);
  });

  tearDown(() async {
    advTimer?.cancel();
    await dropSub?.cancel();
    await notificationSub.cancel();
    await env.resetConnection();
  });

  List<AlertNotification> guidanceAlerts() => notifications
      .whereType<AlertNotification>()
      .where((n) => n.alertMessage.contains(AppLocalizations.current.wheeltopClaimedByDerailleurHint))
      .toList();

  // "Connecting to:" is a log line, not a toast, since the calmer app start.
  int connectingCount() => notifications
      .whereType<LogNotification>()
      .where((n) => n.message.startsWith('Connecting to:') && n.message.contains('WHEELTOP EDS TX Left'))
      .length;

  test('three quick drops give up with one guidance alert', () async {
    final pod = buildWheeltopEdsTxLeft();
    env.ble.addPeripheral(pod);
    startAdvertising(pod);

    // Drop the pod the instant it connects — the quick-drop loop.
    dropSub = core.connection.connectionStream.listen((d) {
      if (d is WheeltopEds && d.isConnected) {
        env.ble.dropConnection(pod.deviceId);
      }
    });

    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => guidanceAlerts().isNotEmpty,
      timeout: const Duration(seconds: 10),
      description: 'quick-drop guidance alert',
    );

    // Exactly three connect attempts led to the give-up (maxAutoConnectAttempts).
    expect(connectingCount(), 3);
    final alert = guidanceAlerts().single;
    expect(
      alert.alertMessage,
      contains(AppLocalizations.current.connectionGaveUpAfterAttempts('WHEELTOP EDS TX Left')),
    );
    expect(alert.buttonTitle, AppLocalizations.current.reconnect);

    // Suppressed now: the drop loop stops churning.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(connectingCount(), 3);
    expect(guidanceAlerts().length, 1);
  });

  test('with the experiment on, quick drops keep cycling (no give-up)', () async {
    await env.resetState(prefs: {'wheeltop_probe_enabled': true});
    core.actionHandler = stubActions;
    core.connection.quickDropThreshold = const Duration(seconds: 30);

    final pod = buildWheeltopEdsTxLeft();
    env.ble.addPeripheral(pod);
    startAdvertising(pod);
    dropSub = core.connection.connectionStream.listen((d) {
      if (d is WheeltopEds && d.isConnected) {
        env.ble.dropConnection(pod.deviceId);
      }
    });

    await core.connection.performScanning();
    // Keeps reconnecting well past the 3-attempt limit — the probe needs it.
    await IntegrationEnv.waitFor(
      () => connectingCount() >= 5,
      timeout: const Duration(seconds: 10),
      description: 'sustained reconnect cycling',
    );
    expect(guidanceAlerts(), isEmpty);
  });
}
