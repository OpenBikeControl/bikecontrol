import 'dart:async';

import 'package:bike_control/models/user_settings.dart';
import 'package:bike_control/repositories/user_settings_repository.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/foundation.dart';

/// Service that manages automatic syncing of settings for Pro users.
class SettingsSyncService {
  final UserSettingsRepository _repository;
  bool _isSyncing = false;

  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(null);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  SettingsSyncService({UserSettingsRepository? repository})
    : _repository = repository ?? UserSettingsRepository(core.supabase);

  /// Initializes the sync service and sets up listeners.
  Future<void> initialize() async {
    // Check if user is pro and logged in
    if (!_canSync()) return;

    // Load last sync info
    await _loadLastSyncInfo();

    // Listen for settings changes
    _setupSettingsListeners();
  }

  /// Disposes resources.
  void dispose() {
    lastSyncedAt.dispose();
    isSyncing.dispose();
    lastError.dispose();
  }

  /// Checks if the user can sync (is pro and logged in).
  bool _canSync() {
    return IAPManager.instance.hasActiveSubscription && IAPManager.instance.isLoggedIn;
  }

  /// Loads the last sync information.
  Future<void> _loadLastSyncInfo() async {
    if (!_canSync()) return;

    try {
      final info = await _repository.getLastSyncInfo();
      lastSyncedAt.value = info.lastSynced;
    } catch (e) {
      print('Error loading last sync info: $e');
    }
  }

  /// Syncs local settings to the server.
  /// Returns true if sync was successful.
  Future<bool> syncToServer() async {
    if (_isSyncing) return false;
    if (!_canSync()) {
      lastError.value = 'Pro subscription required';
      return false;
    }

    _isSyncing = true;
    isSyncing.value = true;
    lastError.value = null;

    try {
      final settings = await _repository.saveSettings();

      if (settings != null) {
        lastSyncedAt.value = settings.updatedAt;
        await _repository.saveLocalVersionInfo(settings.version, settings.updatedAt ?? DateTime.now());
        return true;
      } else {
        lastError.value = 'Failed to save settings';
        return false;
      }
    } catch (e) {
      lastError.value = e.toString();
      return false;
    } finally {
      _isSyncing = false;
      isSyncing.value = false;
    }
  }

  /// Syncs from server to local (download settings).
  /// Returns true if sync was successful.
  /// If [deviceId] is provided, syncs settings from that specific device.
  Future<bool> syncFromServer({String? deviceId}) async {
    if (_isSyncing) return false;
    if (!_canSync()) {
      lastError.value = 'Pro subscription required';
      return false;
    }

    _isSyncing = true;
    isSyncing.value = true;
    lastError.value = null;

    try {
      final hasNewer = await _repository.hasNewerSettingsOnServer(deviceId: deviceId);

      if (!hasNewer) {
        // No newer settings on server
        return true;
      }

      final success = await _repository.loadAndApplySettings(deviceId: deviceId);

      if (success) {
        // Update last sync info
        UserSettings? settings;
        if (deviceId != null) {
          settings = await _repository.getSettingsFromDevice(deviceId);
        } else {
          settings = await _repository.getSettings();
        }
        
        if (settings != null) {
          lastSyncedAt.value = settings.updatedAt;
          await _repository.saveLocalVersionInfo(settings.version, settings.updatedAt ?? DateTime.now());
        }
      }

      return success;
    } catch (e) {
      lastError.value = e.toString();
      return false;
    } finally {
      _isSyncing = false;
      isSyncing.value = false;
    }
  }

  /// Checks if server has newer settings.
  /// If [deviceId] is provided, checks settings from that specific device.
  Future<bool> checkForUpdates({String? deviceId}) async {
    if (!_canSync()) return false;

    try {
      return await _repository.hasNewerSettingsOnServer(deviceId: deviceId);
    } catch (e) {
      return false;
    }
  }

  /// Sets up listeners for settings changes to trigger auto-sync.
  void _setupSettingsListeners() {
    // Listen to settings changes - this is a simplified approach
    // In a real implementation, you'd want to debounce these calls
  }
}
