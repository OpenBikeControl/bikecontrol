import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/pages/subscriptions/login.dart';
import 'package:bike_control/pages/subscriptions/registered_devices_view.dart';
import 'package:bike_control/pages/subscriptions/sync_settings_view.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool? _hasStripeCustomer;

  @override
  void initState() {
    super.initState();
    _checkStripeCustomer();
    _iapManager.entitlements.addListener(_onEntitlementsChanged);
  }

  @override
  dispose() {
    _iapManager.entitlements.removeListener(_onEntitlementsChanged);
    super.dispose();
  }

  Future<void> _checkStripeCustomer() async {
    if (_iapManager.isWindows && _iapManager.isLoggedIn) {
      final hasCustomer = await _iapManager.hasStripeCustomer();
      if (mounted) {
        setState(() {
          _hasStripeCustomer = hasCustomer;
        });
      }
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
    showGoProDialog(context);
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
                            IAPManager.instance.getStatusMessage(),
                          ).large.bold,
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_isPro) ...[
                  Divider(),
                  Text(
                    !_iapManager.isPurchased.value
                        ? 'Unlock the full version - or Go Pro'
                        : 'Unlock all features with Pro',
                  ).small.muted,
                  if (_iapManager.isWindows && !_iapManager.isWindowsLoggedIn) _buildWindowsAuthWarning(),
                  Row(
                    spacing: 8,
                    children: [
                      if (!_iapManager.isPurchased.value)
                        Expanded(
                          child: LoadingWidget(
                            futureCallback: () => _buyFullVersion(),
                            renderChild: (isLoading, tap) => Button.secondary(
                              onPressed: tap,
                              child: isLoading ? SmallProgressIndicator() : Text('Buy Full Version'),
                            ),
                          ),
                        ),
                      Expanded(
                        child: LoadingWidget(
                          futureCallback: () => _buyProVersion(),
                          renderChild: (isLoading, tap) => Button.primary(
                            onPressed: tap,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                isLoading ? SmallProgressIndicator() : Icon(Icons.workspace_premium, size: 16),
                                const SizedBox(width: 8),
                                Text('Go Pro'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_isPro && _iapManager.isWindows) ...[
                  // Show manage subscription button for Windows Pro users
                  if (_hasStripeCustomer == true)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(),
                        LoadingWidget(
                          futureCallback: () async {
                            await _openBillingPortal();
                          },
                          renderChild: (isLoading, tap) => Button.secondary(
                            onPressed: tap,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                isLoading ? SmallProgressIndicator() : Icon(Icons.manage_accounts, size: 16),
                                const SizedBox(width: 8),
                                Text('Manage Subscription'),
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
            subtitle: _getAccountSubtitle(session),
            onTap: () => _navigateTo(SubscriptionPageView.login),
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
      isProOnly: icon != Icons.account_circle,
      title: Padding(
        padding: const EdgeInsets.all(8),
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
    );
  }

  Widget _buildLoginView() {
    return LoginPage(pushed: false);
  }

  Widget _buildDevicesView() {
    return RegisteredDevicesView(
      onBack: _goBack,
    );
  }

  Widget _buildSyncSettingsView() {
    return SyncSettingsView();
  }

  Future<void> _buyFullVersion() {
    return _iapManager.purchaseFullVersion(context);
  }

  Future<void> _buyProVersion() {
    return _iapManager.purchaseSubscription(context);
  }

  Future<void> _openBillingPortal() async {
    final shouldShowButton = await _iapManager.openBillingPortal(context);
    if (!shouldShowButton && mounted) {
      setState(() {
        _hasStripeCustomer = false;
      });
    }
  }

  /// Get the account subtitle with Windows-specific messaging
  String _getAccountSubtitle(Session? session) {
    if (session != null) {
      return 'Logged in as ${session.user.email}';
    }

    if (_iapManager.isWindows) {
      return 'Not logged in - Required for subscription';
    }

    return 'Not logged in';
  }

  /// Shows a warning on Windows that authentication is required for subscriptions
  Widget _buildWindowsAuthWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Windows subscriptions require you to be logged in',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onEntitlementsChanged() {
    setState(() {});
  }
}
