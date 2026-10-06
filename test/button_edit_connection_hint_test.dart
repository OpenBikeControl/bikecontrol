import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// "Not assigned" used to stand for two different things: the button does
/// nothing, or it has an action that can't run because no connection method
/// is on. And the messages that said so offered no way to the page that
/// fixes it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The editor's Pro checks reach Supabase.instance: an offline dummy one.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'button-edit-hint-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.settings.setTrainerApp(MyWhoosh());
    core.actionHandler.init(MyWhoosh());
    await AppLocalizations.load(const Locale('en'));
  });

  Future<void> pumpEditor(WidgetTester tester, KeyPair keyPair) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [
          ...ShadcnLocalizations.localizationsDelegates,
          OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        locale: const Locale('en'),
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: Align(
          alignment: Alignment.topLeft,
          child: ButtonEditPage(
            device: ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: 'hint-ride')),
            keyPair: keyPair,
            keymap: MyWhoosh().keymap,
            trigger: ButtonTrigger.singleClick,
            onUpdate: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('no connection method: the editor offers the way to Connection Settings', (tester) async {
    await pumpEditor(tester, KeyPair(buttons: [ZwiftButtons.y], physicalKey: null, logicalKey: null));
    final l = AppLocalizations.current;
    expect(find.text(l.pleaseSelectAConnectionMethodFirst), findsOneWidget);
    final open = find.widgetWithText(Button, l.openConnectionSettings);
    expect(open, findsOneWidget);
    await tester.tap(open);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TrainerConnectionSettingsPage), findsOneWidget);
  });

  testWidgets('MyWhoosh Link off: the hint also opens Connection Settings', (tester) async {
    debugHostPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugHostPlatformOverride = null);
    await core.settings.setLastTarget(Target.otherDevice);
    core.actionHandler = StubActions()..init(MyWhoosh());
    await pumpEditor(tester, KeyPair(buttons: [ZwiftButtons.y], physicalKey: null, logicalKey: null));
    final l = AppLocalizations.current;
    final hint = find.text(l.enableMywhooshLinkInTheConnectionSettingsFirst);
    expect(hint, findsOneWidget);
    final warning = find.ancestor(of: hint, matching: find.byType(Warning));
    expect(find.descendant(of: warning, matching: find.widgetWithText(Button, l.openConnectionSettings)), findsOneWidget);
  });
}
