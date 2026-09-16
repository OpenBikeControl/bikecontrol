import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/purchase_done_dialogs.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/toast.dart';
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

/// What a comparison-table cell shows for one plan. [text] is for the one
/// place a tick or a dash would lie: Base does get BikeControl-driven virtual
/// shifting, just capped — so its cell says "20 min/day" instead.
sealed class _PaywallCell {
  const _PaywallCell();

  static const _PaywallCell unlimited = _PaywallUnlimited();
  static const _PaywallCell check = _PaywallCheck();
  static const _PaywallCell dash = _PaywallDash();
  const factory _PaywallCell.text(String text) = _PaywallText;
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
  static const fallback = _PaywallPricing(
    yearlyPrice: 'About 2.25 \$/mo',
    yearlyBilled: 'Billed yearly',
    monthlyPrice: 'About 2.50 \$/mo',
    monthlyBilled: '',
    fullVersionSubtitle: 'About 4.99 \$ \u2014 one-time',
    discountBadge: '10% OFF',
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
  // The first three rows answer the question riders bought the wrong plan
  // over: Base covers pressing the buttons in a trainer app that shifts by
  // itself; BikeControl shifting the trainer (virtual shifting through the
  // bridge) is the Pro part, and Base only gets the daily taster of it.
  late final List<_FeatureLine> _features = [
    _FeatureLine(
      icon: Icons.functions,
      label: AppLocalizations.current.paywall_amountOfActions,
      full: _PaywallCell.unlimited,
      pro: _PaywallCell.unlimited,
    ),
    _FeatureLine(
      icon: Icons.public,
      label: AppLocalizations.current.paywall_shiftInYourApp,
      full: _PaywallCell.check,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.directions_bike_outlined,
      label: AppLocalizations.current.paywall_bikeControlShifts,
      full: _PaywallCell.text(AppLocalizations.current.paywall_twentyMinPerDay),
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.tune,
      label: AppLocalizations.current.paywall_configure3ActionsPerButton,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.devices,
      label: AppLocalizations.current.paywall_useBikecontrolOnAllPlatforms,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.keyboard_command_key,
      label: AppLocalizations.current.paywall_startAnyCommandShortcutWithAnyButton,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.music_note_outlined,
      label: AppLocalizations.current.paywall_controlYourDeviceMusic,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.screenshot_monitor_outlined,
      label: AppLocalizations.current.paywall_createScreenshots,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.volunteer_activism_outlined,
      label: AppLocalizations.of(context).paywall_supportDevelopmentOfNewFeaturesDevicesAndMore,
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
  ];

  final IAPManager _iapManager = IAPManager.instance;

  late _PaywallPlan _selectedPlan;
  _PaywallPricing _pricing = _PaywallPricing.fallback;

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

  void _close() {
    // The drawer is the normal host; _showPaywall falls back to a dialog when
    // no DrawerOverlay is in scope, and closeDrawer has nothing to close there.
    if (DrawerOverlay.maybeFind(context) != null) {
      closeDrawer(context);
    } else {
      Navigator.of(context).maybePop();
    }
  }

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
        title: 'Purchase Error',
        subtitle: 'Something went wrong starting your purchase. Please try again.',
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
          _pricing = pricing;
        });
      }
    } catch (e) {
      debugPrint('Could not load RevenueCat offerings for paywall: $e');
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
        ? '${_formatCurrency(yearlyStoreProduct.price / 12, yearlyStoreProduct.currencyCode, sampleFormattedPrice: yearlyStoreProduct.priceString)}/mo'
        : _pricing.yearlyPrice;

    final yearlyBilled = yearlyStoreProduct != null
        ? AppLocalizations.of(context).paywall_billedAtYearly(yearlyStoreProduct.priceString)
        : _pricing.yearlyBilled;

    final monthlyPrice = monthlyStoreProduct != null
        ? '${_formatCurrency(monthlyStoreProduct.price, monthlyStoreProduct.currencyCode, sampleFormattedPrice: monthlyStoreProduct.priceString)}/mo'
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
        discountBadge = '$savingsPercent% OFF';
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
              _buildComparisonTable(context),
              _buildPlansSection(context),
              _buildPurchaseButton(context),
              Align(
                child: Button.ghost(
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
                        _isRestoring ? 'Restoring purchases...' : AppLocalizations.of(context).restorePurchases,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              // One line, whatever the language: shrink before wrapping.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Button.text(
                      onPressed: () => launchUrlString('https://bikecontrol.app/terms-of-use'),
                      child: Text(AppLocalizations.of(context).termsOfUse, maxLines: 1).xSmall.muted.underline,
                    ),
                    Button.text(
                      onPressed: () => launchUrlString('https://bikecontrol.app/privacy-policy'),
                      child: Text(AppLocalizations.of(context).privacyPolicy, maxLines: 1).xSmall.muted.underline,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullColumnWidth = 72.0;
        final proColumnWidth = 92.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: const Color(0xFFF5F5F8),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: proColumnWidth,
                  child: Container(
                    color: const Color(0xFFE6E7F5),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.8,
                  color: Color(0xFF55565C),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: proColumnWidth,
          child: Center(
            child: ProBadge(fontSize: 14),
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
                  color: const Color(0xFF94959A),
                  size: compact ? 16 : 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature.label,
                    style: TextStyle(
                      color: const Color(0xFF4D4E54),
                      fontWeight: FontWeight.normal,
                      fontSize: compact ? 13.5 : 19,
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
            fontSize: compact ? 12 : 24,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
      _PaywallText(:final text) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 12 : 24,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      _PaywallCheck() => Icon(
        Icons.check_rounded,
        size: compact ? 22 : 48,
        color: Colors.black,
      ),
      _PaywallDash() => Container(
        width: compact ? 20 : 40,
        height: 3,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    };
  }

  Widget _buildPlansSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
                  ),
                ),
                Expanded(
                  child: _buildPlanCard(
                    plan: _PaywallPlan.monthly,
                    title: AppLocalizations.of(context).paywall_monthly,
                    price: _pricing.monthlyPrice,
                    billed: _pricing.monthlyBilled,
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

  Widget _buildPlanCard({
    required _PaywallPlan plan,
    required String title,
    required String price,
    required String billed,
    String? badge,
  }) {
    final selected = _selectedPlan == plan;

    return Stack(
      clipBehavior: Clip.none,
      // Hand the row's stretched height to the card itself, so both plans
      // stay the same height even though only yearly has a billing line.
      fit: StackFit.passthrough,
      children: [
        GestureDetector(
          onTap: () => _selectPlan(plan),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? const Color(0xFF5A6ED6) : const Color(0xFFC1C2C8),
                width: selected ? 2.6 : 2,
              ),
            ),
            child: Column(
              spacing: 2,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      // "Monatlich" must not wrap on a narrow card — shrink
                      // rather than break the word.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF07070A),
                          ),
                        ),
                      ),
                    ),
                    _buildRadioIndicator(selected, compact: true),
                  ],
                ),
                const SizedBox(height: 4),
                // Per-month equivalent leads; the actual billing follows.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    price,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111216),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (billed.isNotEmpty)
                  Text(
                    billed,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7A7B85),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Align(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5A6ED6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),

        if (plan == _PaywallPlan.monthly || plan == _PaywallPlan.yearly)
          Positioned(
            top: 0,
            right: 0,
            child: ProBadge(
              fontSize: 14,
              borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomLeft: Radius.circular(8)),
            ),
          ),
      ],
    );
  }

  Widget _buildFullVersionCard(BuildContext context) {
    final selected = _selectedPlan == _PaywallPlan.fullVersion;
    return GestureDetector(
      onTap: () => _selectPlan(_PaywallPlan.fullVersion),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // The one-time Base plan sits quieter than the Pro cards above it.
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF5A6ED6) : const Color(0xFFDDDEE5),
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
                    style: const TextStyle(
                      color: Color(0xFF07070A),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _pricing.fullVersionSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF6C6D73),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Base is a store receipt, not an account: riders who bought
                  // it on one store and installed from another wrote in asking
                  // where their purchase went. Say so before they buy.
                  Text(
                    AppLocalizations.of(context).paywall_baseStoreNote(_storeName(context)),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: Color(0xFF6C6D73),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      margin: EdgeInsets.only(top: compact ? 2 : 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF5A6ED6) : Colors.transparent,
        border: Border.all(
          color: selected ? const Color(0xFF5A6ED6) : const Color(0xFFB8B9C0),
          width: selected ? 2 : 1.6,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF5A6ED6).withAlpha(70),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: selected
          ? Icon(
              Icons.check,
              size: small ? 10 : (compact ? 13 : 18),
              color: Colors.white,
            )
          : null,
    );
  }

  Widget _buildPurchaseButton(BuildContext context) {
    return GestureDetector(
      onTap: _isPurchasing ? null : _onPurchasePressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _isPurchasing ? 0.85 : 1,
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
                  AppLocalizations.of(context).purchase,
                  style: const TextStyle(
                    fontSize: 20,
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
