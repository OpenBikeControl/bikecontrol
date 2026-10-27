// Settings → Virtual shifting: the page the trainer's gear settings moved to
// when the Smart Trainer page became hardware only. Shifting config and mode
// on top, the live drivetrain directly above Gears (so every gear change stays
// in view while it animates), then Physics; the per-gear steppers one screen
// deeper.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/proxy_device_details/self_test_card.dart';
import 'package:bike_control/pages/proxy_device_details/self_test_page.dart';
import 'package:bike_control/pages/proxy_device_details/vs_calibration_page.dart';
import 'package:bike_control/pages/proxy_device_details/shifting_config_picker.dart';
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:bike_control/services/trainer_self_test/self_test_result.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/drivetrain/chain_geometry.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_view.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart' show loadAppFonts;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/live_trainer.dart';
import '../../helpers/text_breaks.dart';
import '../../widget_snapshot.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  bool reducedMotion = false,
  double height = 3200,
  double width = 430,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ShadcnApp(
      localizationsDelegates: [
        ...ShadcnLocalizations.localizationsDelegates,
        const OtherLocalizationsDelegate(),
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      theme: BkTheme.build(Brightness.dark),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
          child: home,
        ),
      ),
    ),
  );
  await tester.pump();
}

double _top(WidgetTester tester, Finder f) => tester.getTopLeft(f.first).dy;

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l;

  setUp(() {
    l = AppLocalizations.current;
    core.settings.setTrainerApp(MyWhoosh());
  });

  tearDown(() => core.connection.devices.clear());

  group('the Settings row', () {
    Widget settings() => const Scaffold(
      child: SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: 12), child: SettingsPage()),
    );

    testWidgets('is there only while a trainer is shifting', (tester) async {
      await _pump(tester, settings());
      expect(find.byKey(const ValueKey('settings-vs')), findsNothing);
    });

    testWidgets('is called Virtual shifting, sums the gears up and opens the page', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await _pump(tester, settings());

      final row = find.byKey(const ValueKey('settings-vs'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text(l.rideVirtualShifting)), findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('${l.gearsCount(definition.maxGear)} · ${l.smoothingOn}')),
        findsOneWidget,
      );
      expect(find.text(l.gearSettings), findsNothing);

      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VirtualShiftingSettingsPage), findsOneWidget);
    });
  });

  group('the page', () {
    testWidgets('config and mode first, the drivetrain directly above Gears, then Physics', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();

      final config = _top(tester, find.byType(ShiftingConfigPicker));
      final mode = _top(tester, find.byType(VirtualShiftingModeCard));
      final drivetrain = find.byKey(const ValueKey('vs-drivetrain'));
      final gearsHeader = find.text(l.vsGroupGears.toUpperCase());
      final curve = _top(tester, find.byType(GearRatioCurveView));
      final gearCount = _top(tester, find.text(l.gearCount));
      final frontShift = _top(tester, find.text(l.frontShiftEnableLabel));
      final smoothing = _top(tester, find.text(l.gradeSmoothing));
      final cadence = _top(tester, find.text(l.cadenceFilter));
      final perGear = _top(tester, find.text(l.perGearRatiosTitle));
      final physics = _top(tester, find.text(l.vsGroupPhysics.toUpperCase()));
      final bike = _top(tester, find.text(l.bikeWeight));

      expect(drivetrain, findsOneWidget);
      expect(find.descendant(of: drivetrain, matching: find.byType(DrivetrainControls)), findsOneWidget);
      expect(config, lessThan(mode));
      expect(mode, lessThan(_top(tester, drivetrain)));
      // Directly above: nothing but the group's own header between them.
      final gap = _top(tester, gearsHeader) - tester.getBottomLeft(drivetrain).dy;
      expect(gap, inInclusiveRange(0, 40));
      for (final (a, b) in [
        (_top(tester, gearsHeader), curve),
        (curve, gearCount),
        (gearCount, frontShift),
        (frontShift, smoothing),
        (smoothing, cadence),
        (cadence, perGear),
        (perGear, physics),
        (physics, bike),
      ]) {
        expect(a, lessThan(b));
      }
      // The steppers live one screen deeper.
      expect(find.text(l.gearNumber(1)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('−/+ shift the trainer and the ring toggle is labelled', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await core.shiftingConfigs.upsert(
        core.shiftingConfigs.activeFor(proxy.trainerKey).copyWith(frontShiftEnabled: true),
      );
      addTearDown(
        () => core.shiftingConfigs.upsert(
          core.shiftingConfigs.activeFor(proxy.trainerKey).copyWith(frontShiftEnabled: false),
        ),
      );
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();

      final before = definition.currentGear.value;
      await tester.tap(find.bySemanticsLabel(l.actionShiftUp).first);
      await tester.pump();
      expect(definition.currentGear.value, before + 1);

      final ring = find.bySemanticsLabel(RegExp(l.a11yChangeChainring));
      expect(ring, findsOneWidget);
      expect(tester.getSize(ring).height, greaterThanOrEqualTo(44));
      await tester.tap(ring);
      await tester.pump();
      expect(definition.frontRing.value, FrontRing.large);
    });

    Future<void> flipFrontDerailleur(WidgetTester tester) async {
      final row = find.ancestor(of: find.text(l.frontShiftEnableLabel), matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the front derailleur switch eases the chainring onto the new ring', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      addTearDown(
        () => core.shiftingConfigs.upsert(
          core.shiftingConfigs.activeFor(proxy.trainerKey).copyWith(frontShiftEnabled: false),
        ),
      );
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();
      final view = find.descendant(of: find.byKey(const ValueKey('vs-drivetrain')), matching: find.byType(DrivetrainView));
      final state = tester.state<DrivetrainViewState>(view);
      expect(state.debugFrontRadius, kSingleRingRadius);
      expect(state.debugIdleRingOpacity, 0);

      await flipFrontDerailleur(tester);
      expect(tester.widget<DrivetrainView>(view).frontShift, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      final target = definition.smallChainringTeeth * kRadiusPerTooth;
      expect(state.debugFrontRadius, isNot(target), reason: 'still on its way');
      expect(state.debugIdleRingOpacity, inExclusiveRange(0, 1), reason: 'the second ring fades in');

      // The drivetrain advances at most 50 ms per frame; let it run out.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state.debugFrontRadius, closeTo(target, 0.001));
      expect(state.debugIdleRingOpacity, 1);
      // The teeth steppers came with it.
      expect(find.text(l.frontShiftSmallRingLabel), findsOneWidget);
    });

    testWidgets('under reduced motion the chainring swaps at once', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      addTearDown(
        () => core.shiftingConfigs.upsert(
          core.shiftingConfigs.activeFor(proxy.trainerKey).copyWith(frontShiftEnabled: false),
        ),
      );
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy), reducedMotion: true);
      await tester.pump();
      final view = find.descendant(of: find.byKey(const ValueKey('vs-drivetrain')), matching: find.byType(DrivetrainView));
      final state = tester.state<DrivetrainViewState>(view);

      await flipFrontDerailleur(tester);
      expect(state.debugFrontRadius, closeTo(definition.smallChainringTeeth * kRadiusPerTooth, 0.001));
      expect(state.debugIdleRingOpacity, 1);
    });

    // The trainer app's gear count is not synced with BikeControl's, and the
    // overlay is what shows the rider the real gear — so a count that differs
    // from the app's is not a problem to warn about.
    testWidgets('a gear count that differs from the trainer app raises no warning', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      definition.setMaxGear(24);
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();
      expect(MyWhoosh().virtualGearAmount, isNot(definition.maxGear));
      final row = find.byType(GearCountRow);
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.byIcon(LucideIcons.triangleAlert)), findsNothing);
      expect(find.descendant(of: row, matching: find.byType(GhostButton)), findsNothing);
    });

    // Reset wipes the rider's own gears; it asks first, and Cancel keeps them.
    testWidgets('Reset asks first: Cancel keeps the gears, confirming resets them', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      definition.setMaxGear(24);
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('vs-reset')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(definition.maxGear, 24, reason: 'nothing changes before the rider confirms');
      expect(find.byKey(const ValueKey('vs-reset-confirm')), findsOneWidget);

      await tester.tap(find.text(l.cancel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('vs-reset-confirm')), findsNothing);
      expect(definition.maxGear, 24);

      await tester.tap(find.byKey(const ValueKey('vs-reset')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('vs-reset-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(definition.maxGear, MyWhoosh().virtualGearAmount);
    });

    // A calibrated difficulty is part of how the gears feel, so Reset takes it
    // back to 100 % with the rest.
    testWidgets('Reset also takes the calibrated difficulty back to the default', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await core.shiftingConfigs.upsert(
        core.shiftingConfigs.activeFor(proxy.trainerKey).copyWith(difficultyPct: 70, isActive: true),
      );
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();
      expect(definition.difficultyPct.value, 70);

      await tester.tap(find.byKey(const ValueKey('vs-reset')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('vs-reset-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(definition.difficultyPct.value, FitnessBikeDefinition.defaultDifficultyPct);
      expect(
        core.shiftingConfigs.activeFor(proxy.trainerKey).difficultyPct,
        FitnessBikeDefinition.defaultDifficultyPct,
      );
    });

    testWidgets('Per-gear ratios opens the steppers with the curve pinned above them', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy), height: 844);
      await tester.pump();

      final row = find.text(l.perGearRatiosTitle);
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(PerGearRatiosPage), findsOneWidget);
      expect(find.text(l.gearNumber(1)), findsOneWidget);
      final curve = find.descendant(of: find.byType(PerGearRatiosPage), matching: find.byType(GearRatioCurveView));
      final curveTop = _top(tester, curve);

      await tester.drag(find.text(l.gearNumber(2)), const Offset(0, -600));
      await tester.pump();
      expect(_top(tester, curve), curveTop, reason: 'pinned while the rows scroll');
      expect(find.text(l.gearNumber(1)), findsNothing);
    });
  });

  group('per-gear ratios on desktop', () {
    testWidgets('opens in a side panel beside the settings, closed with X', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy), width: 1280, height: 900);
      await tester.pump();

      final row = find.text(l.perGearRatiosTitle);
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final panel = find.byType(PerGearRatiosPage);
      expect(panel, findsOneWidget);
      expect(find.byType(VirtualShiftingSettingsPage), findsOneWidget, reason: 'the settings stay underneath');
      final rect = tester.getRect(panel);
      expect(rect.width, lessThanOrEqualTo(480), reason: 'a side panel, not the whole window');
      expect(rect.right, moreOrLessEquals(1280, epsilon: 1), reason: 'docked on the right');
      expect(find.descendant(of: panel, matching: find.byKey(const ValueKey('page-header-back'))), findsNothing);

      await tester.tap(find.byKey(const ValueKey('per-gear-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PerGearRatiosPage), findsNothing);
    });

    testWidgets('the row says what the panel holds, not the preset and gear count set elsewhere', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();

      final row = find.byKey(const ValueKey('vs-per-gear'));
      expect(
        find.descendant(of: row, matching: find.textContaining(l.gearsCount(definition.gearRatios.value.length))),
        findsNothing,
      );
    });
  });

  // Last: it loads the real fonts, which stay loaded for the rest of the file.
  group('the mode choice at phone width', () {
    setUpAll(loadAppFonts);

    for (final locale in const ['en', 'de', 'fr', 'es', 'it', 'pl']) {
      testWidgets('never breaks a label mid-word ($locale)', (tester) async {
        await AppLocalizations.load(Locale(locale));
        addTearDown(() => AppLocalizations.load(const Locale('en')));
        final (:proxy, :definition) = attachLiveTrainer();
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ShadcnApp(
            locale: Locale(locale),
            localizationsDelegates: [
              ...ShadcnLocalizations.localizationsDelegates,
              const OtherLocalizationsDelegate(),
              AppLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.delegate.supportedLocales,
            scaling: BkTheme.scalingFor(TargetPlatform.android),
            theme: BkTheme.build(Brightness.light),
            home: VirtualShiftingSettingsPage(definition: definition, device: proxy),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final card = find.byType(VirtualShiftingModeCard);
        await tester.ensureVisible(card);
        await tester.pump();
        final l = AppLocalizations.current;
        for (final label in [l.targetPowerMode, l.trackResistanceMode, l.basicMode, l.vsModeRecommended]) {
          final text = find.descendant(of: card, matching: find.text(label));
          expect(text, findsOneWidget, reason: label);
          expectBreaksOnlyBetweenWords(tester, text);
        }
      });
    }
  });

  // The resistance self-test and the calibrator live with the rest of the
  // shifting settings: checking that the trainer obeys and tuning how its
  // gears feel are both about shifting, not about the hardware link. Both are
  // rows of one group, each opening its own page.
  group('check and calibrate', () {
    final selfTest = find.byKey(const ValueKey('vs-self-test'));
    final calibrate = find.byKey(const ValueKey('vs-calibrate'));

    // The snapshot harness this file runs under turns screenshot mode on; the
    // section is (rightly) hidden there, so these tests ride with it off.
    late bool wasScreenshotMode;
    setUp(() {
      wasScreenshotMode = screenshotMode;
      screenshotMode = false;
    });
    tearDown(() => screenshotMode = wasScreenshotMode);

    String subtitleOf(WidgetTester tester, Finder row) => tester.widget<BkGroupedRow>(row).subtitle!;

    Future<void> open(WidgetTester tester, Finder row) async {
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('the self-test and the calibrator are two rows of one group below Physics', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();

      expect(selfTest, findsOneWidget);
      expect(calibrate, findsOneWidget);
      expect(find.byType(SelfTestCard), findsNothing, reason: 'the test runs on its own page now');
      Finder groupOf(Finder row) => find.ancestor(of: row, matching: find.byType(BkGroupedSection));
      expect(tester.widget(groupOf(selfTest).first), same(tester.widget(groupOf(calibrate).first)));
      final physics = find.byKey(const ValueKey('vs-physics'));
      expect(_top(tester, physics), lessThan(_top(tester, selfTest)));
      expect(_top(tester, selfTest), lessThan(_top(tester, calibrate)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the self-test row says what it does until there is a result, then the result', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer(id: 'row-subtitle-kickr');
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();
      expect(subtitleOf(tester, selfTest), l.selfTestStart);

      // A test finishes on the self-test page; back here the row shows it.
      await open(tester, selfTest);
      expect(find.byType(SelfTestPage), findsOneWidget);
      await core.settings.setSelfTestResultJson(proxy.trainerKey, _passResultJson);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        subtitleOf(tester, selfTest),
        l.selfTestLastResult(SelfTestCard.verdictTitle(l, SelfTestVerdict.pass)),
      );
    });

    testWidgets('the calibrator row opens the calibrator', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();

      await open(tester, calibrate);
      expect(find.byType(VsCalibrationPage), findsOneWidget);
    });

    testWidgets('a disconnected trainer still shows both, and nothing crashes', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      proxy
        ..isConnected = false
        ..debugSetTrainerAppConnected(false);
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();

      expect(selfTest, findsOneWidget);
      expect(calibrate, findsOneWidget);
      await open(tester, calibrate);
      await tester.tap(find.byKey(const ValueKey('vs-cal-start')));
      await tester.pump();
      expect(find.byKey(const ValueKey('vs-cal-refusal')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('store screenshots leave them out, like the trainer page did', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      screenshotMode = true;
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();

      expect(selfTest, findsNothing);
      expect(calibrate, findsNothing);
    });

    testWidgets('openTrainerSelfTest opens the self-test page directly', (tester) async {
      final (:proxy, definition: _) = attachLiveTrainer();
      await _pump(
        tester,
        Builder(
          builder: (context) => Button.primary(
            key: const ValueKey('go'),
            onPressed: () => openTrainerSelfTest(context, proxy),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('go')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.widget<SelfTestPage>(find.byType(SelfTestPage)).device, same(proxy));
      expect(find.byType(VirtualShiftingSettingsPage), findsNothing);
    });
  });

  // Where the real chain sits at the trainer: the physics need it, so a rider
  // whose chain is not on 34/17 (a 39 ring on a 14 Zwift Cog) gets gears that
  // feel like their real counterparts.
  group('the real chain', () {
    Finder inRow(String key, String stepper) =>
        find.descendant(of: find.byKey(ValueKey(key)), matching: find.byKey(ValueKey(stepper)));

    testWidgets('starts on 34/17 and a change goes to the trainer and the config', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();

      expect(find.byKey(const ValueKey('vs-real-chainring')), findsOneWidget);
      expect(find.byKey(const ValueKey('vs-real-cog')), findsOneWidget);
      expect(definition.realChainRatio, 2.0);

      await tester.ensureVisible(inRow('vs-real-chainring', 'stepper-plus'));
      await tester.tap(inRow('vs-real-chainring', 'stepper-plus'));
      await tester.pump();
      await tester.tap(inRow('vs-real-cog', 'stepper-minus'));
      await tester.pump();

      expect(definition.realChainRatio, closeTo(35 / 16, 1e-9));
      final cfg = core.shiftingConfigs.activeFor(proxy.trainerKey);
      expect(cfg.realChainringTeeth, 35);
      expect(cfg.realCogTeeth, 16);
      expect(find.textContaining('35/16\u00A0=\u00A02.19'), findsOneWidget);
    });

    testWidgets('Reset leaves it alone: it is the bike, not a preference', (tester) async {
      final (:proxy, :definition) = attachLiveTrainer();
      await core.shiftingConfigs.upsert(
        core.shiftingConfigs
            .activeFor(proxy.trainerKey)
            .copyWith(realChainringTeeth: 39, realCogTeeth: 14, isActive: true),
      );
      await _pump(tester, VirtualShiftingSettingsPage(definition: definition, device: proxy));
      await tester.pump();
      expect(definition.realChainRatio, closeTo(39 / 14, 1e-9));

      await tester.tap(find.byKey(const ValueKey('vs-reset')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('vs-reset-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(definition.realChainRatio, closeTo(39 / 14, 1e-9));
      expect(core.shiftingConfigs.activeFor(proxy.trainerKey).realCogTeeth, 14);
    });
  });
}

/// A stored passing result, as [SelfTestResult.toJsonString] writes it.
final _passResultJson = SelfTestResult(
  at: DateTime(2026, 10, 11),
  verdict: SelfTestVerdict.pass,
  ergStepsPassed: 3,
  ergStepsTotal: 3,
  shiftStepsPassed: 3,
  shiftStepsTotal: 3,
  vsMode: 'trackResistance',
  protocol: 'ftms',
).toJsonString();
