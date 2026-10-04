import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/help_center/widgets/pricing_faq_section.dart';
import 'package:bike_control/pages/paywall_feature_clip.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/plan/vs_without_pro_note.dart';
import 'package:bike_control/widgets/purchase_done_dialogs.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
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
}

/// Decides [PaywallConfirmation] from the IAP state before an attempt and
/// now. Pure, so the cases can be pinned down without a store.
/// [isBasePurchase] is true for the Base plan; false for Pro plans and restore.
PaywallConfirmation? paywallConfirmationFor({
  required bool isBasePurchase,
  required bool wasPurchased,
  required bool wasPro,
  required bool isPurchased,
  required bool isPro,
  required bool isProForDevice,
  bool deviceLimitReached = false,
}) {
  // The device limit answered instead of an entitlement: nothing else will
  // tell the rider why Pro didn't turn on.
  if (!isBasePurchase && !wasPro && !isProForDevice && deviceLimitReached) {
    return PaywallConfirmation.proDeviceLimit;
  }
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

/// One line of a plan card's feature list.
class _FeatureLine {
  final String label;

  /// The website demo clip that shows this feature, if there is one.
  final PaywallFeatureClip? clip;

  /// Drawn with "Unlimited" at its end (button commands per day).
  final bool unlimited;

  /// Base has it too. Every line is Pro.
  final bool inBase;

  const _FeatureLine(this.label, {this.unlimited = false, this.inBase = false, this.clip});
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

  const Paywall({
    super.key,
    this.defaultToFullVersion = false,
    this.debugYearlyStorePrice,
    this.debugOnPurchase,
    this.debugClipPoster,
  });

  @override
  State<Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<Paywall> {
  // Hovering a clip line on desktop previews its clip beside it.
  late final _clipPreviews = PaywallClipPreviews(poster: widget.debugClipPoster);

  // Unlimited button commands opens the list (it has no demo clip, so the
  // clip rows run together below it). Next, the line riders bought the wrong
  // plan over: BikeControl shifting the trainer itself is Pro. Base covers
  // pressing the buttons in a trainer app that shifts by itself (lines one
  // and three; on the Base card, its first two);
  // that line names the rider's app so it's clear which app does the gears.
  // Sensor sharing is gated on Pro (SensorHub.isProEnabled and the standalone
  // sensor emulator's shouldAdvertise).
  // A line whose feature has a website demo clip offers it (Pro card only).
  List<_FeatureLine> _features(AppLocalizations l10n) {
    final app = paywallShiftAppName(core.settings.getTrainerApp());
    return [
      _FeatureLine(l10n.paywall_amountOfActions, unlimited: true, inBase: true),
      _FeatureLine(l10n.paywall_vsByBikeControl, clip: PaywallFeatureClip.smartTrainerVirtualShifting),
      _FeatureLine(
        app == null ? l10n.paywall_shiftInYourApp : l10n.paywall_shiftInNamedApp(app),
        inBase: true,
        clip: PaywallFeatureClip.virtualGearShifting,
      ),
      _FeatureLine(l10n.paywall_configure3ActionsPerButton, clip: PaywallFeatureClip.buttonGestures),
      _FeatureLine(l10n.paywall_useBikecontrolOnAllPlatforms),
      _FeatureLine(l10n.paywall_shareSensors, clip: PaywallFeatureClip.heartRate),
      _FeatureLine(l10n.paywall_startAnyCommandShortcutWithAnyButton, clip: PaywallFeatureClip.launchCommand),
      _FeatureLine(l10n.paywall_controlYourDeviceMusic, clip: PaywallFeatureClip.music),
      _FeatureLine(l10n.paywall_createScreenshots, clip: PaywallFeatureClip.screenshots),
    ];
  }

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
    );
    final rootContext = navigatorKey.currentContext;
    if (confirmation == null || rootContext == null || !rootContext.mounted) return;
    _confirmed = true;
    unawaited(switch (confirmation) {
      PaywallConfirmation.baseDone => showPurchaseBaseDoneDialog(rootContext),
      PaywallConfirmation.proUnregistered => showPurchaseProUnregisteredDialog(rootContext),
      PaywallConfirmation.proDeviceLimit => _showDeviceLimit(rootContext),
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
    final proOffering = offerings.all[_iapManager.isPurchased.value ? 'proonly-freemonth' : 'pro'];
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ownsBase = _iapManager.isPurchased.value && !_iapManager.isProEnabled;
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
              if (!_iapManager.isPurchased.value || ownsBase) _buildBaseCard(context, owned: ownsBase),
              // Without Pro the trainer app does the shifting; what Pro adds
              // on top concerns both plans, so it sits under both.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: VsWithoutProNote(app: core.settings.getTrainerApp()),
              ),
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

  /// The feature list with checks: accent on Pro, quiet on Base. With
  /// [clips], a line whose feature has a demo clip ends in a ▶ that opens it
  /// (48 dp on phones, which sets that line's height).
  Widget _featureList(BuildContext context, List<_FeatureLine> lines, {required bool accent, bool clips = false}) {
    final cs = Theme.of(context).colorScheme;
    final style = context.typography.small.copyWith(color: cs.foreground, height: 1.3);
    return Column(
      // A ▶ already makes its line a touch target tall; a smaller gap keeps
      // the list from spreading out.
      spacing: clips ? 4 : 6,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          _clipLine(
            clips ? line.clip : null,
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: clips && isCompactWindow(context) ? 28 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 8,
                children: [
                  Icon(
                    LucideIcons.check,
                    size: 16,
                    color: accent ? bkAccentText(context) : cs.mutedForeground,
                  ),
                  Expanded(child: Text(line.label, style: style)),
                  if (line.unlimited)
                    Text(
                      AppLocalizations.of(context).unlimited,
                      style: style.copyWith(fontWeight: FontWeight.w600),
                    ),
                  if (clips && line.clip != null)
                    PaywallClipButton(
                      clip: line.clip!,
                      feature: line.label,
                      tooltip: !PaywallClipPreviews.enabled,
                      onPressed: () {
                        _clipPreviews.hide();
                        showPaywallFeatureClip(
                          context,
                          title: line.label,
                          clip: line.clip!,
                          poster: widget.debugClipPoster?.call(line.clip!),
                        );
                      },
                    ),
                ],
              ),
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
          _featureList(context, _features(l10n), accent: true, clips: true),
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
          _featureList(context, [
            for (final f in _features(l10n))
              if (f.inBase) f,
          ], accent: false),
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
          // purchase went. Say so before they buy.
          Text(
            l10n.paywall_baseStoreNote(_storeName(context)),
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
        await openSheet<void>(context: context, position: OverlayPosition.bottom, builder: body);
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
