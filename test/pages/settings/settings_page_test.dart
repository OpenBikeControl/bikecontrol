// The Settings tab: the plan card on top (with today's virtual shifting trial
// while Pro is off on this device), Riding with, During the ride, Help &
// support and App — each row only where it applies.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, screenshotMode;
import 'package:bike_control/pages/settings/settings_page.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_snapshot.dart';

Future<void> _pumpSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 2400);
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
      home: const Scaffold(
        child: SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: 12), child: SettingsPage()),
      ),
    ),
  );
  await tester.pump();
}

Finder _inSection(String key, Finder finder) => find.descendant(of: find.byKey(ValueKey(key)), matching: finder);

Future<void> main() async {
  await ensureSnapshotHarness();
  late AppLocalizations l;

  setUp(() {
    l = AppLocalizations.current;
    core.settings.setTrainerApp(MyWhoosh());
  });

  tearDown(() {
    core.connection.devices.clear();
    IAPManager.instance.setProForTesting(enabled: false);
    debugHostPlatformOverride = null;
  });

  group('plan card', () {
    testWidgets('without Pro: Go Pro and what is left of today\'s virtual shifting', (tester) async {
      IAPManager.instance.setProForTesting(enabled: false);
      // Store renders leave the daily limit out; this is the real app.
      screenshotMode = false;
      addTearDown(() => screenshotMode = true);
      await _pumpSettings(tester);

      final plan = find.byKey(const ValueKey('settings-plan'));
      expect(find.descendant(of: plan, matching: find.text(l.currentPlan)), findsOneWidget);
      expect(find.descendant(of: plan, matching: find.text(l.goPro)), findsOneWidget);
      expect(find.descendant(of: plan, matching: find.text(l.chainTrialBridgeMeter)), findsOneWidget);
      final minutes = core.bridgeUsageTracker.remainingToday.inMinutes;
      expect(find.descendant(of: plan, matching: find.text(l.bridgeMinutesRemainingToday(minutes))), findsOneWidget);
    });

    testWidgets('with Pro on this device: no meter and no Go Pro', (tester) async {
      IAPManager.instance.setProForTesting(enabled: true, registeredDevice: true);
      await _pumpSettings(tester);

      final plan = find.byKey(const ValueKey('settings-plan'));
      expect(find.descendant(of: plan, matching: find.text(l.goPro)), findsNothing);
      expect(find.descendant(of: plan, matching: find.text(l.chainTrialBridgeMeter)), findsNothing);
      expect(find.descendant(of: plan, matching: find.text(l.manageAction)), findsOneWidget);
    });
  });

  group('riding with', () {
    testWidgets('names the trainer app and opens Connection settings', (tester) async {
      await _pumpSettings(tester);

      final row = find.byKey(const ValueKey('settings-trainer-app'));
      expect(find.descendant(of: row, matching: find.text('MyWhoosh')), findsOneWidget);
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TrainerConnectionSettingsPage), findsOneWidget);
    });

  });

  testWidgets('during the ride: sound everywhere, vibration and Quit only on a phone', (tester) async {
    debugHostPlatformOverride = TargetPlatform.macOS;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpSettings(tester);
    expect(_inSection('settings-during-ride', find.text(l.shiftFeedbackSound)), findsOneWidget);
    expect(_inSection('settings-during-ride', find.text(l.shiftFeedbackHaptics)), findsNothing);
    expect(find.byKey(const ValueKey('settings-quit')), findsNothing);

    debugHostPlatformOverride = TargetPlatform.android;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(const SizedBox());
    await _pumpSettings(tester);
    expect(_inSection('settings-during-ride', find.text(l.shiftFeedbackHaptics)), findsOneWidget);
    expect(_inSection('settings-app', find.text(l.chainCloseAndQuit)), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('help & support and the app sections carry their rows', (tester) async {
    await _pumpSettings(tester);

    for (final text in [l.helpCenterTitle, l.onboardingMenuEntry, l.logs, l.networkTroubleshootingTitle]) {
      expect(_inSection('settings-help', find.text(text)), findsOneWidget, reason: text);
    }
    for (final text in [l.language, l.changelog, l.leaveAReview, l.license]) {
      expect(_inSection('settings-app', find.text(text)), findsOneWidget, reason: text);
    }
    // The blog lives in Activity → News; one home, not two.
    expect(find.text(l.blogTab), findsNothing);
  });
}
