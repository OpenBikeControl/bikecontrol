// Apple 3.1.2: a free trial on the yearly plan says how long it lasts and
// what is charged after it, on the plan and next to the button that buys it.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/iap/pro_trial.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  // Outside the Black Friday window unless a test opens it.
  setUp(() => StripeYearlyTrialPromo.now = () => DateTime.utc(2026, 12, 1));

  const badge = ValueKey('paywall-yearly-trial-badge');
  const terms = ValueKey('paywall-yearly-trial-terms');
  const twoMonths = ProTrial(ProTrialUnit.month, 2);

  Future<void> pump(WidgetTester tester, Widget paywall, {PurchaseChannel channel = PurchaseChannel.appStore}) async {
    IAPManager.instance.isPurchased.value = false;
    IAPManager.instance.purchaseChannelForTesting = channel;
    addTearDown(() {
      IAPManager.instance.isPurchased.value = true;
      IAPManager.instance.purchaseChannelForTesting = null;
    });
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: SingleChildScrollView(child: paywall),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  }

  testWidgets('yearly with a store trial shows its length, the price after it and a trial button', (tester) async {
    await pump(
      tester,
      Paywall(debugYearlyStorePrice: '22,99 €', debugYearlyTrial: twoMonths, debugNativeTrainer: () => null),
    );
    final l10n = AppLocalizations.current;
    expect(l10n.paywall_trialMonths(2), '2 months');

    expect(find.byKey(badge), findsOneWidget);
    expect(find.text('2 months free'), findsOneWidget);
    expect(find.text('Try Pro free for 2 months'), findsOneWidget);
    expect(find.text(l10n.paywall_startProYearly), findsNothing);
    expect(find.byKey(terms), findsOneWidget);
    expect(find.text(l10n.paywall_trialThenYearly('2 months', '22,99 €')), findsOneWidget);

    // The terms sit right under the button that starts the trial.
    final buttonBottom = tester.getBottomLeft(find.text('Try Pro free for 2 months')).dy;
    final termsTop = tester.getTopLeft(find.byKey(terms)).dy;
    expect(termsTop, greaterThan(buttonBottom));
    expect(termsTop - buttonBottom, lessThan(40));
  });

  testWidgets('monthly has no trial', (tester) async {
    await pump(
      tester,
      Paywall(debugYearlyStorePrice: '22,99 €', debugYearlyTrial: twoMonths, debugNativeTrainer: () => null),
    );
    await tester.tap(find.text(AppLocalizations.current.paywall_monthly));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(badge), findsNothing);
    expect(find.byKey(terms), findsNothing);
    expect(find.text(AppLocalizations.current.paywall_startProMonthly), findsOneWidget);
  });

  testWidgets('no trial on the product, no trial on the paywall', (tester) async {
    await pump(tester, Paywall(debugYearlyStorePrice: '22,99 €', debugNativeTrainer: () => null));
    expect(find.byKey(badge), findsNothing);
    expect(find.byKey(terms), findsNothing);
    expect(find.text(AppLocalizations.current.paywall_startProYearly), findsOneWidget);
  });

  testWidgets('any trial length: one week', (tester) async {
    await pump(
      tester,
      Paywall(
        debugYearlyStorePrice: '22,99 €',
        debugYearlyTrial: const ProTrial(ProTrialUnit.week, 1),
        debugNativeTrainer: () => null,
      ),
    );
    expect(find.text('1 week free'), findsOneWidget);
    expect(find.text('Try Pro free for 1 week'), findsOneWidget);
  });

  testWidgets('during Black Friday the store trial says it is the Black Friday offer', (tester) async {
    StripeYearlyTrialPromo.now = () => DateTime.utc(2026, 11, 27, 12);
    await pump(
      tester,
      Paywall(debugYearlyStorePrice: '22,99 €', debugYearlyTrial: twoMonths, debugNativeTrainer: () => null),
    );
    expect(find.text('BLACK FRIDAY · 2 months free'), findsOneWidget);
  });

  group('Stripe builds', () {
    testWidgets('show a month free on yearly inside the window', (tester) async {
      StripeYearlyTrialPromo.now = () => DateTime.utc(2026, 11, 27, 12);
      await pump(tester, Paywall(debugNativeTrainer: () => null), channel: PurchaseChannel.windowsDirect);
      expect(find.text('BLACK FRIDAY · 1 month free'), findsOneWidget);
      expect(find.text('Try Pro free for 1 month'), findsOneWidget);
      expect(find.text(AppLocalizations.current.paywall_trialThenBilledYearly('1 month')), findsOneWidget);
    });

    testWidgets('show no trial outside the window', (tester) async {
      StripeYearlyTrialPromo.now = () => DateTime.utc(2026, 11, 28, 12);
      await pump(tester, Paywall(debugNativeTrainer: () => null), channel: PurchaseChannel.linuxDirect);
      expect(find.byKey(badge), findsNothing);
      expect(find.byKey(terms), findsNothing);
      expect(find.text(AppLocalizations.current.paywall_startProYearly), findsOneWidget);
    });

    testWidgets('store builds never take the Stripe window', (tester) async {
      StripeYearlyTrialPromo.now = () => DateTime.utc(2026, 11, 27, 12);
      await pump(tester, Paywall(debugNativeTrainer: () => null), channel: PurchaseChannel.appStore);
      expect(find.byKey(badge), findsNothing);
    });
  });
}
