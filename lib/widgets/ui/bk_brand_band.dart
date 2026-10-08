import 'dart:math' as math;

import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The brand band: the website's brand-blue → deep-teal gradient with faint
/// topographic contour lines, white text on it.
///
/// Reserved for two places (a guard test holds the list): the header of
/// Ride's virtual shifting card, and the plan cards (Settings, the desktop
/// sidebar). Never on buttons or state indicators, and never animated.
///
/// Its child is themed for the band: foreground, secondary text, accent text
/// and `primary` all become white, `primaryForeground` the band's deep blue
/// (a selected segment or a CTA is white with blue text) and the muted fill
/// a darkened track. Controls inside therefore need no band-specific code.
class BkBrandBand extends StatelessWidget {
  const BkBrandBand({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = BorderRadius.zero,
    this.contours = const BkContourPlacement.header(),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// Where the contour lines sit over the band's right-hand side.
  final BkContourPlacement contours;

  /// Whether [context] sits on a brand band.
  static bool isOn(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_BandScope>() != null;

  /// The colour scheme for content on the band, derived from [base].
  static ColorScheme schemeFor(ColorScheme base, BkBrandColors brand) {
    final white = brand.onBand;
    return base.copyWith(
      // Light-on-dark everywhere inside: helpers that ask for the brightness
      // (accent text, status colours) pick their light-on-dark variants.
      brightness: () => Brightness.dark,
      background: () => brand.bandStart,
      foreground: () => white,
      card: () => const Color(0x00FFFFFF),
      cardForeground: () => white,
      primary: () => white,
      primaryForeground: () => brand.onBandSelectedText,
      secondary: () => brand.bandTrack,
      secondaryForeground: () => white,
      muted: () => brand.bandTrack,
      mutedForeground: () => white,
      accent: () => brand.bandTrack,
      accentForeground: () => white,
      border: () => const Color(0x4DFFFFFF),
      ring: () => white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BkBrandColors.of(context);
    final bandTheme = theme.copyWith(colorScheme: () => schemeFor(theme.colorScheme, brand));
    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        key: const ValueKey('bk-brand-band-fill'),
        decoration: BoxDecoration(
          // The website's 120° band.
          gradient: LinearGradient(
            begin: const Alignment(-1, -0.6),
            end: const Alignment(1, 0.6),
            colors: [brand.bandStart, brand.bandEnd],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: contours.right,
              top: contours.top,
              width: contours.size.width,
              height: contours.size.height,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    key: const ValueKey('bk-brand-band-contours'),
                    painter: BkContourPainter(color: brand.contourStroke),
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: _BandScope(
                child: Theme(
                  data: bandTheme,
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: brand.onBand),
                    child: IconTheme.merge(
                      data: IconThemeData(color: brand.onBand),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where a band's contour lines sit, measured from its top-right corner.
class BkContourPlacement {
  const BkContourPlacement({required this.right, required this.top, required this.size});

  /// A card header (Ride's shifting card).
  const BkContourPlacement.header() : right = -30, top = -70, size = const Size(280, 220);

  /// A plan card.
  const BkContourPlacement.card() : right = -40, top = -60, size = const Size(300, 220);

  /// The sidebar's small plan card.
  const BkContourPlacement.compact() : right = -60, top = -50, size = const Size(240, 180);

  final double right;
  final double top;
  final Size size;
}

class _BandScope extends InheritedWidget {
  const _BandScope({required super.child});

  @override
  bool updateShouldNotify(_BandScope oldWidget) => false;
}

/// Nine nested, gently irregular closed lines — terrain contours, the
/// website's line-art language. Drawn once; nothing about them moves.
class BkContourPainter extends CustomPainter {
  const BkContourPainter({required this.color});

  final Color color;

  /// The lines are drawn in this box and scaled to cover the paint area.
  static const Size _box = Size(300, 220);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.max(size.width / _box.width, size.height / _box.height);
    canvas
      ..save()
      ..translate((size.width - _box.width * scale) / 2, (size.height - _box.height * scale) / 2)
      ..scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale
      ..isAntiAlias = true;
    for (var k = 0; k < 9; k++) {
      final path = Path();
      final radius = 18.0 + k * 15;
      for (var s = 0; s <= 72; s++) {
        final t = s / 72 * math.pi * 2;
        final r =
            radius * (1 + .10 * math.sin(3 * t + k * .45) + .06 * math.sin(5 * t - k * .3) + .03 * math.sin(7 * t + k));
        final x = 190 + math.cos(t) * r * 1.25;
        final y = 110 + math.sin(t) * r * .9;
        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BkContourPainter oldDelegate) => oldDelegate.color != color;
}
