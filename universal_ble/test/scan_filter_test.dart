import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/src/universal_ble_filter_util.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  final universalBleFilter = UniversalBleFilterUtil();
  var device1 = BleDevice(
    deviceId: '1',
    name: '1_device',
    services: ['1_ser'],
    manufacturerDataList: [
      ManufacturerData(0x01, Uint8List.fromList([1, 2, 3])),
    ],
  );
  var device2 = BleDevice(
    deviceId: '2',
    name: '2_device',
    services: ['2_ser'],
    manufacturerDataList: [
      ManufacturerData(0x02, Uint8List.fromList([1, 2, 3]))
    ],
  );
  var device3 = BleDevice(
    deviceId: '3',
    name: '3_device',
    services: ['3_ser'],
    manufacturerDataList: [
      ManufacturerData(0x03, Uint8List.fromList([1, 2, 3]))
    ],
  );

  group("Test Individual Filter", () {
    test('Test isNameMatchingFilters', () {
      var scanFilter = ScanFilter(
        withNamePrefix: ['1', '2'],
      );
      expect(
        universalBleFilter.nameMatches(scanFilter, device1),
        isTrue,
      );
      expect(
        universalBleFilter.nameMatches(scanFilter, device2),
        isTrue,
      );
      expect(
        universalBleFilter.nameMatches(scanFilter, device3),
        isFalse,
      );
    });

    test('Test isServicesMatchingFilters', () {
      var scanFilter = ScanFilter(
        withServices: ['1_ser', 'random', '3_ser'],
      );
      expect(
        universalBleFilter.servicesMatch(scanFilter, device1),
        isTrue,
      );
      expect(
        universalBleFilter.servicesMatch(scanFilter, device2),
        isFalse,
      );
      expect(
        universalBleFilter.nameMatches(scanFilter, device3),
        isTrue,
      );
    });

    test('Test isManufacturerDataMatchingFilters', () {
      var scanFilter = ScanFilter(withManufacturerData: [
        ManufacturerDataFilter(
          companyIdentifier: 0x01,
          payloadPrefix: Uint8List.fromList([1, 2]),
        ),
        ManufacturerDataFilter(
          companyIdentifier: 0x02,
        ),
        ManufacturerDataFilter(
          companyIdentifier: 0x03,
          payloadPrefix: Uint8List.fromList([3, 4]),
        )
      ]);
      expect(
        universalBleFilter.manufacturerDataMatches(
          scanFilter,
          device1,
        ),
        isTrue,
      );
      expect(
        universalBleFilter.manufacturerDataMatches(
          scanFilter,
          device2,
        ),
        isTrue,
      );
      expect(
        universalBleFilter.manufacturerDataMatches(
          scanFilter,
          device3,
        ),
        isFalse,
      );
    });
  });

  group("Test Scan Filter", () {
    test('Test filterDevice: Have filter for all', () {
      universalBleFilter.scanFilter = ScanFilter(
        withNamePrefix: ['1'],
        withServices: ['3_ser'],
        withManufacturerData: [
          ManufacturerDataFilter(
            companyIdentifier: 0x02,
          )
        ],
      );
      expect(
        universalBleFilter.matchesDevice(device1),
        isTrue,
      );
      expect(
        universalBleFilter.matchesDevice(device2),
        isTrue,
      );
      expect(
        universalBleFilter.matchesDevice(device3),
        isTrue,
      );
    });
    test('Test filterDevice: Filter for one', () {
      universalBleFilter.scanFilter = ScanFilter(
        withNamePrefix: ['1'],
      );
      expect(
        universalBleFilter.matchesDevice(device1),
        isTrue,
      );
      expect(
        universalBleFilter.matchesDevice(device2),
        isFalse,
      );
      expect(
        universalBleFilter.matchesDevice(device3),
        isFalse,
      );
    });
    test('Test filterDevice: Filter for two', () {
      universalBleFilter.scanFilter = ScanFilter(
        withNamePrefix: ['1', '2'],
      );
      expect(
        universalBleFilter.matchesDevice(device1),
        isTrue,
      );
      expect(
        universalBleFilter.matchesDevice(device2),
        isTrue,
      );
      expect(
        universalBleFilter.matchesDevice(device3),
        isFalse,
      );
    });
    test('Test filterDevice: Empty Filter', () {
      universalBleFilter.scanFilter = ScanFilter();
      expect(
        universalBleFilter.matchesDevice(device1),
        isTrue,
      );
      expect(
        universalBleFilter.matchesDevice(device2),
        isTrue,
      );
      expect(
        universalBleFilter.matchesDevice(device3),
        isTrue,
      );
    });
    test('Test filterDevice: Null Filter', () {
      universalBleFilter.scanFilter = ScanFilter();
      expect(
        universalBleFilter.matchesDevice(device1),
        isTrue,
      );
      expect(
        universalBleFilter.matchesDevice(device2),
        isTrue,
      );
      expect(
        universalBleFilter.matchesDevice(device3),
        isTrue,
      );
    });
  });
}
