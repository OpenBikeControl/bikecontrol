import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/onboarding/widgets/vs_stage.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The preview carousel is driven three ways — it advances itself, the dots
/// jump to a scene, and it can be swiped. The swipe is the one with no visible
/// affordance, so it's the one worth pinning down.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    await AppLocalizations.load(const Locale('en'));
  });

  /// Animations off: the scenes each run an endless timer, so `pumpAndSettle`
  /// would never return with them on. Reduced motion only stops the stage
  /// moving by itself — swiping and the dots keep working, which is exactly
  /// what these tests exercise.
  Future<void> pumpStage(WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: const Scaffold(
          child: Padding(padding: EdgeInsets.all(16), child: VirtualShiftingStage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder caption(String text) => find.text(text);

  /// The stage box, not the whole widget — the widget includes the caption and
  /// dots below it, whose centre falls outside the area that takes swipes.
  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.dragFrom(tester.getCenter(find.byType(AnimatedSlide)), Offset(dx, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('swiping left walks forward through the scenes', (tester) async {
    await pumpStage(tester);
    expect(caption('Shifting without the detour'), findsOneWidget);

    await swipe(tester, -120);
    expect(caption('Your gearing, your way'), findsOneWidget);

    await swipe(tester, -120);
    expect(caption('Add a second chainring'), findsOneWidget);
  });

  testWidgets('swiping right walks back, and wraps at the first scene', (tester) async {
    await pumpStage(tester);

    // Back from the first scene lands on the last of the four rather than
    // refusing to move.
    await swipe(tester, 120);
    expect(caption("And there's more"), findsOneWidget);

    await swipe(tester, 120);
    expect(caption('Add a second chainring'), findsOneWidget);
  });

  testWidgets('a nudge too short to be a swipe leaves the scene alone', (tester) async {
    await pumpStage(tester);

    await swipe(tester, -20);
    expect(caption('Shifting without the detour'), findsOneWidget);
  });
}
