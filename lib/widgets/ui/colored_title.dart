import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'colors.dart' show bkAccentText;

class ColoredTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  const ColoredTitle({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        if (icon != null) Icon(icon, size: 18, color: bkAccentText(context)),
        Text(text).small.medium,
      ],
    );
  }
}
