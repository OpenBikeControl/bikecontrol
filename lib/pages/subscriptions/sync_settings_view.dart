import 'dart:async';

import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/models/user_settings.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/repositories/user_settings_repository.dart';
import 'package:bike_control/services/settings_sync_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/toast.dart';
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
  String? _selectedDeviceId;
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
      _lastSyncText = 'Never';
    } else {
      final now = DateTime.now();
      final diff = now.difference(lastSynced);
      
      if (diff.inMinutes < 1) {
        _lastSyncText = 'Just now';
      } else if (diff.inMinutes < 60) {
        _lastSyncText = '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
      } else if (diff.inHours < 24) {
        _lastSyncText = '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
      } else {
        _lastSyncText = '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
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
    } catch (e) {
      print('Error loading sync data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final hasNewer = await _syncService.checkForUpdates(deviceId: _selectedDeviceId);
      if (mounted) {
        setState(() {
          _hasNewerSettings = hasNewer;
        });
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
  }

  Future<void> _syncToServer() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await _syncService.syncToServer();
      
      if (mounted) {
        if (success) {
          buildToast(title: 'Settings synced successfully');
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
      final success = await _syncService.syncFromServer(deviceId: _selectedDeviceId);
      
      if (mounted) {
        if (success) {
          buildToast(title: 'Settings downloaded from server');
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

  void _onDeviceSelected(String? deviceId) {
    setState(() {
      _selectedDeviceId = deviceId;
    });
    _checkForUpdates();
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
      if (isCurrentDevice) return false;
      
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
          if (_getDevicesWithSettings().isNotEmpty)
            _buildDeviceSelectionCard(),

          // Selected Device Settings Card
          if (_selectedDeviceId != null)
            _buildSelectedDeviceSettingsCard(),

          // Server Settings Card (if available and no device selected)
          if (_selectedDeviceId == null && _serverSettings != null && _serverSettings!.updatedAt != null)
            _buildServerSettingsCard(),

          // Sync Actions
          if (_isLoading)
            Card(
              filled: true,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  spacing: 16,
                  children: [
                    CircularProgressIndicator(),
                    Text('Syncing...').small.muted,
                  ],
                ),
              ),
            )
          else ...[
            // Upload button
            Button.primary(
              onPressed: _syncToServer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload, size: 20),
                  const SizedBox(width: 12),
                  Text('Upload Settings'),
                ],
              ),
            ),

            // Download button (only if newer settings available)
            if (_hasNewerSettings)
              Button.secondary(
                onPressed: _syncFromServer,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_download, size: 20),
                    const SizedBox(width: 12),
                    Text(_selectedDeviceId != null 
                        ? 'Use Settings from Selected Device'
                        : 'Download Settings from Server'),
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
                      'Your settings are automatically synced when you make changes. You can also manually sync using the buttons above. Select a device to sync settings from that specific device.',
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
                    Text('Sync Status').small.muted,
                    Text(
                      _hasNewerSettings 
                          ? 'Newer settings available'
                          : 'Settings Synchronization'
                    ).large.bold,
                  ],
                ),
              ),
            ],
          ),
          Divider(),
          Text(
            'Synchronize your app settings across all your devices. This includes your keymaps, button configurations, and preferences.',
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
                    Text('Last synced: ${_lastSyncText ?? 'Never'}').small,
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
                    Text('Your Devices').small.muted,
                    Text('Select a device to sync from').large.bold,
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
    final isSelected = _selectedDeviceId == remoteDeviceId;
    final deviceSettings = remoteDeviceId != null ? _getSettingsForDevice(remoteDeviceId) : null;
    final hasSettings = deviceSettings != null;
    final isNewer = hasSettings && deviceSettings.isNewerThan(_serverSettings);

    return SelectableCard(
      onPressed: () => _onDeviceSelected(isSelected ? null : remoteDeviceId),
      isActive: isSelected,
      title: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.device_unknown,
                  size: 24,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.mutedForeground,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceName ?? 'Unknown Device',
                      ).small.bold,
                      const SizedBox(height: 4),
                      Text('${device.platform.toUpperCase()} • ${_formatDateTime(device.lastSeenAt)}').small.muted,
                      if (hasSettings) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Version: ${deviceSettings.version} • Keymaps: ${deviceSettings.keymaps?.length ?? 0}',
                        ).small.muted,
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
                      'NEWER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (isSelected)
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                else
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.mutedForeground),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDeviceSettingsCard() {
    UserDevice? device;
    try {
      device = _registeredDevices.firstWhere(
        (d) => d.id == _selectedDeviceId,
      );
    } catch (e) {
      device = null;
    }
    
    if (device == null) return const SizedBox.shrink();
    
    final remoteDeviceId = _getDeviceRemoteId(device);
    final deviceSettings = remoteDeviceId != null ? _getSettingsForDevice(remoteDeviceId) : null;
    final keymapCount = deviceSettings?.keymaps?.length ?? 0;
    final ignoredDeviceCount = deviceSettings?.ignoredDeviceIds?.length ?? 0;

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
                  color: Colors.green.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.download,
                  size: 28,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selected Device').small.muted,
                    Text(device.deviceName ?? 'Unknown Device').large.bold,
                  ],
                ),
              ),
            ],
          ),
          Divider(),
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
                    Text('Last updated: ${_formatDateTime(deviceSettings?.updatedAt)}').small,
                  ],
                ),
                if (deviceSettings?.version != null)
                  Row(
                    children: [
                      Icon(Icons.tag, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                      const SizedBox(width: 8),
                      Text('Version: ${deviceSettings!.version}').small,
                    ],
                  ),
                Row(
                  children: [
                    Icon(Icons.keyboard, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                    const SizedBox(width: 8),
                    Text('Keymaps: $keymapCount profiles').small,
                  ],
                ),
                if (ignoredDeviceCount > 0)
                  Row(
                    children: [
                      Icon(Icons.devices, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                      const SizedBox(width: 8),
                      Text('Ignored devices: $ignoredDeviceCount').small,
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerSettingsCard() {
    final keymapCount = _serverSettings?.keymaps?.length ?? 0;
    final ignoredDeviceCount = _serverSettings?.ignoredDeviceIds?.length ?? 0;

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
                  color: Colors.blue.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storage,
                  size: 28,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Server Settings').small.muted,
                    Text('Cloud Backup').large.bold,
                  ],
                ),
              ),
            ],
          ),
          Divider(),
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
                    Text('Last updated: ${_formatDateTime(_serverSettings?.updatedAt)}').small,
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.keyboard, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                    const SizedBox(width: 8),
                    Text('Keymaps: $keymapCount profiles').small,
                  ],
                ),
                if (ignoredDeviceCount > 0)
                  Row(
                    children: [
                      Icon(Icons.devices, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                      const SizedBox(width: 8),
                      Text('Ignored devices: $ignoredDeviceCount').small,
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
