import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// An icon-only button that always says what it does.
///
/// A bare `IconButton` exposes nothing but a tap action to screen readers —
/// TalkBack and VoiceOver announce "button" and nothing else. [label] is
/// required so that can't happen: it becomes the button's semantics label and,
/// on desktop, its hover tooltip.
class BkIconButton extends StatelessWidget {
  const BkIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.variance = ButtonVariance.ghost,
    this.size = ButtonSize.normal,
    this.density = ButtonDensity.icon,
    this.shape = ButtonShape.rectangle,
    this.onLongPress,
    this.focusNode,
    this.tooltip = true,
  });

  const BkIconButton.ghost({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = ButtonSize.normal,
    this.density = ButtonDensity.icon,
    this.shape = ButtonShape.rectangle,
    this.onLongPress,
    this.focusNode,
    this.tooltip = true,
  }) : variance = ButtonVariance.ghost;

  const BkIconButton.primary({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = ButtonSize.normal,
    this.density = ButtonDensity.icon,
    this.shape = ButtonShape.rectangle,
    this.onLongPress,
    this.focusNode,
    this.tooltip = true,
  }) : variance = ButtonVariance.primary;

  const BkIconButton.secondary({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = ButtonSize.normal,
    this.density = ButtonDensity.icon,
    this.shape = ButtonShape.rectangle,
    this.onLongPress,
    this.focusNode,
    this.tooltip = true,
  }) : variance = ButtonVariance.secondary;

  const BkIconButton.outline({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = ButtonSize.normal,
    this.density = ButtonDensity.icon,
    this.shape = ButtonShape.rectangle,
    this.onLongPress,
    this.focusNode,
    this.tooltip = true,
  }) : variance = ButtonVariance.outline;

  const BkIconButton.destructive({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = ButtonSize.normal,
    this.density = ButtonDensity.icon,
    this.shape = ButtonShape.rectangle,
    this.onLongPress,
    this.focusNode,
    this.tooltip = true,
  }) : variance = ButtonVariance.destructive;

  const BkIconButton.link({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = ButtonSize.normal,
    this.density = ButtonDensity.icon,
    this.shape = ButtonShape.rectangle,
    this.onLongPress,
    this.focusNode,
    this.tooltip = true,
  }) : variance = ButtonVariance.link;

  const BkIconButton.menu({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = ButtonSize.normal,
    this.density = ButtonDensity.iconDense,
    this.shape = ButtonShape.rectangle,
    this.onLongPress,
    this.focusNode,
    this.tooltip = true,
  }) : variance = ButtonVariance.menu;

  final Widget icon;

  /// What the button does, in the rider's language ("Back", "Send message").
  final String label;

  /// Null disables the button (and reports it as disabled to accessibility).
  final VoidCallback? onPressed;

  final AbstractButtonStyle variance;
  final ButtonSize size;
  final ButtonDensity density;
  final ButtonShape shape;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;

  /// Show [label] as a hover tooltip on desktop. Off for buttons that open a
  /// popover of their own, where the tooltip would sit on top of it.
  final bool tooltip;

  static bool get _isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    Widget button = IconButton(
      icon: icon,
      variance: variance,
      onPressed: onPressed,
      size: size,
      density: density,
      shape: shape,
      focusNode: focusNode,
      onLongPressEnd: onLongPress == null ? null : (_) => onLongPress!(),
    );
    if (tooltip && _isDesktop) {
      button = Tooltip(
        tooltip: (context) => TooltipContainer(child: Text(label)),
        child: button,
      );
    }
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      child: button,
    );
  }
}
