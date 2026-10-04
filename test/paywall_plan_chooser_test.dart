// The paywall's job is to get the rider into the right plan. Riders bought
// Base expecting BikeControl's virtual shifting because the table gave Base a
// "20 min/day" cell for it — a trial of a Pro feature, drawn as if Base had
// some of it. So:
// - virtual shifting leads the Pro card, the Base card doesn't list it, and
//   a footnote under both plans says the trainer app shifts without Pro;
// - each purchase button says which plan it buys.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/plan/vs_without_pro_note.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    bool purchased = false,
    void Function(String plan)? onPurchase,
  }) async {
    tester.view.physicalSize = const Size(390, 1800) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    IAPManager.instance.isPurchased.value = purchased;
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
        home: SingleChildScrollView(child: Paywall(debugOnPurchase: onPurchase)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    return AppLocalizations.of(tester.element(find.byType(Paywall)));
  }

  final proCard = find.byKey(const ValueKey('paywall-pro-card'));
  final baseCard = find.byKey(const ValueKey('paywall-base-card'));
  Finder inCard(Finder card, String text) => find.descendant(of: card, matching: find.text(text));

  testWidgets('both plans are shown, Pro first, each with its kind of purchase', (tester) async {
    final l = await pump(tester);
    expect(proCard, findsOneWidget);
    expect(baseCard, findsOneWidget);
    expect(tester.getRect(proCard).top, lessThan(tester.getRect(baseCard).top));
    expect(inCard(proCard, l.subscription), findsOneWidget);
    expect(inCard(baseCard, l.paywall_oneTimePurchase), findsOneWidget);
  });

  testWidgets('virtual shifting leads the Pro card, Base does not list it, the trial is a footnote', (tester) async {
    final l = await pump(tester);

    final vs = tester.getRect(inCard(proCard, l.paywall_vsByBikeControl));
    final commands = tester.getRect(inCard(proCard, l.paywall_amountOfActions));
    expect(vs.top, lessThan(commands.top), reason: 'the line that decides the plan comes first');
    expect(inCard(baseCard, l.paywall_vsByBikeControl), findsNothing, reason: 'Base does not include virtual shifting');

    // Unlimited button commands and shifting in the trainer app are in both.
    for (final card in [proCard, baseCard]) {
      expect(inCard(card, l.paywall_amountOfActions), findsOneWidget);
      expect(inCard(card, l.unlimited), findsOneWidget);
      expect(inCard(card, l.paywall_shiftInYourApp), findsOneWidget);
    }

    // Under both plans: without Pro the trainer app does the shifting, and
    // what Pro adds, with the post comparing the two.
    final footnote = find.byType(VsWithoutProNote);
    expect(footnote, findsOneWidget);
    expect(find.descendant(of: footnote, matching: find.text(l.vsWithoutProNoteYourApp)), findsOneWidget);
    expect(find.descendant(of: footnote, matching: find.text(l.vsWithoutProLearnMore)), findsOneWidget);
    expect(tester.getRect(footnote).top, greaterThan(tester.getRect(baseCard).bottom), reason: 'under both plans');
  });

  testWidgets('the Pro card is titled PRO once, without a PRO badge beside it', (tester) async {
    await pump(tester);
    expect(inCard(proCard, 'PRO'), findsOneWidget);
    expect(find.descendant(of: proCard, matching: find.byType(ProBadge)), findsNothing);
  });

  testWidgets('sensors are a Pro line; "support development" is not a feature', (tester) async {
    final l = await pump(tester);
    expect(inCard(proCard, l.paywall_shareSensors), findsOneWidget);
    expect(inCard(baseCard, l.paywall_shareSensors), findsNothing);
    expect(find.text(l.paywall_supportDevelopmentOfNewFeaturesDevicesAndMore), findsNothing);
  });

  testWidgets('the Pro button names the billing it buys; each button buys its own plan', (tester) async {
    final bought = <String>[];
    final l = await pump(tester, onPurchase: bought.add);

    // Preselection stays Pro yearly.
    expect(find.text(l.paywall_startProYearly), findsOneWidget);
    await tester.tap(find.text(l.paywall_startProYearly));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text(l.paywall_monthly));
    await tester.tap(find.text(l.paywall_monthly));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l.paywall_startProMonthly), findsOneWidget);
    await tester.tap(find.text(l.paywall_startProMonthly));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text(l.paywall_buyBase));
    await tester.tap(find.text(l.paywall_buyBase));
    await tester.pump(const Duration(milliseconds: 300));
    expect(bought, ['yearly', 'monthly', 'base']);
    // Buying Base doesn't change which Pro billing is picked.
    expect(find.text(l.paywall_startProMonthly), findsOneWidget);
  });

  testWidgets('the paywall links to the plan questions', (tester) async {
    final l = await pump(tester);
    expect(find.text(l.paywall_planQuestions), findsOneWidget);
  });

  testWidgets('yearly and monthly are drawn at the same size', (tester) async {
    final l = await pump(tester);
    expect(
      tester.getRect(find.text(l.paywall_monthly)).height,
      closeTo(tester.getRect(find.text(l.paywall_yearly)).height, 0.5),
    );
  });

  testWidgets('a Base owner sees "Your plan" on the Base card instead of a Buy button', (tester) async {
    final l = await pump(tester, purchased: true);
    expect(IAPManager.instance.isProEnabled, isFalse);
    expect(inCard(baseCard, l.paywallYourPlan), findsOneWidget);
    expect(find.text(l.paywall_buyBase), findsNothing);
  });

  testWidgets('without a purchase the Base card is not marked "Your plan"', (tester) async {
    final l = await pump(tester);
    expect(inCard(baseCard, l.paywallYourPlan), findsNothing);
  });
}
