// The virtual-shifting step pitched BikeControl's virtual shifting without
// ever saying it is part of Pro — riders found out from the paywall after
// they had set it up. The step now carries the PRO badge and one honest line
// above the trainer list.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  testWidgets('the step says virtual shifting is Pro, with the trial and Base spelled out', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(
            child: Builder(
              builder: (c) => onboardingTrainerBody(
                c,
                app: MyWhoosh(),
                trainers: [ProxyDevice(BleDevice(deviceId: 'vs-pro', name: 'KICKR CORE'))],
                onPick: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    expect(find.byType(ProBadge), findsOneWidget);
    expect(find.text(l.onboardingVsProNote('${core.bridgeUsageTracker.dailyLimit.inMinutes}')), findsOneWidget);
  });

  // A found trainer read like a line of the explanation. It is a device card
  // of its own under "Nearby smart trainers", with a primary Connect.
  testWidgets('a found trainer is a card of its own with a primary Connect', (tester) async {
    final picked = <ProxyDevice>[];
    final kickr = ProxyDevice(BleDevice(deviceId: 'vs-card', name: 'KICKR CORE'));
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(
            child: Builder(
              builder: (c) => onboardingTrainerBody(c, app: MyWhoosh(), trainers: [kickr], onPick: picked.add),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    expect(find.text(l.onboardingNearbyTrainers.toUpperCase()), findsOneWidget);
    final card = find.byKey(ValueKey('onboarding-trainer-${kickr.uniqueId}'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('KICKR CORE')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining(l.onboardingTrainerMeta)), findsOneWidget);
    final connect = find.descendant(of: card, matching: find.widgetWithText(BkPillButton, l.connect));
    expect(connect, findsOneWidget);
    expect(tester.getSize(connect).height, greaterThanOrEqualTo(48));

    await tester.tap(connect);
    expect(picked, [kickr]);
  });

  test('the "other device" target does not look like a controller', () {
    expect(Target.otherDevice.icon, isNot(LucideIcons.gamepad2));
  });

  // With a trainer found, Connect used to sit below the animation, off the
  // first screen on a phone.
  testWidgets('a found trainer can be connected without scrolling at 390x844', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
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
        home: Scaffold(
          child: Builder(
            builder: (c) => SafeArea(
              child: onboardingShell(
                c,
                step: OnboardingStep.virtualShifting,
                body: onboardingTrainerBody(
                  c,
                  app: MyWhoosh(),
                  trainers: [ProxyDevice(BleDevice(deviceId: 'vs-fold', name: 'KICKR CORE 1EB7'))],
                  onPick: (_) {},
                  onRescan: () {},
                ),
                footerActions: [
                  GhostButton(onPressed: () {}, child: Text(AppLocalizations.of(c).onboardingLetAppHandleVs('MyWhoosh'))),
                ],
                onBack: () {},
                onHelp: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    final connect = tester.getRect(find.text(l.connect));
    final footerTop = tester.getTopLeft(find.text(l.onboardingLetAppHandleVs('MyWhoosh'))).dy;
    expect(connect.top, greaterThanOrEqualTo(0));
    expect(connect.bottom, lessThan(footerTop), reason: 'Connect must be visible above the footer without scrolling');
  });
}

