import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/ltwoo/ltwoo_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

/// Appends the XOR checksum (XOR of all preceding bytes) to [body].
Uint8List frame(List<int> body) => Uint8List.fromList([...body, body.fold(0, (a, b) => a ^ b)]);

void main() {
  group('LtwooProtocol request framing', () {
    test('hello request with default PIN "000"', () {
      expect(
        LtwooProtocol.buildRequest('000', LtwooProtocol.opcodeHello),
        Uint8List.fromList([0xA5, 0x30, 0x30, 0x30, 0x46, 0x46, 0x46, 0x20, 0x01, 0x00, 0xF2]),
      );
    });

    test('rear-gear request with default PIN "000"', () {
      expect(
        LtwooProtocol.buildRequest('000', LtwooProtocol.opcodeGetRearGear),
        Uint8List.fromList([0xA5, 0x30, 0x30, 0x30, 0x46, 0x46, 0x46, 0x09, 0x00, 0xDA]),
      );
    });

    test('battery request with default PIN "000"', () {
      expect(
        LtwooProtocol.buildRequest('000', LtwooProtocol.opcodeGetBattery),
        Uint8List.fromList([0xA5, 0x30, 0x30, 0x30, 0x46, 0x46, 0x46, 0x0A, 0x00, 0xD9]),
      );
    });

    test('rear-gear request with custom PIN "199"', () {
      expect(
        LtwooProtocol.buildRequest('199', LtwooProtocol.opcodeGetRearGear),
        Uint8List.fromList([0xA5, 0x31, 0x39, 0x39, 0x46, 0x46, 0x46, 0x09, 0x00, 0xDB]),
      );
    });

    test('rear remote-shift requests with default PIN "000"', () {
      expect(
        LtwooProtocol.buildRequest('000', LtwooProtocol.opcodeShiftRearRawIncrease),
        Uint8List.fromList([0xA5, 0x30, 0x30, 0x30, 0x46, 0x46, 0x46, 0x00, 0x01, 0x00, 0xD2]),
      );
      expect(
        LtwooProtocol.buildRequest('000', LtwooProtocol.opcodeShiftRearRawDecrease),
        Uint8List.fromList([0xA5, 0x30, 0x30, 0x30, 0x46, 0x46, 0x46, 0x01, 0x01, 0x00, 0xD3]),
      );
    });
  });

  group('LtwooProtocol response parsing', () {
    test('valid rear-gear poll reply (pwd field 0xFFFFFF accepted)', () {
      final r = LtwooProtocol.parseResponse(frame([0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x09, 0x0A, 0x05]));
      expect(r, isNotNull);
      expect(r!.opcode, 0x090A);
      expect(r.payload, [0x05]);
      expect(r.isRearGear, isTrue);
      expect(r.isWrongPin, isFalse);
      expect(r.isFrontGear, isFalse);
      expect(r.isBattery, isFalse);
      expect(r.isHello, isFalse);
    });

    test('pwd field echoing the PIN is accepted', () {
      final r = LtwooProtocol.parseResponse(frame([0x5A, 0x30, 0x30, 0x30, 0x46, 0x46, 0x46, 0x09, 0x00, 0x04]));
      expect(r, isNotNull);
      expect(r!.isRearGear, isTrue);
      expect(r.payload, [0x04]);
    });

    test('event-frame opcode variant (0x00 0x09) parses as rear gear', () {
      final r = LtwooProtocol.parseResponse(frame([0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x00, 0x09, 0x05]));
      expect(r, isNotNull);
      expect(r!.isRearGear, isTrue);
      expect(r.payload, [0x05]);
    });

    test('hello response carries numSpeeds', () {
      final r = LtwooProtocol.parseResponse(frame([0x5A, 0x30, 0x30, 0x30, 0x46, 0x46, 0x46, 0x20, 0x01, 0x0C]));
      expect(r, isNotNull);
      expect(r!.isHello, isTrue);
      expect(r.payload.first, 12);
    });

    test('front-gear response', () {
      final r = LtwooProtocol.parseResponse(frame([0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x11, 0x00, 0x02]));
      expect(r, isNotNull);
      expect(r!.isFrontGear, isTrue);
      expect(r.payload, [0x02]);
    });

    test('battery response', () {
      final r = LtwooProtocol.parseResponse(frame([0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x0A, 0x01, 0x63]));
      expect(r, isNotNull);
      expect(r!.isBattery, isTrue);
      expect(r.payload.first, 99);
    });

    test('longer payload keeps payload[0] as the value', () {
      final r = LtwooProtocol.parseResponse(
        frame([0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x09, 0x0A, 0x09, 0x07, 0x3C, 0x00, 0xD0]),
      );
      expect(r, isNotNull);
      expect(r!.isRearGear, isTrue);
      expect(r.payload.first, 0x09);
    });

    test('bad XOR is rejected', () {
      final bytes = frame([0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x09, 0x0A, 0x05]);
      bytes[bytes.length - 1] ^= 0x01;
      expect(LtwooProtocol.parseResponse(bytes), isNull);
    });

    test('wrong header byte is rejected', () {
      expect(
        LtwooProtocol.parseResponse(frame([0xA5, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x09, 0x0A, 0x05])),
        isNull,
      );
    });

    test('wrong device-id field is rejected', () {
      expect(
        LtwooProtocol.parseResponse(frame([0x5A, 0xFF, 0xFF, 0xFF, 0x47, 0x46, 0x46, 0x09, 0x0A, 0x05])),
        isNull,
      );
    });

    test('too-short frame is rejected', () {
      expect(LtwooProtocol.parseResponse(Uint8List.fromList([0x5A, 0x46, 0x46])), isNull);
    });

    test('frame containing EE EE EE is a wrong-PIN reply', () {
      final r = LtwooProtocol.parseResponse(frame([0x5A, 0xEE, 0xEE, 0xEE, 0x46, 0x46, 0x46]));
      expect(r, isNotNull);
      expect(r!.isWrongPin, isTrue);
    });

    test('wrong-PIN reply is recognized even with an unknown trailer', () {
      // The wrong-PIN frame layout is not fully specified; the EE EE EE marker
      // alone (after the 0x5A header) must be enough.
      final r = LtwooProtocol.parseResponse(Uint8List.fromList([0x5A, 0xEE, 0xEE, 0xEE, 0x00]));
      expect(r, isNotNull);
      expect(r!.isWrongPin, isTrue);
    });
  });

  group('LtwooProtocol gear semantics', () {
    test('display gear counts from the smallest cog', () {
      // Raw gear counts from the LARGEST cog: raw 9 of 12 → display gear 4.
      expect(LtwooProtocol.displayGear(numSpeeds: 12, rawGear: 9), 4);
      expect(LtwooProtocol.displayGear(numSpeeds: 12, rawGear: 1), 12);
      expect(LtwooProtocol.displayGear(numSpeeds: 12, rawGear: 12), 1);
    });
  });
}
