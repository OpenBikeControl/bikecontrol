import 'dart:io';

import 'package:bike_control/utils/auth/account_session.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/subscriptions/login.dart';
import 'package:bike_control/pages/subscriptions/registered_devices_view.dart';
import 'package:bike_control/pages/subscriptions/sync_settings_view.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SubscriptionPageView {
  main,
  login,
  syncSettings,
  devices,
}

class SubscriptionPage extends StatefulWidget {
  /// The view to open on. Entry points that already know what the rider needs
  /// (the unregistered-device banner → Registered Devices) skip the main view.
  final SubscriptionPageView initialView;

  const SubscriptionPage({super.key, this.initialView = SubscriptionPageView.main});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final IAPManager _iapManager = IAPManager.instance;
  late SubscriptionPageView _currentView = widget.initialView;
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
    final status = BkStatusColors.of(context);
    if (_iapManager.isProEnabledForCurrentDevice) {
      return status.success;
    } else if (_iapManager.isProEnabled) {
      return status.warning;
    } else if (_iapManager.isPurchased.value) {
      return status.info;
    } else {
      return status.danger;
    }
  }

  IconData _getStatusIcon() {
    if (_iapManager.isProEnabledForCurrentDevice) {
      return LucideIcons.crown;
    } else if (_iapManager.isProEnabled) {
      return LucideIcons.circleEllipsis;
    } else if (_iapManager.isPurchased.value) {
      return LucideIcons.badgeCheck;
    } else {
      return LucideIcons.hourglass;
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
    if (_isPro && hasAccount(core.supabase.auth.currentSession?.user)) {
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
                        Icon(LucideIcons.arrowLeft, size: 16),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context).subscription),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(LucideIcons.chevronRight, size: 16, color: Theme.of(context).colorScheme.mutedForeground),
                  const SizedBox(width: 8),
                  Text(
                    switch (_currentView) {
                      SubscriptionPageView.login => AppLocalizations.of(context).account,
                      SubscriptionPageView.syncSettings => AppLocalizations.of(context).syncSettings,
                      SubscriptionPageView.devices => AppLocalizations.of(context).registeredDevices,
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
    final isOutsideStoreWindowsBuild = _iapManager.isOutsideStoreWindowsBuild;
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text(
                            AppLocalizations.of(context).currentPlan,
                          ).small.muted,
                          Text(
                            IAPManager.instance.getStatusMessage().toUpperCase(),
                            style: BkDisplay.title(context),
                          ),
                        ],
                      ),
                    ),
                    Icon(_getStatusIcon(), size: 24, color: _getStatusColor()),
                  ],
                ),
                if (!_isPro) ...[
                  Divider(),
                  Text(
                    (!_iapManager.isPurchased.value && !isOutsideStoreWindowsBuild)
                        ? AppLocalizations.of(context).unlockTheFullVersionOrGoPro
                        : AppLocalizations.of(context).unlockAllFeaturesWithPro,
                  ).small.muted,
                  if (_iapManager.isWindows && !_iapManager.isWindowsLoggedIn) _buildWindowsAuthWarning(),
                  Row(
                    spacing: 8,
                    children: [
                      if (!_iapManager.isPurchased.value && !isOutsideStoreWindowsBuild)
                        Expanded(
                          child: LoadingWidget(
                            futureCallback: () => _buyFullVersion(),
                            renderChild: (isLoading, tap) => Button.secondary(
                              onPressed: tap,
                              child: isLoading
                                  ? SmallProgressIndicator()
                                  : Text(AppLocalizations.of(context).buyFullVersion),
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
                                isLoading ? SmallProgressIndicator() : Icon(LucideIcons.crown, size: 16),
                                const SizedBox(width: 8),
                                Text(AppLocalizations.of(context).goPro),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_isPro) ...[
                  // Show manage subscription button for Windows Pro users
                  if (_hasStripeCustomer == true || Platform.isIOS || Platform.isAndroid)
                    LoadingWidget(
                      futureCallback: () async {
                        await _openBillingPortal();
                      },
                      renderChild: (isLoading, tap) => Button.secondary(
                        onPressed: tap,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            isLoading ? SmallProgressIndicator() : Icon(LucideIcons.userCog, size: 16),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context).manageSubscription),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),

          BkGroupedSection(
            children: [
              _buildProCard(
                icon: LucideIcons.circleUser,
                title: AppLocalizations.of(context).account,
                subtitle: _getAccountSubtitle(session),
                onTap: () => _navigateTo(SubscriptionPageView.login),
              ),
              _buildProCard(
                icon: LucideIcons.refreshCw,
                title: AppLocalizations.of(context).syncSettings,
                subtitle: AppLocalizations.of(context).synchronizeAcrossDevices,
                onTap: () {
                  _handleLoggedInFeature(() {
                    if (IAPManager.instance.isProEnabledForCurrentDevice) {
                      _navigateTo(SubscriptionPageView.syncSettings);
                    } else {
                      buildToast(title: AppLocalizations.of(context).currentDeviceIsNotRegistered);
                    }
                  });
                },
              ),
              _buildProCard(
                icon: LucideIcons.monitorSmartphone,
                title: AppLocalizations.of(context).registeredDevices,
                subtitle: AppLocalizations.of(context).manageYourDevices,
                onTap: () => _handleLoggedInFeature(() => _navigateTo(SubscriptionPageView.devices)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One row of the account group. Sync and devices are Pro: without Pro
  /// they carry the badge and open the Go Pro dialog instead.
  BkGroupedRow _buildProCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final proOnly = icon != LucideIcons.circleUser;
    final locked = proOnly && !IAPManager.instance.hasActiveSubscription;
    return BkGroupedRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      badge: locked ? const ProBadge() : null,
      chevron: true,
      onPressed: () async {
        if (locked) {
          await showGoProDialog(context);
        } else {
          onTap();
        }
      },
    );
  }

  Widget _buildLoginView() {
    return LoginPage(
      pushed: false,
      onBack: _goBack,
    );
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
    // The support chat's anonymous session is not an account.
    if (session != null && hasAccount(session.user)) {
      return AppLocalizations.of(context).loggedInAsMail(accountLabel(session.user));
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
        color: BkStatusColors.of(context).warningWash,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BkStatusColors.of(context).warning.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, color: BkStatusColors.of(context).warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).windowsSubscriptionsRequireYouToBeLoggedIn,
              style: context.typography.xSmall.copyWith(
                color: BkStatusColors.of(context).warning,
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
