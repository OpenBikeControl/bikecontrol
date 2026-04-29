import 'package:shadcn_flutter/shadcn_flutter.dart';

class SettingTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? child;
  final VoidCallback? onTap;

  const SettingTile({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon!, size: 18),
              const Gap(12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (child != null) child!,
      ],
    );

    if (onTap != null) {
      return SizedBox(
        width: double.infinity,
        child: Button.card(
          style: ButtonStyle.card()
              .withPadding(padding: const EdgeInsets.all(16))
              .withBackgroundColor(hoverColor: cs.border.withLuminance(0.94)),
          onPressed: onTap,
          child: content,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: content,
    );
  }
}
