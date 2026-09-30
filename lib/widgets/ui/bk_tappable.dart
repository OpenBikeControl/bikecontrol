import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A custom-drawn tappable surface that behaves like a button everywhere a
/// `GestureDetector` doesn't: it is reported as a button to screen readers,
/// takes keyboard focus on desktop (Tab to it, Enter/Space to press it, with a
/// focus ring), and shows the click cursor.
///
/// Use it for cards and pills whose look a stock `Button` variant can't give.
///
/// With [wash] it also paints the card surfaces' hover and pressed washes
/// ([bkCardHover], [bkCardPressed]) over its resting [color] — the feedback
/// every grouped row and tappable card shares.
class BkTappable extends StatelessWidget {
  const BkTappable({
    super.key,
    required this.child,
    required this.onPressed,
    this.label,
    this.selected,
    this.expanded,
    this.inMutuallyExclusiveGroup = false,
    this.borderRadius,
    this.focusNode,
    this.excludeChildSemantics = false,
    this.onHover,
    this.wash = false,
    this.color,
  });

  /// Paint the hover and pressed washes behind [child].
  final bool wash;

  /// The resting fill behind [child] (none when null); the washes replace it
  /// while hovered or pressed.
  final Color? color;

  final Widget child;

  /// Null disables the surface, which is also reported to accessibility.
  final VoidCallback? onPressed;

  /// Spoken label. When null the child's own text is read.
  final String? label;

  /// For a choice among options (plan cards, radio-like tiles).
  final bool? selected;

  /// For a disclosure toggle: whether the section it controls is open.
  final bool? expanded;

  /// Set for radio-like groups where exactly one option is selected.
  final bool inMutuallyExclusiveGroup;

  /// Shape of the focus ring; match the child's corners.
  final BorderRadiusGeometry? borderRadius;

  final FocusNode? focusNode;

  /// Replace the child's semantics with [label] (for surfaces whose children
  /// are decorative or would read as fragments).
  final bool excludeChildSemantics;

  /// Hover changes, for a custom hover effect of the caller's own.
  final ValueChanged<bool>? onHover;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      selected: selected,
      expanded: expanded,
      inMutuallyExclusiveGroup: inMutuallyExclusiveGroup ? true : null,
      label: label,
      excludeSemantics: excludeChildSemantics,
      // With excludeSemantics the Clickable's own tap action and focus flag
      // are dropped too, so they are re-declared here.
      onTap: excludeChildSemantics ? onPressed : null,
      focusable: excludeChildSemantics ? onPressed != null : null,
      child: Clickable(
        enabled: onPressed != null,
        onPressed: onPressed,
        focusNode: focusNode,
        onHover: onHover,
        mouseCursor: WidgetStatePropertyAll(onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic),
        disableTransition: prefersReducedMotion(context),
        decoration: wash || color != null
            ? WidgetStateProperty.resolveWith(
                (states) => BoxDecoration(
                  borderRadius: borderRadius,
                  color: wash && states.contains(WidgetState.pressed)
                      ? bkCardPressed(context)
                      : wash && states.contains(WidgetState.hovered)
                      ? bkCardHover(context)
                      : color,
                ),
              )
            : borderRadius == null
            ? null
            : WidgetStatePropertyAll(BoxDecoration(borderRadius: borderRadius)),
        child: child,
      ),
    );
  }
}
