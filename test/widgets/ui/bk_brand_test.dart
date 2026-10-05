// The brand line's building blocks: the blue→teal band (static, with faint
// contour lines and white text), the handlebar mark, the Barlow caps headers
// and the blue-washed icon tiles.
import 'package:bike_control/widgets/home/your_buttons.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_brand_band.dart';
import 'package:bike_control/widgets/ui/bk_brand_mark.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';

Future<void> _pump(WidgetTester tester, Brightness brightness, Widget child) async {
  await tester.pumpWidget(
    ShadcnApp(
      theme: BkTheme.build(brightness),
      home: BkComponentThemes(
        child: Center(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final brightness in Brightness.values) {
    final b = BkBrandColors.forBrightness(brightness);
    final cs = BkTheme.build(brightness).colorScheme;

    group(brightness.name, () {
      testWidgets('the band paints the gradient, contours and white text', (tester) async {
        await _pump(
          tester,
          brightness,
          BkBrandBand(
            child: Builder(
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Virtuelles Schalten', style: TextStyle(color: Theme.of(context).colorScheme.foreground)),
                  Text('KICKR CORE', style: TextStyle(color: Theme.of(context).colorScheme.mutedForeground)),
                ],
              ),
            ),
          ),
        );
        final box = tester.widget<DecoratedBox>(
          find.descendant(of: find.byType(BkBrandBand), matching: find.byKey(const ValueKey('bk-brand-band-fill'))),
        );
        final gradient = (box.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(gradient.colors, [b.bandStart, b.bandEnd]);
        expect(
          find.descendant(of: find.byType(BkBrandBand), matching: find.byKey(const ValueKey('bk-brand-band-contours'))),
          findsOneWidget,
        );
        expectLegibleText(tester, find.byType(BkBrandBand), pageBackground: cs.background);
        // The legibility check reads the gradient's first colour; the far end too.
        expect(contrast(b.onBand, b.bandEnd), greaterThanOrEqualTo(4.5));
      });

      testWidgets('the band is static: nothing keeps drawing frames', (tester) async {
        await _pump(tester, brightness, const BkBrandBand(child: SizedBox(height: 80)));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('inside the band, accent text and the selected segment follow the band', (tester) async {
        late Color accent;
        late ColorScheme band;
        await _pump(
          tester,
          brightness,
          BkBrandBand(
            child: Builder(
              builder: (context) {
                accent = bkAccentText(context);
                band = Theme.of(context).colorScheme;
                return const SizedBox(height: 40);
              },
            ),
          ),
        );
        expect(accent, b.onBand);
        expect(band.primary, b.onBand);
        expect(band.primaryForeground, b.onBandSelectedText);
        expect(band.muted, b.bandTrack);
      });

      testWidgets('the mark sits in a blue→teal disc and is not announced', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, brightness, const Center(child: BkBrandMark(size: 34)));
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(tester.getSize(find.byType(BkBrandMark)), const Size(34, 34));
        final disc = tester.widget<DecoratedBox>(
          find.descendant(of: find.byType(BkBrandMark), matching: find.byType(DecoratedBox)).first,
        );
        final gradient = (disc.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(gradient.colors.first, BkBrandColors.light.bandStart);
        expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
        semantics.dispose();
      });

      testWidgets('group headers: Barlow Condensed caps in the header ink', (tester) async {
        await _pump(tester, brightness, const BkGroupedHeader('Fahren mit'));
        final text = tester.widget<Text>(find.text('FAHREN MIT'));
        expect(text.style!.fontFamily, BkNumerals.family);
        expect(text.style!.color, b.groupHeader);
      });

      testWidgets('Ride section titles: Barlow Condensed caps', (tester) async {
        await _pump(tester, brightness, const RideSectionHeader(title: 'Deine Tasten'));
        final text = tester.widget<Text>(find.text('DEINE TASTEN'));
        expect(text.style!.fontFamily, BkNumerals.family);
        expect(text.style!.color, cs.foreground);
      });

      testWidgets('a grouped card casts the brand-tinted shadow in light, none in dark', (tester) async {
        await _pump(tester, brightness, const BkGroupedSection(children: [BkGroupedRow(title: 'Overlay')]));
        final card = tester
            .widgetList<DecoratedBox>(
              find.descendant(of: find.byType(BkGroupedSection), matching: find.byType(DecoratedBox)),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.color == cs.card);
        expect(card.boxShadow ?? const <BoxShadow>[], b.cardShadow);
      });

      testWidgets('a quiet row (help, app housekeeping) keeps a grey tile', (tester) async {
        await _pump(
          tester,
          brightness,
          const BkGroupedSection(
            children: [BkGroupedRow(icon: LucideIcons.code, title: 'Protokolle', quietIcon: true)],
          ),
        );
        final icon = tester.widget<Icon>(find.descendant(of: find.byType(BkIconTile), matching: find.byType(Icon)));
        expect(icon.color, cs.mutedForeground);
      });

      testWidgets('icon tiles: the blue wash and a blue glyph; a status colour keeps a neutral tile', (tester) async {
        await _pump(
          tester,
          brightness,
          const Row(
            children: [
              BkIconTile(key: ValueKey('plain'), icon: LucideIcons.monitor),
              BkIconTile(key: ValueKey('status'), icon: LucideIcons.circle, color: Color(0xFFB91C1C)),
            ],
          ),
        );
        BoxDecoration fill(String key) =>
            tester
                    .widget<DecoratedBox>(
                      find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(DecoratedBox)),
                    )
                    .decoration
                as BoxDecoration;
        Icon icon(String key) =>
            tester.widget<Icon>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Icon)));
        expect(fill('plain').color, b.tileWash);
        expect(icon('plain').color, b.tileInk);
        expect(fill('status').color, cs.muted);
        expect(icon('status').color, const Color(0xFFB91C1C));
      });
    });
  }
}
