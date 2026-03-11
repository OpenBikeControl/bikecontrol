import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'colors.dart' show BKColor;

class ColoredTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  const ColoredTitle({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: BKColor.main),
          const Gap(6),
        ],
        Text(text).xSmall,
      ],
    );
  }
}
