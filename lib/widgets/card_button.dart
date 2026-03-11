import 'package:shadcn_flutter/shadcn_flutter.dart';

class HoverCardButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final ButtonStyle? buttonStyle;
  const HoverCardButton({
    super.key,
    this.buttonStyle,
    required this.onPressed,
    required this.child,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: trailing != null ? double.infinity : null,
      child: Button.card(
        style: (buttonStyle ?? ButtonStyle.card())
            .withBackgroundColor(
              hoverColor: Theme.of(context).colorScheme.border.withLuminance(0.94),
            )
            .withPadding(
              padding: EdgeInsets.only(left: 16, top: 16, bottom: 16, right: trailing != null ? 10 : 16),
            ),
        leading: leading,
        trailing: trailing,
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
