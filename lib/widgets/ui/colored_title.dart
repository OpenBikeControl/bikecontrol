import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'colors.dart' show BKColor;

class ColoredTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  const ColoredTitle({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        if (icon != null && false) Icon(icon, size: 18, color: BKColor.main),
        Text(text).small.medium,
      ],
    );
  }
}
