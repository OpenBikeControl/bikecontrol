import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  screenshotMode = true;

  await core.settings.init();
  await core.settings.reset();

  core.settings.setTrainerApp(MyWhoosh());
  core.settings.setKeyMap(MyWhoosh());
  core.settings.setLastTarget(Target.thisDevice);

  group('Modifier Keys KeyPair Tests', () {
    test('KeyPair should encode and decode modifiers property', () {
      // Create a KeyPair with modifiers
      final keyPair = KeyPair(
        buttons: [ZwiftButtons.a],
        physicalKey: PhysicalKeyboardKey.keyR,
        logicalKey: LogicalKeyboardKey.keyR,
        modifiers: [ModifierKey.controlModifier, ModifierKey.altModifier],
      );

      // Encode the KeyPair
      final encoded = keyPair.encode();

      // Decode the KeyPair
      final decoded = KeyPair.decode(encoded);

      // Verify the decoded KeyPair has the correct properties
      expect(decoded, isNotNull);
      expect(decoded!.modifiers.length, 2);
      expect(decoded.modifiers, contains(ModifierKey.controlModifier));
      expect(decoded.modifiers, contains(ModifierKey.altModifier));
      expect(decoded.buttons, equals([ZwiftButtons.a]));
      expect(decoded.physicalKey, equals(PhysicalKeyboardKey.keyR));
      expect(decoded.logicalKey, equals(LogicalKeyboardKey.keyR));
    });

    test('KeyPair should default modifiers to empty list when not specified in decode', () {
      // Create a legacy encoded KeyPair without modifiers property
      const legacyEncoded = '''
      {
        "actions": ["a"],
        "logicalKey": "97",
        "physicalKey": "458752",
        "touchPosition": {"x": 0.0, "y": 0.0},
        "isLongPress": false
      }
      ''';

      // Decode the legacy KeyPair
      final decoded = KeyPair.decode(legacyEncoded);

      // Verify the decoded KeyPair defaults modifiers to empty
      expect(decoded, isNotNull);
      expect(decoded!.modifiers, isEmpty);
    });

    test('KeyPair constructor should default modifiers to empty list', () {
      final keyPair = KeyPair(
        buttons: [ZwiftButtons.a],
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
      );

      expect(keyPair.modifiers, isEmpty);
    });

    test('KeyPair should correctly encode empty modifiers', () {
      final keyPair = KeyPair(
        buttons: [ZwiftButtons.a],
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        modifiers: [],
      );

      final encoded = keyPair.encode();
      final decoded = KeyPair.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.modifiers, isEmpty);
    });

    test('KeyPair toString should format modifiers correctly', () {
      final keyPairWithCtrlAlt = KeyPair(
        buttons: [ZwiftButtons.a],
        physicalKey: PhysicalKeyboardKey.keyR,
        logicalKey: LogicalKeyboardKey.keyR,
        modifiers: [ModifierKey.controlModifier, ModifierKey.altModifier],
      );

      final result = keyPairWithCtrlAlt.toString();
      expect(result, contains('Ctrl'));
      expect(result, contains('Alt'));
      expect(result, contains('R'));
    });

    test('KeyPair toString should handle single modifier', () {
      final keyPairWithShift = KeyPair(
        buttons: [ZwiftButtons.a],
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        modifiers: [ModifierKey.shiftModifier],
      );

      final result = keyPairWithShift.toString();
      expect(result, contains('Shift'));
      expect(result, contains('A'));
    });

    test('KeyPair toString should handle no modifiers', () {
      final keyPairNoModifier = KeyPair(
        buttons: [ZwiftButtons.a],
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        modifiers: [],
      );

      final result = keyPairNoModifier.toString();
      expect(result, equals('A'));
      expect(result, isNot(contains('+')));
    });

    test('KeyPair should encode and decode all modifier types', () {
      final keyPair = KeyPair(
        buttons: [ZwiftButtons.a],
        physicalKey: PhysicalKeyboardKey.keyF,
        logicalKey: LogicalKeyboardKey.keyF,
        modifiers: [
          ModifierKey.shiftModifier,
          ModifierKey.controlModifier,
          ModifierKey.altModifier,
          ModifierKey.metaModifier,
        ],
      );

      final encoded = keyPair.encode();
      final decoded = KeyPair.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.modifiers.length, 4);
      expect(decoded.modifiers, contains(ModifierKey.shiftModifier));
      expect(decoded.modifiers, contains(ModifierKey.controlModifier));
      expect(decoded.modifiers, contains(ModifierKey.altModifier));
      expect(decoded.modifiers, contains(ModifierKey.metaModifier));
    });
  });
}
