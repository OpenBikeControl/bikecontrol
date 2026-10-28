import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

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

    test('an ignored device seen in the scan is reported as nearby, never added', () async {
      await core.settings.addIgnoredDevice('fake-zwift-click', 'Zwift Click');
      env.ble.addPeripheral(buildZwiftClick());

      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.ignoredDevicesNearby.value.isNotEmpty,
        description: 'the ignored Click to be reported nearby',
      );

      expect(core.connection.ignoredDevicesNearby.value, {'fake-zwift-click'});
      expect(core.connection.devices, isEmpty);
    });

    test('a new scan starts with no ignored devices nearby', () async {
      core.connection.ignoredDevicesNearby.value = {'stale-id'};

      await core.connection.performScanning();

      expect(core.connection.ignoredDevicesNearby.value, isEmpty);
    });

    test('un-ignoring a device drops it from the nearby set', () async {
      await core.settings.addIgnoredDevice('a', 'Zwift Click');
      await core.settings.addIgnoredDevice('b', 'Old remote');
      core.connection.ignoredDevicesNearby.value = {'a', 'b'};

      await core.settings.removeIgnoredDevice('a');

      expect(core.connection.ignoredDevicesNearby.value, {'b'});
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

    test('a controller disconnected for this session stays away when it advertises again', () async {
      final di2 = buildShimanoDi2();
      env.ble.addPeripheral(di2);

      await core.connection.performScanning();
      final device = await waitForDevice<ShimanoDi2>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'Di2 to connect');

      // The rider taps "Disconnect and forget for this session".
      await core.connection.disconnectForSession(device);
      expect(core.connection.devices, isEmpty);
      expect(core.settings.getIgnoredDevices(), isEmpty);

      // The Di2 keeps advertising, and the scan restarts (Bluetooth toggles,
      // an unlock-mode switch) — neither may bring it back.
      env.ble.updateScanResult(di2.scanResult);
      await core.connection.stop();
      await core.connection.performScanning();
      env.ble.updateScanResult(di2.scanResult);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        core.connection.devices.whereType<ShimanoDi2>(),
        isEmpty,
        reason: 'the Di2 reconnected right after the rider disconnected it',
      );

      // Connecting it on purpose still works, and lifts the hold.
      final again = BluetoothDevice.fromScanResult(di2.scanResult)!;
      core.connection.addDevices([again]);
      expect(core.connection.devices, isEmpty);
      await core.connection.connectDevice(again);
      core.connection.addDevices([again]);
      await IntegrationEnv.waitFor(() => again.isConnected, description: 'explicit reconnect');
    });

    test('a controller disconnected for inactivity is not auto-reconnected on rediscovery', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftClick>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'connect');

      // Battery-saver inactivity disconnect (the timeout path).
      core.connection.debugTriggerInactivityTimeout();
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().isEmpty,
        description: 'controller removed after inactivity disconnect',
      );

      // The controller is still advertising/bonded, so it gets rediscovered
      // (here a getSystemDevices-style re-add through addDevices). It must NOT
      // auto-reconnect — that would defeat the battery saver.
      core.connection.addDevices([BluetoothDevice.fromScanResult(click.scanResult)!]);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        core.connection.devices.whereType<ZwiftClick>(),
        isEmpty,
        reason: 'controller auto-reconnected after the battery-saver disconnect',
      );
    });

    test('the battery-saver Reconnect action clears the suppression and reconnects', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftClick>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'connect');

      // The only notification carrying an onTap is the battery-saver alert's
      // Reconnect action — capture it so we can drive the real user path.
      AlertNotification? reconnectAlert;
      final sub = core.connection.actionStream.listen((n) {
        if (n is AlertNotification && n.onTap != null) reconnectAlert = n;
      });
      addTearDown(sub.cancel);

      core.connection.debugTriggerInactivityTimeout();
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().isEmpty,
        description: 'controller removed after inactivity disconnect',
      );
      await IntegrationEnv.waitFor(
        () => reconnectAlert != null,
        description: 'a battery-saver alert exposing a Reconnect action',
      );

      // Tapping Reconnect lifts the suppression and re-adds the controller, so
      // it must come back instead of staying parked for battery.
      reconnectAlert!.onTap!();
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().any((d) => d.isConnected),
        description: 'controller reconnects after tapping Reconnect',
      );
    });

    test('after the reconnect cooldown a rediscovered controller auto-reconnects', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftClick>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'connect');

      // Shrink the cooldown so the test doesn't wait 90 real seconds (still
      // generous: the fake disconnect flow takes a few hundred ms).
      // core.connection is shared across the file — restore the default so
      // later tests keep the real suppression behavior.
      core.connection.inactivityReconnectCooldown = const Duration(seconds: 1);
      addTearDown(() => core.connection.inactivityReconnectCooldown = const Duration(seconds: 90));
      core.connection.debugTriggerInactivityTimeout();
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().isEmpty,
        description: 'controller removed after inactivity disconnect',
      );

      // Inside the cooldown window the suppression still holds.
      core.connection.addDevices([BluetoothDevice.fromScanResult(click.scanResult)!]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        core.connection.devices.whereType<ZwiftClick>(),
        isEmpty,
        reason: 'controller reconnected during the cooldown window',
      );

      // Once the cooldown elapsed, rediscovery must reconnect normally again.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      core.connection.addDevices([BluetoothDevice.fromScanResult(click.scanResult)!]);
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().any((d) => d.isConnected),
        description: 'controller reconnects after the cooldown',
      );
    });

    test('a woken controller reconnects via the scan path after the cooldown', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      final device = await waitForDevice<ZwiftClick>();
      await IntegrationEnv.waitFor(() => device.isConnected, description: 'connect');

      core.connection.inactivityReconnectCooldown = const Duration(seconds: 1);
      addTearDown(() => core.connection.inactivityReconnectCooldown = const Duration(seconds: 90));
      core.connection.debugTriggerInactivityTimeout();
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().isEmpty,
        description: 'controller removed after inactivity disconnect',
      );

      // Right after the disconnect the controller is still awake and
      // advertises: the advertisement lands in the _lastScanResult dedup list
      // while the suppression drops the device. This stale entry used to block
      // every later advertisement from ever reaching addDevices (issue #329,
      // zerkms's repro: stuck "scanning" until an app restart).
      env.ble.updateScanResult(click.scanResult);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        core.connection.devices.whereType<ZwiftClick>(),
        isEmpty,
        reason: 'controller reconnected during the cooldown window',
      );

      // The controller sleeps, the cooldown elapses, the rider wakes it with a
      // button press -> a fresh advertisement must reconnect it via the scan
      // path (no explicit Reconnect tap, no app restart).
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      env.ble.updateScanResult(click.scanResult);
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().any((d) => d.isConnected),
        description: 'controller reconnects via scan after the cooldown',
      );
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
