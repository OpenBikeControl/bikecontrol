import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import 'harness/fake_ble_platform.dart';
import 'harness/fake_peripherals.dart';
import 'harness/test_env.dart';

/// Controller connection lifecycle through the REAL Connection class: BLE
/// scan results → device classification → connect queue → service discovery →
/// handshake → notifications → disconnect. Only the BLE platform is fake.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late StubActions stubActions;

  // initialize() wires UniversalBle callbacks onto the fake platform; run it
  // once for the whole file like the app does at startup.
  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    stubActions = StubActions();
    stubActions.supportedApp = Zwift();
    core.actionHandler = stubActions;
  });

  tearDown(() async {
    await env.resetConnection();
  });

  Future<T> waitForDevice<T>() async {
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<T>().isNotEmpty,
      description: 'a $T to appear in the device list',
    );
    return core.connection.devices.whereType<T>().first;
  }

  group('discovery and classification', () {
    test('Zwift Click is classified from manufacturer data and auto-connected', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftClick>();
      // isConnected flips at the BLE level before the connect flow finishes;
      // the device-information reads land afterwards — wait for them.
      await IntegrationEnv.waitFor(
        () => device.firmwareVersion != null && device.batteryLevel != null,
        description: 'device information reads to complete',
      );

      expect(device.isConnected, isTrue);
      expect(device.firmwareVersion, '1.1.0');
      expect(device.batteryLevel, 88);

      // The app subscribed to the async + sync TX characteristics.
      expect(
        click.subscriptions,
        containsAll([
          ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID.toLowerCase(),
          ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID.toLowerCase(),
        ]),
      );

      // The RideOn handshake reached the device's Sync RX characteristic.
      await IntegrationEnv.waitFor(() => click.writes.isNotEmpty, description: 'handshake write');
      final handshake = click.writes.firstWhere(
        (w) => w.characteristic.toLowerCase() == ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID.toLowerCase(),
      );
      expect(handshake.value.take(ZwiftConstants.RIDE_ON.length), ZwiftConstants.RIDE_ON);

      // It is listed as a controller, not as a trainer.
      expect(core.connection.controllerDevices, contains(device));
      expect(core.connection.proxyDevices, isEmpty);
    });

    test('Zwift Ride is classified from manufacturer data type 0x08', () async {
      final ride = buildZwiftRide();
      autoRespondToZwiftHandshake(env.ble, ride);
      env.ble.addPeripheral(ride);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftRide>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'Zwift Ride to connect');
      expect(device, isA<ZwiftRide>());
    });

    test('Shimano Di2 is classified by its service UUID', () async {
      env.ble.addPeripheral(buildShimanoDi2());

      await core.connection.performScanning();
      final device = await waitForDevice<ShimanoDi2>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'Di2 to connect');
      expect(device.isConnected, isTrue);
    });

    test('an FTMS trainer becomes a ProxyDevice but is NOT auto-connected without prior consent', () async {
      env.ble.addPeripheral(buildFtmsTrainer());

      await core.connection.performScanning();
      final device = await waitForDevice<ProxyDevice>();

      expect(device.isSmartTrainer, isTrue);
      // No auto-connect intent stored → stays disconnected; controller list
      // must not contain trainers.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(device.isConnected, isFalse);
      expect(core.connection.controllerDevices, isEmpty);
    });

    test('unknown devices and ignored names are not added', () async {
      env.ble.addPeripheral(
        FakePeripheral(deviceId: 'random', name: 'Random Gadget', advertisedServices: ['0000feed-0000-1000-8000-00805f9b34fb']),
      );
      // Power meters with ignored name prefixes are skipped even with a
      // Zwift-style service in the advertisement.
      env.ble.addPeripheral(
        FakePeripheral(
          deviceId: 'assioma',
          name: 'ASSIOMA12345',
          advertisedServices: [ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase()],
        ),
      );

      await core.connection.performScanning();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(core.connection.devices, isEmpty);
    });

    test('devices on the ignore list are filtered out of the scan', () async {
      await core.settings.addIgnoredDevice('fake-zwift-click', 'Zwift Click');
      final click = buildZwiftClick();
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(core.connection.devices, isEmpty);
    });
  });

  group('connection lifecycle', () {
    test('a dropped connection removes the device and updates state', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftClick>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'connect');

      env.ble.dropConnection(click.deviceId);
      await IntegrationEnv.waitFor(() => !device.isConnected, description: 'disconnect');
      await IntegrationEnv.waitFor(
        () => core.connection.devices.isEmpty,
        description: 'device removal after drop',
      );
    });

    test('the same device is not added twice across repeated scan results', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftClick>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'connect');

      // The same advertisement arriving again must be de-duplicated.
      env.ble.updateScanResult(click.scanResult);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(core.connection.devices.length, 1);
    });

    test('battery notifications update the device battery level', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftClick>();
      // Wait for the initial battery READ (88) so it can't race and overwrite
      // the notification value we are about to push.
      await IntegrationEnv.waitFor(() => device.batteryLevel == 88, description: 'initial battery read');

      env.ble.notify(click.deviceId, ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, zwiftBatteryNotification(55));
      await IntegrationEnv.waitFor(() => device.batteryLevel == 55, description: 'battery update');
    });

    test('disconnect with persistForget puts the device on the ignore list', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftClick>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'connect');

      await core.connection.disconnect(device, persistForget: true, forget: true);
      expect(core.connection.devices, isEmpty);
      expect(core.settings.getIgnoredDevices().map((d) => d.id), contains(click.deviceId));

      // Even a fresh scan result must not re-add the ignored device.
      env.ble.updateScanResult(
        BleDevice(
          deviceId: click.deviceId,
          name: click.name,
          services: click.advertisedServices,
          manufacturerDataList: [click.manufacturerData!],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(core.connection.devices, isEmpty);
    });
  });

  group('characteristic error handling', () {
    test('a notification for an unknown device id is logged, not crashing', () async {
      // No devices registered — push a stray notification through the
      // global onValueChange callback.
      env.ble.notify('ghost-device', ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, [0x15]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(core.connection.devices, isEmpty);
    });

    test('malformed protocol bytes do not break the connection', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftClick>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'connect');

      // Garbage in the click-notification envelope.
      env.ble.notify(click.deviceId, ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, [
        ZwiftConstants.CLICK_NOTIFICATION_MESSAGE_TYPE,
        0xDE,
        0xAD,
        0xBE,
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(device.isConnected, isTrue);

      // A valid press afterwards still works.
      env.ble.notify(
        click.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftClickNotification(plusPressed: true, minusPressed: false),
      );
      env.ble.notify(
        click.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftClickNotification(plusPressed: false, minusPressed: false),
      );
      await IntegrationEnv.waitFor(
        () => stubActions.performedActions.isNotEmpty,
        description: 'a performed action after garbage input',
      );
    });
  });
}
