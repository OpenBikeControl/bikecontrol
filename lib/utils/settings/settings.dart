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
    } catch (e) {
      // couldn't decode, reset
      await _prefs.clear();
    }
  }

  void setKeymap(Keymap keymap) {
    _prefs.setStringList("keymap", keymap.encode());
  }
}
