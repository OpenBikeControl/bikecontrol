import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'controller-settings-ride-test-anon-key',
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
  });

  Future<void> pumpPage(WidgetTester tester, ZwiftRide device) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: ControllerSettingsPage(device: device),
      ),
    );
    await tester.pump();
  }

  testWidgets('a Zwift Ride on a 1.2 patch release shows no firmware notice', (tester) async {
    final device = ZwiftRide(BleDevice(deviceId: 'zr', name: 'Zwift Ride'))..firmwareVersion = '1.2.5';
    await pumpPage(tester, device);

    expect(find.textContaining(AppLocalizations.current.zwiftRideFirmwareNoticeBody('1.2.5')), findsNothing);
  });
}
