import 'dart:convert';

import 'package:bike_control/bluetooth/ble_string.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a plain firmware version', () {
    expect(decodeBleDeviceInfoString('1.2.0'.codeUnits), '1.2.0');
    expect(decodeBleDeviceInfoString('0.105'.codeUnits), '0.105');
  });

  test('drops NUL padding that would render as tofu', () {
    expect(
      decodeBleDeviceInfoString([...'0.105'.codeUnits, 0, 0, 0, 0, 0xFF, 0xFF]),
      '0.105',
    );
  });

  test('drops 0xFF fill and non-UTF-8 tails after the version', () {
    expect(decodeBleDeviceInfoString([...'0.105'.codeUnits, 0xFF, 0xFF, 0xFF]), '0.105');
    expect(
      decodeBleDeviceInfoString([...'0.105'.codeUnits, 0x80, 0x81, 0xFE, 0xFD]),
      '0.105',
    );
  });

  test('keeps a valid UTF-8 manufacturer name', () {
    final name = utf8.encode('迈金');
    expect(decodeBleDeviceInfoString(name), '迈金');
    expect(decodeBleDeviceInfoString([...name, 0, 0xFF]), '迈金');
  });

  test('returns null for an empty or padding-only buffer', () {
    expect(decodeBleDeviceInfoString(const []), isNull);
    expect(decodeBleDeviceInfoString([0, 0, 0xFF]), isNull);
    expect(decodeBleDeviceInfoString([0xFF, 0xFF]), isNull);
  });
}
