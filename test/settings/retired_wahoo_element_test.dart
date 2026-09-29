// The Wahoo ELEMNT trainer-app target was removed. Riders who had it saved
// must land on "no app chosen" rather than a crash, and hotkeys saved for its
// D-Fly actions must not take the rider's other hotkeys down with them.
import 'dart:convert';

import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Wahoo ELEMNT is no longer offered as a trainer app', () {
    expect(SupportedApp.supportedApps.map((a) => a.name), isNot(contains('Wahoo ELEMNT')));
  });

  test('a saved Wahoo ELEMNT trainer app loads as no app chosen', () async {
    SharedPreferences.setMockInitialValues({'trainer_app': 'Wahoo ELEMNT', 'app': 'Wahoo ELEMNT'});
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();

    expect(s.getTrainerApp(), isNull);
    expect(s.getKeyMap(), isNull);
  });

  test('a saved hotkey for a removed action is dropped, the others survive', () async {
    SharedPreferences.setMockInitialValues({
      'button_simulator_hotkeys': jsonEncode({'shiftUp': 'a', 'dFlyChannel1': 'b', 'shiftDown': 'c'}),
    });
    final s = Settings();
    s.prefs = await SharedPreferences.getInstance();

    expect(s.getButtonSimulatorHotkeys(), {InGameAction.shiftUp: 'a', InGameAction.shiftDown: 'c'});
  });
}
