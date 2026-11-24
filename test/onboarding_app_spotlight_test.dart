// Step 1: picking an app folds the grid into one enlarged tile with a way back
// ("Change app") and the "runs on" choice right under it.
import 'package:bike_control/main.dart' show debugAnimatesInScreenshotMode;
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile, TrainerAppGrid, onboardingAppBody;
import 'package:bike_control/pages/onboarding/widgets/onboarding_headline.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_viewport.dart';
import 'package:bike_control/utils/keymap/apps/grimpa.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'widget_snapshot.dart';

Future<void> main() async {
  await ensureSnapshotHarness();

  Widget body({List<Target> targets = Target.values}) {
    SupportedApp? selected;
    Target? target;
    return StatefulBuilder(
      builder: (c, setState) => onboardingAppBody(
        c,
        selected: selected,
        onSelect: (a) => setState(() => selected = a),
        targets: targets,
        selectedTarget: target,
        onSelectTarget: (t) => setState(() => target = t),
      ),
    );
  }

  Finder tile<T>() => find.byWidgetPredicate((w) => w is OnboardingAppTile && w.app is T);

  testWidgets('picking an app shows it enlarged with "runs on", Change app brings the grid back', (tester) async {
    await captureWidget(
      tester,
      name: 'onboarding_step_app_spotlight',
      width: 380,
      builder: (_) => body(),
      beforeCapture: (tester) async {
        await tester.tap(tile<MyWhoosh>());
        await tester.pumpAndSettle();
      },
    );

    expect(find.byType(OnboardingAppTile), findsNothing, reason: 'the grid folds away');
    expect(find.byKey(const ValueKey('onboarding-app-spotlight-MyWhoosh')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-where-thisDevice')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-where-otherDevice')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-change-app')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingAppTile), findsWidgets, reason: 'Change app reopens the grid');
    expect(find.byKey(const ValueKey('onboarding-app-spotlight-MyWhoosh')), findsNothing);
  });

  testWidgets('the spotlight sits vertically centred in the space under the headline', (tester) async {
    const screen = 820.0;
    await captureWidget(
      tester,
      name: 'onboarding_step_app_spotlight_centered',
      width: 640,
      builder: (_) => OnboardingViewport(bodyHeight: screen, child: body()),
      beforeCapture: (tester) async {
        await tester.tap(tile<MyWhoosh>());
        await tester.pumpAndSettle();
      },
    );

    final top = tester.getRect(find.byType(OnboardingHeadline)).bottom;
    final origin = tester.getTopLeft(find.byType(OnboardingViewport)).dy;
    final spot = tester.getRect(find.byKey(const ValueKey('onboarding-app-spotlight-MyWhoosh')));
    final above = spot.top - top;
    final below = origin + screen - spot.bottom;
    expect(below, greaterThan(100), reason: 'there is room to centre in');
    expect((above - below).abs(), lessThan(24), reason: 'above $above vs below $below');
  });

  testWidgets('the picked tile flies straight to the centre; Change app flies it back', (tester) async {
    debugAnimatesInScreenshotMode = true;
    addTearDown(() => debugAnimatesInScreenshotMode = false);
    const screen = 820.0;
    final flight = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_FlightCard');
    final spotlight = find.byKey(const ValueKey('onboarding-app-spotlight-MyWhoosh'));
    Rect? firstFrame;
    Rect? midFlight;
    await captureWidget(
      tester,
      name: 'onboarding_step_app_flight',
      width: 640,
      settle: false,
      builder: (_) => OnboardingViewport(bodyHeight: screen, child: body()),
      beforeCapture: (tester) async {
        await tester.pump(const Duration(seconds: 2));
        final tileRect = tester.getRect(tile<MyWhoosh>());
        await tester.tap(tile<MyWhoosh>());
        await tester.pump();
        // The very frame that swaps the grid out already shows the tile and the
        // fading grid — no blank frame for the grid to flash back from.
        expect(flight, findsOneWidget, reason: 'the tile is up from the first frame');
        expect(find.byType(TrainerAppGrid), findsOneWidget, reason: 'the grid fades out, it does not blink');
        await tester.pump();
        firstFrame = tester.getRect(spotlight);
        await tester.pump(const Duration(milliseconds: 140));
        expect(flight, findsOneWidget, reason: 'the tile is in flight');
        midFlight = tester.getRect(flight);
        expect(midFlight!.width, greaterThan(tileRect.width), reason: 'it grows on the way');
        await tester.pump(const Duration(seconds: 2));
      },
    );

    expect(flight, findsNothing, reason: 'landed');
    expect(tester.getRect(spotlight), firstFrame, reason: 'the layout is centred from the first frame, no drift');

    await tester.tap(find.byKey(const ValueKey('onboarding-change-app')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(flight, findsOneWidget, reason: 'flies back into the grid');
    await tester.pump(const Duration(seconds: 2));
    expect(flight, findsNothing);
    final back = tester.widget<Opacity>(find.ancestor(of: tile<MyWhoosh>(), matching: find.byType(Opacity)).first);
    expect(back.opacity, 1, reason: 'the tile shows again once landed');
  });

  testWidgets('the spotlight links the app on smarttrainerapps.com; only Grimpa shows its rider deal', (tester) async {
    await captureWidget(
      tester,
      name: 'onboarding_step_app_spotlight_grimpa',
      width: 380,
      builder: (_) => body(targets: const [Target.otherDevice]),
      beforeCapture: (tester) async {
        await tester.ensureVisible(tile<Grimpa>());
        await tester.tap(tile<Grimpa>());
        await tester.pumpAndSettle();
      },
    );
    expect(find.byKey(const ValueKey('onboarding-app-directory-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-rider-deal')), findsOneWidget);
    expect(find.text('BIKECONTROL'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-change-app')));
    await tester.pumpAndSettle();
    await tester.tap(tile<MyWhoosh>());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-app-directory-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-rider-deal')), findsNothing);
  });
}
