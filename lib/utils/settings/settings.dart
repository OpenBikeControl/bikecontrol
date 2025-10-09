import 'dart:convert';

import 'package:dartx/dartx.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';

import '../../main.dart';
import '../keymap/apps/custom_app.dart';

class Settings {
  late final SharedPreferences prefs;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();

    try {
      // Get screen size for migrations
      Size? screenSize;
      try {
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        screenSize = view.physicalSize / view.devicePixelRatio;
      } catch (e) {
        screenSize = null;
      }

      // Handle migration from old "customapp" key to new "customapp_Custom" key
      if (prefs.containsKey('customapp') && !prefs.containsKey('customapp_Custom')) {
        final oldCustomApp = prefs.getStringList('customapp');
        if (oldCustomApp != null) {
          // Migrate pixel-based to percentage-based if screen size available
          if (screenSize != null) {
            final migratedData = await _migrateToPercentageBased(oldCustomApp, screenSize);
            await prefs.setStringList('customapp_Custom', migratedData);
          } else {
            await prefs.setStringList('customapp_Custom', oldCustomApp);
          }
          await prefs.remove('customapp');
        }
      }

      final appName = prefs.getString('app');
      if (appName == null) {
        return;
      }

      // Check if it's a custom app with a profile name
      if (appName.startsWith('Custom') || prefs.containsKey('customapp_$appName')) {
        final customApp = CustomApp(profileName: appName);
        final appSetting = prefs.getStringList('customapp_$appName');
        if (appSetting != null) {
          customApp.decodeKeymap(appSetting);
        }
        actionHandler.init(customApp);
      } else {
        final app = SupportedApp.supportedApps.firstOrNullWhere((e) => e.name == appName);
        actionHandler.init(app);
      }
    } catch (e) {
      // couldn't decode, reset
      await prefs.clear();
      rethrow;
    }
  }

  Future<void> reset() async {
    await prefs.clear();
    actionHandler.init(null);
  }

  Future<void> setApp(SupportedApp app) async {
    if (app is CustomApp) {
      await prefs.setStringList('customapp_${app.profileName}', app.encodeKeymap());
    }
    await prefs.setString('app', app.name);
  }

  List<String> getCustomAppProfiles() {
    // Get all keys starting with 'customapp_'
    final keys = prefs.getKeys().where((key) => key.startsWith('customapp_')).toList();
    return keys.map((key) => key.replaceFirst('customapp_', '')).toList();
  }

  List<String>? getCustomAppKeymap(String profileName) {
    return prefs.getStringList('customapp_$profileName');
  }

  Future<void> deleteCustomAppProfile(String profileName) async {
    await prefs.remove('customapp_$profileName');
    // If the current app is the one being deleted, reset
    if (prefs.getString('app') == profileName) {
      actionHandler.init(null);
      await prefs.remove('app');
    }
  }

  Future<void> duplicateCustomAppProfile(String sourceProfileName, String newProfileName) async {
    final sourceData = prefs.getStringList('customapp_$sourceProfileName');
    if (sourceData != null) {
      await prefs.setStringList('customapp_$newProfileName', sourceData);
    }
  }

  String? exportCustomAppProfile(String profileName) {
    final data = prefs.getStringList('customapp_$profileName');
    if (data == null) return null;

    // Export as JSON with metadata
    return jsonEncode({'version': 1, 'profileName': profileName, 'keymap': data});
  }

  Future<bool> importCustomAppProfile(String jsonData, {String? newProfileName}) async {
    try {
      final decoded = jsonDecode(jsonData);

      // Validate the structure
      if (decoded['version'] == null || decoded['keymap'] == null) {
        return false;
      }

      final profileName = newProfileName ?? decoded['profileName'] ?? 'Imported';
      final keymap = List<String>.from(decoded['keymap']);

      await prefs.setStringList('customapp_$profileName', keymap);
      return true;
    } catch (e) {
      return false;
    }
  }

  String? getLastSeenVersion() {
    return prefs.getString('last_seen_version');
  }

  Future<void> setLastSeenVersion(String version) async {
    await prefs.setString('last_seen_version', version);
  }

  bool getVibrationEnabled() {
    return prefs.getBool('vibration_enabled') ?? true;
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    await prefs.setBool('vibration_enabled', enabled);
  }

  Future<List<String>> _migrateToPercentageBased(List<String> keymapData, Size screenSize) async {
    final migratedData = <String>[];

    final needMigrations = keymapData.associateWith((encodedKeyPair) {
      final decoded = jsonDecode(encodedKeyPair);
      final touchPosData = decoded['touchPosition'];

      // Convert pixel-based to percentage-based
      final x = (touchPosData['x'] as num).toDouble();
      final y = (touchPosData['y'] as num).toDouble();
      return x > 100.0 || y > 100.0;
    });

    for (final entry in needMigrations.entries) {
      if (entry.value) {
        final decoded = jsonDecode(entry.key);
        final touchPosData = decoded['touchPosition'];

        // Convert pixel-based to percentage-based
        final x = (touchPosData['x'] as num).toDouble();
        final y = (touchPosData['y'] as num).toDouble();
        final newX = (x / screenSize.width).clamp(0.0, 1.0) * 100.0;
        final newY = (y / screenSize.height).clamp(0.0, 1.0) * 100.0;

        // Update the JSON structure
        decoded['touchPosition'] = {'x': newX, 'y': newY};

        migratedData.add(jsonEncode(decoded));
      } else {
        migratedData.add(entry.key);
      }
    }

    return migratedData;
  }
}
