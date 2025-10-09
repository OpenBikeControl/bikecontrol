import 'package:dartx/dartx.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';

import '../../main.dart';
import '../keymap/apps/custom_app.dart';

class Settings {
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    try {
      // Handle migration from old "customapp" key to new "customapp_Custom" key
      if (_prefs.containsKey('customapp') && !_prefs.containsKey('customapp_Custom')) {
        final oldCustomApp = _prefs.getStringList('customapp');
        if (oldCustomApp != null) {
          await _prefs.setStringList('customapp_Custom', oldCustomApp);
          await _prefs.remove('customapp');
        }
      }
      
      final appName = _prefs.getString('app');
      if (appName == null) {
        return;
      }
      
      // Check if it's a custom app with a profile name
      if (appName.startsWith('Custom') || _prefs.containsKey('customapp_$appName')) {
        final customApp = CustomApp(profileName: appName);
        final appSetting = _prefs.getStringList('customapp_$appName');
        if (appSetting != null) {
          // Get screen size for percentage-based decoding
          Size? screenSize;
          try {
            final view = WidgetsBinding.instance.platformDispatcher.views.first;
            screenSize = view.physicalSize / view.devicePixelRatio;
          } catch (e) {
            screenSize = null;
          }
          customApp.decodeKeymap(appSetting, screenSize: screenSize);
        }
        actionHandler.init(customApp);
      } else {
        final app = SupportedApp.supportedApps.firstOrNullWhere((e) => e.name == appName);
        actionHandler.init(app);
      }
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
      // Get screen size for percentage-based encoding
      Size? screenSize;
      try {
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        screenSize = view.physicalSize / view.devicePixelRatio;
      } catch (e) {
        // Fallback if screen size is not available
        screenSize = null;
      }
      await _prefs.setStringList('customapp_${app.profileName}', app.encodeKeymap(screenSize: screenSize));
    }
    await _prefs.setString('app', app.name);
  }
  
  List<String> getCustomAppProfiles() {
    // Get all keys starting with 'customapp_'
    final keys = _prefs.getKeys().where((key) => key.startsWith('customapp_')).toList();
    return keys.map((key) => key.replaceFirst('customapp_', '')).toList();
  }
  
  List<String>? getCustomAppKeymap(String profileName) {
    return _prefs.getStringList('customapp_$profileName');
  }
  
  Future<void> deleteCustomAppProfile(String profileName) async {
    await _prefs.remove('customapp_$profileName');
    // If the current app is the one being deleted, reset
    if (_prefs.getString('app') == profileName) {
      actionHandler.init(null);
      await _prefs.remove('app');
    }
  }
  
  Future<void> duplicateCustomAppProfile(String sourceProfileName, String newProfileName) async {
    final sourceData = _prefs.getStringList('customapp_$sourceProfileName');
    if (sourceData != null) {
      await _prefs.setStringList('customapp_$newProfileName', sourceData);
    }
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
