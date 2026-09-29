import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The phone's primary call to action: a full-width, fully rounded primary
/// button at least 48 dp tall ("Continue", "Done — start riding").
///
/// Elsewhere use shadcn's `Button.primary`; this is only its pill shape and
/// size. For a pill of another variant, apply [shape] to that style.
class BkPillButton extends StatelessWidget {
  const BkPillButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.expand = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;

  /// Fill the available width (the phone default).
  final bool expand;

  static const double minHeight = 48;

  /// Rounds [style] into a pill in every state.
  static AbstractButtonStyle shape(AbstractButtonStyle style) {
    const pill = BorderRadius.all(Radius.circular(999));
    return style.withBorderRadius(
      borderRadius: pill,
      hoverBorderRadius: pill,
      focusBorderRadius: pill,
      disabledBorderRadius: pill,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight, minWidth: expand ? double.infinity : 0),
      child: Button(
        style: shape(
          const ButtonStyle.primary().withPadding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
        ),
        alignment: Alignment.center,
        leading: leading,
        trailing: trailing,
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
