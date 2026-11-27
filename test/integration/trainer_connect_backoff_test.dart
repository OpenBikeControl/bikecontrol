import 'dart:async';

import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/test_env.dart';

/// A remembered Bluetooth trainer that another app holds (MyWhoosh on
/// Windows: service discovery fails with AccessDenied) must stop being
/// retried. Without a cap every advertisement re-added and re-connected it,
/// about once a second, with a "Couldn't connect" and a "disconnected" toast
/// each round. Drives the REAL Connection; only the BLE platform is fake.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  final notifications = <BaseNotification>[];
  late StreamSubscription<BaseNotification> notificationSub;
  Timer? advTimer;

  core.connection.initialize();

  const trainerName = 'RIVO COG';

  void startAdvertising(FakePeripheral peripheral) {
    advTimer?.cancel();
    advTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) => env.ble.updateScanResult(peripheral.scanResult),
    );
  }

  setUp(() async {
    await env.resetState();
    core.actionHandler = StubActions()..supportedApp = Zwift();
    // The rider connected this trainer once: it has auto-connect consent.
    await core.settings.setAutoConnect(trainerName, true);
    notifications.clear();
    notificationSub = core.connection.actionStream.listen(notifications.add);
    core.connection.autoConnectBackoffCooldown = const Duration(seconds: 30);
  });

  tearDown(() async {
    advTimer?.cancel();
    await notificationSub.cancel();
    await env.resetConnection();
  });

  List<AlertNotification> gaveUpAlerts() => notifications
      .whereType<AlertNotification>()
      .where((n) => n.alertMessage.contains(AppLocalizations.current.connectionGaveUpAfterAttempts(trainerName)))
      .toList();

  test('a trainer another app holds gives up after three attempts', () async {
    final trainer = buildFtmsTrainer(deviceId: 'rivo-cog', name: trainerName);
    trainer.connectError = Exception('Failed to get characteristics for service 00001826: AccessDenied');
    env.ble.addPeripheral(trainer);
    startAdvertising(trainer);
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(() => gaveUpAlerts().isNotEmpty, description: 'give-up alert');
    expect(trainer.connectAttempts, 3);
    expect(gaveUpAlerts().single.alertMessage, contains(AppLocalizations.current.trainerConnectGuidance));

    // Suppressed while the trainer keeps advertising: no further attempts.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(trainer.connectAttempts, 3);
    expect(gaveUpAlerts().length, 1);
    // The rider's choice stays: Reconnect or the cooldown can bring it back.
    expect(core.settings.getAutoConnect(trainerName), isTrue);
  });

  test('picking the trainer again connects it once it is free', () async {
    final trainer = buildFtmsTrainer(deviceId: 'rivo-cog', name: trainerName);
    trainer.connectError = Exception('AccessDenied');
    env.ble.addPeripheral(trainer);
    startAdvertising(trainer);
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(() => gaveUpAlerts().isNotEmpty, description: 'give-up alert');

    trainer.connectError = null;
    final device = core.connection.proxyDevices.single;
    await core.connection.connectDevice(device);
    await IntegrationEnv.waitFor(
      () => core.connection.proxyDevices.any((d) => d.isConnected),
      description: 'rider-initiated connect',
    );
  });
}
