// The done step used to call a setup "ready to ride" with no controller at
// all — and its subtitle then claimed "Your controller is connected to
// {app}". BikeControl cannot shift without a controller, so the step now
// warns (it does not block): a "Not paired" row with a way back to the
// controller step, and a title that says what is missing.
//
// It also used to lead with the upsell. Starting to ride is the primary
// action now, the plan options secondary; and the trial card says what the
// rider would actually pay for given what they set up.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/steps/step_controller.dart';
import 'package:bike_control/pages/onboarding/steps/step_done.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Future<void> pump(WidgetTester tester, Widget Function(BuildContext) builder) async {
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: SingleChildScrollView(child: Builder(builder: builder))),
      ),
    );
    await tester.pump();
  }

  AppLocalizations l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Scaffold)));

  testWidgets('without a controller the step warns and offers the controller step again', (tester) async {
    var paired = 0;
    await pump(
      tester,
      (c) => onboardingDoneBody(
        c,
        app: MyWhoosh(),
        controllerName: null,
        trainerName: null,
        appConnected: true,
        trainerAppConnected: false,
        reduceMotion: true,
        showTestMode: false,
        onPairController: () => paired++,
      ),
    );
    final l = l10n(tester);

    expect(find.text(l.onboardingDoneTitle), findsNothing, reason: 'nothing can shift yet — not "ready to ride"');
    expect(find.text(l.onboardingDoneNoControllerTitle), findsOneWidget);
    expect(find.text(l.onboardingDoneSubtitle(l.onboardingYourController, 'MyWhoosh')), findsNothing);
    expect(find.text(l.onboardingSummaryNotPaired), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-done-pair-controller')));
    expect(paired, 1);
  });

  testWidgets('with a controller and the app connected it is ready, with no pair action', (tester) async {
    await pump(
      tester,
      (c) => onboardingDoneBody(
        c,
        app: MyWhoosh(),
        controllerName: 'Zwift Click',
        trainerName: null,
        appConnected: true,
        trainerAppConnected: false,
        reduceMotion: true,
        showTestMode: false,
        onPairController: () {},
      ),
    );
    final l = l10n(tester);
    expect(find.text(l.onboardingDoneTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-done-pair-controller')), findsNothing);
  });

  testWidgets('a bridged trainer offers the trainer check', (tester) async {
    var checked = 0;
    await pump(
      tester,
      (c) => onboardingDoneBody(
        c,
        app: MyWhoosh(),
        controllerName: 'Zwift Click',
        trainerName: 'KICKR CORE',
        appConnected: true,
        trainerAppConnected: true,
        reduceMotion: true,
        showTestMode: false,
        onRunTrainerCheck: () => checked++,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-done-trainer-check')));
    expect(checked, 1);
  });

  testWidgets('the trial card points at Pro when a trainer is bridged, Base or Pro otherwise', (tester) async {
    Widget body(BuildContext c, {String? trainer}) => onboardingDoneBody(
      c,
      app: MyWhoosh(),
      controllerName: 'Zwift Click',
      trainerName: trainer,
      appConnected: true,
      trainerAppConnected: true,
      reduceMotion: true,
      showTestMode: true,
    );

    await pump(tester, (c) => body(c, trainer: 'KICKR CORE'));
    var l = l10n(tester);
    expect(find.text(l.onboardingTrialKeepVs), findsOneWidget);
    expect(find.text(l.onboardingTrialUnlimited), findsNothing);

    await pump(tester, (c) => body(c));
    l = l10n(tester);
    expect(find.text(l.onboardingTrialUnlimited), findsOneWidget);
    expect(find.text(l.onboardingTrialKeepVs), findsNothing);
  });

  testWidgets('starting to ride is the primary action; the plan options come second', (tester) async {
    await pump(
      tester,
      (c) => Column(
        children: onboardingDoneFooter(
          c,
          allReady: true,
          showPlanOptions: true,
          onStartRiding: () {},
          onSeePlanOptions: () {},
        ),
      ),
    );
    final l = l10n(tester);
    final primary = find.ancestor(of: find.text(l.onboardingDoneStartRiding), matching: find.byType(PrimaryButton));
    expect(primary, findsOneWidget);
    final options = find.ancestor(of: find.text(l.onboardingSeeProOptions), matching: find.byType(PrimaryButton));
    expect(options, findsNothing);
    expect(find.text(l.onboardingSeeProOptions), findsOneWidget);
    // Primary first, in reading order.
    expect(
      tester.getTopLeft(find.text(l.onboardingDoneStartRiding)).dy,
      lessThan(tester.getTopLeft(find.text(l.onboardingSeeProOptions)).dy),
    );
  });

  testWidgets('skipping the controller step says what it costs', (tester) async {
    await pump(
      tester,
      (c) => onboardingControllerBody(c, phase: ControllerPhase.empty, devices: const [], appName: 'MyWhoosh'),
    );
    expect(find.text(l10n(tester).onboardingSkipControllerNote), findsOneWidget);
  });
}
