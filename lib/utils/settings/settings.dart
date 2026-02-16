import 'dart:convert';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/android.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:prop/emulators/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../../main.dart';
import '../actions/desktop.dart';
import '../keymap/apps/custom_app.dart';
import '../keymap/buttons.dart';

class Settings {
  late final SharedPreferences prefs;

  Future<String?> init({bool retried = false}) async {
    try {
      prefs = await SharedPreferences.getInstance();
      propPrefs.initialize(prefs);
      try {
        await NotificationRequirement.setup();
      } catch (error, stack) {
        recordError(error, stack, context: 'Notification setup');
      }
      initializeActions(getLastTarget()?.connectionType ?? ConnectionType.unknown);

      if (getShowOnboarding() && getTrainerApp() != null) {
        // If onboarding is to be shown, but a trainer app is already set,
        // skip onboarding and set to not show again.
        await setShowOnboarding(false);
      }

      if (core.actionHandler is DesktopActions) {
        // Must add this line.
        await windowManager.ensureInitialized();
      }

      final app = getKeyMap();
      core.actionHandler.init(app);

      try {
        await Supabase.initialize(
          url: 'https://pikrcyynovdvogrldfnw.supabase.co',
          anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
        );
      } catch (e, s) {
        recordError(e, s, context: 'Supabase initialization');
      }

      // Initialize IAP manager
      await IAPManager.instance.initialize();

      // Start trial if this is the first launch
      if (!IAPManager.instance.hasTrialStarted && !IAPManager.instance.isPurchased.value) {
        await IAPManager.instance.startTrial();
      }

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
    IAPManager.instance.reset(true);
    init();
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
      core.actionHandler.init(null);
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
    IAPManager.instance.setAttributes();
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
    return prefs.getBool('mywhoosh_link_enabled') ?? false;
  }

  Future<void> setMyWhooshLinkEnabled(bool enabled) async {
    await prefs.setBool('mywhoosh_link_enabled', enabled);
  }

  bool getObpMdnsEnabled() {
    return prefs.getBool('openbikeprotocol_mdns_enabled') ?? false;
  }

  Future<void> setObpMdnsEnabled(bool enabled) async {
    await prefs.setBool('openbikeprotocol_mdns_enabled', enabled);
  }

  bool getObpBleEnabled() {
    return prefs.getBool('openbikeprotocol_ble_enabled') ?? false;
  }

  Future<void> setObpBleEnabled(bool enabled) async {
    await prefs.setBool('openbikeprotocol_ble_enabled', enabled);
  }

  bool getZwiftBleEmulatorEnabled() {
    return prefs.getBool('zwift_emulator_enabled') ?? false;
  }

  Future<void> setZwiftBleEmulatorEnabled(bool enabled) async {
    await prefs.setBool('zwift_emulator_enabled', enabled);
  }

  bool getZwiftMdnsEmulatorEnabled() {
    return prefs.getBool('zwift_mdns_emulator_enabled') ?? false;
  }

  Future<void> setZwiftMdnsEmulatorEnabled(bool enabled) async {
    await prefs.setBool('zwift_mdns_emulator_enabled', enabled);
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

  bool getShowZwiftClickV2ReconnectWarning() {
    return prefs.getBool('zwift_click_v2_reconnect_warning') ?? true;
  }

  Future<void> setShowZwiftClickV2ReconnectWarning(bool show) async {
    await prefs.setBool('zwift_click_v2_reconnect_warning', show);
  }

  void setRemoteControlEnabled(bool value) {
    prefs.setBool('remote_control_enabled', value);
  }

  bool getRemoteControlEnabled() {
    return prefs.getBool('remote_control_enabled') ?? false;
  }

  void setRemoteKeyboardControlEnabled(bool value) {
    prefs.setBool('remote_keyboard_control_enabled', value);
  }

  bool getRemoteKeyboardControlEnabled() {
    return prefs.getBool('remote_keyboard_control_enabled') ?? false;
  }

  bool getLocalEnabled() {
    return prefs.getBool('local_control_enabled') ?? false;
  }

  void setLocalEnabled(bool value) {
    prefs.setBool('local_control_enabled', value);
  }

  // Button Simulator Hotkey Settings
  Map<InGameAction, String> getButtonSimulatorHotkeys() {
    final json = prefs.getString('button_simulator_hotkeys');
    if (json == null) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(InGameAction.values.firstWhere((e) => e.name == key), value.toString()),
      );
    } catch (e) {
      return {};
    }
  }

  Future<void> setButtonSimulatorHotkeys(Map<InGameAction, String> hotkeys) async {
    await prefs.setString(
      'button_simulator_hotkeys',
      jsonEncode(hotkeys.map((key, value) => MapEntry(key.name, value))),
    );
  }

  Future<void> setButtonSimulatorHotkey(InGameAction action, String hotkey) async {
    final hotkeys = getButtonSimulatorHotkeys();
    hotkeys[action] = hotkey;
    await setButtonSimulatorHotkeys(hotkeys);
  }

  Future<void> removeButtonSimulatorHotkey(InGameAction action) async {
    final hotkeys = getButtonSimulatorHotkeys();
    hotkeys.remove(action);
    await setButtonSimulatorHotkeys(hotkeys);
  }

  void setPhoneSteeringEnabled(bool value) {
    prefs.setBool('phone_steering_enabled', value);
  }

  bool getPhoneSteeringEnabled() {
    return prefs.getBool('phone_steering_enabled') ?? false;
  }

  void setPhoneSteeringThreshold(int value) {
    prefs.setInt('phone_steering_threshold', value);
  }

  double getPhoneSteeringThreshold() {
    return prefs.getInt('phone_steering_threshold')?.toDouble() ?? GyroscopeSteering.STEERING_THRESHOLD;
  }

  // SRAM AXS Settings
  static const int _sramAxsDoubleClickWindowDefaultMs = 350;
  static const int _sramAxsDoubleClickWindowMinMs = 150;
  static const int _sramAxsDoubleClickWindowMaxMs = 800;

  int getSramAxsDoubleClickWindowMs() {
    final v = prefs.getInt('sram_axs_double_click_window_ms') ?? _sramAxsDoubleClickWindowDefaultMs;
    return v.clamp(_sramAxsDoubleClickWindowMinMs, _sramAxsDoubleClickWindowMaxMs);
  }

  Future<void> setSramAxsDoubleClickWindowMs(int ms) async {
    final v = ms.clamp(_sramAxsDoubleClickWindowMinMs, _sramAxsDoubleClickWindowMaxMs);
    await prefs.setInt('sram_axs_double_click_window_ms', v);
  }

  bool getShowOnboarding() {
    return !kIsWeb && (prefs.getBool('show_onboarding') ?? true);
  }

  Future<void> setShowOnboarding(bool show) async {
    await prefs.setBool('show_onboarding', show);
  }

  bool hasAskedPermissions() {
    return prefs.getBool('asked_permissions') ?? false;
  }

  Future<void> setHasAskedPermissions(bool asked) async {
    await prefs.setBool('asked_permissions', asked);
  }

  bool getMediaKeyDetectionEnabled() {
    return prefs.getBool('media_key_detection_enabled') ?? false;
  }

  Future<void> setMediaKeyDetectionEnabled(bool enabled) async {
    await prefs.setBool('media_key_detection_enabled', enabled);
  }
}
