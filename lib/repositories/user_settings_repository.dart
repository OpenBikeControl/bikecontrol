import 'dart:async';

import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/models/user_settings.dart';
import 'package:bike_control/services/device_identity_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing user settings synchronization with Supabase.
class UserSettingsRepository {
  final SupabaseClient _supabase;
  final DeviceIdentityService _deviceIdentity;
  
  UserSettingsRepository(this._supabase, {DeviceIdentityService? deviceIdentity})
      : _deviceIdentity = deviceIdentity ?? DeviceIdentityService();

  /// Gets the current user's settings from Supabase.
  /// Returns null if no settings exist or user is not logged in.
  Future<UserSettings?> getSettings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response == null) return null;
      
      return UserSettings.fromJson(response);
    } catch (e) {
      print('Error fetching user settings: $e');
      return null;
    }
  }

  /// Gets settings from a specific device.
  /// [deviceId] is the device ID to fetch settings from.
  Future<UserSettings?> getSettingsFromDevice(String deviceId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .eq('device_id', deviceId)
          .maybeSingle();
      
      if (response == null) return null;
      
      return UserSettings.fromJson(response);
    } catch (e) {
      print('Error fetching device settings: $e');
      return null;
    }
  }

  /// Gets all settings for the current user across all devices.
  Future<List<UserSettings>> getAllDeviceSettings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
      
      return (response as List)
          .map((json) => UserSettings.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching all device settings: $e');
      return [];
    }
  }

  /// Gets all registered devices for the current user.
  Future<List<UserDevice>> getRegisteredDevices() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .eq('revoked_at', 'null')
          .order('last_seen_at', ascending: false);
      
      return (response as List)
          .map((json) => UserDevice.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching registered devices: $e');
      return [];
    }
  }

  /// Saves the current local settings to Supabase.
  /// Automatically increments version and handles conflict resolution.
  Future<UserSettings?> saveSettings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      // Get remote device ID (from user_devices table)
      final deviceId = await _deviceIdentity.getRemoteId(_supabase);
      if (deviceId == null || deviceId.isEmpty) {
        print('Cannot save settings: device is not registered');
        return null;
      }

      // Get current settings from server
      final currentSettings = await getSettings();
      final newVersion = (currentSettings?.version ?? 0) + 1;

      // Build keymaps JSON from current settings
      final keymapsData = await _buildKeymapsData();
      
      // Get ignored devices
      final ignoredDevices = core.settings.getIgnoredDevices();
      final ignoredIds = ignoredDevices.map((d) => d.id).toList();
      final ignoredNames = ignoredDevices.map((d) => d.name).toList();

      final settings = UserSettings(
        userId: userId,
        deviceId: deviceId,
        keymaps: keymapsData,
        ignoredDeviceIds: ignoredIds,
        ignoredDeviceNames: ignoredNames,
        version: newVersion,
      );

      final response = await _supabase
          .from('user_settings')
          .upsert(
            settings.toJson(),
            onConflict: 'user_id,device_id',
          )
          .select()
          .single();

      return UserSettings.fromJson(response);
    } catch (e) {
      print('Error saving user settings: $e');
      return null;
    }
  }

  /// Loads settings from Supabase and applies them locally.
  /// Returns true if settings were applied, false otherwise.
  /// If [deviceId] is provided, loads settings from that specific device.
  Future<bool> loadAndApplySettings({String? deviceId}) async {
    UserSettings? settings;
    
    if (deviceId != null) {
      settings = await getSettingsFromDevice(deviceId);
    } else {
      settings = await getSettings();
    }
    
    if (settings == null) return false;

    try {
      // Apply keymaps
      if (settings.keymaps != null) {
        await _applyKeymaps(settings.keymaps!);
      }

      // Apply ignored devices
      if (settings.ignoredDeviceIds != null && settings.ignoredDeviceNames != null) {
        await _applyIgnoredDevices(settings.ignoredDeviceIds!, settings.ignoredDeviceNames!);
      }

      return true;
    } catch (e) {
      print('Error applying settings: $e');
      return false;
    }
  }

  /// Checks if server settings are newer than local.
  /// Returns true if server has newer data.
  /// If [deviceId] is provided, checks settings from that specific device.
  Future<bool> hasNewerSettingsOnServer({String? deviceId}) async {
    UserSettings? serverSettings;
    
    if (deviceId != null) {
      serverSettings = await getSettingsFromDevice(deviceId);
    } else {
      serverSettings = await getSettings();
    }
    
    if (serverSettings == null) return false;

    // Get local version from settings
    final localVersion = core.settings.prefs.getInt('settings_version') ?? 0;
    final localUpdatedAt = core.settings.prefs.getString('settings_updated_at');
    final localDateTime = localUpdatedAt != null ? DateTime.tryParse(localUpdatedAt) : null;

    final localSettings = UserSettings(
      version: localVersion,
      updatedAt: localDateTime,
    );

    return serverSettings.isNewerThan(localSettings);
  }

  /// Gets the last sync information.
  Future<({DateTime? lastSynced, int? version})> getLastSyncInfo() async {
    final settings = await getSettings();
    return (
      lastSynced: settings?.updatedAt,
      version: settings?.version,
    );
  }

  /// Builds keymaps data from current settings.
  Future<Map<String, dynamic>> _buildKeymapsData() async {
    final data = <String, dynamic>{};
    
    // Get all custom app profiles
    final profiles = core.settings.getCustomAppProfiles();
    
    for (final profileName in profiles) {
      final keymap = core.settings.getCustomAppKeymap(profileName);
      if (keymap != null) {
        data[profileName] = keymap;
      }
    }

    // Include current app
    final currentApp = core.settings.getKeyMap();
    if (currentApp != null) {
      data['_current_app'] = currentApp.name;
    }

    return data;
  }

  /// Applies keymaps from server data.
  Future<void> _applyKeymaps(Map<String, dynamic> keymapsData) async {
    for (final entry in keymapsData.entries) {
      if (entry.key == '_current_app') {
        // Set current app if it exists
        final appName = entry.value as String?;
        if (appName != null) {
          // Find the app and set it
          // This will be handled by the settings system
          await core.settings.prefs.setString('app', appName);
        }
        continue;
      }

      // Save keymap data for custom app
      if (entry.value is List) {
        final keymapList = (entry.value as List).map((e) => e.toString()).toList();
        await core.settings.prefs.setStringList('customapp_${entry.key}', keymapList);
      }
    }
  }

  /// Applies ignored devices from server data.
  Future<void> _applyIgnoredDevices(List<String> ids, List<String> names) async {
    await core.settings.prefs.setStringList('ignored_device_ids', ids);
    await core.settings.prefs.setStringList('ignored_device_names', names);
  }

  /// Saves the local version information after successful sync.
  Future<void> saveLocalVersionInfo(int version, DateTime updatedAt) async {
    await core.settings.prefs.setInt('settings_version', version);
    await core.settings.prefs.setString('settings_updated_at', updatedAt.toIso8601String());
  }
}
