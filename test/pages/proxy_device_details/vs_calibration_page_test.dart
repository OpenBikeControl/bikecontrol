// The virtual shifting calibrator: the rider pedals, the page puts three grades
// on the trainer, and their "too heavy / about right / too light" tunes the
// difficulty of every virtual gear on this trainer.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate, installLoggerErrorListener, navigatorKey;
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/vs_calibration_page.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/transports/trainer_transport.dart';
import 'package:prop/utils/constants.dart';
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
  Future<void> write(String s, String c, Uint8List b, {bool withoutResponse = false}) async {}
  @override
  Future<void> subscribe(String s, String c, {required bool indicate}) async {}
  @override
  Stream<({String characteristic, Uint8List value})> get notifications => const Stream.empty();
  @override
  Future<void> disconnect() async {}
}

const _wakelockChannels = [
  'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
  'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.isEnabled',
];

void _mockWakelock(bool install) {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in _wakelockChannels) {
    messenger.setMockMessageHandler(
      channel,
      install ? (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]) : null,
    );
  }
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting();
    installLoggerErrorListener();
    Logger.onRecordError = (message, error, _) => debugPrint('recordError($message): $error');
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'vs-calibration-page-anon-key',
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
    await core.shiftingConfigs.init();
    core.actionHandler = StubActions();
    _mockWakelock(true);
  });

  tearDown(() => _mockWakelock(false));

  var trainerCount = 0;

  /// A connected FTMS trainer with no trainer app attached. A fresh name per
  /// call: core.shiftingConfigs outlives the prefs reset between tests.
  ProxyDevice trainer({bool zwiftHub = false}) {
    final services = [
      BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [
        BleCharacteristic(FitnessBikeDefinition.FITNESS_MACHINE_CONTROL_POINT_UUID, [
          CharacteristicProperty.write,
          CharacteristicProperty.indicate,
        ], []),
      ]),
      if (zwiftHub)
        BleService(FtmsMdnsConstants.ZWIFT_PLAY_SERVICE_UUID, [
          BleCharacteristic(FtmsMdnsConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID, [CharacteristicProperty.write], []),
        ]),
    ];
    final name = 'KICKR CORE ${trainerCount++}';
    final device = ProxyDevice(
      BleDevice(deviceId: name, name: name, services: services.map((s) => s.uuid).toList()),
    )..services = services;
    final def = FitnessBikeDefinition(
      connectedDevice: device.scanResult,
      connectedDeviceServices: services,
      data: ValueNotifier(''),
      transport: _SilentTransport(),
    );
    device.debugAttachFitnessBike(def);
    device.isConnected = true;
    return device;
  }

  Future<void> pumpPage(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(900, 2400);
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
        home: home,
      ),
    );
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pump();
  }

  Future<void> tearDownPage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('a full run tunes, applies and stores the difficulty', (tester) async {
    final device = trainer();
    final def = device.fitnessBike!;
    await pumpPage(tester, VsCalibrationPage(device: device));

    await tapKey(tester, 'vs-cal-start');
    expect(def.trainerMode.value, TrainerMode.simModeVirtualShifting);
    expect(def.simGrade.value, 0, reason: 'the flat comes first');

    await tapKey(tester, 'vs-cal-too-heavy');
    expect(def.difficultyPct.value, 80, reason: 'the change is on the trainer right away');

    await tapKey(tester, 'vs-cal-about-right');
    expect(def.simGrade.value, 300);
    await tapKey(tester, 'vs-cal-about-right');
    expect(def.simGrade.value, 600);
    await tapKey(tester, 'vs-cal-about-right');

    expect(find.byKey(const ValueKey('vs-cal-result')), findsOneWidget);
    expect(core.shiftingConfigs.activeFor(device.trainerKey).difficultyPct, 80);
    expect(def.simGrade.value, 0, reason: 'fine-tuning happens on the flat');

    await tapKey(tester, 'stepper-plus');
    expect(def.difficultyPct.value, 85);
    expect(core.shiftingConfigs.activeFor(device.trainerKey).difficultyPct, 85);

    await tapKey(tester, 'vs-cal-reset');
    expect(def.difficultyPct.value, 100);
    expect(core.shiftingConfigs.activeFor(device.trainerKey).difficultyPct, 100);

    await tearDownPage(tester);
  });

  testWidgets('stopping mid-run puts the old difficulty back and stores nothing', (tester) async {
    final device = trainer();
    final def = device.fitnessBike!;
    await pumpPage(tester, VsCalibrationPage(device: device));

    await tapKey(tester, 'vs-cal-start');
    await tapKey(tester, 'vs-cal-too-heavy');
    expect(def.difficultyPct.value, 80);

    await tapKey(tester, 'vs-cal-stop');
    expect(def.difficultyPct.value, 100);
    expect(core.shiftingConfigs.storedActiveFor(device.trainerKey), isNull);
    expect(find.byKey(const ValueKey('vs-cal-start')), findsOneWidget);

    await tearDownPage(tester);
  });

  testWidgets('leaving the page mid-run puts the old difficulty back', (tester) async {
    final device = trainer();
    final def = device.fitnessBike!;
    await pumpPage(tester, VsCalibrationPage(device: device));
    await tapKey(tester, 'vs-cal-start');
    await tapKey(tester, 'vs-cal-too-light');
    expect(def.difficultyPct.value, 120);

    await tearDownPage(tester);
    expect(def.difficultyPct.value, 100);
  });

  testWidgets('will not start while a trainer app holds the trainer', (tester) async {
    final device = trainer()..debugSetTrainerAppConnected(true);
    final def = device.fitnessBike!;
    await pumpPage(tester, VsCalibrationPage(device: device));

    await tapKey(tester, 'vs-cal-start');
    expect(find.byKey(const ValueKey('vs-cal-refusal')), findsOneWidget);
    expect(find.byKey(const ValueKey('vs-cal-too-heavy')), findsNothing);
    expect(def.trainerMode.value, isNot(TrainerMode.simModeVirtualShifting));

    await tearDownPage(tester);
  });

  testWidgets('a trainer app connecting mid-run ends the run', (tester) async {
    final device = trainer();
    final def = device.fitnessBike!;
    await pumpPage(tester, VsCalibrationPage(device: device));
    await tapKey(tester, 'vs-cal-start');
    await tapKey(tester, 'vs-cal-too-heavy');

    device.debugSetTrainerAppConnected(true);
    await tester.pump();
    expect(find.byKey(const ValueKey('vs-cal-refusal')), findsOneWidget);
    expect(def.difficultyPct.value, 100);

    await tearDownPage(tester);
  });

  testWidgets('the on-screen shift buttons move the gear, for mouse and keyboard riders', (tester) async {
    final device = trainer();
    final def = device.fitnessBike!;
    await pumpPage(tester, VsCalibrationPage(device: device));
    await tapKey(tester, 'vs-cal-start');

    final before = def.currentGear.value;
    await tapKey(tester, 'vs-cal-shift-up');
    expect(def.currentGear.value, before + 1);
    await tapKey(tester, 'vs-cal-shift-down');
    await tapKey(tester, 'vs-cal-shift-down');
    expect(def.currentGear.value, before - 1);

    await tearDownPage(tester);
  });

  testWidgets('the rating buttons can be reached and pressed from the keyboard', (tester) async {
    final device = trainer();
    final def = device.fitnessBike!;
    await pumpPage(tester, VsCalibrationPage(device: device));
    await tapKey(tester, 'vs-cal-start');

    // Tab until "Too heavy" has focus, then press it with Enter.
    for (var i = 0; i < 20; i++) {
      final focused = FocusManager.instance.primaryFocus?.context;
      final onTooHeavy = focused != null &&
          find
              .ancestor(of: find.byWidget(focused.widget), matching: find.byKey(const ValueKey('vs-cal-too-heavy')))
              .evaluate()
              .isNotEmpty;
      if (onTooHeavy) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(def.difficultyPct.value, 80);

    await tearDownPage(tester);
  });

  testWidgets('a trainer that shifts in its own firmware is not offered a calibration', (tester) async {
    final device = trainer(zwiftHub: true);
    expect(device.fitnessBike!.controlProtocol, TrainerControlProtocol.zwiftHub);
    await pumpPage(tester, VsCalibrationPage(device: device));

    expect(find.byKey(const ValueKey('vs-cal-firmware')), findsOneWidget);
    expect(find.byKey(const ValueKey('vs-cal-start')), findsNothing);

    await tearDownPage(tester);
  });

  testWidgets('the trainer page opens the calibrator from next to the self-test', (tester) async {
    final device = trainer();
    await pumpPage(tester, ProxyDeviceDetailsPage(device: device));

    await tapKey(tester, 'vs-calibrate');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(VsCalibrationPage), findsOneWidget);

    await tearDownPage(tester);
  });
}
