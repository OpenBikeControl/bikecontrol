import 'dart:io';

import 'package:bike_control/bluetooth/devices/gamepad/gamepad_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/wifi_trainer_scanner.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart';
import 'package:universal_ble/universal_ble.dart';

import 'harness/test_env.dart';

/// USB gamepads and Wi-Fi trainers need no Bluetooth, so a PC without an
/// adapter, or with Bluetooth off, must still list them.
void main() async {
  final env = await IntegrationEnv.setUp();
  core.connection.initialize();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void plugInGamepad({String id = 'pad-1', String name = 'Xbox Wireless Controller'}) {
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/gamepads'),
      (call) async => call.method == 'listGamepads'
          ? <dynamic>[
              {'id': id, 'name': name},
            ]
          : null,
    );
  }

  final kickr = Service(
    name: 'KICKR CORE 7E57',
    type: WifiTrainerScanner.serviceType,
    port: 36866,
    addresses: [InternetAddress('192.168.1.50')],
  );

  setUp(() async {
    await env.resetState();
    core.actionHandler = StubActions();
    plugInGamepad();
  });

  tearDown(() async {
    await env.resetConnection();
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/gamepads'),
      (call) async => call.method == 'listGamepads' ? <dynamic>[] : null,
    );
  });

  Future<void> waitForGamepadAndTrainer() async {
    await IntegrationEnv.waitFor(
      () => core.connection.gamepadDevices.isNotEmpty,
      description: 'the gamepad to be listed',
    );
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<ProxyDevice>().isNotEmpty,
      description: 'the Wi-Fi trainer to be listed',
    );
  }

  test('without Bluetooth, gamepads and Wi-Fi trainers are still listed', () async {
    env.ble.availability = AvailabilityState.unsupported;
    env.mdns.addForeignService(kickr);

    core.connection.startNonBluetoothDiscovery();

    await waitForGamepadAndTrainer();
    expect(core.connection.gamepadDevices.single, isA<GamepadDevice>());
    expect(env.ble.scanning, isFalse);
  });

  test('a Bluetooth scan that fails to start does not stop gamepad and Wi-Fi discovery', () async {
    env.ble.startScanError = PlatformException(code: 'NoAdapter', message: 'No Bluetooth adapter');
    env.mdns.addForeignService(kickr);

    await expectLater(core.connection.performScanning(), throwsA(isA<PlatformException>()));

    await waitForGamepadAndTrainer();
  });

  test('turning Bluetooth off keeps looking for gamepads', () async {
    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.gamepadDevices.isNotEmpty,
      description: 'the gamepad to be listed',
    );

    env.ble.availability = AvailabilityState.poweredOff;
    env.ble.updateAvailability(AvailabilityState.poweredOff);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // A pad plugged in after Bluetooth went off still shows up.
    plugInGamepad(id: 'pad-2', name: '8BitDo Pro 2');
    await IntegrationEnv.waitFor(
      () => core.connection.gamepadDevices.any((pad) => pad.id == 'pad-2'),
      description: 'the new gamepad to be listed',
    );
  });
}
