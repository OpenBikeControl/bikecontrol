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
/// (gear hero card, drivetrain controls, trainer overlay). Tabular figures so
/// the number doesn't jitter sideways as it changes.
abstract final class BkNumerals {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// A gear numeral of [size] logical px.
  static TextStyle gear(double size, {Color? color, FontWeight fontWeight = FontWeight.w800, double? height}) =>
      TextStyle(
        fontSize: size,
        fontWeight: fontWeight,
        color: color,
        height: height,
        fontFeatures: tabular,
      );
}
