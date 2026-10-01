import 'package:flutter/widgets.dart';

/// The app's window-size classes, following the Material 3 split
/// (compact < 600 < medium < 840 < expanded).
enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize fromWidth(double width) {
    if (width < Breakpoints.compact) return WindowSize.compact;
    if (width < Breakpoints.medium) return WindowSize.medium;
    return WindowSize.expanded;
  }

  static WindowSize of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == WindowSize.compact;
}

/// Every width the layout switches on, named in one place.
///
/// The size classes are [compact] and [medium]. The others predate them and
/// are kept at their exact values on purpose — moving them onto a class
/// boundary would change a layout at widths riders already use.
abstract final class Breakpoints {
  /// Below this the window is a phone: stacked layouts, bottom tab bar,
  /// compact scaling. Upper edge of [WindowSize.compact].
  static const double compact = 600;

  /// Upper edge of [WindowSize.medium]. From here the sections sit in a
  /// permanent sidebar instead of a floating tab bar.
  static const double medium = 840;

  /// From here onboarding shows its step rail beside the step.
  static const double twoPane = 800;

  /// Below this, network-check rows drop their right-hand value column and
  /// the troubleshooter header moves its run stamp into the body.
  static const double networkValueColumn = 640;

  /// Below this the keymap explanation stacks its controller picture above
  /// the button list.
  static const double keymapSideBySide = 860;

  /// App picker in onboarding: five columns from here, three below.
  static const double onboardingAppGridWide = 560;

  /// Zwift Click v2 card: below this it stacks its content.
  static const double clickV2Narrow = 380;

  /// Smallest main window on desktop. Narrow enough to use as a sidebar next
  /// to a trainer app, wide enough that the compact layout still fits.
  static const Size minDesktopWindow = Size(360, 560);
}

/// Shorthand for `WindowSize.of(context).isCompact`.
bool isCompactWindow(BuildContext context) => MediaQuery.sizeOf(context).width < Breakpoints.compact;
