import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/actions/base_actions.dart' show StubActions;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// With BikeControl itself as the trainer app ("self-hosted"), no other app
/// and no connection method is involved: BikeControl runs the trainer actions
/// (gear changes, ERG/SIM, ...) on the connected trainer directly. A button
/// mapped to one of them works, so it must not read "Won't work yet".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The editor's Pro checks reach Supabase.instance: an offline dummy one.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'self-hosted-label-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    // iOS: no Local method, so no connection method is on at all.
    debugHostPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.settings.setTrainerApp(BikeControl());
    await core.settings.setLastTarget(Target.thisDevice);
    core.actionHandler.init(BikeControl());
    await AppLocalizations.load(const Locale('en'));
  });

  tearDown(() => debugHostPlatformOverride = null);

  KeyPair pair(InGameAction action) =>
      KeyPair(buttons: [ZwiftButtons.y], physicalKey: null, logicalKey: null, inGameAction: action);

  group('self-hosted: actions BikeControl runs itself show their title', () {
    for (final action in trainerActions) {
      test(action.name, () {
        expect(core.logic.emulatorEnabled, isFalse);
        final kp = pair(action);
        expect(kp.toString(), action.title);
        expect(kp.waitsForConnectionMethod, isFalse);
      });
    }
  });

  test('self-hosted: an action only a trainer app can carry still waits', () {
    final kp = pair(InGameAction.up);
    expect(kp.toString(), AppLocalizations.current.actionWaitsForConnectionMethod);
    expect(kp.waitsForConnectionMethod, isTrue);
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
            device: ZwiftRide(BleDevice(name: 'Zwift Ride', deviceId: 'self-hosted-ride')),
            keyPair: keyPair,
            keymap: BikeControl().keymap,
            trigger: ButtonTrigger.singleClick,
            onUpdate: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('self-hosted editor: a gear change carries no "won\'t work" warning', (tester) async {
    await pumpEditor(tester, pair(InGameAction.shiftDown));
    final l = AppLocalizations.current;
    expect(find.text(l.actionWaitsForConnectionMethod), findsNothing);
    expect(find.text(l.pleaseSelectAConnectionMethodFirst), findsNothing);
  });

  testWidgets('self-hosted editor: an unmapped button keeps the connection-method hint', (tester) async {
    await pumpEditor(tester, KeyPair(buttons: [ZwiftButtons.y], physicalKey: null, logicalKey: null));
    expect(find.text(AppLocalizations.current.pleaseSelectAConnectionMethodFirst), findsOneWidget);
  });
}
