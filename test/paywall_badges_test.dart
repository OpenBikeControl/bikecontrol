// The yearly plan card carries two badges: the discount on its top edge and
// PRO in its corner. The centred discount used to run into the corner badge
// and clip ("10% OF"; worse in German, French and Polish).
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' show ScreenshotTester;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  for (final locale in ['en', 'de', 'fr', 'pl']) {
    testWidgets('$locale: the discount and PRO badges do not collide, and the discount is not clipped', (tester) async {
      tester.view.physicalSize = const Size(390, 1400) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      IAPManager.instance.isPurchased.value = false;
      addTearDown(() => IAPManager.instance.isPurchased.value = true);
      await AppLocalizations.load(Locale(locale));
      addTearDown(() => AppLocalizations.load(const Locale('en')));

      await tester.pumpWidget(
        ShadcnApp(
          debugShowCheckedModeBanner: false,
          scaling: BkTheme.scaling,
          locale: Locale(locale),
          localizationsDelegates: [
            ...ShadcnLocalizations.localizationsDelegates,
            const OtherLocalizationsDelegate(),
            AppLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          theme: BkTheme.build(Brightness.light),
          home: const SingleChildScrollView(child: Paywall(defaultToFullVersion: false)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.loadAssets();
      await tester.binding.reassembleApplication();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      final l10n = AppLocalizations.current;
      final discount = find.text(l10n.paywall_discountOff('10'));
      expect(discount, findsOneWidget);
      final discountRect = tester.getRect(discount);

      for (final pro in find.byType(ProBadge).evaluate()) {
        final box = pro.renderObject! as RenderBox;
        final proRect = box.localToGlobal(Offset.zero) & box.size;
        expect(discountRect.overlaps(proRect), isFalse, reason: 'discount $discountRect vs PRO $proRect');
      }

      // Drawn in full: the paragraph got its natural width and isn't scaled.
      final paragraph = tester.renderObject<RenderParagraph>(discount);
      final natural = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout();
      expect(paragraph.size.width, greaterThanOrEqualTo(natural.width - 0.5), reason: 'clipped');
      expect(paragraph.didExceedMaxLines, isFalse);
      natural.dispose();
    });
  }
}
