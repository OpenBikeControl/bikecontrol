import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/configuration.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/tacx.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The "install BikeControl on that device" warning is the only thing a rider
/// running an app we can't control remotely (Tacx Training) sees at this
/// point. Left as-is it reads as "install it and you're set", when for Tacx
/// the Local method — BikeControl typing keystrokes on the very device Tacx
/// runs on — is the only control path there is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  Future<void> pumpWarning(WidgetTester tester, SupportedApp app) async {
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        locale: const Locale('en'),
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: Scaffold(
          child: SingleChildScrollView(
            child: Builder(builder: (context) => installOnTargetDeviceWarning(context, app)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Tacx is told the Local method is the only way to control it', (tester) async {
    final tacx = Tacx();
    await pumpWarning(tester, tacx);
    final l10n = AppLocalizations.current;

    expect(find.text(l10n.warningInstallOnTargetDevice(tacx.name)), findsOneWidget);
    expect(find.text(l10n.warningAppLocalControlOnly(tacx.name)), findsOneWidget);
    expect(find.text(l10n.warningAppLocalControlIosNote(tacx.name)), findsOneWidget);
  });

  testWidgets('the configuration page survives "other device" with no trainer app resolved', (tester) async {
    // e.g. a saved app that is not listed in this build (debug-only apps).
    SharedPreferences.setMockInitialValues({'last_target': 'otherDevice', 'trainer_app': 'Not A Listed App'});
    core.settings.prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        locale: const Locale('en'),
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: Scaffold(child: SingleChildScrollView(child: ConfigurationPage(onUpdate: () {}))),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ConfigurationPage), findsOneWidget);
  });

  testWidgets('apps with a controller protocol keep the plain install warning', (tester) async {
    final zwift = Zwift();
    await pumpWarning(tester, zwift);
    final l10n = AppLocalizations.current;

    expect(find.text(l10n.warningInstallOnTargetDevice(zwift.name)), findsOneWidget);
    expect(find.text(l10n.warningAppLocalControlOnly(zwift.name)), findsNothing);
    expect(find.text(l10n.warningAppLocalControlIosNote(zwift.name)), findsNothing);
  });
}
