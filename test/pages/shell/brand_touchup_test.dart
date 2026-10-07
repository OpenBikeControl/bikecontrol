// The brand line in the shell: the handlebar mark beside "BikeControl" in the
// phone's large title and the sidebar's wordmark; the blue→teal band on
// Ride's virtual shifting header and on both plan cards, with legible white
// text and SIM / ERG still switching the trainer; the selected tab's pill.
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/plan/vs_trial_meter.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_brand_band.dart';
import 'package:bike_control/widgets/ui/bk_brand_mark.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/contrast.dart';
import '../../helpers/live_trainer.dart';
import '../../helpers/shell_harness.dart';
import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();
  quietShellEnvironment();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );

  tearDown(() {
    IAPManager.instance.setProForTesting(enabled: false);
    screenshotMode = true;
  });

  for (final brightness in Brightness.values) {
    final cs = BkTheme.build(brightness).colorScheme;

    group(brightness.name, () {
      testWidgets('phone: the mark stands beside "BikeControl" on Ride only', (tester) async {
        await pumpShell(tester, const Size(390, 844), brightness: brightness);
        final topBar = find.byType(ShellTopBar);
        expect(find.descendant(of: topBar, matching: find.byType(BkBrandMark)), findsOneWidget);
        final mark = tester.getRect(find.descendant(of: topBar, matching: find.byType(BkBrandMark)));
        final title = tester.getRect(find.descendant(of: topBar, matching: find.text('BikeControl')));
        expect(mark.right, lessThanOrEqualTo(title.left), reason: 'the mark leads the wordmark');
        expect(mark.center.dy, closeTo(title.center.dy, 3), reason: 'on the title\'s line');

        final shell = tester.widget<ShellTabBar>(find.byType(ShellTabBar)).controller;
        shell.select(AppSection.devices);
        await tester.pump();
        expect(find.descendant(of: topBar, matching: find.byType(BkBrandMark)), findsNothing);
        await disposeShell(tester);
      });

      testWidgets('phone: the selected tab wears the accent pill behind its icon', (tester) async {
        await pumpShell(tester, const Size(390, 844), brightness: brightness);
        final pills = find.descendant(
          of: find.byType(ShellTabBar),
          matching: find.byKey(const ValueKey('shell-tab-pill')),
        );
        expect(pills, findsOneWidget, reason: 'only the selected tab');
        final pill = tester.widget<DecoratedBox>(pills);
        expect((pill.decoration as BoxDecoration).color, BkBrandColors.forBrightness(brightness).navPill);
        await disposeShell(tester);
      });

      testWidgets('desktop: the sidebar wordmark carries the mark; its plan card wears the band', (tester) async {
        screenshotMode = false;
        // On the trial the card also carries today's virtual shifting meter.
        IAPManager.instance.isPurchased.value = false;
        addTearDown(() => IAPManager.instance.isPurchased.value = true);
        await pumpShell(tester, const Size(1280, 800), brightness: brightness);
        final sidebar = find.byType(ShellSidebar);
        expect(find.descendant(of: sidebar, matching: find.byType(BkBrandMark)), findsOneWidget);
        final card = find.byKey(const ValueKey('plan-card'));
        expect(find.descendant(of: card, matching: find.byType(BkBrandBand)), findsOneWidget);
        expect(find.descendant(of: card, matching: find.byType(VsTrialMeter)), findsOneWidget);
        expectLegibleText(tester, card, pageBackground: cs.background);
        await disposeShell(tester);
      });

      testWidgets('Settings: the plan card wears the band with a white Go Pro', (tester) async {
        screenshotMode = false;
        await pumpShell(tester, const Size(390, 844), brightness: brightness);
        tester.widget<ShellTabBar>(find.byType(ShellTabBar)).controller.select(AppSection.settings);
        await tester.pump();
        final card = find.byType(SettingsPlanCard);
        expect(find.descendant(of: card, matching: find.byType(BkBrandBand)), findsOneWidget);
        expectLegibleText(tester, card, pageBackground: cs.background);
        await disposeShell(tester);
      });

      testWidgets('Ride: the shifting header is the band; SIM / ERG still switch the trainer', (tester) async {
        final definition = attachLiveTrainer().definition;
        core.connection.hasDevices.value = true;
        await pumpShell(tester, const Size(390, 844), brightness: brightness);
        await tester.pump(const Duration(seconds: 1));

        final band = find.descendant(
          of: find.byKey(const ValueKey('ride-vs-live')),
          matching: find.byType(BkBrandBand),
        );
        expect(band, findsOneWidget);
        for (final key in ['ride-vs-settings-link', 'ride-vs-trainer-link', 'ride-vs-mode-sim', 'ride-vs-mode-erg']) {
          expect(
            find.descendant(of: band, matching: find.byKey(ValueKey(key))),
            findsOneWidget,
            reason: key,
          );
        }
        expectLegibleText(tester, band, pageBackground: cs.background);
        // The gear and − / + stay on the card, not the band.
        expect(find.descendant(of: band, matching: find.byKey(const ValueKey('ride-vs-number'))), findsNothing);

        expect(definition.trainerMode.value, isNot(TrainerMode.ergMode));
        await tester.tap(find.byKey(const ValueKey('ride-vs-mode-erg')));
        await tester.pump();
        expect(definition.trainerMode.value, TrainerMode.ergMode);
        await tester.tap(find.byKey(const ValueKey('ride-vs-mode-sim')));
        await tester.pump();
        expect(definition.trainerMode.value, isNot(TrainerMode.ergMode));
        await disposeShell(tester);
      });
    });
  }
}
