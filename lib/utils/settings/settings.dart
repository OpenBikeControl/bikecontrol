import 'dart:convert';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';
import 'package:swift_control/utils/keymap/apps/supported_app.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:window_manager/window_manager.dart';

import '../../main.dart';
import '../actions/desktop.dart';
import '../keymap/apps/custom_app.dart';

class Settings {
  late final SharedPreferences prefs;

  Future<String?> init({bool retried = false}) async {
    try {
      prefs = await SharedPreferences.getInstance();
      initializeActions(getLastTarget()?.connectionType ?? ConnectionType.unknown);

      if (actionHandler is DesktopActions) {
        // Must add this line.
        await windowManager.ensureInitialized();
      }

      final app = getKeyMap();
      actionHandler.init(app);
      return null;
    } catch (e, s) {
      if (!retried) {
        if (Platform.isWindows) {
          // delete settings file
          final fs = SharedPreferencesWindows.instance.fs;

          final pathProvider = PathProviderWindows();
          final String? directory = await pathProvider.getApplicationSupportPath();
          if (directory == null) {
            return null;
          }
          final String fileLocation = path.join(directory, 'shared_preferences.json');
          final file = fs.file(fileLocation);
          if (await file.exists()) {
            await file.delete();
          }
        }
        return init(retried: true);
      } else {
        return '$e\n$s';
      }
    }
  }

  Future<void> reset() async {
    await prefs.clear();
    actionHandler.init(null);
  }

  void setTrainerApp(SupportedApp app) {
    prefs.setString('trainer_app', app.name);
  }

  SupportedApp? getTrainerApp() {
    final appName = prefs.getString('trainer_app');
    if (appName == null) {
      return null;
    }
    return SupportedApp.supportedApps.firstOrNullWhere((e) => e.name == appName);
  }

  bool knowsAboutNameChange() {
    final knows = prefs.getBool('name_change') == true;
    prefs.setBool('name_change', true);
    return knows;
  }

  Future<void> setKeyMap(SupportedApp app) async {
    if (app is CustomApp) {
      await prefs.setStringList('customapp_${app.profileName}', app.encodeKeymap());
    }
    await prefs.setString('app', app.name);
  }

  SupportedApp? getKeyMap() {
    final appName = prefs.getString('app');
    if (appName == null) {
      return null;
    }

    // Check if it's a custom app with a profile name
    if (appName.startsWith('Custom') || prefs.containsKey('customapp_$appName')) {
      final customApp = CustomApp(profileName: appName);
      final appSetting = prefs.getStringList('customapp_$appName');
      if (appSetting != null) {
        customApp.decodeKeymap(appSetting);
      }
      return customApp;
    } else {
      return SupportedApp.supportedApps.firstOrNullWhere((e) => e.name == appName);
    }
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
    var encoder = JsonEncoder.withIndent("     ");
    return encoder.convert({
      'version': 1,
      'profileName': profileName,
      'keymap': data.map((e) => jsonDecode(e)).toList(),
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
      final keymap = (decoded['keymap'] as List).map((e) => jsonEncode(e)).toList().cast<String>();

      await prefs.setStringList('customapp_$profileName', keymap);
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  String? getLastSeenVersion() {
    return prefs.getString('last_seen_version');
  }

  Target? getLastTarget() {
    final targetString = prefs.getString('last_target');
    if (targetString == null) return null;
    return Target.values.firstOrNullWhere((e) => e.name == targetString);
  }

  Future<void> setLastTarget(Target target) async {
    await prefs.setString('last_target', target.name);
    initializeActions(target.connectionType);
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

  bool getMyWhooshLinkEnabled() {
    return prefs.getBool('mywhoosh_link_enabled') ?? true;
  }

  Future<void> setMyWhooshLinkEnabled(bool enabled) async {
    await prefs.setBool('mywhoosh_link_enabled', enabled);
  }

  bool getZwiftEmulatorEnabled() {
    return prefs.getBool('zwift_emulator_enabled') ?? true;
  }

  Future<void> setZwiftEmulatorEnabled(bool enabled) async {
    await prefs.setBool('zwift_emulator_enabled', enabled);
  }

  bool getMiuiWarningDismissed() {
    return prefs.getBool('miui_warning_dismissed') ?? false;
  }

  Future<void> setMiuiWarningDismissed(bool dismissed) async {
    await prefs.setBool('miui_warning_dismissed', dismissed);
  }

  List<String> _getIgnoredDeviceIds() {
    return prefs.getStringList('ignored_device_ids') ?? [];
  }

  List<String> _getIgnoredDeviceNames() {
    return prefs.getStringList('ignored_device_names') ?? [];
  }

  Future<void> addIgnoredDevice(String deviceId, String deviceName) async {
    final ids = _getIgnoredDeviceIds();
    final names = _getIgnoredDeviceNames();

    if (!ids.contains(deviceId)) {
      ids.add(deviceId);
      names.add(deviceName);
      await prefs.setStringList('ignored_device_ids', ids);
      await prefs.setStringList('ignored_device_names', names);
    }
  }

  Future<void> removeIgnoredDevice(String deviceId) async {
    final ids = _getIgnoredDeviceIds();
    final names = _getIgnoredDeviceNames();

    final index = ids.indexOf(deviceId);
    if (index != -1) {
      ids.removeAt(index);
      names.removeAt(index);
      await prefs.setStringList('ignored_device_ids', ids);
      await prefs.setStringList('ignored_device_names', names);
    }
  }

  List<({String id, String name})> getIgnoredDevices() {
    final ids = _getIgnoredDeviceIds();
    final names = _getIgnoredDeviceNames();

    final result = <({String id, String name})>[];
    for (int i = 0; i < ids.length && i < names.length; i++) {
      result.add((id: ids[i], name: names[i]));
    }
    return result;
  }
}
