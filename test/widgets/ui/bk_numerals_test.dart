import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  test('gear numerals are Barlow Condensed with tabular figures', () {
    final style = BkNumerals.gear(64, color: const Color(0xFF000000));
    expect(style.fontFamily, BkNumerals.family);
    expect(BkNumerals.family, 'BarlowCondensed');
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(style.fontWeight!.value, greaterThanOrEqualTo(700));
    expect(style.fontSize, 64);
  });

  testWidgets('the family survives the theme text it is merged onto (no package prefix)', (tester) async {
    // Text merges its style onto DefaultTextStyle, whose Geist family comes
    // from the shadcn_flutter package; a merged family would inherit that
    // package prefix ("packages/shadcn_flutter/BarlowCondensed", which
    // doesn't exist) and silently fall back.
    await tester.pumpWidget(
      ShadcnApp(
        theme: BkTheme.build(Brightness.dark),
        home: Builder(
          builder: (context) => Column(
            children: [
              Text('12', style: BkNumerals.gear(64, color: const Color(0xFFFFFFFF))),
              Text('READY', style: BkDisplay.headline(context)),
            ],
          ),
        ),
      ),
    );
    for (final text in ['12', 'READY']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(paragraph.text.style!.fontFamily, BkNumerals.family, reason: text);
    }
  });

  testWidgets('display headlines use the display face, bold, sized off the theme', (tester) async {
    late TextStyle headline;
    late TextStyle title;
    late Typography typography;
    await tester.pumpWidget(
      ShadcnApp(
        theme: BkTheme.build(Brightness.light),
        home: Builder(
          builder: (context) {
            headline = BkDisplay.headline(context);
            title = BkDisplay.title(context);
            typography = context.typography;
            return const SizedBox();
          },
        ),
      ),
    );
    for (final style in [headline, title]) {
      expect(typography.base.merge(style).fontFamily, BkNumerals.family);
      expect(style.color, isNotNull);
      expect(style.fontWeight!.value, greaterThanOrEqualTo(700));
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
    expect(headline.fontSize, greaterThan(typography.x2Large.fontSize!));
    expect(title.fontSize, greaterThanOrEqualTo(typography.xLarge.fontSize!));
  });

  test('the bundled font is declared and its digits are the same width', () async {
    final loader = FontLoader(BkNumerals.family);
    for (final weight in ['SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/barlow_condensed/BarlowCondensed-$weight.ttf'));
    }
    await loader.load();

    double widthOf(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: BkNumerals.gear(100, color: const Color(0xFF000000))),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    // Loaded for real (not the test font): a condensed face is far narrower
    // than the 1em-per-glyph placeholder.
    expect(widthOf('88'), lessThan(150));
    expect(widthOf('11'), closeTo(widthOf('88'), 0.5));
  });
}
