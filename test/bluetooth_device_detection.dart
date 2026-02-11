import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_square.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  core.actionHandler = StubActions();

  group('Detect Zwift devices', () {
    test('Detect Zwift Play', () {
      final device = _createBleDevice(
        name: 'Zwift Play',
        manufacturerData: [
          ManufacturerData(ZwiftConstants.ZWIFT_MANUFACTURER_ID, Uint8List.fromList([ZwiftConstants.RC1_RIGHT_SIDE])),
        ],
        services: [ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase()],
      );
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<ZwiftPlay>());
    });

    test('Detect Zwift Ride', () {
      final device = _createBleDevice(
        name: 'Zwift Ride',
        manufacturerData: [
          ManufacturerData(ZwiftConstants.ZWIFT_MANUFACTURER_ID, Uint8List.fromList([ZwiftConstants.RIDE_LEFT_SIDE])),
        ],
        services: [ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase()],
      );
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<ZwiftRide>());
    });
    test('Detect Zwift Ride old firmware', () {
      final device = _createBleDevice(
        name: 'Zwift Ride',
        manufacturerData: [
          ManufacturerData(ZwiftConstants.ZWIFT_MANUFACTURER_ID, Uint8List.fromList([ZwiftConstants.RIDE_LEFT_SIDE])),
        ],
        services: [ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID.toLowerCase()],
      );
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<ZwiftRide>());
    });

    test('Detect Zwift Ride oldest firmware', () {
      final device = _createBleDevice(
        name: 'Zwift Ride',
        manufacturerData: [
          ManufacturerData(ZwiftConstants.ZWIFT_MANUFACTURER_ID, Uint8List.fromList([ZwiftConstants.RIDE_LEFT_SIDE])),
        ],
        services: [ZwiftConstants.ZWIFT_CUSTOM_SERVICE_SHORT_UUID.toLowerCase()],
      );
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<ZwiftRide>());
    });

    test('Detect Zwift Click V1', () {
      final device = _createBleDevice(
        name: 'Zwift Click',
        manufacturerData: [
          ManufacturerData(ZwiftConstants.ZWIFT_MANUFACTURER_ID, Uint8List.fromList([ZwiftConstants.BC1])),
        ],
        services: [ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase()],
      );
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<ZwiftClick>());
    });

    test('Detect Zwift Click V2', () {
      final device = _createBleDevice(
        name: 'Zwift Click',
        manufacturerData: [
          ManufacturerData(
            ZwiftConstants.ZWIFT_MANUFACTURER_ID,
            Uint8List.fromList([ZwiftConstants.CLICK_V2_LEFT_SIDE]),
          ),
        ],
        services: [ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase()],
      );
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<ZwiftClickV2>());
    });
  });

  group('Detect Elite devices', () {
    test('Elite Square', () {
      final device = _createBleDevice(name: 'SQUARE 1337');
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<EliteSquare>());
    });
    test('Elite Sterzo', () {
      final device = _createBleDevice(name: 'STERZO 1337');
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<EliteSterzo>());
    });
  });

  group('Detect Wahoo devices', () {
    test('Kickr Bike Shift', () {
      final device = _createBleDevice(name: '133 KICKR BIKE SHIFT 133');
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<WahooKickrBikeShift>());
    });
  });

  group('Detect Cycplus devices', () {
    test('Cycplus BC2', () {
      final device = _createBleDevice(name: 'Cycplus BC2');
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<CycplusBc2>());
    });
    test('Other cycplus', () {
      final device = _createBleDevice(name: 'Cycplus 1337');
      expect(BluetoothDevice.fromScanResult(device), isNull);
    });
  });

  group('Detect Shimano Di2', () {
    test('Shimano Di2', () {
      final device = _createBleDevice(name: 'RDR 1337', services: [ShimanoDi2Constants.SERVICE_UUID.toLowerCase()]);
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<ShimanoDi2>());
    });
  });

  group('Skip powermeters', () {
    test('Skip Favero Assioma', () {
      final device = _createBleDevice(name: 'Assioma 133', services: [SramAxsConstants.SERVICE_UUID]);
      expect(BluetoothDevice.fromScanResult(device), isNull);
    });
    test('Skip QUARQ', () {
      final device = _createBleDevice(name: 'QUARQ 133', services: [SramAxsConstants.SERVICE_UUID]);
      expect(BluetoothDevice.fromScanResult(device), isNull);
    });
  });
}

BleDevice _createBleDevice({
  required String name,
  List<ManufacturerData> manufacturerData = const <ManufacturerData>[],
  List<String> services = const [],
}) {
  return BleDevice(
    deviceId: '1337',
    name: name,
    manufacturerDataList: manufacturerData,
    services: services,
  );
}
