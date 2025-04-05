import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

import '../../main.dart';

class Settings {
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    try {
      final appSetting = _prefs.getStringList("customapp");
      if (appSetting != null) {
        final customApp = CustomApp();
        customApp.decode(appSetting);
        actionHandler.init(customApp);
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

  void setCustomApp(CustomApp app) {
    _prefs.setStringList("customapp", app.encode());
  }

  void updateTouchPositions(Offset gearUp, Offset gearDown) {
    _prefs.setDouble("gearUpX", gearUp.dx);
    _prefs.setDouble("gearUpY", gearUp.dy);
    _prefs.setDouble("gearDownX", gearDown.dx);
    _prefs.setDouble("gearDownY", gearDown.dy);
  }
}
