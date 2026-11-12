// The paywall's job is to get the rider into the right plan. Riders bought
// Base expecting BikeControl's virtual shifting because the table gave Base a
// "20 min/day" cell for it — a trial of a Pro feature, drawn as if Base had
// some of it. So:
// - virtual shifting leads the Pro card, the Base card doesn't list it, and
//   a footnote under both plans says the trainer app shifts without Pro;
// - each purchase button says which plan it buys.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/widgets/plan/vs_without_pro_note.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    bool purchased = false,
    bool showAllPlans = false,
    String? nativeTrainer,
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
        home: SingleChildScrollView(
          child: Paywall(
            debugOnPurchase: onPurchase,
            debugNativeTrainer: () => nativeTrainer,
            debugShowAllPlans: showAllPlans,
          ),
        ),
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

  /// Selects [app] as the trainer app, with real app names (the snapshot
  /// harness keeps them generic, as for store screenshots).
  void useApp(SupportedApp? app) {
    final was = screenshotMode;
    screenshotMode = false;
    if (app != null) core.settings.setTrainerApp(app);
    addTearDown(() {
      screenshotMode = was;
      core.settings.prefs.remove('trainer_app');
    });
  }

  testWidgets('Base is one line: unlimited presses, and the trainer app does the shifting', (tester) async {
    useApp(MyWhoosh());
    final l = await pump(tester);
    expect(inCard(baseCard, l.paywallBaseTitleNamed('MyWhoosh')), findsOneWidget);
    expect(inCard(baseCard, l.paywallBaseShiftNamed('MyWhoosh')), findsOneWidget);
    // No separate footnote under both cards any more: Base says it itself.
    expect(find.byType(VsWithoutProNote), findsNothing);
  });

  testWidgets('without a trainer app, Base says "your trainer app"', (tester) async {
    useApp(null);
    final l = await pump(tester);
    expect(inCard(baseCard, l.paywallBaseTitle), findsOneWidget);
    expect(inCard(baseCard, l.paywallBaseShift), findsOneWidget);
  });

  group('native and instant, only where it is true', () {
    testWidgets('a trainer that shifts natively, with an app that does not: native and instant', (tester) async {
      useApp(MyWhoosh());
      final l = await pump(tester, nativeTrainer: 'Zwift Hub One');
      expect(inCard(proCard, l.paywallFeelShiftNative('Zwift Hub One')), findsOneWidget);
      expect(inCard(proCard, l.paywallFeelShift), findsNothing);
    });

    // Zwift and Rouvy shift a Zwift Ready trainer natively themselves: there
    // BikeControl's shifting is neither faster nor more native, and Base's
    // line doesn't say the app might feel less snappy.
    for (final (name, app) in [('Zwift', Zwift()), ('Rouvy', Rouvy())]) {
      testWidgets('$name on a trainer that shifts natively: no native, instant or snappy claim', (tester) async {
        useApp(app);
        final l = await pump(tester, nativeTrainer: 'Zwift Hub One');
        expect(inCard(proCard, l.paywallFeelShift), findsOneWidget);
        expect(inCard(proCard, l.paywallFeelShiftNative('Zwift Hub One')), findsNothing);
        expect(inCard(baseCard, l.paywallBaseShiftNamedNative(name)), findsOneWidget);
        expect(inCard(baseCard, l.paywallBaseShiftNamed(name)), findsNothing);
      });
    }

    testWidgets('a trainer that does not shift natively: no native or instant claim', (tester) async {
      useApp(MyWhoosh());
      final l = await pump(tester);
      expect(inCard(proCard, l.paywallFeelShift), findsOneWidget);
      expect(find.textContaining('Native'), findsNothing);
    });

    test('native means commanded over the Zwift interface, with no gear commands ignored', () {
      expect(paywallShiftsNatively(TrainerControlProtocol.zwiftHub, null), isTrue);
      expect(paywallShiftsNatively(TrainerControlProtocol.zwiftHub, ZwiftGearEchoVerdict.fellBackToFtms), isTrue);
      expect(paywallShiftsNatively(TrainerControlProtocol.ftms, null), isFalse);
      expect(paywallShiftsNatively(TrainerControlProtocol.fec, null), isFalse);
      expect(paywallShiftsNatively(TrainerControlProtocol.zwiftHub, ZwiftGearEchoVerdict.riderOverrideKept), isFalse);
      expect(paywallShiftsNatively(TrainerControlProtocol.zwiftHub, ZwiftGearEchoVerdict.noFtmsToFallBackTo), isFalse);
    });

    test('Zwift and Rouvy are the apps that shift natively themselves', () {
      final SupportedApp? none = null;
      expect(paywallAppShiftsNatively(Zwift()), isTrue);
      expect(paywallAppShiftsNatively(Rouvy()), isTrue);
      expect(paywallAppShiftsNatively(MyWhoosh()), isFalse);
      expect(paywallAppShiftsNatively(none), isFalse);
    });
  });

  testWidgets('the Pro card is titled PRO once, without a PRO badge beside it', (tester) async {
    await pump(tester);
    expect(inCard(proCard, 'PRO'), findsOneWidget);
    expect(find.descendant(of: proCard, matching: find.byType(ProBadge)), findsNothing);
  });

  testWidgets('"support development" is not a feature', (tester) async {
    final l = await pump(tester);
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

  testWidgets('the debug menu\'s paywall shows Base for sale even to a Base owner', (tester) async {
    final l = await pump(tester, purchased: true, showAllPlans: true);
    expect(inCard(baseCard, l.paywallYourPlan), findsNothing);
    expect(find.text(l.paywall_buyBase), findsOneWidget);
  });

  testWidgets('without a purchase the Base card is not marked "Your plan"', (tester) async {
    final l = await pump(tester);
    expect(inCard(baseCard, l.paywallYourPlan), findsNothing);
  });
}
