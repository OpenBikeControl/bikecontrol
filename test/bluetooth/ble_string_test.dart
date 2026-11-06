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

  test('malformed UTF-8 tails preserve the valid Chinese prefix', () {
    expect(decodeBleDeviceInfoString([...utf8.encode('迈金'), 0x80, 0xFF]), '迈金');
  });

  test('ASCII after the first malformed sequence is not appended to the firmware version', () {
    for (final tail in [
      [0x80, 0x41],
      [0xE2, 0x41],
      [0xE2, 0x82, 0x41],
      [0xC0, 0xAF, 0x41],
      [0xED, 0xA0, 0x80, 0x41],
      [0xF4, 0x90, 0x80, 0x80, 0x41],
      [0xFF, 0x41],
    ]) {
      expect(decodeBleDeviceInfoString([...'0.105'.codeUnits, ...tail]), '0.105', reason: '$tail');
    }
  });

  test('incomplete multibyte tails preserve the valid Unicode prefix', () {
    for (final tail in [
      [0xC2],
      [0xE2, 0x82],
      [0xF0, 0x9F, 0x92],
    ]) {
      expect(decodeBleDeviceInfoString([...utf8.encode('迈金🚴'), ...tail]), '迈金🚴', reason: '$tail');
    }
  });

  test('valid replacement characters do not truncate subsequent device information', () {
    final name = utf8.encode('迈\uFFFD金');
    expect(decodeBleDeviceInfoString(name), '迈金');
    expect(decodeBleDeviceInfoString([...name, 0x80]), '迈金');
  });

  test('malformed leading bytes do not expose subsequent ASCII as device information', () {
    expect(decodeBleDeviceInfoString([0x80, ...'0.105'.codeUnits]), isNull);
  });

  test('returns null for an empty or padding-only buffer', () {
    expect(decodeBleDeviceInfoString(const []), isNull);
    expect(decodeBleDeviceInfoString([0, 0, 0xFF]), isNull);
    expect(decodeBleDeviceInfoString([0xFF, 0xFF]), isNull);
  });
}
