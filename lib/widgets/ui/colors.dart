import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class BKColor {
  static const Color main = Color(0xFF0E74B7);
  static const Color mainEnd = Color(0xFF0E9297);
}

/// A recessed surface one step off the page background — the sidebar and
/// Ride's activity column. Light: a touch darker than the grouped page, toward the
/// fill. Dark: the page is already the bottom of the tonal ladder (cards and
/// fills sit above it), so the recess goes one step darker still.
Color bkSunkenSurface(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  return theme.brightness == Brightness.dark
      ? Color.lerp(cs.background, const Color(0xFF000000), 0.35)!
      : Color.lerp(cs.background, cs.muted, 0.5)!;
}

/// Hover wash for tappable card surfaces: the card lifted a step toward the
/// foreground in dark mode, and the fill colour on light cards (white → the
/// grouped fill), so hover reads on both.
Color bkCardHover(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  return theme.brightness == Brightness.dark
      ? Color.lerp(cs.card, cs.foreground, 0.08)!
      : Color.lerp(cs.card, cs.muted, 0.6)!;
}

/// One step firmer than `colorScheme.border` — the design's `border-strong`,
/// for hairlines that have to stay readable against an inset fill.
Color bkStrongBorder(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Color.lerp(cs.border, cs.mutedForeground, 0.45)!;
}

/// Accent colour for TEXT and links: `primary` in dark mode; on light
/// grounds [BkTheme.lightAccentText], because the brand blue is a hair under
/// 4.5:1 on the grouped page. Fills (buttons, switches) keep `primary`.
Color bkAccentText(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark ? theme.colorScheme.primary : BkTheme.lightAccentText;
}
