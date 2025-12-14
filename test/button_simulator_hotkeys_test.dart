import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';

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
        InGameAction.shiftUp: '1',
        InGameAction.shiftDown: '2',
        InGameAction.uturn: '3',
      };

      await core.settings.setButtonSimulatorHotkeys(testHotkeys);

      final retrievedHotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(retrievedHotkeys[InGameAction.shiftUp], '1');
      expect(retrievedHotkeys[InGameAction.shiftDown], '2');
      expect(retrievedHotkeys[InGameAction.uturn], '3');
      expect(retrievedHotkeys.length, 3);
    });

    test('Should set individual hotkey', () async {
      await core.settings.setButtonSimulatorHotkey(InGameAction.shiftUp, 'q');

      final hotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(hotkeys[InGameAction.shiftUp], 'q');
    });

    test('Should update existing hotkey', () async {
      await core.settings.setButtonSimulatorHotkey(InGameAction.shiftUp, '1');
      await core.settings.setButtonSimulatorHotkey(InGameAction.shiftUp, 'q');

      final hotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(hotkeys[InGameAction.shiftUp], 'q');
    });

    test('Should remove hotkey', () async {
      await core.settings.setButtonSimulatorHotkey(InGameAction.shiftUp, '1');
      await core.settings.setButtonSimulatorHotkey(InGameAction.shiftDown, '2');

      await core.settings.removeButtonSimulatorHotkey(InGameAction.shiftUp);

      final hotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(hotkeys.containsKey(InGameAction.shiftUp), false);
      expect(hotkeys[InGameAction.shiftDown], '2');
    });

    test('Should handle multiple actions with different hotkeys', () async {
      final testHotkeys = {
        InGameAction.shiftUp: '1',
        InGameAction.shiftDown: '2',
        InGameAction.uturn: '3',
        InGameAction.steerLeft: 'q',
        InGameAction.steerRight: 'w',
        InGameAction.openActionBar: 'a',
        InGameAction.usePowerUp: 's',
      };

      await core.settings.setButtonSimulatorHotkeys(testHotkeys);

      final retrievedHotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(retrievedHotkeys.length, 7);
      expect(retrievedHotkeys[InGameAction.steerLeft], 'q');
      expect(retrievedHotkeys[InGameAction.usePowerUp], 's');
    });

    test('Should clear all hotkeys', () async {
      await core.settings.setButtonSimulatorHotkeys({InGameAction.shiftUp: '1', InGameAction.shiftDown: '2'});
      await core.settings.setButtonSimulatorHotkeys({});

      final hotkeys = core.settings.getButtonSimulatorHotkeys();
      expect(hotkeys.isEmpty, true);
    });
  });
}
