import 'package:dartx/dartx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';

import '../../main.dart';
import '../keymap/apps/custom_app.dart';

class Settings {
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    try {
      final appSetting = _prefs.getStringList("customapp");
      if (appSetting != null) {
        final customApp = CustomApp();
        customApp.decodeKeymap(appSetting);
      }

      final appName = _prefs.getString('app');
      if (appName == null) {
        return;
      }
      final app = SupportedApp.supportedApps.firstOrNullWhere((e) => e.name == appName);

      actionHandler.init(app);
    } catch (e) {
      // couldn't decode, reset
      await _prefs.clear();
      rethrow;
    }
  }

  Future<void> reset() async {
    await _prefs.clear();
    actionHandler.init(null);
  }

  Future<void> setApp(SupportedApp app) async {
    if (app is CustomApp) {
      await _prefs.setStringList("customapp", app.encodeKeymap());
    }
    await _prefs.setString('app', app.name);
  }

  String? getLastSeenVersion() {
    return _prefs.getString('last_seen_version');
  }

  Future<void> setLastSeenVersion(String version) async {
    await _prefs.setString('last_seen_version', version);
  }

  bool getVibrationEnabled() {
    return _prefs.getBool('vibration_enabled') ?? true;
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    await _prefs.setBool('vibration_enabled', enabled);
  }
}
