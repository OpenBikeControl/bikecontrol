import 'dart:async';

import 'package:bike_control/bluetooth/devices/wheeltop/wheeltop_eds.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/test_env.dart';

/// Auto-connect backoff for devices that limit their attempts (Wheeltop EDS):
/// counting, suppression, cooldown, guidance alert, Retry — through the REAL
/// Connection class; only the BLE platform is fake.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late StubActions stubActions;
  final notifications = <BaseNotification>[];
  late StreamSubscription<BaseNotification> notificationSub;
  Timer? advTimer;

  core.connection.initialize();

  /// Re-emit the advertisement continuously, like a real pod's beacon — the
  /// retry loop is driven by rediscovery, which the fake only produces on
  /// explicit updateScanResult calls.
  void startAdvertising(FakePeripheral peripheral) {
    advTimer?.cancel();
    advTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => env.ble.updateScanResult(peripheral.scanResult),
    );
  }

  setUp(() async {
    // The connect-failure backoff (RD contention) is the experiment-OFF path;
    // with the keepalive experiment on, a Wheeltop device opts out of backoff
    // to keep the probe's reconnect loop cycling.
    await env.resetState(prefs: {'wheeltop_probe_enabled': false});
    stubActions = StubActions();
    stubActions.supportedApp = Zwift();
    core.actionHandler = stubActions;
    notifications.clear();
    notificationSub = core.connection.actionStream.listen(notifications.add);
    // Long by default so suppression holds within a test; the cooldown test
    // shortens it locally.
    core.connection.autoConnectBackoffCooldown = const Duration(seconds: 30);
  });

  tearDown(() async {
    advTimer?.cancel();
    await notificationSub.cancel();
    await env.resetConnection();
  });

  // "Connecting to:" is a log line, not a toast, since the calmer app start.
  int connectingCount() => notifications
      .whereType<LogNotification>()
      .where((n) => n.message.startsWith('Connecting to:') && n.message.contains('WHEELTOP EDS TX Left'))
      .length;

  int failedToastCount() => notifications
      .whereType<AlertNotification>()
      .where(
        (n) =>
            n.alertMessage.startsWith("Couldn't connect to WHEELTOP EDS TX Left")
            // The give-up alert starts the same way.
            &&
            !n.alertMessage.contains(AppLocalizations.current.wheeltopClaimedByDerailleurHint),
      )
      .length;

  List<AlertNotification> guidanceAlerts() => notifications
      .whereType<AlertNotification>()
      .where((n) => n.alertMessage.contains(AppLocalizations.current.wheeltopClaimedByDerailleurHint))
      .toList();

  test('healthy pod connects and subscribes to the button characteristic', () async {
    final pod = buildWheeltopEdsTxLeft();
    env.ble.addPeripheral(pod);
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<WheeltopEds>().any((d) => d.isConnected),
      description: 'WheeltopEds to connect',
    );
    await IntegrationEnv.waitFor(
      () => pod.subscriptions.contains(WheeltopEdsConstants.TX_CHARACTERISTIC_UUID.toLowerCase()),
      description: 'subscription to the button characteristic',
    );
    expect(guidanceAlerts(), isEmpty);
  });

  test('gives up after three failed connects with exactly one guidance alert', () async {
    final pod = buildWheeltopEdsTxLeft();
    pod.connectError = Exception('Unknown Error 147');
    env.ble.addPeripheral(pod);
    startAdvertising(pod);
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(() => guidanceAlerts().isNotEmpty, description: 'guidance alert');

    expect(connectingCount(), 3);
    // The generic failure toast fired for the first two attempts only — the
    // suppressing third attempt shows the guidance alert instead.
    expect(failedToastCount(), 2);
    final alert = guidanceAlerts().single;
    expect(
      alert.alertMessage,
      contains(AppLocalizations.current.connectionGaveUpAfterAttempts('WHEELTOP EDS TX Left')),
    );
    expect(alert.buttonTitle, AppLocalizations.current.reconnect);

    // Suppression holds while the pod keeps advertising: no further attempts.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(connectingCount(), 3);
    expect(guidanceAlerts().length, 1);
  });

  test('cooldown lifts suppression for one quiet attempt, no second alert', () async {
    core.connection.autoConnectBackoffCooldown = const Duration(milliseconds: 300);
    final pod = buildWheeltopEdsTxLeft();
    pod.connectError = Exception('Unknown Error 147');
    env.ble.addPeripheral(pod);
    startAdvertising(pod);
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(() => guidanceAlerts().isNotEmpty, description: 'first suppression');
    expect(connectingCount(), 3);

    // After the cooldown, rediscovery earns a single further attempt, which
    // fails and re-suppresses silently (log-only, still one alert). The round
    // is quiet (Fix 1), so watch the platform-level attempt counter instead
    // of the (now-silenced) "Connecting to:" toast.
    await IntegrationEnv.waitFor(() => pod.connectAttempts >= 4, description: 'post-cooldown retry');
    expect(guidanceAlerts().length, 1);
    final silentLogs = notifications
        .where((n) => n is! AlertNotification)
        .whereType<LogNotification>()
        .where((n) => n.message.contains(AppLocalizations.current.wheeltopClaimedByDerailleurHint));
    expect(silentLogs, isNotEmpty);
  });

  test('Retry button reconnects immediately once the pod is free', () async {
    final pod = buildWheeltopEdsTxLeft();
    pod.connectError = Exception('Unknown Error 133');
    env.ble.addPeripheral(pod);
    startAdvertising(pod);
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(() => guidanceAlerts().isNotEmpty, description: 'suppression alert');

    pod.connectError = null; // the user powered the derailleur down
    guidanceAlerts().single.onTap!();

    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<WheeltopEds>().any((d) => d.isConnected),
      description: 'reconnect after Retry',
    );
  });

  test('a successful connect resets the failure counter', () async {
    final pod = buildWheeltopEdsTxLeft();
    pod.connectError = Exception('Unknown Error 133');
    env.ble.addPeripheral(pod);
    startAdvertising(pod);
    await core.connection.performScanning();

    // Two failures, then the pod becomes connectable before the third.
    await IntegrationEnv.waitFor(() => connectingCount() >= 2, description: 'two failed attempts');
    advTimer?.cancel(); // gate rediscovery so no third failure races the reset
    pod.connectError = null;
    startAdvertising(pod);
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<WheeltopEds>().any((d) => d.isConnected),
      description: 'successful connect',
    );
    final attemptsBeforeDrop = connectingCount();

    // Pod claimed again: the counter starts from zero, so suppression needs
    // three fresh failures — not one.
    pod.connectError = Exception('Unknown Error 147');
    env.ble.dropConnection(pod.deviceId);
    await IntegrationEnv.waitFor(() => guidanceAlerts().isNotEmpty, description: 'second suppression');
    expect(connectingCount() - attemptsBeforeDrop, 3);

    // Retry clears the counter (and the suppression) immediately, once the
    // pod is free again.
    pod.connectError = null;
    guidanceAlerts().single.onTap!();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<WheeltopEds>().any((d) => d.isConnected),
      description: 'reconnect after Retry',
    );

    // Pod claimed a third time: prove Retry truly cleared the counter by
    // requiring three fresh failures again — and prove the give-up alert
    // fires only once per session (this round re-suppresses silently).
    final attemptsBeforeThirdDrop = pod.connectAttempts;
    pod.connectError = Exception('Unknown Error 147');
    env.ble.dropConnection(pod.deviceId);
    await IntegrationEnv.waitFor(
      () => pod.connectAttempts - attemptsBeforeThirdDrop >= 3,
      description: 'three fresh attempts after Retry (counter cleared)',
    );
    expect(pod.connectAttempts - attemptsBeforeThirdDrop, 3);
    expect(guidanceAlerts().length, 1);
  });

  test('devices without an attempt limit retry forever', () async {
    final click = buildZwiftClick();
    click.connectError = Exception('Unknown Error 133');
    env.ble.addPeripheral(click);
    advTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => env.ble.updateScanResult(click.scanResult),
    );
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(
      () => click.connectAttempts >= 5,
      timeout: const Duration(seconds: 10),
      description: 'unlimited retries',
    );
    expect(guidanceAlerts(), isEmpty);
  });
}
