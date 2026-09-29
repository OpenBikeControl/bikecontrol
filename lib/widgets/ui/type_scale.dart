import 'package:shadcn_flutter/shadcn_flutter.dart';

/// BikeControl's type scale.
///
/// Every text size in the app is a step of shadcn's Geist [Typography]
/// (`xSmall` 12, `small` 14, `base` 16, `large` 18, `xLarge` 20, `x2Large` 24,
/// `x3Large` 30 at desktop scale), so it follows the theme's scaling: phones
/// get the same 1.25x as the rest of the UI instead of a literal pixel size
/// that stays tiny next to scaled body text.
///
/// The one step Geist lacks is [caption]: 11 px, the floor. Nothing in the app
/// is drawn smaller than that.
///
/// In a build method prefer the fluent form (`Text('x').small`); where a
/// [TextStyle] is needed, start from `context.typography.small` and
/// `copyWith` the colour/weight.
extension BkTypeScale on Typography {
  /// 11 px at desktop scale: badges, axis ticks, timestamps, meta lines.
  /// The smallest size the app uses.
  TextStyle get caption => xSmall.copyWith(fontSize: (xSmall.fontSize ?? 12) * 11 / 12);
}

extension BkTypeContext on BuildContext {
  /// The current theme's (scaled) typography.
  Typography get typography => Theme.of(this).typography;
}

extension BkCaptionText on Widget {
  /// Applies the [BkTypeScale.caption] size, like shadcn's `.xSmall`.
  TextModifier get caption => WrappedText(
    style: (context, theme) => theme.typography.caption,
    child: this,
  );
}

/// The one deliberate display size outside the scale: the big gear numeral
/// (gear hero card, drivetrain controls, trainer overlay). Set in the bundled
/// display face, Barlow Condensed, with tabular figures so the number doesn't
/// jitter sideways as it changes.
abstract final class BkNumerals {
  /// The bundled display family (pubspec `fonts:`; weights 600/700/800).
  static const String family = 'BarlowCondensed';

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// A gear numeral of [size] logical px.
  ///
  /// Self-contained (`inherit: false`): `Text` merges an inheriting style onto
  /// the theme's text style, and Geist is a shadcn_flutter package font, so a
  /// merged family picks up its package prefix
  /// ("packages/shadcn_flutter/BarlowCondensed") and silently falls back.
  /// Pass [color] whenever the style paints (null is for measuring only).
  static TextStyle gear(double size, {Color? color, FontWeight fontWeight = FontWeight.w800, double? height}) =>
      display(size, color: color, fontWeight: fontWeight, height: height);

  /// Any text in the display face at [size]; see [gear] for why it doesn't
  /// inherit.
  static TextStyle display(double size, {Color? color, FontWeight fontWeight = FontWeight.w700, double? height}) =>
      TextStyle(
        inherit: false,
        fontFamily: family,
        fontSize: size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        textBaseline: TextBaseline.alphabetic,
        fontFeatures: tabular,
      );
}

/// Display headlines in the numeral face: onboarding headlines ("YOUR
/// CONTROLLER IS READY") and plan names. Sized off the theme's typography so
/// they follow its scaling. Upper-case the string at the call site where the
/// design wants caps; the style doesn't transform text.
abstract final class BkDisplay {
  static TextStyle _display(BuildContext context, TextStyle base, double factor) => BkNumerals.display(
    (base.fontSize ?? 24) * factor,
    color: Theme.of(context).colorScheme.foreground,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );

  /// Page-level display headline, a step above `x2Large`. Foreground colour;
  /// `copyWith(color: …)` for another.
  static TextStyle headline(BuildContext context) => _display(context, context.typography.x2Large, 1.25);

  /// Card-level display title (plan names), `x2Large` in the display face.
  static TextStyle title(BuildContext context) => _display(context, context.typography.x2Large, 1.0);
}
