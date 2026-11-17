// "Don't like subscriptions? Get Pro forever": a quiet link under the Pro
// button that buys Pro once. Shown once the store carries the product, never
// to riders who already have Pro.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  final link = find.byKey(const ValueKey('paywall-pro-lifetime'));

  Future<void> pump(WidgetTester tester, {String? lifetimePrice, void Function(String plan)? onPurchase}) async {
    tester.view.physicalSize = const Size(390, 1800) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    IAPManager.instance.isPurchased.value = false;
    addTearDown(() => IAPManager.instance.isPurchased.value = true);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        scaling: BkTheme.scaling,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: BkTheme.build(Brightness.light),
        home: SingleChildScrollView(
          child: Paywall(
            debugLifetimePrice: lifetimePrice,
            debugOnPurchase: onPurchase,
            debugNativeTrainer: () => null,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }

  testWidgets('the link sits in the Pro card, below its button, with the store price', (tester) async {
    await pump(tester, lifetimePrice: '49,99 €');
    final proCard = find.byKey(const ValueKey('paywall-pro-card'));
    expect(find.descendant(of: proCard, matching: link), findsOneWidget);
    expect(find.textContaining('49,99 €', findRichText: true), findsOneWidget);
  });

  testWidgets('no store product, no link', (tester) async {
    await pump(tester);
    expect(link, findsNothing);
  });

  testWidgets('riders who already have Pro are not offered it', (tester) async {
    IAPManager.instance.setProForTesting(enabled: true);
    addTearDown(() => IAPManager.instance.setProForTesting(enabled: false));
    await pump(tester, lifetimePrice: '49,99 €');
    expect(link, findsNothing);
  });

  testWidgets('tapping it buys Pro once', (tester) async {
    final plans = <String>[];
    await pump(tester, lifetimePrice: '49,99 €', onPurchase: plans.add);
    await tester.tap(link);
    await tester.pump();
    expect(plans, ['lifetime']);
  });
}
