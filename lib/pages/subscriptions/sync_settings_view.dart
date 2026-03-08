import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/models/user_settings.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/repositories/user_settings_repository.dart';
import 'package:bike_control/services/settings_sync_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class SyncSettingsView extends StatefulWidget {
  const SyncSettingsView({super.key});

  @override
  State<SyncSettingsView> createState() => _SyncSettingsViewState();
}

class _SyncSettingsViewState extends State<SyncSettingsView> {
  late final SettingsSyncService _syncService;
  late final UserSettingsRepository _repository;

  UserSettings? _serverSettings;
  List<UserDevice> _registeredDevices = [];
  List<UserSettings> _allDeviceSettings = [];
  bool _isLoading = false;
  bool _hasNewerSettings = false;
  String? _lastSyncText;
  Timer? _syncStatusTimer;

  @override
  void initState() {
    super.initState();
    _repository = UserSettingsRepository(core.supabase);
    _syncService = SettingsSyncService(repository: _repository);
    _syncService.initialize();

    // Listen to sync status changes
    _syncService.lastSyncedAt.addListener(_onSyncStatusChanged);
    _syncService.isSyncing.addListener(_onSyncStatusChanged);
    _syncService.lastError.addListener(_onSyncStatusChanged);

    // Check for updates periodically
    _syncStatusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkForUpdates();
    });

    // Initial load
    _loadData();
  }

  @override
  void dispose() {
    _syncStatusTimer?.cancel();
    _syncService.lastSyncedAt.removeListener(_onSyncStatusChanged);
    _syncService.isSyncing.removeListener(_onSyncStatusChanged);
    _syncService.lastError.removeListener(_onSyncStatusChanged);
    _syncService.dispose();
    super.dispose();
  }

  void _onSyncStatusChanged() {
    if (mounted) {
      setState(() {
        _updateLastSyncText();
      });
    }
  }

  void _updateLastSyncText() {
    final lastSynced = _syncService.lastSyncedAt.value;
    if (lastSynced == null) {
      _lastSyncText = AppLocalizations.of(context).never;
    } else {
      final now = DateTime.now();
      final diff = now.difference(lastSynced);

      if (diff.inMinutes < 1) {
        _lastSyncText = AppLocalizations.of(context).justNow;
      } else if (diff.inMinutes < 60) {
        _lastSyncText = '${diff.inMinutes}min ago';
      } else if (diff.inHours < 24) {
        _lastSyncText = '${diff.inHours}h ago';
      } else {
        _lastSyncText = '${diff.inDays}d ago';
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load current device ID first (needed for filtering)
      await _loadCurrentDeviceId();

      // Load registered devices from DeviceManagementService (same as RegisteredDevicesView)
      _registeredDevices = await IAPManager.instance.deviceManagement.getMyDevices();

      // Load all device settings
      _allDeviceSettings = await _repository.getAllDeviceSettings();

      // Load current server settings
      _serverSettings = await _repository.getSettings();

      _updateLastSyncText();
      await _checkForUpdates();
    } catch (e, s) {
      recordError(e, s, context: 'Load Data');
      print('Error loading sync data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final hasNewer = await _syncService.checkForUpdates();
      if (mounted) {
        setState(() {
          _hasNewerSettings = hasNewer;
        });
      }
    } catch (e, s) {
      recordError(e, s, context: 'Check for Updates');
      print('Error checking for updates: $e');
    }
  }

  Future<void> _syncToServer() async {
    setState(() => _isLoading = true);

    try {
      final success = await _syncService.syncToServer();

      if (mounted) {
        if (success) {
          buildToast(title: AppLocalizations.of(context).settingsSyncedSuccessfully);
          await _loadData();
        } else if (_syncService.lastError.value != null) {
          buildToast(
            title: _syncService.lastError.value!,
            level: LogLevel.LOGLEVEL_ERROR,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncFromServer() async {
    setState(() => _isLoading = true);

    try {
      final success = await _syncService.syncFromServer();

      if (mounted) {
        if (success) {
          buildToast(title: AppLocalizations.of(context).settingsDownloadedFromServer);
          await _loadData();
          setState(() => _hasNewerSettings = false);
        } else if (_syncService.lastError.value != null) {
          buildToast(
            title: _syncService.lastError.value!,
            level: LogLevel.LOGLEVEL_ERROR,
          );
        } else {
          buildToast(
            title: 'No newer settings on server',
            level: LogLevel.LOGLEVEL_WARNING,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    final local = dateTime.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  UserSettings? _getSettingsForDevice(String deviceId) {
    try {
      return _allDeviceSettings.firstWhere(
        (s) => s.deviceId == deviceId,
      );
    } catch (e) {
      return null;
    }
  }

  String? _getDeviceRemoteId(UserDevice device) {
    // Use the remote ID (UUID from user_devices table)
    return device.id;
  }

  /// Returns only devices that have settings available and are not the current device.
  List<UserDevice> _getDevicesWithSettings() {
    return _registeredDevices.where((device) {
      // Skip devices with no settings
      final remoteId = _getDeviceRemoteId(device);
      if (remoteId == null) return false;

      final settings = _getSettingsForDevice(remoteId);
      if (settings == null) return false;

      // Skip the current device
      final isCurrentDevice = _isCurrentDevice(device);
      if (isCurrentDevice) return kDebugMode;

      return true;
    }).toList();
  }

  /// Checks if the given device is the current device.
  bool _isCurrentDevice(UserDevice device) {
    // Compare the local device ID from the UserDevice with the current device's local ID
    return device.deviceId == _currentDeviceId;
  }

  /// The current device's local ID (populated during init).
  String? _currentDeviceId;

  Future<void> _loadCurrentDeviceId() async {
    try {
      _currentDeviceId = await IAPManager.instance.deviceManagement.currentDeviceId();
    } catch (e) {
      print('Error loading current device ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 24,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sync Status Card
          _buildSyncStatusCard(),

          // Device Selection Card
          if (_getDevicesWithSettings().isNotEmpty) _buildDeviceSelectionCard(),

          // Sync Actions
          if (_isLoading)
            Card(
              filled: true,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else ...[
            // Download button (only if newer settings available)
            if (_hasNewerSettings)
              Button.secondary(
                onPressed: _syncFromServer,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_download, size: 20),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context).downloadLatestSettings),
                  ],
                ),
              ),
          ],

          // Info Card
          Card(
            filled: true,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                spacing: 12,
                children: [
                  Icon(Icons.info, size: 20, color: Theme.of(context).colorScheme.primary),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).yourSettingsAreAutomaticallySyncedWhenYouMakeChangesTap,
                    ).small.muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    return Card(
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _hasNewerSettings
                      ? Colors.orange.withAlpha(30)
                      : Theme.of(context).colorScheme.primary.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hasNewerSettings ? Icons.cloud_download : Icons.cloud_sync,
                  size: 28,
                  color: _hasNewerSettings ? Colors.orange : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).syncStatus).small.muted,
                    Text(
                      _hasNewerSettings
                          ? AppLocalizations.of(context).newerSettingsAvailable
                          : AppLocalizations.of(context).settingsSynchronization,
                    ).large.bold,
                  ],
                ),
              ),
            ],
          ),
          Divider(),
          Text(
            AppLocalizations.of(context).synchronizeYourAppSettingsAcrossAllYourDevicesThisIncludes,
          ).small.muted,
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.muted.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                    const SizedBox(width: 8),
                    Text('${AppLocalizations.of(context).lastSynced} ${_lastSyncText ?? 'Never'}').small,
                  ],
                ),
                if (_serverSettings?.version != null)
                  Row(
                    children: [
                      Icon(Icons.tag, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                      const SizedBox(width: 8),
                      Text('Version: ${_serverSettings!.version}').small,
                    ],
                  ),
                // Upload button
                Button.primary(
                  onPressed: _syncToServer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload, size: 20),
                      const SizedBox(width: 12),
                      Text(AppLocalizations.of(context).uploadSettings),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelectionCard() {
    return Card(
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.devices,
                  size: 28,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).yourDevices).small.muted,
                    Text(AppLocalizations.of(context).selectADeviceToSyncFrom).large.bold,
                  ],
                ),
              ),
            ],
          ),
          Divider(),
          ..._getDevicesWithSettings().map((device) => _buildDeviceTile(device)),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(UserDevice device) {
    final remoteDeviceId = _getDeviceRemoteId(device);
    final deviceSettings = remoteDeviceId != null ? _getSettingsForDevice(remoteDeviceId) : null;
    final hasSettings = deviceSettings != null;
    final isNewer = hasSettings && deviceSettings.isNewerThan(_serverSettings);

    return Builder(
      builder: (context) {
        return SelectableCard(
          onPressed: () => _showDeviceOptions(context, device, remoteDeviceId),
          isActive: false,
          title: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  Icons.device_unknown,
                  size: 24,
                  color: Theme.of(context).colorScheme.mutedForeground,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (device.deviceName != null)
                        Text(
                          device.deviceName!,
                        ).small.bold,
                      const SizedBox(height: 4),
                      Text(device.platform.capitalize().replaceAll('os', 'OS')).small.muted,
                      if (hasSettings) ...[
                        const SizedBox(height: 4),
                        Text(_formatDateTime(device.lastSeenAt)).xSmall.muted,
                        Text(
                          'Version: ${deviceSettings.version} • Keymaps: ${deviceSettings.keymaps?.length ?? 0}',
                        ).xSmall.muted,
                      ],
                    ],
                  ),
                ),
                if (isNewer)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      AppLocalizations.of(context).newer,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeviceOptions(BuildContext context, UserDevice device, String? remoteDeviceId) {
    if (remoteDeviceId == null) return;

    showDropdown(
      context: context,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            child: Row(
              children: [
                Icon(Icons.download, size: 20),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).applyNow),
              ],
            ),
            onPressed: (context) async {
              await _syncFromDevice(remoteDeviceId);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _syncFromDevice(String deviceId) async {
    setState(() => _isLoading = true);

    try {
      final success = await _syncService.syncFromServer(deviceId: deviceId);

      if (mounted) {
        if (success) {
          buildToast(title: AppLocalizations.of(context).settingsAppliedFromId(deviceId.substring(0, 8)));
          await _loadData();
          setState(() => _hasNewerSettings = false);
        } else if (_syncService.lastError.value != null) {
          buildToast(
            title: _syncService.lastError.value!,
            level: LogLevel.LOGLEVEL_ERROR,
          );
        } else {
          buildToast(
            title: 'No newer settings available',
            level: LogLevel.LOGLEVEL_WARNING,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
