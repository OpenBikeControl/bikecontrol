import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/button_edit.dart' show SelectableCard;
import 'package:bike_control/pages/configuration.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/wahoo.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Wahoo app only ever sees BikeControl as a trainer on another device,
/// so the connection settings must not warn about controlling it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The target cards reach Supabase.instance: an offline dummy one.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'wahoo-configuration-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  testWidgets('no install-on-that-device warning and no "this device" choice', (tester) async {
    SharedPreferences.setMockInitialValues({'last_target': 'otherDevice'});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    final app = WahooApp();
    core.settings.setTrainerApp(app);

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
          child: SingleChildScrollView(child: ConfigurationPage(onUpdate: () {})),
        ),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.current;

    expect(find.text(l10n.warningInstallOnTargetDevice(app.name)), findsNothing);
    expect(find.text(l10n.warningAppLocalControlOnly(app.name)), findsNothing);
    expect(find.text(l10n.warningAppLocalControlIosNote(app.name)), findsNothing);
    // One target card: "Other Device".
    expect(find.byType(SelectableCard), findsOneWidget);
    expect(core.settings.getLastTarget(), Target.otherDevice);
  });
}
