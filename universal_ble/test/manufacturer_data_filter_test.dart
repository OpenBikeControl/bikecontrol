import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/src/universal_ble_filter_util.dart';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

void main() {
  group('ManufacturerData Matching Tests', () {
    late UniversalBleFilterUtil filterUtil;
    late ScanFilter scanFilter;
    late BleDevice device;

    setUp(() {
      filterUtil = UniversalBleFilterUtil();
      scanFilter = ScanFilter(
        withNamePrefix: [],
        withServices: [],
        withManufacturerData: [],
      );
    });

    test('should match when no manufacturer filters are present', () {
      device = BleDevice(
        deviceId: '1',
        name: 'Test Device',
        manufacturerDataList: [],
        services: [],
      );

      expect(filterUtil.manufacturerDataMatches(scanFilter, device), true);
    });

    test('should not match when device has no manufacturer data', () {
      scanFilter = ScanFilter(
        withNamePrefix: [],
        withServices: [],
        withManufacturerData: [
          ManufacturerDataFilter(companyIdentifier: 0x004C),
        ],
      );

      device = BleDevice(
        deviceId: '1',
        name: 'Test Device',
        manufacturerDataList: [],
        services: [],
      );

      expect(filterUtil.manufacturerDataMatches(scanFilter, device), false);
    });

    test(
        'should match when company identifiers are equal and no payload prefix',
        () {
      scanFilter = ScanFilter(
        withNamePrefix: [],
        withServices: [],
        withManufacturerData: [
          ManufacturerDataFilter(companyIdentifier: 0x004C),
        ],
      );

      device = BleDevice(
        deviceId: '1',
        name: 'Test Device',
        manufacturerDataList: [
          ManufacturerData(0x004C, Uint8List.fromList([])),
        ],
        services: [],
      );

      expect(filterUtil.manufacturerDataMatches(scanFilter, device), true);
    });

    group('Payload Prefix Tests', () {
      test('should match when payload prefix matches start of payload', () {
        scanFilter = ScanFilter(
          withNamePrefix: [],
          withServices: [],
          withManufacturerData: [
            ManufacturerDataFilter(
              companyIdentifier: 0x004C,
              payloadPrefix: Uint8List.fromList([0x01, 0x02]),
            ),
          ],
        );

        device = BleDevice(
          deviceId: '1',
          name: 'Test Device',
          manufacturerDataList: [
            ManufacturerData(0x004C, Uint8List.fromList([0x01, 0x02, 0x03])),
          ],
          services: [],
        );

        expect(filterUtil.manufacturerDataMatches(scanFilter, device), true);
      });

      test('should match with multiple manufacturer data entries', () {
        scanFilter = ScanFilter(
          withNamePrefix: [],
          withServices: [],
          withManufacturerData: [
            ManufacturerDataFilter(
              companyIdentifier: 0x004D,
              payloadPrefix: Uint8List.fromList([0x01, 0x02]),
            ),
          ],
        );

        device = BleDevice(
          deviceId: '1',
          name: 'Test Device',
          manufacturerDataList: [
            ManufacturerData(0x004C, Uint8List.fromList([0x03, 0x04])),
            ManufacturerData(0x004D, Uint8List.fromList([0x01, 0x02, 0x03])),
          ],
          services: [],
        );

        expect(filterUtil.manufacturerDataMatches(scanFilter, device), true);
      });
    });

    group('Payload Mask Tests', () {
      test('should match when masked values are equal', () {
        scanFilter = ScanFilter(
          withNamePrefix: [],
          withServices: [],
          withManufacturerData: [
            ManufacturerDataFilter(
              companyIdentifier: 0x004C,
              payloadPrefix: Uint8List.fromList([0xFF, 0xFF]),
              payloadMask: Uint8List.fromList([0xF0, 0xF0]),
            ),
          ],
        );

        device = BleDevice(
          deviceId: '1',
          name: 'Test Device',
          manufacturerDataList: [
            ManufacturerData(0x004C, Uint8List.fromList([0xF5, 0xF8])),
          ],
          services: [],
        );

        expect(filterUtil.manufacturerDataMatches(scanFilter, device), true);
      });

      test('should not match when masked values are different', () {
        scanFilter = ScanFilter(
          withNamePrefix: [],
          withServices: [],
          withManufacturerData: [
            ManufacturerDataFilter(
              companyIdentifier: 0x004C,
              payloadPrefix: Uint8List.fromList([0xFF, 0xFF]),
              payloadMask: Uint8List.fromList([0xF0, 0xF0]),
            ),
          ],
        );

        device = BleDevice(
          deviceId: '1',
          name: 'Test Device',
          manufacturerDataList: [
            ManufacturerData(0x004C, Uint8List.fromList([0xE5, 0xF8])),
          ],
          services: [],
        );

        expect(filterUtil.manufacturerDataMatches(scanFilter, device), false);
      });
    });
  });
}
