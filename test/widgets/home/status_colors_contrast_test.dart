// Status text uses the contrast-pinned BkStatusColors; the bright Ampel hues
// stay on dots, fills and indicators. Glyphs drawn on a status fill clear the
// 3:1 non-text minimum.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/pages/onboarding/steps/step_done.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/ready_banner.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureSnapshotAppState);

  Future<ThemeData> pump(WidgetTester tester, Brightness brightness, Widget child) async {
    final theme = BkTheme.build(brightness);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pump();
    return theme;
  }

  Color textColor(WidgetTester tester, Finder text) {
    final widget = tester.widget<Text>(text);
    final explicit = widget.style?.color;
    if (explicit != null) return explicit;
    return DefaultTextStyle.of(tester.element(text)).style.color!;
  }

  Color fillBehind(WidgetTester tester, Finder icon) {
    final box = tester
        .widgetList(find.ancestor(of: icon, matching: find.byWidgetPredicate((w) => w is Container || w is AnimatedContainer)))
        .map((w) => w is Container ? w.decoration : (w as AnimatedContainer).decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color != null);
    return box.color!;
  }

  for (final brightness in Brightness.values) {
    group(brightness.name, () {
      for (final status in [LinkStatus.attention, LinkStatus.problem]) {
        testWidgets('${status.name} status line text clears 4.5:1 on the card', (tester) async {
          final theme = await pump(tester, brightness, StatusLine(status: status, label: 'Status'));
          expect(contrast(textColor(tester, find.text('Status')), theme.colorScheme.card), greaterThanOrEqualTo(4.5));
        });
      }

      testWidgets('status text colours clear 4.5:1 on the card and the wash', (tester) async {
        final theme = await pump(tester, brightness, const SizedBox.shrink(key: Key('x')));
        final ctx = tester.element(find.byKey(const Key('x')));
        for (final status in [LinkStatus.ready, LinkStatus.attention, LinkStatus.problem]) {
          final style = AmpelStyle.of(ctx, status);
          expect(contrast(style.text, theme.colorScheme.card), greaterThanOrEqualTo(4.5), reason: status.name);
          final wash = Color.alphaBlend(style.wash, theme.colorScheme.card);
          expect(contrast(style.text, wash), greaterThanOrEqualTo(4.5), reason: '${status.name} on its wash');
        }
      });

      testWidgets('the banner title and its glyph are legible', (tester) async {
        final theme = await pump(
          tester,
          brightness,
          ReadyBanner(
            banner: const ChainBanner(
              kind: ChainBannerKind.broken,
              status: LinkStatus.problem,
              stepsLeft: 1,
              targetLinkId: 'controller',
              targetKey: ChainLinkKey.controller,
              outstandingKeys: [ChainLinkKey.controller],
            ),
            brokenLinkName: 'Zwift Click',
            appName: 'MyWhoosh',
          ),
        );
        final l = AppLocalizations.of(tester.element(find.byType(ReadyBanner)));
        final title = find.text(l.chainBrokenTitle('Zwift Click'));
        expect(contrast(textColor(tester, title), theme.colorScheme.card), greaterThanOrEqualTo(4.5));

        final glyph = find.descendant(of: find.byType(ReadyBanner), matching: find.byType(Icon)).first;
        final icon = tester.widget<Icon>(glyph);
        expect(contrast(icon.color!, fillBehind(tester, glyph)), greaterThanOrEqualTo(3));
      });

      for (final ready in [true, false]) {
        testWidgets('done-step badge glyph clears 3:1 (${ready ? 'ready' : 'waiting'})', (tester) async {
          await pump(
            tester,
            brightness,
            Builder(
              builder: (c) => onboardingDoneBody(
                c,
                app: MyWhoosh(),
                controllerName: 'Zwift Click',
                trainerName: null,
                appConnected: ready,
                trainerAppConnected: false,
                reduceMotion: true,
                showTestMode: false,
              ),
            ),
          );
          final glyph = find.byWidgetPredicate((w) => w is Icon && w.size == 44);
          expect(glyph, findsOneWidget);
          final icon = tester.widget<Icon>(glyph);
          expect(contrast(icon.color!, fillBehind(tester, glyph)), greaterThanOrEqualTo(3));
        });
      }
    });
  }
}
