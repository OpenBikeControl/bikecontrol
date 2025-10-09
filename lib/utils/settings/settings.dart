import 'dart:convert';

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
      // Get screen size for migrations
      Size? screenSize;
      try {
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        screenSize = view.physicalSize / view.devicePixelRatio;
      } catch (e) {
        screenSize = null;
      }

      // Handle migration from old "customapp" key to new "customapp_Custom" key
      if (_prefs.containsKey('customapp') && !_prefs.containsKey('customapp_Custom')) {
        final oldCustomApp = _prefs.getStringList('customapp');
        if (oldCustomApp != null) {
          // Migrate pixel-based to percentage-based if screen size available
          if (screenSize != null) {
            final migratedData = await _migrateToPercentageBased(oldCustomApp, screenSize);
            await _prefs.setStringList('customapp_Custom', migratedData);
          } else {
            await _prefs.setStringList('customapp_Custom', oldCustomApp);
          }
          await _prefs.remove('customapp');
        }
      }
      
      // Migrate all existing custom profiles to percentage-based format
      await _migrateAllProfilesToPercentageBased(screenSize);
      
      final appName = _prefs.getString('app');
      if (appName == null) {
        return;
      }
      
      // Check if it's a custom app with a profile name
      if (appName.startsWith('Custom') || _prefs.containsKey('customapp_$appName')) {
        final customApp = CustomApp(profileName: appName);
        final appSetting = _prefs.getStringList('customapp_$appName');
        if (appSetting != null) {
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
  
  String? exportCustomAppProfile(String profileName) {
    final data = _prefs.getStringList('customapp_$profileName');
    if (data == null) return null;
    
    // Export as JSON with metadata
    return jsonEncode({
      'version': 1,
      'profileName': profileName,
      'keymap': data,
    });
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
      
      await _prefs.setStringList('customapp_$profileName', keymap);
      return true;
    } catch (e) {
      return false;
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

  Future<List<String>> _migrateToPercentageBased(List<String> keymapData, Size screenSize) async {
    final migratedData = <String>[];
    
    for (final encodedKeyPair in keymapData) {
      try {
        final decoded = jsonDecode(encodedKeyPair);
        final touchPosData = decoded['touchPosition'];
        
        // Check if already percentage-based
        if (touchPosData.containsKey('x_percent') && touchPosData.containsKey('y_percent')) {
          migratedData.add(encodedKeyPair);
          continue;
        }
        
        // Convert pixel-based to percentage-based
        final x = (touchPosData['x'] as num).toDouble();
        final y = (touchPosData['y'] as num).toDouble();
        
        decoded['touchPosition'] = {
          'x_percent': x / screenSize.width,
          'y_percent': y / screenSize.height,
        };
        
        migratedData.add(jsonEncode(decoded));
      } catch (e) {
        // If can't decode, keep original
        migratedData.add(encodedKeyPair);
      }
    }
    
    return migratedData;
  }

  Future<void> _migrateAllProfilesToPercentageBased(Size? screenSize) async {
    if (screenSize == null) return;
    
    final profiles = getCustomAppProfiles();
    for (final profile in profiles) {
      final keymap = _prefs.getStringList('customapp_$profile');
      if (keymap != null) {
        // Check if migration is needed
        bool needsMigration = false;
        for (final encodedKeyPair in keymap) {
          try {
            final decoded = jsonDecode(encodedKeyPair);
            final touchPosData = decoded['touchPosition'];
            if (!touchPosData.containsKey('x_percent') || !touchPosData.containsKey('y_percent')) {
              needsMigration = true;
              break;
            }
          } catch (e) {
            // Skip if can't decode
          }
        }
        
        if (needsMigration) {
          final migratedData = await _migrateToPercentageBased(keymap, screenSize);
          await _prefs.setStringList('customapp_$profile', migratedData);
        }
      }
    }
  }
}
