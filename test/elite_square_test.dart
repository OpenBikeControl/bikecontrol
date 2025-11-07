import 'package:flutter_test/flutter_test.dart';

// Helper functions matching the Elite Square implementation
String extractButtonCode(String hexValue) {
  if (hexValue.length >= 14) {
    return hexValue.substring(6, 14);
  }
  return hexValue;
}

String extractRelevantPart(String fullValue) {
  return fullValue.length >= 14
      ? fullValue.substring(6, 14)
      : fullValue.substring(6);
}

String bytesToHex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  group('Elite Square Button Detection Tests', () {
    test('Should extract correct button code from hex string', () {
      // Test with actual dump data
      expect(extractButtonCode('030153000000020318f40101'), equals('00000002'));
      expect(extractButtonCode('030153000000010318f40101'), equals('00000001'));
      expect(extractButtonCode('030153000004000318f40101'), equals('00000400'));
      expect(extractButtonCode('030153000001000318f40101'), equals('00000100'));
      expect(extractButtonCode('030153000008000318f40101'), equals('00000800'));
      expect(extractButtonCode('030153000002000318f40101'), equals('00000200'));
      expect(extractButtonCode('030153000000000318f40101'), equals('00000000'));
    });

    test('Should detect button changes correctly', () {
      // Test that relevant part extraction is consistent with button code extraction

      final idleState = '030153000000000318f40101';
      final buttonPressed = '030153000000020318f40101';
      
      final idleRelevant = extractRelevantPart(idleState);
      final pressedRelevant = extractRelevantPart(buttonPressed);

      expect(idleRelevant, equals('00000000'));
      expect(pressedRelevant, equals('00000002'));
      expect(idleRelevant != pressedRelevant, isTrue);
    });

    test('Should handle button release correctly', () {
      // Simulate button press and release
      final states = [
        '030153000000000318f40101', // idle
        '030153000000020318f40101', // button pressed
        '030153000000000318f40101', // button released (back to idle)
      ];

      final parts = states.map(extractRelevantPart).toList();
      
      expect(parts[0], equals('00000000')); // idle
      expect(parts[1], equals('00000002')); // pressed
      expect(parts[2], equals('00000000')); // released
      
      // Verify state transitions
      expect(parts[0] != parts[1], isTrue);  // idle -> pressed
      expect(parts[1] != parts[2], isTrue);  // pressed -> released
      expect(parts[0] == parts[2], isTrue);  // back to idle
    });

    test('Should handle all button codes from mapping', () {
      // Test all button codes from the mapping
      final buttonCodes = {
        "00000200": "up",
        "00000100": "left",
        "00000800": "down",
        "00000400": "right",
        "00002000": "x",
        "00001000": "square",
        "00008000": "campagnoloLeft",
        "00004000": "leftBrake",
        "00000002": "leftShift1",
        "00000001": "leftShift2",
        "02000000": "y",
        "01000000": "a",
        "08000000": "b",
        "04000000": "z",
        "20000000": "circle",
        "10000000": "triangle",
        "80000000": "campagnoloRight",
        "40000000": "rightBrake",
        "00020000": "rightShift1",
        "00010000": "rightShift2",
      };

      // Verify all button codes are 8 characters
      for (final code in buttonCodes.keys) {
        expect(code.length, equals(8), reason: 'Button code $code should be 8 characters');
      }
    });

    test('Should convert bytes to hex correctly', () {
      // Test with sample data from the dump
      // 030153000000020318f40101 = [0x03, 0x01, 0x53, 0x00, 0x00, 0x00, 0x02, 0x03, 0x18, 0xf4, 0x01, 0x01]
      final bytes = [0x03, 0x01, 0x53, 0x00, 0x00, 0x00, 0x02, 0x03, 0x18, 0xf4, 0x01, 0x01];
      final hex = bytesToHex(bytes);
      
      expect(hex, equals('030153000000020318f40101'));
    });

    test('Should handle edge cases', () {
      // Test with short strings
      expect(extractRelevantPart('0123456789'), equals('6789'));
      expect(extractRelevantPart('012345'), equals(''));
      
      // Test with exact length
      expect(extractRelevantPart('01234567890123'), equals('67890123'));
    });
  });

  group('Elite Square Protocol Tests', () {
    test('Should recognize button press pattern', () {
      // According to the dump, the pattern is:
      // Base: 030153000000000318f40101
      // Byte positions 6-13 (8 chars) change to indicate button
      
      final baseHex = '030153000000000318f40101';
      final buttonHex = '030153000000020318f40101';
      
      // Extract the button part (positions 6-14)
      final baseButton = baseHex.substring(6, 14);
      final pressedButton = buttonHex.substring(6, 14);
      
      expect(baseButton, equals('00000000'));
      expect(pressedButton, equals('00000002'));
    });
  });
}
