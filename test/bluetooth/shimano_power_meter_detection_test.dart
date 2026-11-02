import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_power_device.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

/// Shimano's crank power meters (FC-R8100-P, FC-R9200-P, …) advertise the
/// E-TUBE config service 18FF like every E-TUBE device, but not the D-FLY
/// service 18EF a Di2 needs. Classified as a Di2 they failed every connect
/// with "Service not found: 000018ef…"; their Cycling Power advert was
/// bridged as a trainer. They must be power meters.
void main() {
  core.actionHandler = StubActions();

  final etube = ShimanoDi2Constants.SERVICE_UUID_ALTERNATIVE.toLowerCase();
  final dfly = ShimanoDi2Constants.SERVICE_UUID.toLowerCase();
  final cps = BleSensorSource.cyclingPowerServiceUuid;

  BleDevice scan(String name, List<String> services) => BleDevice(deviceId: 'id-$name', name: name, services: services);

  for (final web in [false, true]) {
    group(web ? 'web' : 'native', () {
      setUp(() => BluetoothDevice.debugIsWeb = () => web);
      tearDown(() => BluetoothDevice.debugIsWeb = null);

      test('an Ultegra power meter advertising only E-TUBE is a power meter, not a Di2', () {
        expect(BluetoothDevice.fromScanResult(scan('FCR8100P173', [etube])), isA<BlePowerDevice>());
      });

      test('an Ultegra power meter advertising Cycling Power is a power meter, not a trainer', () {
        expect(BluetoothDevice.fromScanResult(scan('FCR8100P173', [cps])), isA<BlePowerDevice>());
      });

      test('a Dura-Ace power meter advertising E-TUBE and Cycling Power is a power meter', () {
        expect(BluetoothDevice.fromScanResult(scan('FCR9200P042', [etube, cps])), isA<BlePowerDevice>());
      });
    });
  }

  group('native Di2 detection is unchanged', () {
    test('a wireless Di2 unit advertising D-FLY and E-TUBE is a Di2', () {
      expect(BluetoothDevice.fromScanResult(scan('RDR7150 1234', [dfly, etube])), isA<ShimanoDi2>());
    });

    test('a Di2 unit advertising only E-TUBE is still a Di2', () {
      expect(BluetoothDevice.fromScanResult(scan('Liv     DAE', [etube])), isA<ShimanoDi2>());
    });
  });
}
