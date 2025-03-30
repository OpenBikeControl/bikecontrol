import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../keymap/keymap.dart';

class Settings {
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    try {
      final keymapSetting = _prefs.getStringList("keymap");
      if (keymapSetting != null) {
        actionHandler.init(Keymap.decode(keymapSetting));
      }

      final gearUpX = _prefs.getDouble("gearUpX");
      final gearUpY = _prefs.getDouble("gearUpY");
      final gearDownX = _prefs.getDouble("gearDownX");
      final gearDownY = _prefs.getDouble("gearDownY");
      if (gearUpX != null && gearUpY != null && gearDownX != null && gearDownY != null) {
        actionHandler.updateTouchPositions(Offset(gearUpX, gearUpY), Offset(gearDownX, gearDownY));
      }
    } catch (e) {
      // couldn't decode, reset
      await _prefs.clear();
    }
  }

  void setKeymap(Keymap keymap) {
    _prefs.setStringList("keymap", keymap.encode());
  }

  void updateTouchPositions(Offset gearUp, Offset gearDown) {
    _prefs.setDouble("gearUpX", gearUp.dx);
    _prefs.setDouble("gearUpY", gearUp.dy);
    _prefs.setDouble("gearDownX", gearDown.dx);
    _prefs.setDouble("gearDownY", gearDown.dy);
  }
}
