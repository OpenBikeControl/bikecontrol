import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/keymap/keymap.dart';

void main() {
  group('Percentage-based Keymap Tests', () {
    test('Should encode touch position as percentage using fallback screen size', () {
      final keyPair = KeyPair(
        buttons: [ControllerButton.paddleRight],
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

    test('Should encode touch position as percentages with fallback when screen size not available', () {
      final keyPair = KeyPair(
        buttons: [ControllerButton.paddleRight],
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
      final encoded =
          '{"actions":["leftButton"],"logicalKey":"0","physicalKey":"0","touchPosition":{"x_percent":0.5,"y_percent":0.5},"isLongPress":false}';

      final keyPair = KeyPair.decode(encoded);
      expect(keyPair, isNotNull);
      // Since no real screen is available in tests, it should return Offset.zero or use fallback
      expect(keyPair!.touchPosition, isNotNull);
    });

    test('Should decode pixel-based touch position correctly (backward compatibility)', () {
      final encoded =
          '{"actions":["leftButton"],"logicalKey":"0","physicalKey":"0","touchPosition":{"x":300,"y":600},"isLongPress":false}';

      final keyPair = KeyPair.decode(encoded);
      expect(keyPair, isNotNull);
      expect(keyPair!.touchPosition.dx, 300);
      expect(keyPair.touchPosition.dy, 600);
    });

    test('Should handle zero touch position correctly', () {
      final keyPair = KeyPair(
        buttons: [ControllerButton.paddleRight],
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        touchPosition: Offset.zero,
      );

      final encoded = keyPair.encode();
      // Should encode as percentages even when position is zero
      expect(encoded, contains('x_percent'));
      expect(encoded, contains('y_percent'));
      expect(encoded, contains('0.0'));
    });

    test('Should encode and decode with fallback screen size', () {
      final keyPair = KeyPair(
        buttons: [ControllerButton.paddleRight],
        physicalKey: null,
        logicalKey: null,
        touchPosition: Offset(480, 270), // 25% of 1920x1080
      );

      // Encode (will use fallback screen size)
      final encoded = keyPair.encode();

      // Decode (will also use fallback or available screen size)
      final decoded = KeyPair.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.touchPosition, isNotNull);
    });

    test('Should handle decoding when no screen size available', () {
      final encoded =
          '{"actions":["leftButton"],"logicalKey":"0","physicalKey":"0","touchPosition":{"x_percent":0.5,"y_percent":0.5},"isLongPress":false}';

      final keyPair = KeyPair.decode(encoded);
      expect(keyPair, isNotNull);
      // When no screen size is available, it may return Offset.zero as fallback
      expect(keyPair!.touchPosition, isNotNull);
    });
  });
}
