import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/pages/login.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

enum SubscriptionPageView {
  main,
  login,
  syncSettings,
  devices,
}

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final IAPManager _iapManager = IAPManager.instance;
  SubscriptionPageView _currentView = SubscriptionPageView.main;
  bool _isSyncingSettings = false;

  String _getVersionStatus() {
    if (_iapManager.isProEnabledForCurrentDevice) {
      return 'Pro Version';
    } else if (_iapManager.isProEnabled) {
      return 'Subscription Active (Device Not Registered)';
    } else if (_iapManager.isPurchased.value) {
      return 'Full Version';
    } else {
      return 'Trial Version';
    }
  }

  Color _getStatusColor() {
    if (_iapManager.isProEnabledForCurrentDevice) {
      return Colors.green;
    } else if (_iapManager.isProEnabled) {
      return Colors.orange;
    } else if (_iapManager.isPurchased.value) {
      return Colors.blue;
    } else {
      return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    if (_iapManager.isProEnabledForCurrentDevice) {
      return Icons.workspace_premium;
    } else if (_iapManager.isProEnabled) {
      return Icons.pending;
    } else if (_iapManager.isPurchased.value) {
      return Icons.verified;
    } else {
      return Icons.hourglass_empty;
    }
  }

  bool get _isPro => _iapManager.hasActiveSubscription;

  void _navigateTo(SubscriptionPageView view) {
    setState(() {
      _currentView = view;
    });
  }

  void _goBack() {
    setState(() {
      _currentView = SubscriptionPageView.main;
    });
  }

  void _showGoProDialog() {
    showDialog(
      context: context,
      builder: (c) => Container(
        constraints: BoxConstraints(maxWidth: 400),
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Pro Feature'),
            ],
          ),
          content: Text('This feature is only available with Pro. Upgrade to Pro to unlock all features.'),
          actions: [
            Button.secondary(
              onPressed: () => Navigator.of(c).pop(),
              child: Text('Cancel'),
            ),
            Button.primary(
              onPressed: () {
                Navigator.of(c).pop();
                _buyProVersion();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium, size: 16),
                  const SizedBox(width: 8),
                  Text('Go Pro'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleProFeature(VoidCallback action) {
    if (_isPro) {
      action();
    } else {
      _showGoProDialog();
    }
  }

  void _handleLoggedInFeature(VoidCallback action) {
    if (_isPro && core.supabase.auth.currentSession != null) {
      action();
    } else {
      _handleProFeature(() {
        _navigateTo(SubscriptionPageView.login);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Breadcrumbs
          if (_currentView != SubscriptionPageView.main)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Button.secondary(
                    onPressed: _goBack,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, size: 16),
                        const SizedBox(width: 8),
                        Text('Subscription'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                  const SizedBox(width: 8),
                  Text(
                    switch (_currentView) {
                      SubscriptionPageView.login => 'Account',
                      SubscriptionPageView.syncSettings => 'Sync Settings',
                      SubscriptionPageView.devices => 'Registered Devices',
                      _ => '',
                    },
                  ).small,
                ],
              ),
            ),
          // Content
          Flexible(
            child: switch (_currentView) {
              SubscriptionPageView.main => _buildMainView(),
              SubscriptionPageView.login => _buildLoginView(),
              SubscriptionPageView.syncSettings => _buildSyncSettingsView(),
              SubscriptionPageView.devices => _buildDevicesView(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    final session = core.supabase.auth.currentSession;
    print(
      "Is Pro: ${_isPro}, Purchased: ${_iapManager.isPurchased.value}, Subscription Active: ${_iapManager.hasActiveSubscription}",
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Version Status Card
          Card(
            child: Column(
              spacing: 16,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(),
                        size: 28,
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Plan',
                          ).small.muted,
                          Text(
                            _getVersionStatus(),
                          ).large.bold,
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_isPro) ...[
                  Divider(),
                  Text(
                    'Unlock all features with Pro',
                  ).small.muted,
                  Row(
                    spacing: 8,
                    children: [
                      if (!_iapManager.isPurchased.value)
                        Expanded(
                          child: Button.secondary(
                            onPressed: _buyFullVersion,
                            child: Text('Buy Full Version'),
                          ),
                        ),
                      Expanded(
                        child: Button.primary(
                          onPressed: _buyProVersion,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.workspace_premium, size: 16),
                              const SizedBox(width: 8),
                              Text('Go Pro'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Account Section
          _buildProCard(
            icon: Icons.account_circle,
            title: 'Account',
            subtitle: session != null ? 'Logged in as ${session.user.email}' : 'Not logged in',
            onTap: () => _handleProFeature(() => _navigateTo(SubscriptionPageView.login)),
          ),

          // Sync Settings Section
          _buildProCard(
            icon: Icons.sync,
            title: 'Sync Settings',
            subtitle: 'Synchronize across devices',
            onTap: () => _handleLoggedInFeature(() => _navigateTo(SubscriptionPageView.syncSettings)),
          ),

          // Registered Devices Section
          _buildProCard(
            icon: Icons.devices,
            title: 'Registered Devices',
            subtitle: 'Manage your devices',
            onTap: () => _handleLoggedInFeature(() => _navigateTo(SubscriptionPageView.devices)),
          ),
        ],
      ),
    );
  }

  Widget _buildProCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SelectableCard(
      onPressed: onTap,
      isActive: false,
      title: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title).small.bold,
                      const SizedBox(height: 4),
                      Text(subtitle).small.muted,
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: Theme.of(context).colorScheme.mutedForeground),
              ],
            ),
          ),
          if (!_isPro)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginView() {
    return LoginPage();
  }

  Widget _buildDevicesView() {
    return _RegisteredDevicesView(
      onBack: _goBack,
    );
  }

  Widget _buildSyncSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 24,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sync Status Card
          Card(
            child: Column(
              spacing: 16,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_sync,
                        size: 28,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sync Status').small.muted,
                          Text('Settings Synchronization').large.bold,
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
                          Text('Last synced: Never').small,
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.devices, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                          const SizedBox(width: 8),
                          Text('Synced devices: 0').small,
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sync Now Button
          if (_isSyncingSettings)
            Card(
              filled: true,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  spacing: 16,
                  children: [
                    CircularProgressIndicator(),
                    Text('Syncing your settings...').small.muted,
                  ],
                ),
              ),
            )
          else
            Button.primary(
              onPressed: _syncSettings,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_sync, size: 20),
                  const SizedBox(width: 12),
                  Text('Sync Now'),
                ],
              ),
            ),

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
                      'Your settings will be securely stored and synchronized across all devices logged into your account.',
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

  void _showSyncSettings() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sync, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Sync Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Synchronize your settings across all devices.'),
            const SizedBox(height: 16),
            if (_isSyncingSettings)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text('Syncing...').small.muted,
                  ],
                ),
              )
            else
              Text('Last synced: Never').small.muted,
          ],
        ),
        actions: [
          Button.secondary(
            onPressed: () => Navigator.of(c).pop(),
            child: Text('Close'),
          ),
          if (!_isSyncingSettings)
            Button.primary(
              onPressed: () async {
                Navigator.of(c).pop();
                await _syncSettings();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_sync, size: 16),
                  const SizedBox(width: 8),
                  Text('Sync Now'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _buyFullVersion() {
    _iapManager.purchaseFullVersion(context);
  }

  void _buyProVersion() {
    _iapManager.purchaseSubscription(context);
  }

  Future<void> _syncSettings() async {
    setState(() {
      _isSyncingSettings = true;
    });

    await Future.delayed(Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isSyncingSettings = false;
      });
    }
  }
}

class _RegisteredDevicesView extends StatefulWidget {
  final VoidCallback onBack;

  const _RegisteredDevicesView({required this.onBack});

  @override
  State<_RegisteredDevicesView> createState() => _RegisteredDevicesViewState();
}

class _RegisteredDevicesViewState extends State<_RegisteredDevicesView> {
  final IAPManager _iapManager = IAPManager.instance;
  bool _isLoading = false;
  Map<String, List<UserDevice>> _devicesByPlatform = {};

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final devices = await _iapManager.deviceManagement.getMyDevices();
      final grouped = <String, List<UserDevice>>{};
      for (final device in devices) {
        grouped.putIfAbsent(device.platform, () => <UserDevice>[]).add(device);
      }
      if (mounted) {
        setState(() {
          _devicesByPlatform = grouped;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoading)
            Center(
              child: Column(
                spacing: 16,
                children: [
                  CircularProgressIndicator(),
                  Text('Loading devices...').small.muted,
                ],
              ),
            ),
          if (!IAPManager.instance.isProEnabledForCurrentDevice)
            LoadingWidget(
              futureCallback: _registerCurrentDevice,
              renderChild: (isLoading, tap) => Button.primary(
                onPressed: tap,
                child: isLoading
                    ? SmallProgressIndicator()
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('Register current device'),
                        ],
                      ),
              ),
            ),

          if (_devicesByPlatform.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.muted.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  spacing: 12,
                  children: [
                    Icon(
                      Icons.devices,
                      size: 48,
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
                    Text('No devices registered').small.muted,
                  ],
                ),
              ),
            )
          else
            ..._devicesByPlatform.entries.map((entry) => _buildPlatformSection(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildPlatformSection(String platform, List<UserDevice> devices) {
    return Card(
      child: Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(platform.toUpperCase()).small.bold,
              const Spacer(),
              Text('${devices.where((d) => d.isActive).length} active').small.muted,
            ],
          ),
          Divider(),
          ...devices.map((device) => _buildDeviceTile(device)),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(UserDevice device) {
    final isRevoked = device.isRevoked;

    return Card(
      filled: true,
      child: Row(
        children: [
          Icon(
            Icons.device_unknown,
            size: 20,
            color: isRevoked ? Theme.of(context).colorScheme.mutedForeground : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  device.deviceName?.isNotEmpty == true ? device.deviceName! : device.deviceId.split("|").first,
                ).small.bold,
                if (device.deviceName?.isNotEmpty == true) Text('ID: ${device.deviceId.split("|").first}').small.muted,
                Text('Last seen: ${_formatDate(device.lastSeenAt)}').small.muted,
              ],
            ),
          ),
          if (isRevoked)
            Text(
              'Revoked',
              style: TextStyle(color: Colors.red, fontSize: 12),
            )
          else
            Button.secondary(
              onPressed: () => _revokeDevice(device),
              child: Text('Revoke'),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Never';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _revokeDevice(UserDevice device) async {
    try {
      await _iapManager.deviceManagement.revokeDevice(
        platform: device.platform,
        deviceId: device.deviceId,
      );
      await _iapManager.entitlements.refresh(force: true);
      await _loadDevices();
    } catch (e) {
      buildToast(title: 'Could not revoke device: $e');
    }
  }

  Future<void> _registerCurrentDevice() async {
    try {
      final platform = await _iapManager.deviceManagement.currentPlatform();
      final deviceName = 'BikeControl ${platform?.toUpperCase() ?? ''}';

      final package = await PackageInfo.fromPlatform();
      final version = package.version;

      final result = await _iapManager.deviceManagement.registerCurrentDevice(
        deviceName: deviceName,
        appVersion: version,
      );
      await _iapManager.entitlements.refresh(force: true);
      await _loadDevices();
      if (!mounted) return;
      setState(() {});
    } on DeviceLimitReachedError catch (error) {
      if (!mounted) return;
      buildToast(title: 'Device limit reached for ${error.platform}');
    } catch (error) {
      if (!mounted) return;
      buildToast(title: 'Could not register device: $error');
    }
  }
}
