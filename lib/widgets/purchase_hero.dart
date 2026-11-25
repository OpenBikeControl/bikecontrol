import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_brand_band.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Which plan a [PurchaseHero] celebrates.
enum PurchasePlan { base, pro }

/// The header of the purchase confirmations: the brand band (it is the plan
/// card's band, and this is where a plan begins), the plan's mark popping in
/// with a ring that rolls out once, a thank-you line and the dialog's title.
///
/// Under reduced motion the mark is simply there.
class PurchaseHero extends StatefulWidget {
  const PurchaseHero({super.key, required this.plan, required this.title, this.radius = BorderRadius.zero});

  final PurchasePlan plan;
  final String title;

  /// The dialog's top corners, so the band follows them.
  final BorderRadius radius;

  @override
  State<PurchaseHero> createState() => _PurchaseHeroState();
}

class _PurchaseHeroState extends State<PurchaseHero> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isAnimating || _entrance.isCompleted) return;
    if (prefersReducedMotion(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPro = widget.plan == PurchasePlan.pro;
    final markColor = isPro ? BkTheme.proOrange : BkBrandColors.of(context).bandStart;

    final pop = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
    );
    final ring = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
    );
    final text = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    );

    return BkBrandBand(
      borderRadius: widget.radius,
      padding: EdgeInsets.zero,
      contours: const BkContourPlacement.card(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 64,
              child: AnimatedBuilder(
                animation: _entrance,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // One ring rolling out from behind the mark, then gone.
                    Opacity(
                      opacity: (1 - ring.value).clamp(0, 1) * 0.6,
                      child: Transform.scale(
                        scale: 0.8 + ring.value * 0.7,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
                          ),
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: pop.value,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFFFFF),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), offset: Offset(0, 4), blurRadius: 12),
                          ],
                        ),
                        child: Icon(isPro ? LucideIcons.crown : LucideIcons.badgeCheck, size: 28, color: markColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(16),
            Expanded(
              child: FadeTransition(
                opacity: text,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(text),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.purchaseThanks,
                        style: context.typography.xSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xDDFFFFFF),
                        ),
                      ),
                      const Gap(3),
                      Text(
                        widget.title,
                        style: context.typography.large.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFFFFF),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A purchase confirmation: [PurchaseHero] on top, then [body] and the
/// [actions] on the dialog surface. The actions sit in a Wrap so a long pair
/// can fall onto two lines.
class PurchaseDialog extends StatelessWidget {
  const PurchaseDialog({
    super.key,
    required this.plan,
    required this.title,
    required this.body,
    required this.actions,
  });

  final PurchasePlan plan;
  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = theme.borderRadiusXxl;
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AlertDialog(
        padding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PurchaseHero(
              plan: plan,
              title: title,
              radius: BorderRadius.only(topLeft: radius.topLeft, topRight: radius.topRight),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DefaultTextStyle.merge(
                    style: context.typography.small.copyWith(color: theme.colorScheme.foreground, height: 1.45),
                    child: body,
                  ),
                  const Gap(18),
                  Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
