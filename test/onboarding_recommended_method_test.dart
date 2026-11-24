// Picking where the trainer app runs turns on the method the ride step
// recommends, for apps like Zwift whose network method used to start off. The
// ride step keeps the methods folded away then — and unfolds them while none
// is on, since picking one is the thing to do.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/steps/step_connection.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/biketerra.dart';
import 'package:bike_control/utils/keymap/apps/grimpa.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/trainer_setup.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = RemoteActions();
    // No nsd plugin under `flutter test`: let the advertise attempt succeed
    // rather than have the emulator's error path switch the method off again.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.haberey/nsd'), (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.haberey/nsd'), null);
  });

  for (final SupportedApp app in [Zwift(), Rouvy()]) {
    test('${app.name} on another device: the network method is on, so setup can finish', () async {
      await applyTrainerAppSelection(app);
      await applyTargetSelection(Target.otherDevice);

      expect(core.settings.getZwiftMdnsEmulatorEnabled(), isTrue);
      expect(core.logic.hasNoConnectionMethod, isFalse);
    });
  }

  for (final SupportedApp app in [Grimpa(), Biketerra()]) {
    test('${app.name} on another device: Bluetooth is on, not the network method it has none of', () async {
      await applyTrainerAppSelection(app);
      await applyTargetSelection(Target.otherDevice);

      expect(core.settings.getObpBleEnabled(), isTrue);
      expect(core.settings.getObpMdnsEnabled(), isFalse);
      expect(core.logic.hasNoConnectionMethod, isFalse);
    });
  }

  test('a declined advertise permission never holds the controller scan', () async {
    await AppLocalizations.load(const Locale('en'));
    expect(Permissions.blockingScan([BluetoothAdvertiseRequirement()]), isEmpty);
  });

  test('a method the rider already turned on is left alone', () async {
    await applyTrainerAppSelection(Zwift());
    await core.settings.setLastTarget(Target.otherDevice);
    core.settings.setZwiftBleEmulatorEnabled(true);

    await applyTargetSelection(Target.otherDevice);

    expect(core.settings.getZwiftMdnsEmulatorEnabled(), isFalse);
  });

  Future<AppLocalizations> pumpMethods(WidgetTester tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(child: OnboardingMethodsDisclosure(app: Zwift(), onUpdate: () {})),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(OnboardingMethodsDisclosure)));
  }

  testWidgets('no method on: the methods are unfolded', (tester) async {
    core.settings.setTrainerApp(Zwift());
    await core.settings.setLastTarget(Target.otherDevice);
    expect(core.logic.hasNoConnectionMethod, isTrue);

    final l = await pumpMethods(tester);
    expect(find.text(l.onboardingMethodNetwork), findsOneWidget);
  });

  testWidgets('a method on: folded away until the heading is tapped', (tester) async {
    await applyTrainerAppSelection(Zwift());
    await applyTargetSelection(Target.otherDevice);

    final l = await pumpMethods(tester);
    expect(find.text(l.onboardingConnectionMethods), findsOneWidget);
    expect(find.text(l.onboardingMethodNetwork), findsNothing);

    await tester.tap(find.byKey(const ValueKey('onboarding-methods-toggle')));
    await tester.pump();
    expect(find.text(l.onboardingMethodNetwork), findsOneWidget);
  });
}
