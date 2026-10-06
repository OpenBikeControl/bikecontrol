// Picking where the trainer app runs turns on the method the connection step
// recommends, so "Finish setup" isn't greyed out for apps like Zwift whose
// network method used to start off. When no method is on, the step says why
// Finish is unavailable instead of leaving a dead button.
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/core.dart';
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

  test('a method the rider already turned on is left alone', () async {
    await applyTrainerAppSelection(Zwift());
    await core.settings.setLastTarget(Target.otherDevice);
    core.settings.setZwiftBleEmulatorEnabled(true);

    await applyTargetSelection(Target.otherDevice);

    expect(core.settings.getZwiftMdnsEmulatorEnabled(), isFalse);
  });

  Future<AppLocalizations> pumpFinish(WidgetTester tester, {required bool noMethod}) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: Builder(
            builder: (c) => onboardingConnectionFinishAction(
              c,
              onFinish: noMethod ? null : () {},
              noConnectionMethod: noMethod,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return AppLocalizations.of(tester.element(find.byType(PrimaryButton)));
  }

  testWidgets('no method on: Finish is disabled and says what to do', (tester) async {
    final l = await pumpFinish(tester, noMethod: true);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNull);
    expect(find.text(l.onboardingConnectionTurnOnMethod), findsOneWidget);
  });

  testWidgets('a method on: no hint under Finish', (tester) async {
    final l = await pumpFinish(tester, noMethod: false);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNotNull);
    expect(find.text(l.onboardingConnectionTurnOnMethod), findsNothing);
  });
}
