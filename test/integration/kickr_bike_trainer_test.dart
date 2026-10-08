import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_trainer.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/emulation/profiles/wahoo_profiles.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;

import 'harness/test_env.dart';

/// A KICKR BIKE is ONE Bluetooth peripheral that is both a smart trainer and
/// the host of its shifters. Through the real Connection class it must show up
/// as a controller (buttons) AND as a trainer (bridging), over a single BLE
/// connection, with the trainer found in the GATT database at connect time —
/// not in the advertisement, which may well carry no trainer service at all.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late StubActions stubActions;

  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    stubActions = StubActions();
    core.actionHandler = stubActions;
  });

  tearDown(() async {
    await env.resetConnection();
  });

  Future<WahooKickrBikeShift> connectBike(FakePeripheral bike) async {
    env.ble.addPeripheral(bike);
    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<WahooKickrBikeShift>().any((d) => d.isConnected),
      description: 'KICKR BIKE connected as a controller',
    );
    return core.connection.devices.whereType<WahooKickrBikeShift>().single;
  }

  Future<void> pressShiftUpRight(FakePeripheral bike) async {
    stubActions.performedActions.clear();
    env.ble.notify(bike.deviceId, kickrShiftCharacteristicUuid, kickrBikeShiftFrame(0x0004, pressed: true));
    env.ble.notify(bike.deviceId, kickrShiftCharacteristicUuid, kickrBikeShiftFrame(0x0004, pressed: false));
    await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'shift action');
    expect(stubActions.performedActions.map((a) => a.button), contains(WahooKickrShiftButtons.shiftUpRight));
  }

  test('a KICKR BIKE exposing FTMS is both a controller and a trainer', () async {
    final bike = buildKickrBike(name: 'KICKR BIKE 1234');
    final controller = await connectBike(bike);

    await IntegrationEnv.waitFor(
      () => core.connection.proxyDevices.isNotEmpty,
      description: 'KICKR BIKE listed as a trainer',
    );
    final trainer = core.connection.proxyDevices.single;
    expect(trainer, isA<WahooKickrBikeTrainer>());
    expect(trainer.device.deviceId, bike.deviceId);
    expect(trainer.name, 'KICKR BIKE 1234');
    // FTMS was only in the GATT database, never advertised — still a smart
    // trainer, so Virtual Shifting is on offer.
    expect(bike.advertisedServices, isEmpty);
    expect(trainer.isSmartTrainer, isTrue);

    // Controller side unchanged: listed once, buttons work.
    expect(core.connection.controllerDevices, [controller]);
    await pressShiftUpRight(bike);

    // One BLE connection for both roles.
    expect(bike.connectAttempts, 1);
  });

  test('with trainer consent the bridge starts over the same BLE connection, buttons keep working', () async {
    await core.settings.setAutoConnect('KICKR BIKE 1234', true);
    final bike = buildKickrBike(name: 'KICKR BIKE 1234');
    final controller = await connectBike(bike);

    await IntegrationEnv.waitFor(
      () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.isConnected,
      description: 'trainer role connected',
    );
    final trainer = core.connection.proxyDevices.single;
    await IntegrationEnv.waitFor(() => trainer.isStartedListenable.value, description: 'bridge started');

    // FTMS found at connect time makes it a smart trainer, so it bridges with
    // Virtual Shifting rather than falling back to Proxy …
    expect(trainer.retrofitMode.value, RetrofitMode.wifi);
    // … and drives the bike's FTMS over the controller's link …
    trainer.fitnessBike!.subscribeToTrainer();
    await IntegrationEnv.waitFor(
      () => bike.subscriptions.contains(FitnessBikeDefinition.INDOOR_BIKE_DATA_UUID.toLowerCase()),
      description: 'Indoor Bike Data subscription on the bike',
    );
    // … without a second connect to the same peripheral.
    expect(bike.connectAttempts, 1);
    expect(controller.isConnected, isTrue);

    await pressShiftUpRight(bike);
  });

  test('"No connection" on the trainer leaves the controller connected', () async {
    await core.settings.setAutoConnect('KICKR BIKE 1234', true);
    final bike = buildKickrBike(name: 'KICKR BIKE 1234');
    final controller = await connectBike(bike);
    await IntegrationEnv.waitFor(
      () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.isStartedListenable.value,
      description: 'bridge started',
    );
    final trainer = core.connection.proxyDevices.single;

    await core.connection.disconnect(trainer, forget: false, persistForget: false, keepInList: true);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(trainer.isBridged, isFalse);
    expect(bike.isConnected, isTrue);
    expect(controller.isConnected, isTrue);
    await pressShiftUpRight(bike);
  });

  test('when the bike drops, both roles go — no half-alive trainer', () async {
    await core.settings.setAutoConnect('KICKR BIKE 1234', true);
    final bike = buildKickrBike(name: 'KICKR BIKE 1234');
    await connectBike(bike);
    await IntegrationEnv.waitFor(
      () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.isStartedListenable.value,
      description: 'bridge started',
    );
    final trainer = core.connection.proxyDevices.single;

    // Gone for good (powered off), so rediscovery cannot bring it back.
    env.ble.removePeripheral(bike.deviceId);

    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<WahooKickrBikeShift>().isEmpty,
      description: 'controller removed',
    );
    await IntegrationEnv.waitFor(() => core.connection.proxyDevices.isEmpty, description: 'trainer removed');
    expect(trainer.isBridged, isFalse);
    expect(trainer.isConnected, isFalse);
  });

  test('disconnecting the controller takes the trainer role with it', () async {
    final bike = buildKickrBike(name: 'KICKR BIKE 1234');
    final controller = await connectBike(bike);
    await IntegrationEnv.waitFor(() => core.connection.proxyDevices.isNotEmpty, description: 'trainer listed');

    await core.connection.disconnect(controller, forget: true, persistForget: false);

    await IntegrationEnv.waitFor(() => core.connection.proxyDevices.isEmpty, description: 'trainer removed');
    expect(core.connection.devices.whereType<WahooKickrBikeShift>(), isEmpty);
  });

  test('a KICKR BIKE with only the shifter service stays controller-only', () async {
    final bike = buildKickrBike(name: 'KICKR BIKE 1234', withTrainerServices: false);
    final controller = await connectBike(bike);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(core.connection.proxyDevices, isEmpty);
    expect(core.connection.devices, [controller]);
    await pressShiftUpRight(bike);
  });

  test('the existing shifter-only KICKR BIKE SHIFT profile stays controller-only', () async {
    core.emulation.reset();
    core.emulation.attach(env.ble);
    core.emulation.start(wahooKickrBikeShiftProfile);
    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<WahooKickrBikeShift>().any((d) => d.isConnected),
      description: 'KICKR BIKE SHIFT connected',
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(core.connection.proxyDevices, isEmpty);
    expect(core.connection.devices.whereType<ProxyDevice>(), isEmpty);
  });

  test('shifter frames reaching the trainer role still press the controller buttons', () async {
    final bike = buildKickrBike(name: 'KICKR BIKE 1234');
    await connectBike(bike);
    await IntegrationEnv.waitFor(() => core.connection.proxyDevices.isNotEmpty, description: 'trainer listed');
    final trainer = core.connection.proxyDevices.single;

    for (final pressed in [true, false]) {
      await trainer.processCharacteristic(
        kickrShiftCharacteristicUuid,
        Uint8List.fromList(kickrBikeShiftFrame(0x0004, pressed: pressed)),
      );
    }
    await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'shift action');
    expect(stubActions.performedActions.map((a) => a.button), contains(WahooKickrShiftButtons.shiftUpRight));
  });

  test('the battery saver leaves a KICKR BIKE connected while it carries the bridge', () async {
    await core.settings.setAutoConnect('KICKR BIKE 1234', true);
    final bike = buildKickrBike(name: 'KICKR BIKE 1234');
    final controller = await connectBike(bike);
    await IntegrationEnv.waitFor(
      () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.isStartedListenable.value,
      description: 'bridge started',
    );
    final trainer = core.connection.proxyDevices.single;

    core.connection.debugTriggerInactivityTimeout();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(bike.isConnected, isTrue);
    expect(controller.isConnected, isTrue);
    expect(trainer.isBridged, isTrue);
  });
}
