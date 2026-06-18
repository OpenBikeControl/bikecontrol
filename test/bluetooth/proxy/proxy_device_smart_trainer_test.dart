import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  group('ProxyDevice._isSmartTrainer', () {
    test('FTMS-only scan result is treated as a smart trainer', () {
      final dev = ProxyDevice(BleDevice(
        deviceId: 'ftms',
        name: 'KICKR',
        services: const ['00001826-0000-1000-8000-00805f9b34fb'],
      ));
      expect(dev.isSmartTrainer, isTrue);
    });

    test('FE-C-only scan result is also treated as a smart trainer', () {
      final dev = ProxyDevice(BleDevice(
        deviceId: 'fec',
        name: 'X2Max',
        services: const ['6e40fec1-b5a3-f393-e0a9-e50e24dcca9e'],
      ));
      expect(dev.isSmartTrainer, isTrue);
    });

    test('Power-meter-only scan result (CPS) is NOT a smart trainer', () {
      final dev = ProxyDevice(BleDevice(
        deviceId: 'pm',
        name: 'Stages',
        services: const ['00001818-0000-1000-8000-00805f9b34fb'],
      ));
      expect(dev.isSmartTrainer, isFalse);
    });

    test('HR-only scan result is NOT a smart trainer', () {
      final dev = ProxyDevice(BleDevice(
        deviceId: 'hr',
        name: 'TICKR',
        services: const ['0000180d-0000-1000-8000-00805f9b34fb'],
      ));
      expect(dev.isSmartTrainer, isFalse);
    });

    test('UUID matching is case-insensitive', () {
      final dev = ProxyDevice(BleDevice(
        deviceId: 'fec-upper',
        name: 'X2Max',
        services: const ['6E40FEC1-B5A3-F393-E0A9-E50E24DCCA9E'],
      ));
      expect(dev.isSmartTrainer, isTrue);
    });
  });

  group('in-place disconnect → reconnect re-binds emulator state', () {
    test('reconnect re-mirrors the active emulator state into the UI wrappers', () async {
      final device = ProxyDevice(BleDevice(
        deviceId: 'ftms',
        name: 'KICKR',
        services: const ['00001826-0000-1000-8000-00805f9b34fb'],
      ));

      // First session: the active (proxy) emulator's "started" state mirrors
      // into the listenable the connection card binds to.
      device.emulator.isStarted.value = true;
      expect(device.isStartedListenable.value, isTrue);

      // In-place disconnect ("No connection"): resets the wrapper and detaches
      // the mirror listeners from the active emulator.
      await device.disconnect();
      expect(device.isStartedListenable.value, isFalse);

      // While detached, a later emulator "started" no longer reaches the
      // wrapper — this is the stuck-on-"connecting" state the user saw when
      // reconnecting Virtual Shifting after No connection.
      device.emulator.isStarted.value = true;
      expect(device.isStartedListenable.value, isFalse);

      // The reconnect path (startProxy) re-establishes the bindings, so the
      // emulator state mirrors into the wrapper again.
      device.debugRebindEmulatorState();
      expect(device.isStartedListenable.value, isTrue);
    });

    test('in-place disconnect keeps the device registered; a normal disconnect removes it', () async {
      final inPlace = ProxyDevice(BleDevice(
        deviceId: 'a',
        name: 'KICKR A',
        services: const ['00001826-0000-1000-8000-00805f9b34fb'],
      ));
      final normal = ProxyDevice(BleDevice(
        deviceId: 'b',
        name: 'KICKR B',
        services: const ['00001826-0000-1000-8000-00805f9b34fb'],
      ));
      core.connection.devices
        ..clear()
        ..addAll([inPlace, normal]);

      // "No connection" disconnects in place — the device must stay in the
      // registry so the open details page can reconnect the same object.
      // Without it the page's reference is orphaned and reconnect logs
      // "Device not found".
      await core.connection.disconnect(inPlace, forget: false, persistForget: false, keepInList: true);
      expect(core.connection.devices, contains(inPlace));

      // The Disconnect button (which also pops the page) removes it as before.
      await core.connection.disconnect(normal, forget: false, persistForget: false);
      expect(core.connection.devices, isNot(contains(normal)));
    });
  });
}
