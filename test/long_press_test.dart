import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

void main() {
  group('Long Press KeyPair Tests', () {
    test('KeyPair should encode and decode isLongPress property', () {
      // Create a KeyPair with long press enabled
      final keyPair = KeyPair(
        buttons: [ControllerButton.a],
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        isLongPress: true,
      );

      // Encode the KeyPair
      final encoded = keyPair.encode();

      // Decode the KeyPair
      final decoded = KeyPair.decode(encoded);

      // Verify the decoded KeyPair has the correct properties
      expect(decoded, isNotNull);
      expect(decoded!.isLongPress, true);
      expect(decoded.buttons, equals([ControllerButton.a]));
      expect(decoded.physicalKey, equals(PhysicalKeyboardKey.keyA));
      expect(decoded.logicalKey, equals(LogicalKeyboardKey.keyA));
    });

    test('KeyPair should default isLongPress to false when not specified in decode', () {
      // Create a legacy encoded KeyPair without isLongPress property
      const legacyEncoded = '''
      {
        "actions": ["a"],
        "logicalKey": "97",
        "physicalKey": "458752",
        "touchPosition": {"x": 0.0, "y": 0.0}
      }
      ''';

      // Decode the legacy KeyPair
      final decoded = KeyPair.decode(legacyEncoded);

      // Verify the decoded KeyPair defaults isLongPress to false
      expect(decoded, isNotNull);
      expect(decoded!.isLongPress, false);
    });

    test('KeyPair constructor should default isLongPress to false', () {
      final keyPair = KeyPair(
        buttons: [ControllerButton.a],
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
      );

      expect(keyPair.isLongPress, false);
    });

    test('KeyPair should correctly encode isLongPress false', () {
      final keyPair = KeyPair(
        buttons: [ControllerButton.a],
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        isLongPress: false,
      );

      final encoded = keyPair.encode();
      final decoded = KeyPair.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.isLongPress, false);
    });
  });
}
