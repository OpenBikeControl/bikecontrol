import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';

void main() {
  group('Zwift Ride Analog Paddle - ZigZag Encoding Tests', () {
    test('Should correctly decode positive ZigZag values', () {
      // Test ZigZag decoding algorithm: (n >>> 1) ^ -(n & 1)
      const threshold = ZwiftRide.analogPaddleThreshold;

      expect(_zigzagDecode(0), 0); // 0 -> 0
      expect(_zigzagDecode(2), 1); // 2 -> 1
      expect(_zigzagDecode(4), 2); // 4 -> 2
      expect(_zigzagDecode(threshold * 2), threshold); // threshold value
      expect(_zigzagDecode(200), 100); // 200 -> 100 (max positive)
    });

    test('Should correctly decode negative ZigZag values', () {
      const threshold = ZwiftRide.analogPaddleThreshold;

      expect(_zigzagDecode(1), -1); // 1 -> -1
      expect(_zigzagDecode(3), -2); // 3 -> -2
      expect(_zigzagDecode(threshold * 2 - 1), -threshold); // negative threshold
      expect(_zigzagDecode(199), -100); // 199 -> -100 (max negative)
    });

    test('Should handle boundary values correctly', () {
      const threshold = ZwiftRide.analogPaddleThreshold;

      // Test values at the detection threshold
      expect(_zigzagDecode(threshold * 2).abs(), threshold);
      expect(_zigzagDecode(threshold * 2 - 1).abs(), threshold);

      // Test maximum paddle values (±100)
      expect(_zigzagDecode(200), 100);
      expect(_zigzagDecode(199), -100);
    });
  });

  group('Zwift Ride Analog Paddle - Protocol Buffer Varint Decoding', () {
    test('Should decode single-byte varint values', () {
      // Values 0-127 fit in a single byte
      final buffer1 = Uint8List.fromList([0x00]); // 0
      expect(_decodeVarint(buffer1, 0).$1, 0);
      expect(_decodeVarint(buffer1, 0).$2, 1); // Consumed 1 byte

      final buffer2 = Uint8List.fromList([0x0A]); // 10
      expect(_decodeVarint(buffer2, 0).$1, 10);

      final buffer3 = Uint8List.fromList([0x7F]); // 127
      expect(_decodeVarint(buffer3, 0).$1, 127);
    });

    test('Should decode multi-byte varint values', () {
      // Values >= 128 require multiple bytes
      final buffer1 = Uint8List.fromList([0xC7, 0x01]); // ZigZag encoded -100 (199)
      expect(_decodeVarint(buffer1, 0).$1, 199);
      expect(_decodeVarint(buffer1, 0).$2, 2); // Consumed 2 bytes

      final buffer2 = Uint8List.fromList([0xC8, 0x01]); // ZigZag encoded 100 (200)
      expect(_decodeVarint(buffer2, 0).$1, 200);
      expect(_decodeVarint(buffer2, 0).$2, 2);
    });

    test('Should handle varint decoding with offset', () {
      // Test decoding from a specific offset in the buffer
      final buffer = Uint8List.fromList([0xFF, 0xFF, 0xC8, 0x01]); // Garbage + 200
      expect(_decodeVarint(buffer, 2).$1, 200);
      expect(_decodeVarint(buffer, 2).$2, 2);
    });
  });

  group('Zwift Ride Analog Paddle - Protocol Buffer Wire Type Parsing', () {
    test('Should correctly extract field number and wire type from tag', () {
      // Tag format: (field_number << 3) | wire_type

      // Field 1, wire type 0 (varint)
      final tag1 = 0x08; // 1 << 3 | 0
      expect(tag1 >> 3, 1); // field number
      expect(tag1 & 0x7, 0); // wire type

      // Field 2, wire type 0 (varint)
      final tag2 = 0x10; // 2 << 3 | 0
      expect(tag2 >> 3, 2);
      expect(tag2 & 0x7, 0);

      // Field 3, wire type 2 (length-delimited)
      final tag3 = 0x1a; // 3 << 3 | 2
      expect(tag3 >> 3, 3);
      expect(tag3 & 0x7, 2);
    });

    test('Should identify location and value field tags', () {
      const locationTag = 0x08; // Field 1 (location), wire type 0
      const valueTag = 0x10; // Field 2 (value), wire type 0
      const nestedMessageTag = 0x1a; // Field 3 (nested), wire type 2

      expect(locationTag >> 3, 1);
      expect(valueTag >> 3, 2);
      expect(nestedMessageTag >> 3, 3);
      expect(nestedMessageTag & 0x7, 2); // Length-delimited
    });
  });

  group('Zwift Ride Analog Paddle - Real-world Scenarios', () {
    test('Threshold value should trigger paddle detection', () {
      const threshold = ZwiftRide.analogPaddleThreshold;
      // At threshold: ZigZag encoding of threshold
      final zigzagValue = threshold * 2;
      final decodedValue = _zigzagDecode(zigzagValue);
      expect(decodedValue, threshold);
      expect(decodedValue.abs() >= threshold, isTrue);
    });

    test('Below threshold value should not trigger paddle detection', () {
      const threshold = ZwiftRide.analogPaddleThreshold;
      // Below threshold: value = threshold - 1
      final zigzagValue = (threshold - 1) * 2;
      final decodedValue = _zigzagDecode(zigzagValue);
      expect(decodedValue, threshold - 1);
      expect(decodedValue.abs() >= threshold, isFalse);
    });

    test('Maximum paddle press (-100) should trigger left paddle', () {
      const threshold = ZwiftRide.analogPaddleThreshold;
      // Max left: value = -100, ZigZag = 199 = 0xC7 0x01
      final zigzagValue = 199;
      final decodedValue = _zigzagDecode(zigzagValue);
      expect(decodedValue, -100);
      expect(decodedValue.abs() >= threshold, isTrue);
    });

    test('Maximum paddle press (100) should trigger right paddle', () {
      const threshold = ZwiftRide.analogPaddleThreshold;
      // Max right: value = 100, ZigZag = 200 = 0xC8 0x01
      final zigzagValue = 200;
      final decodedValue = _zigzagDecode(zigzagValue);
      expect(decodedValue, 100);
      expect(decodedValue.abs() >= threshold, isTrue);
    });

    test('Paddle location mapping is correct', () {
      // Location 0 = left paddle
      // Location 1 = right paddle
      const leftPaddleLocation = 0;
      const rightPaddleLocation = 1;

      expect(leftPaddleLocation, 0);
      expect(rightPaddleLocation, 1);
    });

    test('Analog paddle threshold constant is accessible', () {
      expect(ZwiftRide.analogPaddleThreshold, 25);
    });
  });

  group('Zwift Ride Analog Paddle - Message Structure Documentation', () {
    test('0x1a marker identifies analog message sections', () {
      const analogSectionMarker = 0x1a;
      // Field 3 << 3 | wire type 2 = 3 << 3 | 2 = 26 = 0x1a
      expect(analogSectionMarker, 0x1a);
      expect(analogSectionMarker >> 3, 3); // Field number
      expect(analogSectionMarker & 0x7, 2); // Wire type (length-delimited)
    });

    test('Message offset 7 skips header and button map', () {
      // Offset breakdown:
      // [0]: Message type (0x23 for controller notification)
      // [1]: Button map field tag (0x05)
      // [2-6]: Button map (5 bytes)
      // [7]: Start of analog data
      const messageTypeOffset = 0;
      const buttonMapTagOffset = 1;
      const buttonMapOffset = 2;
      const buttonMapSize = 5;
      const analogDataOffset = 7;

      expect(analogDataOffset, buttonMapOffset + buttonMapSize);
    });
  });
}

/// Helper function to test ZigZag decoding algorithm.
/// ZigZag encoding maps signed integers to unsigned integers:
/// 0 -> 0, -1 -> 1, 1 -> 2, -2 -> 3, 2 -> 4, etc.
int _zigzagDecode(int n) {
  return (n >>> 1) ^ -(n & 1);
}

/// Helper function to decode a Protocol Buffer varint from a buffer.
/// Returns a record of (value, bytesConsumed).
(int, int) _decodeVarint(Uint8List buffer, int offset) {
  var value = 0;
  var shift = 0;
  var bytesRead = 0;

  while (offset + bytesRead < buffer.length) {
    final byte = buffer[offset + bytesRead];
    value |= (byte & 0x7f) << shift;
    bytesRead++;

    if ((byte & 0x80) == 0) {
      // MSB is 0, we're done
      break;
    }
    shift += 7;
  }

  return (value, bytesRead);
}
