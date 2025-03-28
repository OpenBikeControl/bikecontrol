import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  group('Parsing string', () {
    group('Succeeds', () {
      test('128-bit UUID in lowercase', () {
        expect(
          BleUuidParser.string('0000180a-0000-1000-8000-00805f9b34fb'),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });

      test('128-bit UUID in uppercase', () {
        expect(
          BleUuidParser.string('0000180A-0000-1000-8000-00805F9B34FB'),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });

      test('16-bit UUID in lowercase', () {
        expect(
          BleUuidParser.string('180a'),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });

      test('16-bit UUID in uppercase', () {
        expect(
          BleUuidParser.string('180A'),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });

      test('32-bit UUID', () {
        expect(
          BleUuidParser.string('0000180a'),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });

      test('UUID without dashes', () {
        expect(
          BleUuidParser.string('0000180a00001000800000805f9b34fb'),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });

      test('Lowercase 16-bit string to 128-bit starting with 0x', () {
        expect(
          BleUuidParser.string('0x0180a'),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });

      test('Uppercase 16-bit string to 128-bit starting with 0x', () {
        expect(
          BleUuidParser.string('0x0180A'),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });

      test('128-bit UUID with trailing space', () {
        expect(
          BleUuidParser.string('0000180a-0000-1000-8000-00805f9b34fb '),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });
    });
    group('Fails', () {
      test('Invalid UUID length is less than 4', () {
        expect(
          () => BleUuidParser.string('123'),
          throwsFormatException,
        );
      });

      test('Invalid UUID without dashes and short length', () {
        expect(
          () => BleUuidParser.string('0000180a00001000800000805f9b34'),
          throwsFormatException,
        );
      });

      test('Invalid UUID without dashes and long length', () {
        expect(
          () => BleUuidParser.string('0000180a00001000800000805f9b34fb34'),
          throwsFormatException,
        );
      });

      test('Invalid UUID is missing a dash', () {
        expect(
          () => BleUuidParser.string('0000180a-0000-1000-800000805f9b34fb'),
          throwsFormatException,
        );
      });

      test('Invalid UUID has too many dashes', () {
        expect(
          () => BleUuidParser.string('0000-180a-0000-1000-8000-0080-5f9b-34fb'),
          throwsFormatException,
        );
      });

      test('Invalid UUID is too short for 128 bits', () {
        expect(
          () => BleUuidParser.string('01'),
          throwsFormatException,
        );

        expect(
          () => BleUuidParser.string('0000180a-0000-1000-8000-00805f9b34f'),
          throwsFormatException,
        );
      });

      test('Invalid UUID is too long for 128 bits', () {
        expect(
          () => BleUuidParser.string('0000180a-0000-1000-8000-00805f9b34fba'),
          throwsFormatException,
        );
      });

      test('Invalid UUID contains non-hex characters', () {
        expect(
          () => BleUuidParser.string('0000180g-0000-1000-8000-00805f9b34fba'),
          throwsFormatException,
        );
      });
    });
  });

  group('Parsing number', () {
    group('Succeeds', () {
      test('16-bit UUID in lowercase', () {
        expect(
          BleUuidParser.number(0x180a),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });

      test('16-bit UUID in uppercase', () {
        expect(
          BleUuidParser.number(0x180A),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });

      test('32-bit UUID', () {
        expect(
          BleUuidParser.number(0x0000180A),
          equals('0000180a-0000-1000-8000-00805f9b34fb'),
        );
      });
    });
    group('Fails', () {
      test('Invalid UUID is 8 bits', () {
        expect(
          () => BleUuidParser.number(0x18),
          throwsFormatException,
        );
      });

      test('Invalid UUID is more than 32 bits', () {
        expect(
          () => BleUuidParser.number(0x180A01),
          throwsFormatException,
        );
      });
    });
  });

  group('CompareStrings', () {
    group('Succeeds', () {
      test('Identical UUIDs', () {
        expect(
          BleUuidParser.compareStrings('0000180a-0000-1000-8000-00805f9b34fb',
              '0000180a-0000-1000-8000-00805f9b34fb'),
          isTrue,
        );
      });

      test('UUIDs with different case', () {
        expect(
          BleUuidParser.compareStrings('180A', '180a'),
          isTrue,
        );
      });

      test('16-bit and 128-bit UUIDs', () {
        expect(
          BleUuidParser.compareStrings(
              '0000180a-0000-1000-8000-00805f9b34fb', '180a'),
          isTrue,
        );
      });

      test('16-bit and 128-bit UUIDs without dashes', () {
        expect(
          BleUuidParser.compareStrings(
              '0000180A00001000800000805F9B34FB', '180a'),
          isTrue,
        );
      });

      test('32-bit and 128-bit UUIDs', () {
        expect(
          BleUuidParser.compareStrings(
              '0000180A', '0000180a-0000-1000-8000-00805f9b34fb'),
          isTrue,
        );
      });
    });

    group('Fails with', () {
      test('Different UUIDs', () {
        expect(
          BleUuidParser.compareStrings('180A', '180B'),
          isFalse,
        );
      });

      test('Different UUIDs with different formats', () {
        expect(
          BleUuidParser.compareStrings(
              '0000180A', '0000180b-0000-1000-8000-00805f9b34fb'),
          isFalse,
        );
      });
    });
  });
}
