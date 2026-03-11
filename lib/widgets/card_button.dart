import 'package:shadcn_flutter/shadcn_flutter.dart';

class HoverCardButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  const HoverCardButton({super.key, required this.onPressed, required this.child, this.leading, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Button.card(
      style: ButtonStyle.card().withBackgroundColor(
        hoverColor: Theme.of(context).colorScheme.border.withLuminance(0.94),
      ),
      leading: leading,
      trailing: trailing,
      onPressed: onPressed,
      child: child,
    );
  }
}
