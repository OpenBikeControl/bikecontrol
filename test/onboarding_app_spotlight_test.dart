// Step 1: picking an app folds the grid into one enlarged tile with a way back
// ("Change app") and the "runs on" choice right under it.
import 'package:bike_control/pages/onboarding/steps/step_app.dart' show OnboardingAppTile, onboardingAppBody;
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
}
