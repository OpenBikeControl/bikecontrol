import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

enum _PaywallPlan {
  yearly,
  monthly,
  fullVersion,
}

enum _PaywallCell {
  unlimited,
  check,
  dash,
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

  static const fallback = _PaywallPricing(
    yearlyPrice: 'About 2.25 \$/mo',
    yearlyBilled: 'Price calculated at checkout',
    monthlyPrice: 'About 2.50 \$/mo',
    monthlyBilled: 'Price calculated at checkout',
    fullVersionSubtitle: 'About 4.99 \$ - price calculated at checkout',
    discountBadge: '10% OFF',
  );
}

class Paywall extends StatefulWidget {
  final bool defaultToFullVersion;

  const Paywall({
    super.key,
    this.defaultToFullVersion = false,
  });

  @override
  State<Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<Paywall> {
  static const List<_FeatureLine> _features = [
    _FeatureLine(
      icon: Icons.functions,
      label: 'Amount of actions',
      full: _PaywallCell.unlimited,
      pro: _PaywallCell.unlimited,
    ),
    _FeatureLine(
      icon: Icons.public,
      label: 'Connect to your trainer',
      full: _PaywallCell.check,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.tune,
      label: 'Configure 3 actions per button',
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.devices,
      label: 'Use BikeControl on all platforms',
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.cloud_outlined,
      label: 'Synchronize and backup',
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.keyboard_command_key,
      label: 'Start any command / shortcut with any button',
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.music_note_outlined,
      label: 'Control your device / music',
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.screenshot_monitor_outlined,
      label: 'Create screenshots',
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
    _FeatureLine(
      icon: Icons.volunteer_activism_outlined,
      label: 'Support development of new features / devices and more',
      full: _PaywallCell.dash,
      pro: _PaywallCell.check,
    ),
  ];

  final IAPManager _iapManager = IAPManager.instance;

  late _PaywallPlan _selectedPlan;
  _PaywallPricing _pricing = _PaywallPricing.fallback;

  bool _isPurchasing = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.defaultToFullVersion ? _PaywallPlan.fullVersion : _PaywallPlan.yearly;
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
      closeDrawer(context);
    }
  }

  Future<void> _onPurchasePressed() async {
    if (_isPurchasing) {
      return;
    }
    setState(() {
      _isPurchasing = true;
    });

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

    try {
      await _iapManager.restorePurchases();
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
    if (defaultTargetPlatform != TargetPlatform.macOS) {
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
        ? '${_formatCurrency(yearlyStoreProduct.price / 12, yearlyStoreProduct.currencyCode)}/mo'
        : _pricing.yearlyPrice;

    final yearlyBilled = yearlyStoreProduct != null
        ? 'Billed at ${yearlyStoreProduct.priceString}/yr.'
        : _pricing.yearlyBilled;

    final monthlyPrice = monthlyStoreProduct != null ? '${monthlyStoreProduct.priceString}/mo' : _pricing.monthlyPrice;

    final monthlyBilled = monthlyStoreProduct != null
        ? 'Billed at ${monthlyStoreProduct.priceString}/mo.'
        : _pricing.monthlyBilled;

    final fullVersionSubtitle = lifetimeStoreProduct != null
        ? 'Only ${lifetimeStoreProduct.priceString}'
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

  String _formatCurrency(double value, String currencyCode) {
    final formatter = NumberFormat.currency(
      name: currencyCode,
      decimalDigits: 2,
    );
    return formatter.format(value);
  }

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
                        _isRestoring ? 'Restoring purchases...' : 'Restore purchases',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
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
        final fullColumnWidth = 80.0;
        final proColumnWidth = 102.0;

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
          child: const Center(
            child: Text(
              'FULL',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.8,
                color: Color(0xFF55565C),
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
                  size: compact ? 18 : 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature.label,
                    style: TextStyle(
                      color: const Color(0xFF4D4E54),
                      fontWeight: FontWeight.normal,
                      fontSize: compact ? 16 : 19,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: fullColumnWidth,
            child: Center(
              child: _buildCell(feature.full, compact: compact),
            ),
          ),
          SizedBox(
            width: proColumnWidth,
            child: Center(
              child: _buildCell(feature.pro, compact: compact),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(_PaywallCell value, {required bool compact}) {
    return switch (value) {
      _PaywallCell.unlimited => Text(
        'Unlimited',
        style: TextStyle(
          fontSize: compact ? 14 : 24,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      _PaywallCell.check => Icon(
        Icons.check_rounded,
        size: compact ? 28 : 48,
        color: Colors.black,
      ),
      _PaywallCell.dash => Container(
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
        final stackPlans = constraints.maxWidth < 420;

        return Column(
          spacing: 12,
          children: [
            if (!stackPlans)
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: _buildPlanCard(
                      plan: _PaywallPlan.yearly,
                      title: 'Yearly',
                      price: _pricing.yearlyPrice,
                      billed: _pricing.yearlyBilled,
                      badge: _pricing.discountBadge,
                    ),
                  ),
                  Expanded(
                    child: _buildPlanCard(
                      plan: _PaywallPlan.monthly,
                      title: 'Monthly',
                      price: _pricing.monthlyPrice,
                      billed: _pricing.monthlyBilled,
                    ),
                  ),
                ],
              )
            else ...[
              _buildPlanCard(
                plan: _PaywallPlan.yearly,
                title: 'Yearly',
                price: _pricing.yearlyPrice,
                billed: _pricing.yearlyBilled,
                badge: _pricing.discountBadge,
              ),
              _buildPlanCard(
                plan: _PaywallPlan.monthly,
                title: 'Monthly',
                price: _pricing.monthlyPrice,
                billed: _pricing.monthlyBilled,
              ),
            ],
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
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF07070A),
                        ),
                      ),
                    ),
                    _buildRadioIndicator(selected, compact: true),
                  ],
                ),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111216),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  billed,
                  style: const TextStyle(
                    fontSize: 16,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F2F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF5A6ED6) : const Color(0xFFC1C2C8),
            width: selected ? 2.4 : 2,
          ),
        ),
        child: Row(
          children: [
            _buildRadioIndicator(selected, compact: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).fullVersion,
                    style: const TextStyle(
                      color: Color(0xFF07070A),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _pricing.fullVersionSubtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4E4E53),
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

  Widget _buildRadioIndicator(bool selected, {bool compact = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: compact ? 28 : 38,
      height: compact ? 28 : 38,
      margin: EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF5A6ED6) : Colors.transparent,
        border: Border.all(
          color: selected ? const Color(0xFF5A6ED6) : const Color(0xFFB8B9C0),
          width: selected ? 3 : 2,
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
              size: compact ? 17 : 20,
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
