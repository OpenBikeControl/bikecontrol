import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

void main() {
  group('Percentage-based Keymap Tests', () {
    test('Should encode touch position as percentage when screen size provided', () {
      final screenSize = Size(1000, 2000);
      final keyPair = KeyPair(
        buttons: [ZwiftButton.leftButton],
        physicalKey: null,
        logicalKey: null,
        touchPosition: Offset(500, 1000), // 50% x, 50% y
      );

      final encoded = keyPair.encode(screenSize: screenSize);
      expect(encoded, contains('x_percent'));
      expect(encoded, contains('y_percent'));
      expect(encoded, contains('0.5')); // 50% as decimal
    });

    test('Should encode touch position as percentages with fallback when screen size not provided', () {
      final keyPair = KeyPair(
        buttons: [ZwiftButton.leftButton],
        physicalKey: null,
        logicalKey: null,
        touchPosition: Offset(960, 540), // Center of 1920x1080 fallback
      );

      final encoded = keyPair.encode();
      expect(encoded, contains('x_percent'));
      expect(encoded, contains('y_percent'));
      // Should use fallback screen size of 1920x1080
      expect(encoded, contains('0.5')); // 960/1920 and 540/1080 = 0.5
    });

    test('Should decode percentage-based touch position correctly', () {
      final screenSize = Size(1000, 2000);
      final encoded = '{"actions":["leftButton"],"logicalKey":"0","physicalKey":"0","touchPosition":{"x_percent":0.5,"y_percent":0.5},"isLongPress":false}';

      final keyPair = KeyPair.decode(encoded, screenSize: screenSize);
      expect(keyPair, isNotNull);
      expect(keyPair!.touchPosition.dx, 500);
      expect(keyPair.touchPosition.dy, 1000);
    });

    test('Should decode pixel-based touch position correctly (backward compatibility)', () {
      final encoded = '{"actions":["leftButton"],"logicalKey":"0","physicalKey":"0","touchPosition":{"x":300,"y":600},"isLongPress":false}';

      final keyPair = KeyPair.decode(encoded);
      expect(keyPair, isNotNull);
      expect(keyPair!.touchPosition.dx, 300);
      expect(keyPair.touchPosition.dy, 600);
    });

    test('Should handle zero touch position correctly', () {
      final screenSize = Size(1000, 2000);
      final keyPair = KeyPair(
        buttons: [ZwiftButton.leftButton],
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        touchPosition: Offset.zero,
      );

      final encoded = keyPair.encode(screenSize: screenSize);
      // Should encode as percentages even when position is zero
      expect(encoded, contains('x_percent'));
      expect(encoded, contains('y_percent'));
      expect(encoded, contains('0.0'));
    });

    test('Should scale touch position correctly across different screen sizes', () {
      // Original screen: 1000x2000
      final originalSize = Size(1000, 2000);
      final keyPair = KeyPair(
        buttons: [ZwiftButton.leftButton],
        physicalKey: null,
        logicalKey: null,
        touchPosition: Offset(250, 500), // 25% x, 25% y
      );

      // Encode on original screen
      final encoded = keyPair.encode(screenSize: originalSize);

      // Decode on different screen: 1920x1080
      final newSize = Size(1920, 1080);
      final decoded = KeyPair.decode(encoded, screenSize: newSize);

      expect(decoded, isNotNull);
      // Should be 25% of new screen size
      expect(decoded!.touchPosition.dx, closeTo(480, 1)); // 25% of 1920
      expect(decoded.touchPosition.dy, closeTo(270, 1)); // 25% of 1080
    });

    test('Should return Offset.zero when decoding percentage without screen size', () {
      final encoded = '{"actions":["leftButton"],"logicalKey":"0","physicalKey":"0","touchPosition":{"x_percent":0.5,"y_percent":0.5},"isLongPress":false}';

      final keyPair = KeyPair.decode(encoded);
      expect(keyPair, isNotNull);
      expect(keyPair!.touchPosition, Offset.zero);
    });
  });
}
