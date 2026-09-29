// The paywall's job is to get the rider into the right plan. Riders bought
// Base expecting BikeControl's virtual shifting because the table gave Base a
// "20 min/day" cell for it — a trial of a Pro feature, drawn as if Base had
// some of it. So:
// - the virtual-shifting row leads the table, Base gets a dash, and the daily
//   trial is a footnote under the table;
// - the purchase button says which plan it buys.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/paywall.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<AppLocalizations> pump(WidgetTester tester, {bool purchased = false}) async {
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
        home: const SingleChildScrollView(child: Paywall(defaultToFullVersion: false)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    return AppLocalizations.of(tester.element(find.byType(Paywall)));
  }

  Rect rowOf(WidgetTester tester, String label) => tester.getRect(find.text(label));

  bool dashInRow(WidgetTester tester, Rect row) => find
      .byWidgetPredicate((w) => w is Container && w.constraints?.maxHeight == 3)
      .evaluate()
      .map((e) => tester.getRect(find.byWidget(e.widget)))
      .any((r) => r.center.dy > row.top && r.center.dy < row.bottom && r.left > row.right);

  testWidgets('virtual shifting leads the table, Base gets a dash, the trial is a footnote', (tester) async {
    final l = await pump(tester);

    final vs = rowOf(tester, l.paywall_vsByBikeControl);
    final commands = rowOf(tester, l.paywall_amountOfActions);
    expect(vs.top, lessThan(commands.top), reason: 'the row that decides the plan comes first');
    expect(dashInRow(tester, vs), isTrue, reason: 'Base does not include virtual shifting');
    expect(find.text(l.paywall_twentyMinPerDay), findsNothing);

    final minutes = '${core.bridgeUsageTracker.dailyLimit.inMinutes}';
    expect(find.text(l.paywall_vsTrialFootnote(minutes)), findsOneWidget);
  });

  testWidgets('sensors are a Pro row; "support development" is not a feature', (tester) async {
    final l = await pump(tester);
    expect(find.text(l.paywall_shareSensors), findsOneWidget);
    expect(dashInRow(tester, rowOf(tester, l.paywall_shareSensors)), isTrue);
    expect(find.text(l.paywall_supportDevelopmentOfNewFeaturesDevicesAndMore), findsNothing);
  });

  testWidgets('the purchase button names the selected plan', (tester) async {
    final l = await pump(tester);

    // Preselection stays Pro yearly.
    expect(find.text(l.paywall_startProYearly), findsOneWidget);

    await tester.ensureVisible(find.text(l.paywall_monthly));
    await tester.tap(find.text(l.paywall_monthly));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l.paywall_startProMonthly), findsOneWidget);

    final base = find.textContaining(l.paywall_baseStoreNote('').split(' ').first);
    await tester.ensureVisible(base.first);
    await tester.tap(base.first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l.paywall_buyBase), findsOneWidget);
  });

  testWidgets('the paywall links to the plan questions', (tester) async {
    final l = await pump(tester);
    expect(find.text(l.paywall_planQuestions), findsOneWidget);
  });

  testWidgets('yearly and monthly titles are drawn at the same size', (tester) async {
    final l = await pump(tester);
    expect(
      rowOf(tester, l.paywall_monthly).height,
      closeTo(rowOf(tester, l.paywall_yearly).height, 0.5),
    );
  });
  testWidgets('a Base owner sees "Your plan" under the Base column', (tester) async {
    final l = await pump(tester, purchased: true);
    expect(IAPManager.instance.isProEnabled, isFalse);
    final mark = find.text(l.paywallYourPlan);
    expect(mark, findsOneWidget);
    final base = tester.getRect(find.text(l.full));
    final markRect = tester.getRect(mark);
    expect((markRect.center.dx - base.center.dx).abs(), lessThan(1), reason: 'centred under the Base header');
    expect(markRect.top, greaterThanOrEqualTo(base.bottom - 0.5));
  });

  testWidgets('without a purchase there is no "Your plan"', (tester) async {
    final l = await pump(tester);
    expect(find.text(l.paywallYourPlan), findsNothing);
  });
}
