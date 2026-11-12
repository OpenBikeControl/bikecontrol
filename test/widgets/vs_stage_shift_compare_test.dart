import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart' show onboardingAdvertisesZwiftService;
import 'package:bike_control/pages/onboarding/widgets/vs_shift_compare.dart';
import 'package:bike_control/pages/onboarding/widgets/vs_stage.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first scene of the Virtual Shifting preview draws one shift through
/// the trainer app and one through BikeControl — except for the apps that
/// shift a trainer natively themselves, where BikeControl isn't faster.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations l;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    l = await AppLocalizations.load(const Locale('en'));
    final wasScreenshotMode = screenshotMode;
    screenshotMode = false;
    addTearDown(() => screenshotMode = wasScreenshotMode);
  });

  Future<void> pump(WidgetTester tester, Widget child, {bool reduceMotion = true}) async {
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  final compare = find.byKey(const ValueKey('vs-stage-shift-compare'));

  testWidgets('names the picked app: it shifts a beat later, BikeControl sooner', (tester) async {
    core.settings.setTrainerApp(MyWhoosh());
    await pump(tester, const VirtualShiftingStage());
    expect(compare, findsOneWidget);
    expect(find.text(l.vsStageShiftLabel), findsOneWidget);
    expect(find.text(l.vsStageLaneApp('MyWhoosh')), findsOneWidget);
    expect(find.text(l.vsStageLaneLater), findsOneWidget);
    expect(find.text(l.vsStageLaneBikeControl), findsOneWidget);
    // No trainer connected: BikeControl sets the slope, so "sooner", never
    // "right away".
    expect(find.text(l.vsStageLaneSooner), findsOneWidget);
    expect(find.text(l.vsStageLaneRightAway), findsNothing);
    expect(find.text(l.vsStageShiftIllustration), findsOneWidget);
    expect(find.text(l.vsStageAppsLabel), findsNothing);
  });

  testWidgets('with no app picked the app lane stays generic', (tester) async {
    await pump(tester, const VirtualShiftingStage());
    expect(find.text(l.vsStageLaneAppGeneric), findsOneWidget);
  });

  for (final app in [Zwift(), Rouvy()]) {
    testWidgets('${app.name} shifts natively itself: no comparison, the app scene instead', (tester) async {
      core.settings.setTrainerApp(app);
      await pump(tester, const VirtualShiftingStage());
      expect(compare, findsNothing);
      expect(find.text(l.vsStageAppsLabel), findsOneWidget);
      expect(find.text(l.vsStageLaneSooner), findsNothing);
    });
  }

  testWidgets('a found trainer with the Zwift service: the trainer applies the gear right away', (tester) async {
    core.settings.setTrainerApp(MyWhoosh());
    await pump(tester, const VirtualShiftingStage(zwiftReadyNearby: true));
    expect(find.text(l.vsStageLaneRightAway), findsOneWidget);
    expect(find.text(l.vsStageStepTrainerGear), findsOneWidget);
    expect(find.text(l.vsStageLaneSooner), findsNothing);
  });

  test('the Zwift service is spotted in the scan, in either spelling', () {
    expect(onboardingAdvertisesZwiftService(['0000FC82-0000-1000-8000-00805F9B34FB']), isTrue);
    expect(onboardingAdvertisesZwiftService(['fc82']), isTrue);
    expect(onboardingAdvertisesZwiftService(['00000001-19CA-4651-86E5-FA29DCDD09D1']), isTrue);
    expect(onboardingAdvertisesZwiftService(['00001826-0000-1000-8000-00805f9b34fb']), isFalse);
  });

  testWidgets('a trainer shifting natively: the trainer applies the gear right away', (tester) async {
    await pump(tester, const VsShiftCompare(app: 'MyWhoosh', native: true, active: false));
    expect(find.text(l.vsStageLaneRightAway), findsOneWidget);
    expect(find.text(l.vsStageStepTrainerGear), findsOneWidget);
    expect(find.text(l.vsStageLaneSooner), findsNothing);
  });

  testWidgets('draws while active and stops cleanly when the scene leaves', (tester) async {
    await pump(tester, const VsShiftCompare(app: 'MyWhoosh', native: false, active: true), reduceMotion: false);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    await pump(tester, const VsShiftCompare(app: 'MyWhoosh', native: false, active: false), reduceMotion: false);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
