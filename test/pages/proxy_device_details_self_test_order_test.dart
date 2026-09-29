// The resistance self-test answers "does BikeControl actually control my
// trainer?" — the first thing to check when shifting feels wrong. It used to
// sit below the gears, the Pro notice and the live metrics, under a "Need
// help?" card that routes to support. The self-test now comes first, so the
// rider checks before they ask; the done step of the setup guide links
// straight to it.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, installLoggerErrorListener, navigatorKey;
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/need_help_card.dart';
import 'package:bike_control/pages/proxy_device_details/self_test_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/transports/trainer_transport.dart';
import 'package:prop/utils/shared.dart' show Logger;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

class _SilentTransport implements TrainerTransport {
  @override
  String get id => 'silent';

  @override
  void Function()? onDisconnected;

  @override
  Future<void> connect() async {}

  @override
  Future<List<BleService>> discoverServices() async => const [];

  @override
  Future<Uint8List> read(String service, String characteristic) async => Uint8List(0);

  @override
  Future<void> write(String service, String characteristic, Uint8List bytes, {bool withoutResponse = false}) async {}

  @override
  Future<void> subscribe(String service, String characteristic, {required bool indicate}) async {}

  @override
  Stream<({String characteristic, Uint8List value})> get notifications => const Stream.empty();

  @override
  Future<void> disconnect() async {}
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting();
    installLoggerErrorListener();
    Logger.onRecordError = (message, error, _) => debugPrint('recordError($message): $error');
    SharedPreferences.setMockInitialValues({});
    // The Pro notice reads entitlements through core.supabase.
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'proxy-device-details-self-test-order-anon-key',
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

  ProxyDevice trainer() {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'self-test-order',
        name: 'KICKR CORE',
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])];
    device.debugAttachFitnessBike(
      FitnessBikeDefinition(
        connectedDevice: device.scanResult,
        connectedDeviceServices: device.services!,
        data: ValueNotifier(''),
        transport: _SilentTransport(),
      ),
    );
    return device;
  }

  testWidgets('the self-test sits above the Need-help card', (tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ShadcnApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: ProxyDeviceDetailsPage(device: trainer()),
      ),
    );
    await tester.pump();

    expect(find.byType(SelfTestCard), findsOneWidget);
    expect(find.byType(NeedHelpCard), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(SelfTestCard)).dy,
      lessThan(tester.getTopLeft(find.byType(NeedHelpCard)).dy),
    );

    // Let the page's own timers (trainer polling, notices) run out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
