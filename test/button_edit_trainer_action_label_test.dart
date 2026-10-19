import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// The trainer direct-control cards for shifting must say which way they
/// shift: the shift-down card used to read "Gear Up".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The editor's Pro checks reach Supabase.instance: an offline dummy one.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'trainer-action-label-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    debugHostPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.settings.setTrainerApp(BikeControl());
    await core.settings.setLastTarget(Target.thisDevice);
    core.actionHandler.init(BikeControl());
  });

  tearDown(() => debugHostPlatformOverride = null);

  Future<void> pumpEditor(WidgetTester tester, Locale locale) async {
    await AppLocalizations.load(locale);
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
        locale: locale,
        theme: ThemeData(colorScheme: ColorSchemes.lightSlate, radius: 0.7),
        home: Align(
          alignment: Alignment.topLeft,
          child: ButtonEditPage(
            device: ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: 'trainer-label-ride')),
            keyPair: KeyPair(buttons: [ZwiftButtons.y], physicalKey: null, logicalKey: null),
            keymap: BikeControl().keymap,
            trigger: ButtonTrigger.singleClick,
            onUpdate: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the shift cards name their direction', (tester) async {
    await pumpEditor(tester, const Locale('en'));
    expect(find.text('Trainer: Gear Up / ERG up'), findsOneWidget);
    expect(find.text('Trainer: Gear Down / ERG down'), findsOneWidget);
  });

  testWidgets('the shift cards are translated', (tester) async {
    await pumpEditor(tester, const Locale('de'));
    expect(find.text('Trainer: Gang hoch / ERG hoch'), findsOneWidget);
    expect(find.text('Trainer: Gang runter / ERG runter'), findsOneWidget);
  });
}
