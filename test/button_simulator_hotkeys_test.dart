import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/settings/settings.dart';

void main() {
  group('Button Simulator Hotkey Tests', () {
    setUp(() async {
      // Initialize SharedPreferences with in-memory storage for testing
      SharedPreferences.setMockInitialValues({});
      await core.settings.init();
    });

    test('Should initialize with empty hotkeys', () {
      final hotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(hotkeys.isEmpty, true);
    });

    test('Should save and retrieve hotkeys', () async {
      final testHotkeys = {
        'shiftUp': '1',
        'shiftDown': '2',
        'uturn': '3',
      };

      await core.settings.setButtonSimulatorHotkeys(testHotkeys);

      final retrievedHotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(retrievedHotkeys['shiftUp'], '1');
      expect(retrievedHotkeys['shiftDown'], '2');
      expect(retrievedHotkeys['uturn'], '3');
      expect(retrievedHotkeys.length, 3);
    });

    test('Should set individual hotkey', () async {
      await core.settings.setButtonSimulatorHotkey('shiftUp', 'q');

      final hotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(hotkeys['shiftUp'], 'q');
    });

    test('Should update existing hotkey', () async {
      await core.settings.setButtonSimulatorHotkey('shiftUp', '1');
      await core.settings.setButtonSimulatorHotkey('shiftUp', 'q');

      final hotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(hotkeys['shiftUp'], 'q');
    });

    test('Should remove hotkey', () async {
      await core.settings.setButtonSimulatorHotkey('shiftUp', '1');
      await core.settings.setButtonSimulatorHotkey('shiftDown', '2');

      await core.settings.removeButtonSimulatorHotkey('shiftUp');

      final hotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(hotkeys.containsKey('shiftUp'), false);
      expect(hotkeys['shiftDown'], '2');
    });

    test('Should persist hotkeys across settings instances', () async {
      final testHotkeys = {
        'shiftUp': 'a',
        'shiftDown': 'b',
      };

      await core.settings.setButtonSimulatorHotkeys(testHotkeys);

      // Create new settings instance
      final newSettings = Settings();
      await newSettings.init();

      final retrievedHotkeys = newSettings.getButtonSimulatorHotkeys();
      expect(retrievedHotkeys['shiftUp'], 'a');
      expect(retrievedHotkeys['shiftDown'], 'b');
    });

    test('Should handle multiple actions with different hotkeys', () async {
      final testHotkeys = {
        'shiftUp': '1',
        'shiftDown': '2',
        'uturn': '3',
        'steerLeft': 'q',
        'steerRight': 'w',
        'openActionBar': 'a',
        'usePowerUp': 's',
      };

      await core.settings.setButtonSimulatorHotkeys(testHotkeys);

      final retrievedHotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(retrievedHotkeys.length, 7);
      expect(retrievedHotkeys['steerLeft'], 'q');
      expect(retrievedHotkeys['usePowerUp'], 's');
    });

    test('Should clear all hotkeys', () async {
      await core.settings.setButtonSimulatorHotkeys({'shiftUp': '1', 'shiftDown': '2'});
      await core.settings.setButtonSimulatorHotkeys({});

      final hotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(hotkeys.isEmpty, true);
    });
  });
}
