import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ProBadge extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  /// The larger badge (plan cards, the paywall's column header): `small`
  /// instead of the `caption` step.
  final bool large;

  const ProBadge({
    super.key,
    this.padding,
    this.borderRadius,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: borderRadius ?? BorderRadius.circular(6),
      ),
      child: Text(
        'PRO',
        style: (large ? context.typography.small : context.typography.caption).copyWith(
          // White on this orange is 2.8:1 — below even the large-text floor.
          color: const Color(0xFF1C1917),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
