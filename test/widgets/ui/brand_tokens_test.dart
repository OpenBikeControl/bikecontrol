// The brand touch-up's tokens: the icon tile's blue wash, the group header
// ink, the cool-tinted dark ladder and the blue→teal brand band. Every text
// pair they make clears 4.5:1 in both themes; glyphs and indicators 3:1.
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';

void main() {
  group('values', () {
    test('light', () {
      const b = BkBrandColors.light;
      expect(b.tileWash, const Color(0xFFE3EEF7));
      expect(b.tileInk, const Color(0xFF0C6AA8));
      expect(b.groupHeader, const Color(0xFF3D5A73));
      expect(b.bandStart, const Color(0xFF0E74B7));
      expect(b.bandEnd, const Color(0xFF0B7478));
    });

    test('dark', () {
      const b = BkBrandColors.dark;
      expect(b.tileWash, const Color(0xFF1A2C3A));
      expect(b.tileInk, const Color(0xFF4DA9E8));
      expect(b.groupHeader, const Color(0xFF8DB4D1));
      expect(b.bandStart, const Color(0xFF0C5F96));
      expect(b.bandEnd, const Color(0xFF0A5F63));
    });

    test('the dark ladder is graphite with a 3% cool tint', () {
      final cs = BkTheme.darkColorScheme;
      expect(cs.background, const Color(0xFF101318));
      expect(cs.card, const Color(0xFF1B1F25));
      expect(cs.muted, const Color(0xFF262B33));
      expect(cs.popover, const Color(0xFF262B33));
      expect(cs.border, const Color(0xFF2A3038));
    });
  });

  for (final brightness in Brightness.values) {
    group(brightness.name, () {
      final b = BkBrandColors.forBrightness(brightness);
      final cs = BkTheme.build(brightness).colorScheme;
      final grounds = {'page': cs.background, 'card': cs.card, 'fill': cs.muted};

      test('tile glyph on its wash', () {
        expect(contrast(b.tileInk, b.tileWash), greaterThanOrEqualTo(4.5));
      });

      test('group header ink on page, card and fill', () {
        for (final MapEntry(:key, :value) in grounds.entries) {
          expect(contrast(b.groupHeader, value), greaterThanOrEqualTo(4.5), reason: 'on $key');
        }
      });

      test('text on the brand band, at both ends', () {
        for (final end in [b.bandStart, b.bandEnd]) {
          expect(contrast(b.onBand, end), greaterThanOrEqualTo(4.5), reason: 'white on $end');
          // An unselected segment sits on the darkened track.
          expect(contrast(b.onBand, Color.alphaBlend(b.bandTrack, end)), greaterThanOrEqualTo(4.5));
        }
        // The selected segment and the band's CTA: white with blue text.
        expect(contrast(b.onBandSelectedText, b.onBand), greaterThanOrEqualTo(4.5));
      });

      test('contour lines stay faint', () {
        expect(b.contourStroke.a, lessThanOrEqualTo(0.2));
      });

      test('the selected tab pill keeps the accent glyph at 3:1', () {
        final pill = Color.alphaBlend(b.navPill, cs.background);
        final ink = brightness == Brightness.dark ? cs.primary : BkTheme.lightAccentText;
        expect(contrast(ink, pill), greaterThanOrEqualTo(3));
      });

      test('the ready halo is a quiet ring of the success colour', () {
        expect(b.readyHalo.a, lessThanOrEqualTo(0.2));
      });

      test('cards cast a brand-tinted shadow in light only', () {
        if (brightness == Brightness.dark) {
          expect(b.cardShadow, isEmpty);
        } else {
          expect(b.cardShadow, isNotEmpty);
          for (final s in b.cardShadow) {
            expect(s.color.b, greaterThan(s.color.r), reason: 'tinted toward the brand blue');
            expect(s.color.a, lessThanOrEqualTo(0.2));
          }
        }
      });
    });
  }
}
