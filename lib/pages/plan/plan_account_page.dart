import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/widgets/menu.dart' show debugText;
import 'package:bike_control/main.dart';
import 'package:bike_control/models/device_limit_reached_error.dart';
import 'package:bike_control/models/subscription_term.dart';
import 'package:bike_control/models/user_device.dart';
import 'package:bike_control/pages/plan/account_section.dart';
import 'package:bike_control/pages/plan/plan_faq_page.dart';
import 'package:bike_control/pages/plan/plan_summary_card.dart';
import 'package:bike_control/pages/plan/registered_devices_section.dart';
import 'package:bike_control/pages/plan/sync_settings_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/repositories/user_settings_repository.dart';
import 'package:bike_control/services/email_otp_auth_service.dart';
import 'package:bike_control/utils/auth/account_session.dart';
import 'package:bike_control/utils/auth/social_sign_in.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/plan_format.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Opens Plan & account as a pushed page. In a wide window opened from the
/// shell, the sidebar stays beside it. [showDevices] scrolls to the
/// registered devices, [showAccount] to Konto (sign in).
Future<void> openPlanAccount(BuildContext context, {bool showDevices = false, bool showAccount = false}) {
  final page = PlanAccountPage(showDevices: showDevices, showAccount: showAccount);
  final shell = ShellScope.maybeOf(context);
  if (shell == null) return context.push(page);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => _BesideSidebar(shell: shell, child: page),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (context, animation, _, child) => MediaQuery.of(context).disableAnimations
          ? child
          : FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            ),
    ),
  );
}

/// The pushed page beside the shell's sidebar from 840; alone below that.
class _BesideSidebar extends StatelessWidget {
  const _BesideSidebar({required this.shell, required this.child});

  final ShellController shell;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < Breakpoints.medium) return child;
    return ColoredBox(
      color: Theme.of(context).colorScheme.background,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShellSidebar(
              controller: shell,
              planSelected: true,
              onSectionSelected: () => Navigator.of(context).maybePop(),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Plan & account: the plan and the rider's next step (go Pro, register this
/// device, sign in), then the account, the registered devices and sync,
/// purchases and help, as grouped rows.
///
/// The constructor's callbacks are test seams; null runs the real service.
class PlanAccountPage extends StatefulWidget {
  const PlanAccountPage({
    super.key,
    this.showDevices = false,
    this.showAccount = false,
    this.client,
    this.emailAuth,
    this.socialSignIn,
    this.loadDevices,
    this.currentDeviceId,
    this.currentPlatform,
    this.removeDevice,
    this.registerDevice,
    this.restorePurchases,
    this.manageSubscription,
    this.loadLastSynced,
    this.hasBillingPortal,
  });

  /// Opened to manage devices: scroll them into view.
  final bool showDevices;

  /// Opened to sign in: scroll Konto to the top, past the plan card.
  final bool showAccount;

  final SupabaseClient? client;
  final EmailOtpAuth? emailAuth;
  final Future<void> Function(OAuthProvider provider)? socialSignIn;
  final Future<List<UserDevice>> Function()? loadDevices;
  final Future<String?> Function()? currentDeviceId;
  final Future<String?> Function()? currentPlatform;
  final Future<void> Function(UserDevice device)? removeDevice;

  /// Throws [DeviceLimitReachedError] at the platform's limit.
  final Future<void> Function()? registerDevice;
  final Future<void> Function()? restorePurchases;
  final Future<void> Function()? manageSubscription;
  final Future<DateTime?> Function()? loadLastSynced;
  final Future<bool> Function()? hasBillingPortal;

  @override
  State<PlanAccountPage> createState() => _PlanAccountPageState();
}

class _PlanAccountPageState extends State<PlanAccountPage> {
  final IAPManager _iap = IAPManager.instance;
  late final Listenable _iapState = Listenable.merge([
    _iap.entitlements,
    _iap.isPurchased,
    _iap.isLocalPro,
    _iap.storeTerm,
  ]);
  StreamSubscription<AuthState>? _authSub;
  final GlobalKey _devicesKey = GlobalKey();
  final GlobalKey _accountKey = GlobalKey();

  List<UserDevice>? _devices;
  bool _devicesFailed = false;
  String? _currentDeviceId;
  String? _currentPlatform;
  DateTime? _lastSynced;
  bool _hasBillingPortal = false;
  DeviceLimitReachedError? _limit;
  bool _registering = false;
  bool _restoring = false;
  final Set<String> _removing = {};

  SupabaseClient get _client => widget.client ?? core.supabase;

  bool get _signedIn => hasAccount(_client.auth.currentSession?.user);

  /// Devices and sync belong to an account with Pro.
  bool get _hasAccountPro => _signedIn && _iap.isProEnabled;

  @override
  void initState() {
    super.initState();
    _iapState.addListener(_onIapChanged);
    _authSub = _client.auth.onAuthStateChange.listen(
      (_) {
        if (!mounted) return;
        setState(() {});
        unawaited(_load());
      },
      onError: (Object e, StackTrace s) => recordError(e, s, context: 'Plan: auth state'),
    );
    unawaited(_load(scrollToDevices: widget.showDevices));
    if (widget.showAccount) WidgetsBinding.instance.addPostFrameCallback((_) => _revealAccount());
  }

  void _revealAccount() {
    final target = _accountKey.currentContext;
    if (!mounted || target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _iapState.removeListener(_onIapChanged);
    _authSub?.cancel();
    super.dispose();
  }

  void _onIapChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool scrollToDevices = false}) async {
    if (_iap.purchaseChannel == PurchaseChannel.windowsDirect ||
        _iap.purchaseChannel == PurchaseChannel.microsoftStore) {
      unawaited(_loadBillingPortal());
    }
    if (!_hasAccountPro) return;
    await Future.wait([_loadDevices(), _loadLastSynced()]);
    if (scrollToDevices && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealDevices());
    }
  }

  Future<void> _loadBillingPortal() async {
    if (!_signedIn) return;
    try {
      final has = await (widget.hasBillingPortal ?? _iap.hasStripeCustomer)();
      if (mounted) setState(() => _hasBillingPortal = has);
    } catch (e, s) {
      recordError(e, s, context: 'Plan: billing portal check');
    }
  }

  Future<void> _loadDevices() async {
    try {
      final deviceId = await (widget.currentDeviceId ?? _iap.deviceManagement.currentDeviceId)();
      final platform = await (widget.currentPlatform ?? _iap.deviceManagement.currentPlatform)();
      final devices = await (widget.loadDevices ?? _iap.deviceManagement.getMyDevices)();
      if (!mounted) return;
      setState(() {
        _currentDeviceId = deviceId;
        _currentPlatform = platform;
        _devices = devices;
        _devicesFailed = false;
      });
    } catch (e, s) {
      recordError(e, s, context: 'Plan: load registered devices');
      if (mounted) setState(() => _devicesFailed = true);
    }
  }

  Future<void> _loadLastSynced() async {
    try {
      final loader =
          widget.loadLastSynced ??
          () async => (await UserSettingsRepository(core.supabase).getLastSyncInfo()).lastSynced;
      final value = await loader();
      if (mounted) setState(() => _lastSynced = value);
    } catch (e, s) {
      recordError(e, s, context: 'Plan: last sync');
    }
  }

  void _revealDevices() {
    final target = _devicesKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  Future<void> _register() async {
    if (_registering) return;
    setState(() {
      _registering = true;
      _limit = null;
    });
    try {
      await (widget.registerDevice ?? _iap.registerCurrentDevice)();
      await _loadDevices();
    } on DeviceLimitReachedError catch (e, s) {
      recordError(e, s, context: 'Plan: register this device, limit reached');
      if (!mounted) return;
      setState(() => _limit = e);
      await _loadDevices();
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealDevices());
    } catch (e, s) {
      recordError(e, s, context: 'Plan: register this device');
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: AppLocalizations.current.registerDeviceFailedRetry);
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _remove(UserDevice device, String name) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeDeviceTitle(name)),
        content: Text(l10n.removeDeviceBody),
        actions: [
          SecondaryButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          DestructiveButton(
            key: const ValueKey('plan-remove-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.removeDevice),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing.add(device.deviceId));
    try {
      await (widget.removeDevice ?? _removeFromAccount)(device);
      if (mounted) setState(() => _limit = null);
      await _loadDevices();
    } catch (e, s) {
      recordError(e, s, context: 'Plan: remove registered device');
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: AppLocalizations.current.removeDeviceFailed);
    } finally {
      if (mounted) setState(() => _removing.remove(device.deviceId));
    }
  }

  Future<void> _removeFromAccount(UserDevice device) async {
    await _iap.deviceManagement.revokeDevice(platform: device.platform, deviceId: device.deviceId);
    await _iap.entitlements.refresh(force: true);
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    try {
      // The store says the outcome itself, in a toast.
      await (widget.restorePurchases ?? _iap.restorePurchases)();
    } catch (e, s) {
      recordError(e, s, context: 'Plan: restore purchases');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _manage() async {
    try {
      if (widget.manageSubscription case final manage?) {
        await manage();
        return;
      }
      final stillAvailable = await _iap.openBillingPortal(context);
      if (!stillAvailable && mounted) setState(() => _hasBillingPortal = false);
    } catch (e, s) {
      recordError(e, s, context: 'Plan: manage subscription');
      buildToast(
        level: LogLevel.LOGLEVEL_ERROR,
        title: AppLocalizations.current.billingPortalErrorTitle,
        subtitle: AppLocalizations.current.billingPortalErrorBody,
      );
    }
  }

  Future<void> _signInWith(OAuthProvider provider) =>
      (widget.socialSignIn ?? (p) => signInWithProvider(_client, p))(provider);

  Future<void> _signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e, s) {
      recordError(e, s, context: 'Plan: sign out');
    }
    if (mounted) setState(() {});
  }

  /// Where the subscription can be managed from here, if anywhere.
  SubscriptionStore? get _manageTarget {
    if (!_iap.isProEnabled) return null;
    switch (_iap.purchaseChannel) {
      case PurchaseChannel.windowsDirect || PurchaseChannel.microsoftStore:
        return _hasBillingPortal ? SubscriptionStore.billingPortal : null;
      case PurchaseChannel.appStore || PurchaseChannel.macAppStore || PurchaseChannel.playStore:
        final store = _iap.subscriptionTerm?.store;
        return switch (store) {
          SubscriptionStore.appStore || SubscriptionStore.macAppStore || SubscriptionStore.playStore => store,
          _ => null,
        };
      case PurchaseChannel.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final channel = _iap.purchaseChannel;
    final manage = _manageTarget;
    // On the Windows download Pro needs an account: Konto comes first.
    final accountFirst = channel == PurchaseChannel.windowsDirect && !_signedIn;

    // Manage lives under Purchases; the plan card links to it only where
    // Purchases is out of sight (narrow), unless a billing issue needs it.
    Widget plan({required bool purchasesBeside}) => PlanSummaryCard(
      manageTarget: purchasesBeside ? null : manage,
      onManage: _manage,
      onRegister: _register,
      registering: _registering,
      onQuestions: () => context.push(const PlanFaqPage()),
      onBoughtBefore: () => context.push(
        SupportChatPage(
          initialText: AppLocalizations.of(context).supportPrefillBoughtBefore,
          initialIntake: const IntakeAnswers(
            category: IntakeCategory.account,
            subcategory: 'issue',
            subcategoryValue: 'purchase_not_restored',
          ),
          telemetryBuilder: () async => TelemetrySnapshot.general(freetext: await debugText()),
        ),
      ),
    );
    final account = KeyedSubtree(
      key: _accountKey,
      child: AccountSection(
        key: const ValueKey('plan-account'),
        client: _client,
        emailAuth: widget.emailAuth ?? SupabaseEmailOtpAuth(supabase: _client),
        signInWith: _signInWith,
        onSignOut: _signOut,
        onSignedIn: () => setState(() {}),
        note: !_signedIn && channel == PurchaseChannel.windowsDirect
            ? l10n.windowsSubscriptionsRequireYouToBeLoggedIn
            : !_signedIn && _iap.isProEnabled
            ? l10n.signInToBringProToOtherDevices
            : l10n.signInToSyncYourSubscriptionAndManageDevices,
      ),
    );
    final purchases = _purchases(context, manage, channel);

    return Scaffold(
      headers: [BkPageHeader(title: l10n.planAccountTitle)],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: BkPageColumn(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 600;
              final sections = <Widget>[
                if (accountFirst) account,
                plan(purchasesBeside: wide && !accountFirst && purchases != null),
                if (!accountFirst)
                  if (wide && purchases != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16,
                      children: [
                        Expanded(child: account),
                        Expanded(child: purchases),
                      ],
                    )
                  else
                    account,
                ..._syncAndDevices(context, wide),
                if (purchases != null && (accountFirst || !wide)) purchases,
                _help(context),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 24,
                children: sections,
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _syncAndDevices(BuildContext context, bool wide) {
    final l10n = AppLocalizations.of(context);
    if (!_iap.isProEnabled) {
      // Without Pro: what an account with Pro adds, each opening Go Pro.
      return [
        BkGroupedSection(
          header: l10n.syncAndDevices,
          children: [
            BkGroupedRow(
              key: const ValueKey('plan-sync-row'),
              icon: LucideIcons.refreshCw,
              title: l10n.syncTitle,
              subtitle: l10n.syncRowSubtitle,
              badge: const ProBadge(),
              chevron: true,
              onPressed: () => showGoProDialog(context),
            ),
            BkGroupedRow(
              key: const ValueKey('plan-devices-row'),
              icon: LucideIcons.monitorSmartphone,
              title: l10n.registeredDevices,
              subtitle: l10n.manageYourDevices,
              badge: const ProBadge(),
              chevron: true,
              onPressed: () => showGoProDialog(context),
            ),
          ],
        ),
      ];
    }
    // Pro from the store without an account: the account section says what
    // signing in brings.
    if (!_signedIn) return const [];

    final syncRow = BkGroupedRow(
      key: const ValueKey('plan-sync-row'),
      icon: LucideIcons.refreshCw,
      title: l10n.syncSettingsRow,
      subtitle: l10n.lastSyncedAt(_lastSynced == null ? l10n.never : formatRelativeTime(l10n, _lastSynced!)),
      chevron: true,
      onPressed: () {
        if (_iap.isProEnabledForCurrentDevice) {
          context.push(const SyncSettingsPage());
        } else {
          buildToast(title: l10n.currentDeviceIsNotRegistered);
        }
      },
    );
    final devices = RegisteredDevicesSection(
      key: _devicesKey,
      header: wide ? l10n.syncAndDevices : l10n.registeredDevices,
      leadingRows: wide ? [syncRow] : const [],
      devices: _devices,
      failed: _devicesFailed,
      onRetry: _loadDevices,
      currentDeviceId: _currentDeviceId,
      currentPlatform: _currentPlatform,
      thisDeviceRegistered: _iap.isProEnabledForCurrentDevice,
      limit: _limit,
      removing: _removing,
      onRemove: _remove,
    );
    final keyed = KeyedSubtree(key: const ValueKey('plan-devices'), child: devices);
    if (wide) return [keyed];
    return [
      keyed,
      BkGroupedSection(header: l10n.syncTitle, children: [syncRow]),
    ];
  }

  Widget? _purchases(BuildContext context, SubscriptionStore? manage, PurchaseChannel channel) {
    final l10n = AppLocalizations.of(context);
    final rows = <Widget>[
      if (manage != null)
        BkGroupedRow(
          key: const ValueKey('plan-manage-subscription'),
          icon: LucideIcons.creditCard,
          title: l10n.manageSubscription,
          subtitle: switch (manage) {
            SubscriptionStore.appStore => l10n.manageInAppStore,
            SubscriptionStore.macAppStore => l10n.manageInMacAppStore,
            SubscriptionStore.playStore => l10n.manageInGooglePlay,
            _ => l10n.manageInBillingPortal,
          },
          chevron: true,
          onPressed: _manage,
        ),
      if (channel.canRestore)
        BkGroupedRow(
          key: const ValueKey('plan-restore-purchases'),
          icon: LucideIcons.rotateCcw,
          title: l10n.restorePurchases,
          trailing: _restoring ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator()) : null,
          onPressed: _restoring ? null : _restore,
        ),
    ];
    if (rows.isEmpty) return null;
    return BkGroupedSection(key: const ValueKey('plan-purchases'), header: l10n.purchasesHeader, children: rows);
  }

  Widget _help(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BkGroupedSection(
      key: const ValueKey('plan-help'),
      header: l10n.helpHeader,
      children: [
        BkGroupedRow(
          key: const ValueKey('plan-questions'),
          icon: LucideIcons.circleHelp,
          title: l10n.planQuestions,
          chevron: true,
          onPressed: () => context.push(const PlanFaqPage()),
        ),
        BkGroupedRow(
          icon: LucideIcons.shieldCheck,
          title: l10n.privacyPolicy,
          trailing: const Icon(LucideIcons.externalLink, size: 16),
          onPressed: () => _openUrl('https://bikecontrol.app/privacy-policy'),
        ),
        BkGroupedRow(
          icon: LucideIcons.fileText,
          title: l10n.termsOfUse,
          trailing: const Icon(LucideIcons.externalLink, size: 16),
          onPressed: () => _openUrl('https://bikecontrol.app/terms-of-use'),
        ),
        if (!_signedIn && !kIsWeb)
          BkGroupedRow(
            icon: LucideIcons.mail,
            title: l10n.dontWantToSignInWriteAMail,
            chevron: true,
            onPressed: () => openMailFallback(context),
          ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } catch (e, s) {
      recordError(e, s, context: 'Plan: open $url');
    }
  }
}
