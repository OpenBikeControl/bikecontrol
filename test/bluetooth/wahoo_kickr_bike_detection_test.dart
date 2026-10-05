import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_pro.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:universal_ble/universal_ble.dart';

/// A KICKR BIKE is one peripheral that is both a smart trainer and the host of
/// its own shifters. Scan-time classification must keep it on the shifter
/// class whatever trainer services it does or does not advertise — the trainer
/// role is attached at connect time from the discovered GATT database (see
/// `test/integration/kickr_bike_trainer_test.dart`), never by turning the bike
/// into a bare [ProxyDevice] here, which would lose its buttons.
void main() {
  core.actionHandler = StubActions();

  BleDevice scan(String name, {List<String> services = const []}) =>
      BleDevice(deviceId: 'id-$name', name: name, services: services);

  const trainerServices = [
    FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID,
    FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID,
  ];

  for (final web in [false, true]) {
    group(web ? 'web' : 'native', () {
      setUp(() => BluetoothDevice.debugIsWeb = () => web);
      tearDown(() => BluetoothDevice.debugIsWeb = null);

      test('KICKR BIKE without advertised trainer services is the shifter host', () {
        expect(BluetoothDevice.fromScanResult(scan('KICKR BIKE 1234')), isA<WahooKickrBikeShift>());
      });

      test('KICKR BIKE advertising FTMS + Cycling Power is still the shifter host, not a bare ProxyDevice', () {
        final device = BluetoothDevice.fromScanResult(scan('KICKR BIKE 1234', services: trainerServices));
        expect(device, isA<WahooKickrBikeShift>());
        expect(device, isNot(isA<ProxyDevice>()));
      });

      test('KICKR BIKE SHIFT is the shifter host too', () {
        expect(BluetoothDevice.fromScanResult(scan('KICKR BIKE SHIFT 1234')), isA<WahooKickrBikeShift>());
        expect(
          BluetoothDevice.fromScanResult(scan('KICKR BIKE SHIFT 1234', services: trainerServices)),
          isA<WahooKickrBikeShift>(),
        );
      });

      test('KICKR BIKE PRO is unchanged', () {
        expect(BluetoothDevice.fromScanResult(scan('KICKR BIKE PRO 1234')), isA<WahooKickrBikePro>());
      });
    });
  }
}
