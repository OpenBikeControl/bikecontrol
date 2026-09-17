import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_square.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:bike_control/bluetooth/devices/ltwoo/ltwoo_erx.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/bluetooth/devices/wheeltop/wheeltop_eds.dart';
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

  // sensor-sources-phase2: `fromScanResult` used to hide ANY scan result
  // whose name matched a known power-meter brand — Favero Assioma, Quarq,
  // PowerCrank — universally, before any service-based dispatch ran at all
  // (hence these fixtures deliberately advertising an unrelated SRAM AXS
  // service, to prove the old hide applied regardless of what else the
  // device advertised). Selecting a source in the Sensors UI is the rider's
  // consent now (see `SensorQuantitySelector`), so there is no name-based
  // hide left anywhere in `fromScanResult` — a device with one of these
  // names resolves exactly like any other device, via whatever it actually
  // advertises.
  group('formerly-hidden power-meter names have no special effect any more', () {
    test('a Favero Assioma-named device is detected via its actual service, not hidden', () {
      final device = _createBleDevice(name: 'Assioma 133', services: [SramAxsConstants.SERVICE_UUID]);
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<SramAxs>());
    });
    test('a QUARQ-named device is detected via its actual service, not hidden', () {
      final device = _createBleDevice(name: 'QUARQ 133', services: [SramAxsConstants.SERVICE_UUID]);
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<SramAxs>());
    });
  });

  group('Detect L-TWOO eRX/eR9', () {
    test('eRX/eR9 derailleur by name', () {
      final device = _createBleDevice(name: 'LTOED2501AB12');
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<LtwooErx>());
    });
    test('lowercase advertised name still matches', () {
      final device = _createBleDevice(name: 'ltoed2501ab12');
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<LtwooErx>());
    });
    test('legacy LTOED00 model is excluded', () {
      final device = _createBleDevice(name: 'LTOED001234');
      expect(BluetoothDevice.fromScanResult(device), isNull);
    });
  });

  group('Detect Tacx Neo (name-only, empty advertisement)', () {
    test('Tacx Neo 2T with empty services/serviceData still detected as proxy', () {
      // Windows' universal_ble surfaces the Neo with an empty advertisement —
      // no services, no serviceData — so only the name is usable.
      final device = _createBleDevice(name: 'Tacx Neo 2T 48844');
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<ProxyDevice>());
    });

    test('lowercase advertised name still matches (case-insensitive)', () {
      final device = _createBleDevice(name: 'tacx neo 2t');
      expect(BluetoothDevice.fromScanResult(device), isInstanceOf<ProxyDevice>());
    });

    test('unrelated unknown name with empty services stays null', () {
      final device = _createBleDevice(name: 'Some Random Trainer');
      expect(BluetoothDevice.fromScanResult(device), isNull);
    });
  });

  group('Detect WHEELTOP EDS shifters', () {
    // Full advertisement: 07 0f 00 14 55 6a 84 | type | fw(2) | battery(2) | rest.
    // universal_ble splits the first two little-endian bytes off as the
    // company id (0x0F07), leaving the payload below.
    Uint8List payloadFor(int typeByte) => Uint8List.fromList([
      0x00, 0x14, 0x55, 0x6a, 0x84, typeByte, 0x02, 0x3a, 0x01, 0x24, 0x00, 0x00, 0x00,
    ]);

    BleDevice edsDevice(List<ManufacturerData> manufacturerData) =>
        BleDevice(deviceId: '1337', name: null, manufacturerDataList: manufacturerData);

    test('Detect OX with firmware and battery from the advertisement', () {
      final result = BluetoothDevice.fromScanResult(
        edsDevice([ManufacturerData(0x0F07, payloadFor(0x37))]),
      );
      expect(result, isInstanceOf<WheeltopEds>());
      final eds = result as WheeltopEds;
      expect(eds.edsType, WheeltopEdsType.ox);
      expect(eds.name, 'WHEELTOP EDS OX');
      expect(eds.firmwareVersion, '2.58');
      expect(eds.batteryCentivolts, 292);
    });

    test('Detect TX variants from the type byte', () {
      expect(
        (BluetoothDevice.fromScanResult(edsDevice([ManufacturerData(0x0F07, payloadFor(0x36))]))
                as WheeltopEds)
            .edsType,
        WheeltopEdsType.txLeft,
      );
      expect(
        (BluetoothDevice.fromScanResult(edsDevice([ManufacturerData(0x0F07, payloadFor(0x38))]))
                as WheeltopEds)
            .edsType,
        WheeltopEdsType.txRight,
      );
      expect(
        (BluetoothDevice.fromScanResult(edsDevice([ManufacturerData(0x0F07, payloadFor(0x39))]))
                as WheeltopEds)
            .edsType,
        WheeltopEdsType.txFront,
      );
    });

    test('Detect when the platform left the full prefix in the payload', () {
      final fullBytes = Uint8List.fromList([
        0x07, 0x0f, 0x00, 0x14, 0x55, 0x6a, 0x84, 0x37, 0x02, 0x3a, 0x01, 0x24, 0x00, 0x00, 0x00,
      ]);
      final result = BluetoothDevice.fromScanResult(
        edsDevice([ManufacturerData(0x0000, fullBytes)]),
      );
      expect(result, isInstanceOf<WheeltopEds>());
      expect((result as WheeltopEds).edsType, WheeltopEdsType.ox);
    });

    test('Reject wrong prefix, wrong company id, unknown type byte', () {
      final wrongPrefix = Uint8List.fromList([
        0x00, 0x99, 0x55, 0x6a, 0x84, 0x37, 0x02, 0x3a, 0x01, 0x24,
      ]);
      expect(
        BluetoothDevice.fromScanResult(edsDevice([ManufacturerData(0x0F07, wrongPrefix)])),
        isNull,
      );
      expect(
        BluetoothDevice.fromScanResult(edsDevice([ManufacturerData(0x1234, payloadFor(0x37))])),
        isNull,
      );
      expect(
        BluetoothDevice.fromScanResult(edsDevice([ManufacturerData(0x0F07, payloadFor(0x99))])),
        isNull,
      );
    });

    test('Detect from a truncated advertisement without firmware bytes', () {
      final truncated = Uint8List.fromList([0x00, 0x14, 0x55, 0x6a, 0x84, 0x37]);
      final result = BluetoothDevice.fromScanResult(
        edsDevice([ManufacturerData(0x0F07, truncated)]),
      );
      expect(result, isInstanceOf<WheeltopEds>());
      final eds = result as WheeltopEds;
      expect(eds.firmwareVersion, isNull);
      expect(eds.batteryCentivolts, isNull);
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
