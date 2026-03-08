import 'package:shadcn_flutter/shadcn_flutter.dart';

class ProBadge extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final double fontSize;

  const ProBadge({
    super.key,
    this.padding,
    this.borderRadius,
    this.fontSize = 10,
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
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
