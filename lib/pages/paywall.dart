import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/help_center/widgets/pricing_faq_section.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/purchase_done_dialogs.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum _PaywallPlan {
  yearly,
  monthly,
  fullVersion,
}

/// What a comparison-table cell shows for one plan. [text] is for a cell a
/// tick or a dash can't express. BikeControl's virtual shifting is not one of
/// them: it is Pro only — the daily allowance without Pro is a trial of it,
/// told in a footnote under the table, not a Base feature.
sealed class _PaywallCell {
  const _PaywallCell();

  static const _PaywallCell unlimited = _PaywallUnlimited();
  static const _PaywallCell check = _PaywallCheck();
  static const _PaywallCell dash = _PaywallDash();
}

class _PaywallUnlimited extends _PaywallCell {
  const _PaywallUnlimited();
}

class _PaywallCheck extends _PaywallCell {
  const _PaywallCheck();
}

class _PaywallDash extends _PaywallCell {
  const _PaywallDash();
}

class _PaywallText extends _PaywallCell {
  final String text;

  const _PaywallText(this.text);
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
}) {
  // Pro landing on the account outranks a Base receipt: the rider who now
  // has Pro should not be told Base's limits.
  if (!wasPro && isPro && !isProForDevice) return PaywallConfirmation.proUnregistered;
  if (isBasePurchase && !wasPurchased && isPurchased && !isPro) return PaywallConfirmation.baseDone;
  return null;
}

class _FeatureLine {
  final IconData icon;
  final String label;
  final _PaywallCell full;
  final _PaywallCell pro;

  const _FeatureLine({
    required this.icon,
    required this.label,
    required this.full,
    required this.pro,
  });
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

  const Paywall({
    super.key,
    this.defaultToFullVersion = false,
  });

  @override
  State<Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<Paywall> {
  // The first row is the one riders bought the wrong plan over: BikeControl
  // shifting the trainer itself is Pro. Base covers pressing the buttons in a
  // trainer app that shifts by itself (rows two and three).
  late final List<_FeatureLine> _features = [
    _FeatureLine(
      icon: LucideIcons.bike,
      label: AppLocalizations.current.paywall_vsByBikeControl,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: LucideIcons.sigma,
      label: AppLocalizations.current.paywall_amountOfActions,
      full: _PaywallCell.unlimited,
      pro: _PaywallCell.unlimited,
    ),
    _FeatureLine(
      icon: LucideIcons.globe,
      label: AppLocalizations.current.paywall_shiftInYourApp,
      full: _PaywallCell.check,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: LucideIcons.slidersHorizontal,
      label: AppLocalizations.current.paywall_configure3ActionsPerButton,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: LucideIcons.monitorSmartphone,
      label: AppLocalizations.current.paywall_useBikecontrolOnAllPlatforms,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    // Sensor sharing is gated on Pro (SensorHub.isProEnabled and the
    // standalone sensor emulator's shouldAdvertise).
    _FeatureLine(
      icon: LucideIcons.heartPulse,
      label: AppLocalizations.current.paywall_shareSensors,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: LucideIcons.command,
      label: AppLocalizations.current.paywall_startAnyCommandShortcutWithAnyButton,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: LucideIcons.music,
      label: AppLocalizations.current.paywall_controlYourDeviceMusic,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: LucideIcons.camera,
      label: AppLocalizations.current.paywall_createScreenshots,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
  ];

  final IAPManager _iapManager = IAPManager.instance;

  late _PaywallPlan _selectedPlan;

  /// Live store prices once loaded; until then (and always on the Stripe
  /// build) the localized [_PaywallPricing.fallback].
  _PaywallPricing? _storePricing;
  _PaywallPricing get _pricing => _storePricing ?? _PaywallPricing.fallback(AppLocalizations.of(context));

  bool _isPurchasing = false;
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
    _iapManager.entitlements.removeListener(_onEntitlementsChanged);
    _iapManager.isPurchased.removeListener(_onEntitlementsChanged);
    super.dispose();
  }

  void _onEntitlementsChanged() {
    if (!mounted) {
      return;
    }
    if (_iapManager.isProEnabled || _iapManager.isPurchased.value) {
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
    );
    final rootContext = navigatorKey.currentContext;
    if (confirmation == null || rootContext == null || !rootContext.mounted) return;
    _confirmed = true;
    unawaited(switch (confirmation) {
      PaywallConfirmation.baseDone => showPurchaseBaseDoneDialog(rootContext),
      PaywallConfirmation.proUnregistered => showPurchaseProUnregisteredDialog(rootContext),
    });
  }

  Future<void> _onPurchasePressed() async {
    if (_isPurchasing) {
      return;
    }
    setState(() {
      _isPurchasing = true;
    });
    _beginAttempt(isBasePurchase: _selectedPlan == _PaywallPlan.fullVersion);

    try {
      switch (_selectedPlan) {
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
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),
          child: Column(
            spacing: 18,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Image.asset('icon.png', width: 54, height: 54)),
              if (!_iapManager.isPurchased.value) _buildGoalChooser(context),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  _buildComparisonTable(context),
                  // The daily allowance is a trial of Pro's virtual shifting,
                  // so it lives under the table, not in Base's column.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).paywall_vsTrialFootnote('${core.bridgeUsageTracker.dailyLimit.inMinutes}'),
                      style: context.typography.xSmall.copyWith(color: Theme.of(context).colorScheme.mutedForeground),
                    ),
                  ),
                ],
              ),
              _buildPlansSection(context),
              _buildPurchaseButton(context),
              Align(
                child: BkTouchTarget(
                  child: Button.ghost(
                    alignment: Alignment.center,
                    onPressed: _isRestoring ? null : _onRestorePressed,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRestoring) ...[
                          CircularProgressIndicator(
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _isRestoring
                              ? AppLocalizations.of(context).restoringPurchases
                              : AppLocalizations.of(context).restorePurchases,
                          style: context.typography.small,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                child: Button.ghost(
                  onPressed: () => _openPlanQuestions(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.circleHelp, size: 15),
                      const SizedBox(width: 8),
                      Flexible(child: Text(AppLocalizations.of(context).paywall_planQuestions).small),
                    ],
                  ),
                ),
              ),
              // Side by side while they fit; a long translation or a large
              // text size wraps them onto two lines rather than shrinking the
              // legal links until they can't be read.
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Button.text(
                    onPressed: () => launchUrlString('https://bikecontrol.app/terms-of-use'),
                    child: Text(
                      AppLocalizations.of(context).termsOfUse,
                      textAlign: TextAlign.center,
                    ).xSmall.muted.underline,
                  ),
                  Button.text(
                    onPressed: () => launchUrlString('https://bikecontrol.app/privacy-policy'),
                    child: Text(
                      AppLocalizations.of(context).privacyPolicy,
                      textAlign: TextAlign.center,
                    ).xSmall.muted.underline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _proSelected => _selectedPlan != _PaywallPlan.fullVersion;

  /// "What do you want?" before "what does each plan have?": two goals, each
  /// mapped onto the plan that covers it. Picking Pro keeps a monthly choice
  /// the rider already made; otherwise it lands on yearly.
  Widget _buildGoalChooser(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          l10n.paywall_goalHeadline,
          textAlign: TextAlign.center,
          style: context.typography.large.copyWith(fontWeight: FontWeight.w600),
        ),
        _buildGoalRow(
          context,
          label: l10n.paywall_goalPro,
          plan: const ProBadge(),
          selected: _proSelected,
          onPressed: () => _selectPlan(_proSelected ? _selectedPlan : _PaywallPlan.yearly),
        ),
        _buildGoalRow(
          context,
          label: l10n.paywall_goalBase,
          plan: Text(
            l10n.fullVersion,
            style: context.typography.caption.copyWith(fontWeight: FontWeight.bold),
          ),
          selected: !_proSelected,
          onPressed: () => _selectPlan(_PaywallPlan.fullVersion),
        ),
      ],
    );
  }

  Widget _buildGoalRow(
    BuildContext context, {
    required String label,
    required Widget plan,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    return BkTappable(
      onPressed: onPressed,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? cs.primary : cs.border, width: selected ? 2 : 1.5),
        ),
        child: Row(
          children: [
            _buildRadioIndicator(selected, compact: true, small: true),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: context.typography.small.copyWith(color: cs.foreground)),
            ),
            const SizedBox(width: 10),
            Icon(LucideIcons.arrowRight, size: 14, color: cs.mutedForeground),
            const SizedBox(width: 8),
            plan,
          ],
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
        await showDialog<void>(context: context, builder: (c) => Card(child: body(c)));
      }
    } catch (e, s) {
      recordError(e, s, context: 'Paywall plan questions');
    }
  }

  String _purchaseLabel(AppLocalizations l10n) => switch (_selectedPlan) {
    _PaywallPlan.yearly => l10n.paywall_startProYearly,
    _PaywallPlan.monthly => l10n.paywall_startProMonthly,
    _PaywallPlan.fullVersion => l10n.paywall_buyBase,
  };

  Widget _buildComparisonTable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullColumnWidth = 72.0;
        final proColumnWidth = 92.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Theme.of(context).colorScheme.muted,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: proColumnWidth,
                  child: Container(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 0, 12),
                  child: Column(
                    children: [
                      _buildHeaderRow(
                        fullColumnWidth: fullColumnWidth,
                        proColumnWidth: proColumnWidth,
                      ),
                      const SizedBox(height: 8),
                      ..._features.map(
                        (feature) => _buildFeatureRow(
                          feature: feature,
                          fullColumnWidth: fullColumnWidth,
                          proColumnWidth: proColumnWidth,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow({
    required double fullColumnWidth,
    required double proColumnWidth,
  }) {
    return Row(
      children: [
        const Expanded(child: SizedBox()),
        SizedBox(
          width: fullColumnWidth,
          child: Center(
            // "Base" is short in most languages but not all — shrink rather
            // than wrap or clip inside a fixed-width column.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppLocalizations.of(context).full,
                maxLines: 1,
                style: context.typography.small.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: proColumnWidth,
          child: Center(
            child: ProBadge(large: true),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow({
    required _FeatureLine feature,
    required double fullColumnWidth,
    required double proColumnWidth,
    required bool compact,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  feature.icon,
                  color: Theme.of(context).colorScheme.mutedForeground,
                  size: compact ? 16 : 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature.label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.foreground,
                      fontWeight: FontWeight.normal,
                      fontSize: (compact ? context.typography.small : context.typography.large).fontSize,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: fullColumnWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(child: _buildCell(feature.full, compact: compact)),
            ),
          ),
          SizedBox(
            width: proColumnWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: _buildCell(feature.pro, compact: compact)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(_PaywallCell value, {required bool compact}) {
    return switch (value) {
      // One word ("Unbegrenzt", "Nieograniczone") — shrink rather than break
      // it mid-word inside the narrow Base column.
      _PaywallUnlimited() => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          AppLocalizations.of(context).unlimited,
          maxLines: 1,
          style: TextStyle(
            fontSize: (compact ? context.typography.xSmall : context.typography.x2Large).fontSize,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.foreground,
          ),
        ),
      ),
      _PaywallText(:final text) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: (compact ? context.typography.xSmall : context.typography.x2Large).fontSize,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.foreground,
        ),
      ),
      _PaywallCheck() => Icon(
        LucideIcons.check,
        size: compact ? 22 : 48,
        color: Theme.of(context).colorScheme.foreground,
      ),
      _PaywallDash() => Container(
        width: compact ? 20 : 40,
        height: 3,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.foreground,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    };
  }

  Widget _buildPlansSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // One title size for both cards: whichever title is wider decides
        // how far both shrink, so "Monthly" is never drawn smaller than
        // "Yearly" (each used to shrink on its own).
        final l10n = AppLocalizations.of(context);
        final titleStyle = _planTitleStyle(context);
        final cardInner = (constraints.maxWidth - 12) / 2 - 32 - 2 * 2.6;
        double widthOf(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: titleStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          return painter.width;
        }

        final widest = [l10n.paywall_yearly, l10n.paywall_monthly].map(widthOf).reduce((a, b) => a > b ? a : b);
        final titleScale = widest <= cardInner || cardInner <= 0 ? 1.0 : cardInner / widest;
        return Column(
          spacing: 12,
          children: [
            // Yearly and monthly always sit side by side — they're a
            // comparison. IntrinsicHeight bounds the row to its tallest card
            // so stretch can equalise them: inside the sheet's scroll view
            // the cross axis is unbounded, and stretching against that hands
            // the cards an infinite height ("RenderBox was not laid out").
            IntrinsicHeight(
              child: Row(
                spacing: 12,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlanCard(
                      plan: _PaywallPlan.yearly,
                      title: AppLocalizations.of(context).paywall_yearly,
                      price: _pricing.yearlyPrice,
                      billed: _pricing.yearlyBilled,
                      badge: _pricing.discountBadge,
                      titleScale: titleScale,
                    ),
                  ),
                  Expanded(
                    child: _buildPlanCard(
                      plan: _PaywallPlan.monthly,
                      title: AppLocalizations.of(context).paywall_monthly,
                      price: _pricing.monthlyPrice,
                      billed: _pricing.monthlyBilled,
                      titleScale: titleScale,
                    ),
                  ),
                ],
              ),
            ),
            if (!_iapManager.isPurchased.value) _buildFullVersionCard(context),
          ],
        );
      },
    );
  }

  TextStyle _planTitleStyle(BuildContext context) => context.typography.large.copyWith(fontWeight: FontWeight.w600);

  Widget _buildPlanCard({
    required _PaywallPlan plan,
    required String title,
    required String price,
    required String billed,
    required double titleScale,
    String? badge,
  }) {
    final selected = _selectedPlan == plan;
    final cs = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      // Hand the row's stretched height to the card itself, so both plans
      // stay the same height even though only yearly has a billing line.
      fit: StackFit.passthrough,
      children: [
        BkTappable(
          onPressed: () => _selectPlan(plan),
          selected: selected,
          inMutuallyExclusiveGroup: true,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            decoration: BoxDecoration(
              color: cs.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? cs.primary : bkStrongBorder(context),
                width: selected ? 2.6 : 2,
              ),
            ),
            child: Column(
              spacing: 2,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PRO and the radio get their own row, so the title below
                // has the card's full width: next to them "Monthly" had less
                // room than "Yearly" and was shrunk to a smaller size.
                Row(
                  children: [
                    if (plan == _PaywallPlan.monthly || plan == _PaywallPlan.yearly)
                      const ProBadge(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                    const Spacer(),
                    _buildRadioIndicator(selected, compact: true),
                  ],
                ),
                const SizedBox(height: 4),
                // "Monatlich" must not wrap on a narrow card: both titles
                // shrink together (see [_buildPlansSection]) rather than
                // break the word.
                Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: _planTitleStyle(context).copyWith(
                    fontSize: _planTitleStyle(context).fontSize! * titleScale,
                    color: cs.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                // Per-month equivalent leads; the actual billing follows.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    price,
                    maxLines: 1,
                    style: context.typography.large.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.foreground,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (billed.isNotEmpty)
                  Text(
                    billed,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.small.copyWith(
                      fontWeight: FontWeight.w500,
                      color: cs.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -10,
            left: 8,
            right: 8,
            child: Align(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  badge,
                  maxLines: 1,
                  style: context.typography.small.copyWith(
                    color: cs.primaryForeground,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFullVersionCard(BuildContext context) {
    final selected = _selectedPlan == _PaywallPlan.fullVersion;
    final cs = Theme.of(context).colorScheme;
    return BkTappable(
      onPressed: () => _selectPlan(_PaywallPlan.fullVersion),
      selected: selected,
      inMutuallyExclusiveGroup: true,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // The one-time Base plan sits quieter than the Pro cards above it.
          color: cs.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          // The store note makes this a three-line card; keep the radio on
          // the title line rather than floating mid-card.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRadioIndicator(selected, compact: true, small: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).fullVersion,
                    style: context.typography.small.copyWith(
                      color: cs.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _pricing.fullVersionSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.caption.copyWith(
                      color: cs.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Base is a store receipt, not an account: riders who bought
                  // it on one store and installed from another wrote in asking
                  // where their purchase went. Say so before they buy.
                  Text(
                    AppLocalizations.of(context).paywall_baseStoreNote(_storeName(context)),
                    style: context.typography.caption.copyWith(
                      height: 1.25,
                      color: cs.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _storeName(BuildContext context) => paywallStoreName(
    defaultTargetPlatform,
    isOutsideStoreWindowsBuild: _iapManager.isOutsideStoreWindowsBuild,
    directDownload: AppLocalizations.of(context).paywall_storeDirectDownload,
  );

  Widget _buildRadioIndicator(bool selected, {bool compact = false, bool small = false}) {
    final size = small
        ? 16.0
        : compact
        ? 20.0
        : 34.0;
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      margin: EdgeInsets.only(top: compact ? 2 : 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.transparent,
        border: Border.all(
          color: selected ? cs.primary : bkStrongBorder(context),
          width: selected ? 2 : 1.6,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: cs.primary.withAlpha(70),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: selected
          ? Icon(
              LucideIcons.check,
              size: small ? 10 : (compact ? 13 : 18),
              color: cs.primaryForeground,
            )
          : null,
    );
  }

  Widget _buildPurchaseButton(BuildContext context) {
    // The gradient is the brand's purchase call-to-action, so it stays drawn
    // by hand; BkTappable gives it button semantics, keyboard focus and the
    // click cursor. While a purchase runs it is disabled — and looks it.
    return BkTappable(
      onPressed: _isPurchasing ? null : _onPurchasePressed,
      label: _purchaseLabel(AppLocalizations.of(context)),
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _isPurchasing ? 0.55 : 1,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                BKColor.main,
                BKColor.mainEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: BKColor.mainEnd.withAlpha(55),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: _isPurchasing
              ? CircularProgressIndicator(
                  size: 20,
                  color: Colors.white,
                )
              : Text(
                  _purchaseLabel(AppLocalizations.of(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.xLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
