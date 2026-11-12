import 'package:bike_control/widgets/ui/bk_bottom_sheet.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/help_center/widgets/pricing_faq_section.dart';
import 'package:bike_control/pages/paywall_feature_clip.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/purchase_done_dialogs.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode;
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/prop.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum _PaywallPlan {
  yearly,
  monthly,
  fullVersion,
}

/// The storefront the one-time Base purchase is bound to, for the note under
/// the Base card. Store brands stay as-is in every language; only the
/// outside-store Windows build's [directDownload] wording is translated.
String paywallStoreName(
  TargetPlatform platform, {
  required bool isOutsideStoreWindowsBuild,
  required String directDownload,
}) {
  return switch (platform) {
    TargetPlatform.android => 'Google Play',
    TargetPlatform.windows => isOutsideStoreWindowsBuild ? directDownload : 'Microsoft Store',
    // iOS and macOS — the only other platforms the app ships on.
    _ => 'App Store',
  };
}

/// The confirmation a finished purchase or restore calls for.
enum PaywallConfirmation {
  /// Base went through: say what Base covers and what it doesn't.
  baseDone,

  /// Pro is on the account but this device isn't registered for it.
  proUnregistered,

  /// The account's device limit kept Pro from reaching this device.
  proDeviceLimit,

  /// Pro went through without an account: it stays on this device until the
  /// rider signs in, which brings it to their other devices.
  proSignIn,
}

/// Decides [PaywallConfirmation] from the IAP state before an attempt and
/// now. Pure, so the cases can be pinned down without a store.
/// [isBasePurchase] is true for the Base plan; false for Pro plans and restore.
/// [isSignedIn] is whether a real account is signed in on this device.
PaywallConfirmation? paywallConfirmationFor({
  required bool isBasePurchase,
  required bool wasPurchased,
  required bool wasPro,
  required bool isPurchased,
  required bool isPro,
  required bool isProForDevice,
  bool deviceLimitReached = false,
  bool isSignedIn = true,
}) {
  // The device limit answered instead of an entitlement: nothing else will
  // tell the rider why Pro didn't turn on.
  if (!isBasePurchase && !wasPro && !isProForDevice && deviceLimitReached) {
    return PaywallConfirmation.proDeviceLimit;
  }
  // Pro without an account lives on this device only, and registering needs
  // an account: signing in is the next step either way.
  if (!wasPro && isPro && !isSignedIn) return PaywallConfirmation.proSignIn;
  // Pro landing on the account outranks a Base receipt: the rider who now
  // has Pro should not be told Base's limits.
  if (!wasPro && isPro && !isProForDevice) return PaywallConfirmation.proUnregistered;
  if (isBasePurchase && !wasPurchased && isPurchased && !isPro) return PaywallConfirmation.baseDone;
  return null;
}

/// The trainer app to name on the "shift in your app" line, or null for the
/// generic wording: no app picked, a stand-in that isn't an app that shifts
/// (a custom keymap, "OpenBikeControl compatible", BikeControl itself), or
/// store screenshots, which keep app names generic.
String? paywallShiftAppName(SupportedApp? app) {
  if (app == null || app is CustomApp || app is OpenBikeControl || app is BikeControl) return null;
  final shown = shownTrainerAppName(app.name);
  return shown == app.name ? shown : null;
}

/// Whether a trainer on [protocol], with the gear watchdog's [verdict], takes
/// BikeControl's gears natively: commanded over the Zwift interface, where it
/// applies the gear itself. A trainer that ignored the gear commands has been
/// moved to FTMS already, or (with nothing to fall back to) is left out here.
bool paywallShiftsNatively(TrainerControlProtocol protocol, ZwiftGearEchoVerdict? verdict) =>
    protocol == TrainerControlProtocol.zwiftHub && (verdict == null || verdict == ZwiftGearEchoVerdict.fellBackToFtms);

/// The bridged trainer BikeControl shifts natively right now, by name.
String? paywallNativeTrainerName(Iterable<ProxyDevice> devices) {
  for (final device in devices) {
    final bike = device.fitnessBike;
    if (bike != null && paywallShiftsNatively(bike.controlProtocol, bike.gearEchoVerdict.value)) {
      return device.toString();
    }
  }
  return null;
}

/// Zwift and Rouvy shift a Zwift Ready trainer natively themselves: against
/// them BikeControl's shifting is neither faster nor more native.
bool paywallAppShiftsNatively(SupportedApp? app) => app is Zwift || app is Rouvy;

/// What Base covers, in one line: unlimited presses, and the trainer app
/// [selected] doing the shifting with its own gears. Names the app where
/// [paywallShiftAppName] does; says it may feel less snappy except for the
/// apps that shift natively themselves.
({String title, String body}) paywallBaseLine(AppLocalizations l10n, SupportedApp? selected) {
  final app = paywallShiftAppName(selected);
  return (
    title: app == null ? l10n.paywallBaseTitle : l10n.paywallBaseTitleNamed(app),
    body: switch (app) {
      null => l10n.paywallBaseShift,
      final app when paywallAppShiftsNatively(selected) => l10n.paywallBaseShiftNamedNative(app),
      final app => l10n.paywallBaseShiftNamed(app),
    },
  );
}

/// One moment of riding on a plan card: an icon, a short title, one line,
/// and the website clip that shows it, if there is one.
class _Moment {
  const _Moment(this.icon, this.title, this.body, {this.clip});

  final IconData icon;
  final String title;
  final String body;
  final PaywallFeatureClip? clip;
}

class _PaywallPricing {
  final String yearlyPrice;
  final String yearlyBilled;
  final String monthlyPrice;
  final String monthlyBilled;
  final String fullVersionSubtitle;
  final String? discountBadge;

  const _PaywallPricing({
    required this.yearlyPrice,
    required this.yearlyBilled,
    required this.monthlyPrice,
    required this.monthlyBilled,
    required this.fullVersionSubtitle,
    required this.discountBadge,
  });

  // Only the Windows/Stripe build falls back to these — keep them short
  // enough to fit the cards on one line each.
  static _PaywallPricing fallback(AppLocalizations l10n) => _PaywallPricing(
    yearlyPrice: l10n.paywall_aboutPerMonth('2.25 \$'),
    yearlyBilled: l10n.paywall_billedYearly,
    monthlyPrice: l10n.paywall_aboutPerMonth('2.50 \$'),
    monthlyBilled: '',
    fullVersionSubtitle: l10n.paywall_aboutOneTime('4.99 \$'),
    discountBadge: l10n.paywall_discountOff('10'),
  );
}

/// Formats [value] the way the store would. `NumberFormat.currency(name:)`
/// renders the ISO code ("EUR 2,08"), so prefer the symbol: take it from the
/// store's own formatted [sampleFormattedPrice] when there is one (it already
/// carries the locale's symbol), else fall back to intl's simpleCurrency.
String paywallFormatPrice(double value, String currencyCode, {String? sampleFormattedPrice}) {
  final symbol = sampleFormattedPrice == null
      ? null
      : RegExp(r'[^\d\s.,\u00a0]+').firstMatch(sampleFormattedPrice)?.group(0);
  final formatter = symbol != null
      ? NumberFormat.currency(symbol: symbol, decimalDigits: 2)
      : NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 2);
  return formatter.format(value).trim();
}

class Paywall extends StatefulWidget {
  /// True when the rider arrived via a "full version / Base" entry point.
  /// Yearly is always the preselected plan (it's the recommended one), so
  /// this only highlights the one-time Full version card.
  final bool defaultToFullVersion;

  /// Test seam: a store-formatted yearly price (e.g. "22,99 €") to bill with
  /// instead of loading offerings.
  @visibleForTesting
  final String? debugYearlyStorePrice;

  /// Test seam: told which plan ("yearly", "monthly", "base") a purchase
  /// button asked for, before the store is.
  @visibleForTesting
  final void Function(String plan)? debugOnPurchase;

  /// Test seam: the poster a feature clip's sheet shows, instead of loading
  /// it from the website.
  @visibleForTesting
  final ImageProvider Function(PaywallFeatureClip clip)? debugClipPoster;

  /// Test seam: the trainer that shifts natively, instead of looking at the
  /// connected trainers. Returns null for none.
  @visibleForTesting
  final String? Function()? debugNativeTrainer;

  /// Debug menu: shows both plans as a rider without a purchase sees them,
  /// whatever this device owns. Ignored outside debug builds.
  final bool debugShowAllPlans;

  const Paywall({
    super.key,
    this.defaultToFullVersion = false,
    this.debugYearlyStorePrice,
    this.debugOnPurchase,
    this.debugClipPoster,
    this.debugNativeTrainer,
    this.debugShowAllPlans = false,
  });

  @override
  State<Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<Paywall> {
  /// What this device owns, as the paywall shows it.
  bool get _purchased => _iapManager.isPurchased.value && !(kDebugMode && widget.debugShowAllPlans);

  // Hovering a clip line on desktop previews its clip beside it.
  late final _clipPreviews = PaywallClipPreviews(poster: widget.debugClipPoster);

  final IAPManager _iapManager = IAPManager.instance;

  /// The Pro billing picked on the Pro card (yearly or monthly). Base has
  /// its own button.
  late _PaywallPlan _selectedPlan;

  /// Live store prices once loaded; until then (and always on the Stripe
  /// build) the localized [_PaywallPricing.fallback].
  _PaywallPricing? _storePricing;
  _PaywallPricing get _pricing =>
      _storePricing ?? _debugPricing ?? _PaywallPricing.fallback(AppLocalizations.of(context));

  _PaywallPricing? get _debugPricing {
    final price = widget.debugYearlyStorePrice;
    if (price == null) return null;
    final l10n = AppLocalizations.of(context);
    final fallback = _PaywallPricing.fallback(l10n);
    return _PaywallPricing(
      yearlyPrice: fallback.yearlyPrice,
      yearlyBilled: l10n.paywall_billedAtYearly(price),
      monthlyPrice: fallback.monthlyPrice,
      monthlyBilled: '',
      fullVersionSubtitle: fallback.fullVersionSubtitle,
      discountBadge: fallback.discountBadge,
    );
  }

  bool _isPurchasing = false;

  /// The plan whose button shows the spinner while [_isPurchasing].
  _PaywallPlan? _purchasingPlan;
  bool _isRestoring = false;

  /// The purchase or restore in flight (or last finished): the IAP state when
  /// it started and whether it was the Base plan, so the confirmation after
  /// it reports only what this attempt changed. Null until the first attempt.
  ({bool wasPurchased, bool wasPro, bool isBasePurchase})? _attempt;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _selectedPlan = _PaywallPlan.yearly;
    _iapManager.entitlements.addListener(_onEntitlementsChanged);
    _iapManager.isPurchased.addListener(_onEntitlementsChanged);
    _loadRevenueCatPricing();
  }

  @override
  void dispose() {
    _clipPreviews.dispose();
    _iapManager.entitlements.removeListener(_onEntitlementsChanged);
    _iapManager.isPurchased.removeListener(_onEntitlementsChanged);
    super.dispose();
  }

  void _onEntitlementsChanged() {
    if (!mounted) {
      return;
    }
    final limited = _attempt != null && _iapManager.entitlements.lastDeviceLimitError != null;
    if (_iapManager.isProEnabled || _iapManager.isPurchased.value || limited) {
      _close();
      // The store's answer lands here, before the purchase call returns (and
      // RevenueCat's can take seconds) — confirm now, not when it returns.
      _confirmOutcome();
    }
  }

  /// Closes the paywall — once. Entitlement notifications come in pairs after
  /// a purchase (RevenueCat's customer-info listener, then the entitlements
  /// refresh), and this widget is still mounted during its exit transition
  /// when the second one lands; a second pop would take whatever is on top by
  /// then — the confirmation dialog just pushed, or the route beneath.
  void _close() {
    if (_closing) return;
    _closing = true;
    // The drawer is the normal host; _showPaywall falls back to a dialog when
    // no DrawerOverlay is in scope, and closeDrawer has nothing to close there.
    if (DrawerOverlay.maybeFind(context) != null) {
      closeDrawer(context);
      return;
    }
    // Pop this route, not whatever happens to be on top.
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      Navigator.of(context).pop();
    }
  }

  bool _closing = false;

  void _beginAttempt({required bool isBasePurchase}) {
    _attempt = (
      wasPurchased: _iapManager.isPurchased.value,
      wasPro: _iapManager.isProEnabled,
      isBasePurchase: isBasePurchase,
    );
    _confirmed = false;
  }

  /// Shows the one confirmation the attempt's outcome calls for, at most once
  /// per attempt. On the root navigator: by the time it runs the paywall is
  /// usually already closing (see [_onEntitlementsChanged]), so the dialog
  /// cannot hang off this widget's own context.
  void _confirmOutcome() {
    final attempt = _attempt;
    if (attempt == null || _confirmed) return;
    final confirmation = paywallConfirmationFor(
      isBasePurchase: attempt.isBasePurchase,
      wasPurchased: attempt.wasPurchased,
      wasPro: attempt.wasPro,
      isPurchased: _iapManager.isPurchased.value,
      isPro: _iapManager.isProEnabled,
      isProForDevice: _iapManager.isProEnabledForCurrentDevice,
      deviceLimitReached: _iapManager.entitlements.lastDeviceLimitError != null,
      isSignedIn: _iapManager.isLoggedIn,
    );
    final rootContext = navigatorKey.currentContext;
    if (confirmation == null || rootContext == null || !rootContext.mounted) return;
    _confirmed = true;
    unawaited(switch (confirmation) {
      PaywallConfirmation.baseDone => showPurchaseBaseDoneDialog(rootContext),
      PaywallConfirmation.proUnregistered => showPurchaseProUnregisteredDialog(rootContext),
      PaywallConfirmation.proDeviceLimit => _showDeviceLimit(rootContext),
      PaywallConfirmation.proSignIn => showPurchaseProSignInDialog(rootContext),
    });
  }

  Future<void> _showDeviceLimit(BuildContext rootContext) {
    final error = _iapManager.entitlements.lastDeviceLimitError!;
    Logger.warn('Paywall: device limit reached after purchase: $error');
    // The paywall must not stay open under the dialog.
    if (mounted) _close();
    return showProDeviceLimitDialog(rootContext, error);
  }

  Future<void> _onPurchasePressed(_PaywallPlan plan) async {
    if (_isPurchasing) {
      return;
    }
    setState(() {
      _isPurchasing = true;
      _purchasingPlan = plan;
    });
    _beginAttempt(isBasePurchase: plan == _PaywallPlan.fullVersion);
    widget.debugOnPurchase?.call(switch (plan) {
      _PaywallPlan.yearly => 'yearly',
      _PaywallPlan.monthly => 'monthly',
      _PaywallPlan.fullVersion => 'base',
    });

    try {
      switch (plan) {
        case _PaywallPlan.yearly:
          await _iapManager.purchaseSubscription(
            context,
            plan: SubscriptionPlan.yearly,
            fromPaywall: true,
          );
          break;
        case _PaywallPlan.monthly:
          await _iapManager.purchaseSubscription(
            context,
            plan: SubscriptionPlan.monthly,
            fromPaywall: true,
          );
          break;
        case _PaywallPlan.fullVersion:
          await _iapManager.purchaseFullVersion(
            context,
            fromPaywall: true,
          );
          break;
      }
      // Normally already done from the listener; covers a store that answers
      // only through the returned call.
      _confirmOutcome();
    } catch (e, s) {
      // Inner purchase paths toast+log their own failures; this catches anything
      // that escapes them (e.g. loading offerings) so tapping Buy can never fail
      // silently or land in the logs as an unhandled "Zone" crash.
      recordError(e, s, context: 'Paywall purchase');
      buildToast(
        title: AppLocalizations.current.purchaseErrorTitle,
        subtitle: AppLocalizations.current.purchaseErrorBody,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _onRestorePressed() async {
    if (_isRestoring) {
      return;
    }

    setState(() {
      _isRestoring = true;
    });
    _beginAttempt(isBasePurchase: false);

    try {
      await _iapManager.restorePurchases();
      _confirmOutcome();
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  void _selectPlan(_PaywallPlan plan) {
    setState(() {
      _selectedPlan = plan;
    });
  }

  Future<void> _loadRevenueCatPricing() async {
    // Every RevenueCat platform (iOS, Android, macOS) shows this paywall, so
    // every one of them needs the live store prices — without this the
    // hardcoded [_PaywallPricing.fallback] placeholders ("About 2.25 $/mo")
    // leak into the UI. The Windows-outside-store build sells via Stripe and
    // has no offerings to read, so it keeps the fallback.
    if (!_iapManager.isUsingRevenueCat) {
      return;
    }

    try {
      final offerings = await Purchases.getOfferings();
      final pricing = _buildPricingFromOfferings(offerings);
      if (pricing != null && mounted) {
        setState(() {
          _storePricing = pricing;
        });
      }
    } catch (e, s) {
      recordError(e, s, context: 'Loading RevenueCat offerings for paywall');
    }
  }

  _PaywallPricing? _buildPricingFromOfferings(Offerings offerings) {
    final allOfferings = offerings.all.values.toList();
    final proOffering = offerings.all[_purchased ? 'proonly-freemonth' : 'pro'];
    final defaultOffering = offerings.all['default'];

    final monthlyPackage =
        proOffering?.monthly ??
        offerings.current?.monthly ??
        _firstPackageFromOfferings(allOfferings, (offering) => offering.monthly);

    final yearlyPackage =
        proOffering?.annual ??
        offerings.current?.annual ??
        _firstPackageFromOfferings(allOfferings, (offering) => offering.annual);

    final lifetimePackage =
        defaultOffering?.lifetime ??
        offerings.current?.lifetime ??
        _firstPackageFromOfferings(allOfferings, (offering) => offering.lifetime);

    if (monthlyPackage == null && yearlyPackage == null && lifetimePackage == null) {
      return null;
    }

    final monthlyStoreProduct = monthlyPackage?.storeProduct;
    final yearlyStoreProduct = yearlyPackage?.storeProduct;
    final lifetimeStoreProduct = lifetimePackage?.storeProduct;

    final yearlyPrice = yearlyStoreProduct != null
        ? AppLocalizations.of(context).paywall_perMonth(
            _formatCurrency(
              yearlyStoreProduct.price / 12,
              yearlyStoreProduct.currencyCode,
              sampleFormattedPrice: yearlyStoreProduct.priceString,
            ),
          )
        : _pricing.yearlyPrice;

    final yearlyBilled = yearlyStoreProduct != null
        ? AppLocalizations.of(context).paywall_billedAtYearly(yearlyStoreProduct.priceString)
        : _pricing.yearlyBilled;

    final monthlyPrice = monthlyStoreProduct != null
        ? AppLocalizations.of(context).paywall_perMonth(
            _formatCurrency(
              monthlyStoreProduct.price,
              monthlyStoreProduct.currencyCode,
              sampleFormattedPrice: monthlyStoreProduct.priceString,
            ),
          )
        : _pricing.monthlyPrice;

    // The monthly card's price line already reads "2,99 €/mo" — repeating it
    // as "Billed at 2,99 €/mo." adds nothing.
    const monthlyBilled = '';

    final fullVersionSubtitle = lifetimeStoreProduct != null
        ? '${AppLocalizations.of(context).only} ${lifetimeStoreProduct.priceString}'
        : _pricing.fullVersionSubtitle;

    String? discountBadge;
    if (monthlyStoreProduct != null && yearlyStoreProduct != null && monthlyStoreProduct.price > 0) {
      final yearlyEquivalent = yearlyStoreProduct.price / 12;
      final savingsFraction = (monthlyStoreProduct.price - yearlyEquivalent) / monthlyStoreProduct.price;
      final savingsPercent = (savingsFraction * 100).round();
      if (savingsPercent > 0) {
        discountBadge = AppLocalizations.of(context).paywall_discountOff('$savingsPercent');
      }
    }

    return _PaywallPricing(
      yearlyPrice: yearlyPrice,
      yearlyBilled: yearlyBilled,
      monthlyPrice: monthlyPrice,
      monthlyBilled: monthlyBilled,
      fullVersionSubtitle: fullVersionSubtitle,
      discountBadge: discountBadge,
    );
  }

  Package? _firstPackageFromOfferings(
    Iterable<Offering> offerings,
    Package? Function(Offering offering) selector,
  ) {
    for (final offering in offerings) {
      final package = selector(offering);
      if (package != null) {
        return package;
      }
    }
    return null;
  }

  String _formatCurrency(double value, String currencyCode, {String? sampleFormattedPrice}) =>
      paywallFormatPrice(value, currencyCode, sampleFormattedPrice: sampleFormattedPrice);

  /// The trainer BikeControl shifts natively right now, if any.
  late final String? _nativeTrainer = () {
    final seam = widget.debugNativeTrainer;
    if (seam != null) return seam();
    try {
      return paywallNativeTrainerName(core.connection.proxyDevices);
    } catch (e, s) {
      recordError(e, s, context: 'Paywall native trainer');
      return null;
    }
  }();

  /// What Pro feels like, four moments. "Native and instant" only where it is
  /// true against the rider's app: a trainer that takes BikeControl's gears
  /// natively, and an app (not Zwift or Rouvy) that doesn't shift it natively
  /// itself.
  List<_Moment> _proMoments(AppLocalizations l10n) {
    final native = _nativeTrainer;
    final instant = native != null && !paywallAppShiftsNatively(core.settings.getTrainerApp());
    return [
      _Moment(
        instant ? LucideIcons.zap : LucideIcons.gauge,
        l10n.paywallFeelShiftTitle,
        instant ? l10n.paywallFeelShiftNative(native) : l10n.paywallFeelShift,
        clip: PaywallFeatureClip.smartTrainerVirtualShifting,
      ),
      _Moment(
        LucideIcons.slidersHorizontal,
        l10n.paywallFeelDrivetrainTitle,
        l10n.paywallFeelDrivetrain,
        clip: PaywallFeatureClip.drivetrain,
      ),
      _Moment(
        LucideIcons.pointer,
        l10n.paywallFeelGesturesTitle,
        l10n.paywallFeelGestures,
        clip: PaywallFeatureClip.buttonGestures,
      ),
      _Moment(LucideIcons.music, l10n.paywallFeelScreenTitle, l10n.paywallFeelScreen, clip: PaywallFeatureClip.music),
      _Moment(LucideIcons.monitorSmartphone, l10n.paywallFeelDevicesTitle, l10n.paywallFeelDevices),
    ];
  }

  /// Base, in one line: unlimited presses, and the trainer app does the
  /// shifting. Zwift and Rouvy shift natively themselves, so for them it
  /// doesn't say it might feel less snappy.
  _Moment _baseMoment(AppLocalizations l10n) {
    final line = paywallBaseLine(l10n, core.settings.getTrainerApp());
    return _Moment(LucideIcons.check, line.title, line.body);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final purchased = _purchased;
    final ownsBase = purchased && !_iapManager.isProEnabled;
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.paywallYourPlan,
                        style: context.typography.x3Large.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
                      ),
                    ),
                  ),
                  BkTouchTarget(
                    child: BkIconButton.secondary(
                      icon: const Icon(LucideIcons.x, size: 20),
                      label: l10n.close,
                      onPressed: _close,
                    ),
                  ),
                ],
              ),
              _buildProCard(context),
              // A Base owner still sees what Base covers, marked as theirs.
              if (!purchased || ownsBase) _buildBaseCard(context, owned: ownsBase),
              Column(
                children: [
                  BkTouchTarget(
                    child: Button.ghost(
                      onPressed: () => _openPlanQuestions(context),
                      child: Text(
                        l10n.paywall_planQuestions,
                        textAlign: TextAlign.center,
                        style: context.typography.small.copyWith(
                          color: bkAccentText(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Only the app stores can restore; elsewhere the button
                  // would do nothing (Plan & account hides it there too).
                  if (_iapManager.purchaseChannel.canRestore)
                    BkTouchTarget(
                      child: Button.ghost(
                        alignment: Alignment.center,
                        onPressed: _isRestoring ? null : _onRestorePressed,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isRestoring) ...[
                              CircularProgressIndicator(size: 14),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _isRestoring ? l10n.restoringPurchases : l10n.restorePurchases,
                              style: context.typography.small,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              // Side by side while they fit; a long translation or a large
              // text size wraps them onto two lines rather than shrinking the
              // legal links until they can't be read.
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Button.text(
                    onPressed: () => launchUrlString('https://bikecontrol.app/terms-of-use'),
                    child: Text(l10n.termsOfUse, textAlign: TextAlign.center).xSmall.muted.underline,
                  ),
                  Button.text(
                    onPressed: () => launchUrlString('https://bikecontrol.app/privacy-policy'),
                    child: Text(l10n.privacyPolicy, textAlign: TextAlign.center).xSmall.muted.underline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A plan card's head: the plan name in the display face and what kind of
  /// purchase it is at the end.
  Widget _planHead(BuildContext context, {required String name, required Widget kind}) {
    return Row(
      spacing: 8,
      children: [
        Text(name.toUpperCase(), style: BkDisplay.title(context)),
        Expanded(
          child: Align(alignment: AlignmentDirectional.centerEnd, child: kind),
        ),
      ],
    );
  }

  Widget _kind(BuildContext context, String text) => Text(
    text,
    textAlign: TextAlign.end,
    style: context.typography.xSmall.copyWith(color: Theme.of(context).colorScheme.mutedForeground),
  );

  /// The moments on a card: an icon tile, a title and a line, and a ▶ where
  /// there is a clip of it (48 dp on phones). Accent on Pro, quiet on Base.
  Widget _momentList(BuildContext context, List<_Moment> moments, {required bool accent}) {
    final cs = Theme.of(context).colorScheme;
    final tint = accent ? bkAccentText(context) : cs.mutedForeground;
    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in moments)
          _clipLine(
            m.clip,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: accent ? cs.primary.withValues(alpha: 0.10) : cs.muted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(m.icon, size: 15, color: tint),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        m.title,
                        style: context.typography.small.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                      ),
                      Text(
                        m.body,
                        style: context.typography.xSmall.copyWith(color: cs.mutedForeground, height: 1.35),
                      ),
                    ],
                  ),
                ),
                if (m.clip != null)
                  PaywallClipButton(
                    clip: m.clip!,
                    feature: m.title,
                    tooltip: !PaywallClipPreviews.enabled,
                    onPressed: () {
                      _clipPreviews.hide();
                      showPaywallFeatureClip(
                        context,
                        title: m.title,
                        clip: m.clip!,
                        poster: widget.debugClipPoster?.call(m.clip!),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _clipLine(PaywallFeatureClip? clip, Widget line) =>
      clip == null ? line : PaywallClipHoverRegion(previews: _clipPreviews, clip: clip, child: line);

  Widget _buildProCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final yearly = _selectedPlan == _PaywallPlan.yearly;
    final price = yearly ? _pricing.yearlyPrice : _pricing.monthlyPrice;
    final billed = yearly ? _pricing.yearlyBilled : _pricing.monthlyBilled;
    final badge = yearly ? _pricing.discountBadge : null;
    final plan = yearly ? _PaywallPlan.yearly : _PaywallPlan.monthly;
    return Container(
      key: const ValueKey('paywall-pro-card'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        border: Border.all(color: cs.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _planHead(
            context,
            name: 'Pro',
            kind: _kind(context, l10n.subscription),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.paywallProTagline.toUpperCase(),
            style: BkNumerals.display(17, color: bkAccentText(context), fontWeight: FontWeight.w800, height: 1.05),
          ),
          const SizedBox(height: 12),
          Row(
            spacing: 12,
            children: [
              _billingSegments(context),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      price,
                      maxLines: 1,
                      style: BkDisplay.title(context).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (billed.isNotEmpty || badge != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      maxLines: 1,
                      style: context.typography.caption.copyWith(
                        color: cs.primaryForeground,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                // The amount actually charged: wraps rather than being cut off.
                Expanded(
                  child: Text(
                    billed,
                    textAlign: TextAlign.end,
                    style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _momentList(context, _proMoments(l10n), accent: true),
          const SizedBox(height: 16),
          _purchaseButton(context, plan: plan, label: _purchaseLabel(l10n, plan), primary: true),
        ],
      ),
    );
  }

  /// Monthly | Yearly. Each is a button that says whether it is picked.
  Widget _billingSegments(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    Widget segment(_PaywallPlan plan, String label) {
      final selected = _selectedPlan == plan;
      return BkTappable(
        onPressed: () => _selectPlan(plan),
        selected: selected,
        inMutuallyExclusiveGroup: true,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 72, minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? cs.primary : const Color(0x00000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: context.typography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? cs.primaryForeground : cs.mutedForeground,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(_PaywallPlan.monthly, l10n.paywall_monthly),
          segment(_PaywallPlan.yearly, l10n.paywall_yearly),
        ],
      ),
    );
  }

  Widget _buildBaseCard(BuildContext context, {required bool owned}) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('paywall-base-card'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _planHead(
            context,
            name: l10n.fullVersion,
            kind: owned
                ? Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: BkStatusDot(label: l10n.paywallYourPlan),
                  )
                : _kind(context, l10n.paywall_oneTimePurchase),
          ),
          const SizedBox(height: 12),
          _momentList(context, [_baseMoment(l10n)], accent: false),
          const SizedBox(height: 12),
          if (!owned)
            Text(
              _pricing.fullVersionSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.large.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
            ),
          // Base is a store receipt, not an account: riders who bought it on
          // one store and installed from another wrote in asking where their
          // purchase went. Say so before they buy. On Linux there is no
          // receipt: Base is free.
          Text(
            _iapManager.purchaseChannel == PurchaseChannel.linuxDirect
                ? l10n.paywall_baseFreeOnLinux
                : l10n.paywall_baseStoreNote(_storeName(context)),
            style: context.typography.caption.copyWith(height: 1.3, color: cs.mutedForeground),
          ),
          if (!owned) ...[
            const SizedBox(height: 12),
            _purchaseButton(
              context,
              plan: _PaywallPlan.fullVersion,
              label: _purchaseLabel(l10n, _PaywallPlan.fullVersion),
              primary: false,
            ),
          ],
        ],
      ),
    );
  }

  String _purchaseLabel(AppLocalizations l10n, _PaywallPlan plan) => switch (plan) {
    _PaywallPlan.yearly => l10n.paywall_startProYearly,
    _PaywallPlan.monthly => l10n.paywall_startProMonthly,
    _PaywallPlan.fullVersion => l10n.paywall_buyBase,
  };

  /// A full-width pill: primary for Pro, a neutral fill for Base. Disabled
  /// while any purchase runs; the one running shows a spinner.
  Widget _purchaseButton(
    BuildContext context, {
    required _PaywallPlan plan,
    required String label,
    required bool primary,
  }) {
    final busy = _isPurchasing && _purchasingPlan == plan;
    final style = BkPillButton.shape(
      (primary ? const ButtonStyle.primary() : const ButtonStyle.secondary()).withPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BkPillButton.minHeight, minWidth: double.infinity),
      // shadcn's Button reports neither the button role nor its state.
      child: Semantics(
        container: true,
        button: true,
        enabled: !_isPurchasing,
        label: busy ? label : null,
        child: Button(
          style: style,
          alignment: Alignment.center,
          onPressed: _isPurchasing ? null : () => _onPurchasePressed(plan),
          child: busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(size: 20))
              : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  /// The same pricing FAQ the Help Center carries, over the paywall.
  Future<void> _openPlanQuestions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    Widget body(BuildContext c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.sizeOf(c).height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.helpCenterPricingFaq, style: context.typography.large.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const PricingFaqSection(),
            ],
          ),
        ),
      ),
    );
    try {
      if (DrawerOverlay.maybeFind(context) != null) {
        await openBottomSheet<void>(context: context, builder: body);
      } else {
        await showDialog<void>(
          context: context,
          builder: (c) => Card(child: body(c)),
        );
      }
    } catch (e, s) {
      recordError(e, s, context: 'Paywall plan questions');
    }
  }

  String _storeName(BuildContext context) => paywallStoreName(
    defaultTargetPlatform,
    isOutsideStoreWindowsBuild: _iapManager.isOutsideStoreWindowsBuild,
    directDownload: AppLocalizations.of(context).paywall_storeDirectDownload,
  );
}
