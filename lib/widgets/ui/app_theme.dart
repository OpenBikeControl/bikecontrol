import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The one place BikeControl's shadcn themes are built.
///
/// Light and dark share typography, radius and scaling and differ only in
/// colour, so a page never has to ask which brightness it is in to pick a
/// sensible colour: `colorScheme.primary` is the brand blue in both.
///
/// The main app, the desktop overlay window and the Android overlay engine all
/// build their themes here, so the overlay matches the app it belongs to.
abstract final class BkTheme {
  /// Radius multiplier shared by both brightnesses.
  static const double radius = 0.7;

  /// Brand blue lifted for dark surfaces. The light brand blue ([BKColor.main])
  /// sits at ~2.8:1 against the dark background; this one clears 4.5:1.
  static const Color darkPrimary = Color(0xFF4DA9E8);

  /// Text/icon colour on [darkPrimary]. White on the lifted blue is only
  /// ~2.6:1, so dark mode puts near-black on it instead.
  static const Color darkPrimaryForeground = Color(0xFF04121C);

  /// Pro Orange: the PRO badge and Pro marks, nothing else. Text on it is
  /// near-black; white on this orange is about 2.8:1.
  static const Color proOrange = Color(0xFFF97316);

  /// Brand blue for TEXT (links, accent labels) on light grounds. The brand
  /// blue itself is 4.48:1 on the grouped page (#F2F2F7), a hair under
  /// 4.5:1; this one notch darker clears it on the page, cards and fills.
  /// Read it through `bkAccentText(context)`.
  static const Color lightAccentText = Color(0xFF0C6AA8);

  /// Apple-style grouped palette: white cards on a light grey page, so cards
  /// separate by tone rather than by a border.
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    background: Color(0xFFF2F2F7),
    foreground: Color(0xFF1C1C1E),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF1C1C1E),
    popover: Color(0xFFFFFFFF),
    popoverForeground: Color(0xFF1C1C1E),
    primary: BKColor.main,
    primaryForeground: Color(0xFFFFFFFF),
    // Fills (secondary buttons, segmented tracks, chips) read on both the
    // grey page and a white card.
    secondary: Color(0xFFE9E9EE),
    secondaryForeground: Color(0xFF1C1C1E),
    muted: Color(0xFFE9E9EE),
    // #6C6C70 is only 4.3:1 on the fills above; this clears 4.5:1 on the
    // page (5.4), a card (6.0) and a fill.
    mutedForeground: Color(0xFF636366),
    accent: Color(0xFFE9E9EE),
    accentForeground: Color(0xFF1C1C1E),
    // Red-600: white text on it is 4.8:1 (red-500 was 3.8:1).
    destructive: Color(0xFFDC2626),
    destructiveForeground: Color(0xFFFFFFFF),
    // Hairline separators: visible on white and on the page, never loud.
    border: Color(0xFFDCDCE0),
    input: Color(0xFFD1D1D6),
    ring: BKColor.main,
    chart1: Color(0xFFE76E50),
    chart2: Color(0xFF2A9D90),
    chart3: Color(0xFF274754),
    chart4: Color(0xFFE8C468),
    chart5: Color(0xFFF4A462),
  );

  /// One neutral-grey tonal ladder for every dark surface: page #121212,
  /// card #1E1E1E, raised/fill #2A2A2A. Cards separate by tone, not borders.
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    background: Color(0xFF121212),
    foreground: Color(0xFFFFFFFF),
    card: Color(0xFF1E1E1E),
    cardForeground: Color(0xFFFFFFFF),
    // Menus and popovers float over cards, so they sit one step up.
    popover: Color(0xFF2A2A2A),
    popoverForeground: Color(0xFFFFFFFF),
    primary: darkPrimary,
    primaryForeground: darkPrimaryForeground,
    secondary: Color(0xFF2A2A2A),
    secondaryForeground: Color(0xFFFFFFFF),
    muted: Color(0xFF2A2A2A),
    mutedForeground: Color(0xFFA3A3A3),
    accent: Color(0xFF2A2A2A),
    accentForeground: Color(0xFFFFFFFF),
    destructive: Color(0xFFDC2626),
    destructiveForeground: Color(0xFFFFFFFF),
    border: Color(0xFF2E2E2E),
    // Text-field outlines need a touch more than a hairline.
    input: Color(0xFF3A3A3A),
    ring: darkPrimary,
    chart1: Color(0xFF2662D9),
    chart2: Color(0xFF2EB88A),
    chart3: Color(0xFFE88C30),
    chart4: Color(0xFFAF57DB),
    chart5: Color(0xFFE23670),
  );

  /// Phone/tablet scaling. shadcn's own `AdaptiveScaling.mobile` scales
  /// everything 1.25x; sizes, radii and icons keep that (it is what brings
  /// icon buttons to a ~45 px target), but text at 1.25x wrapped the dense
  /// cards far more than on desktop, so text gets 1.1x.
  static const AdaptiveScaling mobileScaling = _BkMobileScaling();

  /// The scaling every BikeControl `ShadcnApp` passes: [mobileScaling] on
  /// iOS/Android (where shadcn would pick its mobile default), none elsewhere.
  static AdaptiveScaling scalingFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.android => mobileScaling,
    _ => AdaptiveScaling.desktop,
  };

  /// [scalingFor] the platform the app runs on.
  static AdaptiveScaling get scaling => scalingFor(defaultTargetPlatform);

  /// Builds the theme for [brightness].
  ///
  /// Deliberately unscaled: every app shell passes [scaling] to `ShadcnApp`,
  /// which applies it on top of this.
  static ThemeData build(Brightness brightness) => ThemeData(
    colorScheme: brightness == Brightness.dark ? darkColorScheme : lightColorScheme,
    typography: const Typography.geist(),
    radius: radius,
  );
}

/// Component defaults every BikeControl app shell puts around its content
/// (main app, overlay, test harnesses), so a plain `Card` is the design's
/// card everywhere: 16 px corners and no outline. Cards separate from the
/// page by tone (dark: #1E1E1E on #121212; light: white on #F2F2F7).
///
/// A card that needs an outline (a selected plan, a warning) still sets
/// `borderColor` itself.
class BkComponentThemes extends StatelessWidget {
  const BkComponentThemes({super.key, required this.child});

  /// Corner radius of a card, in logical px.
  static const double cardRadius = 16;

  static const CardTheme cardTheme = CardTheme(
    borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
    // Border.all(width: 0) still paints a one-pixel hairline, so the default
    // outline is also made transparent.
    borderWidth: 0,
    borderColor: Color(0x00000000),
  );

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ComponentTheme<CardTheme>(
      data: cardTheme,
      child: ComponentTheme<DividerTheme>(
        data: DividerTheme(color: Theme.of(context).colorScheme.border),
        child: child,
      ),
    );
  }
}

/// Status colours, which shadcn's [ColorScheme] has no slots for: success,
/// warning, info and danger, each with a foreground for text/icons on the
/// filled colour and a wash for a tinted background.
///
/// The colour itself is for text and icons on the page, a card or its own
/// wash; all of those clear 4.5:1 in both brightnesses (pinned in
/// app_theme_test). Status must never be colour alone — pair it with an icon
/// or words.
@immutable
class BkStatusColors {
  const BkStatusColors._({
    required this.success,
    required this.successForeground,
    required this.successWash,
    required this.warning,
    required this.warningForeground,
    required this.warningWash,
    required this.info,
    required this.infoForeground,
    required this.infoWash,
    required this.danger,
    required this.dangerForeground,
    required this.dangerWash,
  });

  final Color success;
  final Color successForeground;
  final Color successWash;
  final Color warning;
  final Color warningForeground;
  final Color warningWash;
  final Color info;
  final Color infoForeground;
  final Color infoWash;
  final Color danger;
  final Color dangerForeground;
  final Color dangerWash;

  static const BkStatusColors light = BkStatusColors._(
    // Green-700 (#15803D) is 4.49:1 on the grouped page; one notch darker.
    success: Color(0xFF147A3B),
    successForeground: Color(0xFFFFFFFF),
    successWash: Color(0xFFF0FDF4),
    warning: Color(0xFFB45309),
    warningForeground: Color(0xFFFFFFFF),
    warningWash: Color(0xFFFFFBEB),
    info: Color(0xFF1D4ED8),
    infoForeground: Color(0xFFFFFFFF),
    infoWash: Color(0xFFEFF6FF),
    danger: Color(0xFFB91C1C),
    dangerForeground: Color(0xFFFFFFFF),
    dangerWash: Color(0xFFFEF2F2),
  );

  /// Lifted hues for dark surfaces, dark text on the filled colours, and
  /// low-alpha washes of the colour itself.
  static const BkStatusColors dark = BkStatusColors._(
    success: Color(0xFF22C55E),
    successForeground: Color(0xFF052E16),
    successWash: Color(0x2622C55E),
    warning: Color(0xFFFBBF24),
    warningForeground: Color(0xFF1C1917),
    warningWash: Color(0x26FBBF24),
    info: Color(0xFF93C5FD),
    infoForeground: Color(0xFF0B1B33),
    infoWash: Color(0x2693C5FD),
    danger: Color(0xFFFC8C8C),
    dangerForeground: Color(0xFF1F0707),
    dangerWash: Color(0x26FC8C8C),
  );

  static BkStatusColors forBrightness(Brightness brightness) => brightness == Brightness.dark ? dark : light;

  static BkStatusColors of(BuildContext context) => forBrightness(Theme.of(context).brightness);
}

/// [BkTheme.mobileScaling]: shadcn scales icons with text; this keeps them at
/// the control scale so icon buttons don't shrink with the text.
class _BkMobileScaling extends AdaptiveScaling {
  const _BkMobileScaling() : super.only(radiusScaling: 1.25, sizeScaling: 1.25, textScaling: 1.1);

  static const double _iconScaling = 1.25;

  @override
  ThemeData scale(ThemeData theme) => super.scale(theme).copyWith(iconTheme: () => theme.iconTheme.scale(_iconScaling));
}
