// The yearly card's "billed at" line carries the amount actually charged. In
// the half-width card a long store price string used to be cut off with an
// ellipsis; it wraps instead and is always shown in full.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  const cases = <(String, List<String>)>[
    ('de', ['22,99 €', 'US\$24.99', '1.234,99 €']),
    ('fr', ['22,99 €', 'US\$24.99']),
    ('pl', ['zł 99,99', '99,99 zł']),
  ];

  for (final (lang, prices) in cases) {
    for (final scale in [1.0, 1.3]) {
      for (final price in prices) {
        testWidgets('$lang, text x$scale: "$price" is billed in full', (tester) async {
          IAPManager.instance.isPurchased.value = false;
          addTearDown(() => IAPManager.instance.isPurchased.value = true);
          tester.view.physicalSize = const Size(390, 844) * 3.0;
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final locale = Locale(lang);
          final l = await AppLocalizations.load(locale);
          addTearDown(() => AppLocalizations.load(const Locale('en')));
          await tester.pumpWidget(
            ShadcnApp(
              debugShowCheckedModeBanner: false,
              locale: locale,
              localizationsDelegates: [
                ...ShadcnLocalizations.localizationsDelegates,
                const OtherLocalizationsDelegate(),
                AppLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              home: SingleChildScrollView(
                child: Paywall(debugYearlyStorePrice: price),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          final billed = find.text(l.paywall_billedAtYearly(price));
          expect(billed, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(billed);
          expect(paragraph.didExceedMaxLines, isFalse, reason: 'the billed amount must not be cut off');
          expect(paragraph.text.toPlainText(), contains(price));
        });
      }
    }
  }
}
