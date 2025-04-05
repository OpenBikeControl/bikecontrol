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
        customApp.decodeKeymap(appSetting);

        actionHandler.init(customApp);
      }
    } catch (e) {
      // couldn't decode, reset
      await _prefs.clear();
      rethrow;
    }
  }

  void setCustomApp(CustomApp app) {
    _prefs.setStringList("customapp", app.encodeKeymap());
  }
}
