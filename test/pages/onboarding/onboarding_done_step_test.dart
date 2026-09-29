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
import 'package:bike_control/pages/onboarding/onboarding_app_guides.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/steps/step_controller.dart';
import 'package:bike_control/pages/onboarding/steps/step_done.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  // Fake clock: the waiting hint's 30 s must not be waited out for real.
  TestWidgetsFlutterBinding.ensureInitialized();
  // In setUpAll: under the fake-clock binding, Supabase's initialisation
  // inside Settings.init() needs a test zone.
  setUpAll(ensureSnapshotAppState);

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
    // The trainer row says where the trainer went, in plain words.
    expect(find.text(l10n(tester).onboardingSummaryTrainerInApp('MyWhoosh')), findsOneWidget);
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
          state: OnboardingDoneState.ready,
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

  // "Follow the steps from the previous page" sent the rider back to a page
  // they could no longer see. The waiting state shows the app's own guide,
  // and after a while on a network method, a way into the network test.
  Widget waiting(BuildContext c, {required bool networkMethod, VoidCallback? onTroubleshoot}) => onboardingDoneBody(
    c,
    app: MyWhoosh(),
    controllerName: 'Zwift Click',
    trainerName: null,
    appConnected: false,
    trainerAppConnected: false,
    reduceMotion: true,
    showTestMode: false,
    waitingOnNetworkMethod: networkMethod,
    onTestNetwork: onTroubleshoot ?? () {},
  );

  testWidgets('waiting for the app shows its setup guide', (tester) async {
    await pump(tester, (c) => waiting(c, networkMethod: false));
    expect(find.byType(OnboardingAppGuideCard), findsOneWidget);
  });

  testWidgets('after 30 s on a network method it offers the network test', (tester) async {
    var opened = 0;
    await pump(tester, (c) => waiting(c, networkMethod: true, onTroubleshoot: () => opened++));
    const key = ValueKey('onboarding-done-test-network');
    expect(find.byKey(key), findsNothing, reason: 'give the app a moment before suggesting something is wrong');

    await tester.pump(const Duration(seconds: 31));
    expect(find.byKey(key), findsOneWidget);
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.tap(find.byKey(key));
    expect(opened, 1);
  });

  testWidgets('no network test for a method that is not on the network', (tester) async {
    await pump(tester, (c) => waiting(c, networkMethod: false));
    await tester.pump(const Duration(seconds: 31));
    expect(find.byKey(const ValueKey('onboarding-done-test-network')), findsNothing);
  });

  testWidgets('leaving before 30 s leaves no timer behind', (tester) async {
    await pump(tester, (c) => waiting(c, networkMethod: true));
    await tester.pumpWidget(const SizedBox());
    // flutter_test fails the test if a Timer is still pending here.
  });

  group('done-step states', () {
    test('each combination maps to one state', () {
      OnboardingDoneState state({
        bool controller = true,
        bool app = true,
        bool trainer = false,
        bool pickedUp = false,
      }) => onboardingDoneState(
        hasController: controller,
        appConnected: app,
        hasTrainer: trainer,
        trainerAppConnected: pickedUp,
      );

      expect(state(), OnboardingDoneState.ready);
      expect(state(trainer: true, pickedUp: true), OnboardingDoneState.ready);
      expect(state(controller: false), OnboardingDoneState.noController);
      expect(state(controller: false, trainer: true, pickedUp: true), OnboardingDoneState.noController);
      expect(state(app: false), OnboardingDoneState.waitingForApp);
      expect(state(app: false, trainer: true), OnboardingDoneState.waitingForApp);
      expect(state(trainer: true), OnboardingDoneState.waitingForTrainerPickup);
      expect(state(controller: false, trainer: true), OnboardingDoneState.waitingForTrainerPickup);
    });

    Widget bridgeWaiting(BuildContext c, {VoidCallback? onCheck}) => onboardingDoneBody(
      c,
      app: MyWhoosh(),
      controllerName: 'Zwift Click',
      trainerName: 'KICKR CORE',
      appConnected: true,
      trainerAppConnected: false,
      reduceMotion: true,
      showTestMode: false,
      onRunTrainerCheck: onCheck ?? () {},
    );

    testWidgets('app connected but the trainer not picked up: says to pick it, and shows how', (tester) async {
      await pump(tester, (c) => bridgeWaiting(c));
      final l = l10n(tester);

      expect(find.text(l.onboardingDonePickTrainerTitle), findsOneWidget);
      expect(find.text(l.onboardingDonePickTrainerSubtitle('MyWhoosh')), findsOneWidget);
      expect(find.text(l.onboardingAlmostThereSubtitle('MyWhoosh')), findsNothing);
      expect(find.byType(OnboardingPairAsTrainerCard), findsOneWidget);
      expect(find.byType(OnboardingAppGuideCard), findsNothing, reason: 'the app is already connected');
    });

    testWidgets('no trainer check until the app has picked up the trainer', (tester) async {
      await pump(tester, (c) => bridgeWaiting(c));
      expect(find.byKey(const ValueKey('onboarding-done-trainer-check')), findsNothing);
    });

    testWidgets('waiting for the app keeps its own title, and no trainer check', (tester) async {
      await pump(
        tester,
        (c) => onboardingDoneBody(
          c,
          app: MyWhoosh(),
          controllerName: 'Zwift Click',
          trainerName: 'KICKR CORE',
          appConnected: false,
          trainerAppConnected: false,
          reduceMotion: true,
          showTestMode: false,
          onRunTrainerCheck: () {},
        ),
      );
      final l = l10n(tester);
      expect(find.text(l.onboardingAlmostThereTitle), findsOneWidget);
      expect(find.text(l.onboardingDonePickTrainerTitle), findsNothing);
      expect(find.byType(OnboardingAppGuideCard), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-done-trainer-check')), findsNothing);
    });

    Future<String> primaryLabel(WidgetTester tester, OnboardingDoneState state) async {
      await pump(
        tester,
        (c) => Column(
          children: onboardingDoneFooter(
            c,
            state: state,
            showPlanOptions: false,
            onStartRiding: () {},
            onSeePlanOptions: () {},
          ),
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(of: find.byType(PrimaryButton), matching: find.byType(Text)).first,
      );
      return text.data!;
    }

    testWidgets('only the controller missing: the button says pair later', (tester) async {
      final label = await primaryLabel(tester, OnboardingDoneState.noController);
      expect(label, l10n(tester).onboardingDonePairLater);
    });

    testWidgets('waiting on the app or the trainer: the button says connect later', (tester) async {
      expect(await primaryLabel(tester, OnboardingDoneState.waitingForApp), l10n(tester).onboardingDoneFinishLater);
      expect(
        await primaryLabel(tester, OnboardingDoneState.waitingForTrainerPickup),
        l10n(tester).onboardingDoneFinishLater,
      );
    });
  });

  group('gear overlay offer', () {
    bool offers({
      SupportedApp? app,
      bool pickedUp = true,
      bool platform = true,
      bool enabled = false,
      bool declined = false,
    }) => onboardingDoneOffersOverlay(
      app: app ?? MyWhoosh(),
      trainerBridged: true,
      trainerAppConnected: pickedUp,
      overlayOffered: platform,
      overlayEnabled: enabled,
      overlayDeclined: declined,
    );

    test('offered for an app that shows its own gear, once the trainer is picked up', () {
      expect(offers(), isTrue);
      expect(offers(pickedUp: false), isFalse);
    });

    test('not offered where the overlay cannot be shown, or once answered', () {
      expect(offers(platform: false), isFalse, reason: 'other device, unsupported platform or no VS session');
      expect(offers(enabled: true), isFalse);
      expect(offers(declined: true), isFalse);
    });

    test('not offered for an app without its own gear display', () {
      expect(offers(app: CustomApp()), isFalse);
    });

    test('not offered without a bridged trainer', () {
      expect(
        onboardingDoneOffersOverlay(
          app: MyWhoosh(),
          trainerBridged: false,
          trainerAppConnected: false,
          overlayOffered: true,
          overlayEnabled: false,
          overlayDeclined: false,
        ),
        isFalse,
      );
    });

    testWidgets('the offer explains the gear display and shows the overlay in one tap', (tester) async {
      var shown = 0;
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
          offerOverlay: true,
          onShowOverlay: () => shown++,
        ),
      );
      final l = l10n(tester);
      expect(find.text(l.onboardingDoneOverlayNote('MyWhoosh')), findsOneWidget);
      const key = ValueKey('onboarding-done-show-overlay');
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      expect(shown, 1);
    });

    testWidgets('no offer card unless asked for', (tester) async {
      await pump(tester, (c) => bridgeWaitingReady(c));
      expect(find.byKey(const ValueKey('onboarding-done-show-overlay')), findsNothing);
    });
  });
}

Widget bridgeWaitingReady(BuildContext c) => onboardingDoneBody(
  c,
  app: MyWhoosh(),
  controllerName: 'Zwift Click',
  trainerName: 'KICKR CORE',
  appConnected: true,
  trainerAppConnected: true,
  reduceMotion: true,
  showTestMode: false,
);

