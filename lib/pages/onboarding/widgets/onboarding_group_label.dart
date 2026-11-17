import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Uppercase, letter-spaced section label with a hairline rule filling the
/// rest of the row — the design's GroupLabel.
class OnboardingGroupLabel extends StatelessWidget {
  const OnboardingGroupLabel(this.text, {super.key, this.leading, this.trailing});
  final String text;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        if (leading != null) ...[leading!, Gap(6)],
        DefaultTextStyle.merge(
          style: TextStyle(letterSpacing: 0.8, color: scheme.mutedForeground),
          child: Text(text.toUpperCase()).xSmall.semiBold,
        ),
        if (trailing != null) ...[Gap(7), trailing!],
        Gap(8),
        Expanded(child: Container(height: 1, color: scheme.border)),
      ]),
    );
  }
}
