// A rider who forced FTMS (or FE-C) on a trainer that BikeControl would
// otherwise drive through its native Zwift interface ends up on the weaker
// path without anything on screen saying so; one support case ran a whole
// thread before it surfaced. The protocol section now says so and offers the
// one-tap way back to Auto.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/control_protocol_section.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/transports/trainer_transport.dart';
import 'package:prop/utils/constants.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// Keeps the definition's upstream writes off the real BLE stack — same
/// reasoning as control_protocol_select_test's copy.
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

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  List<BleService> dualProtocolServices() => [
    BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [
      BleCharacteristic(FitnessBikeDefinition.FITNESS_MACHINE_CONTROL_POINT_UUID, [
        CharacteristicProperty.write,
        CharacteristicProperty.indicate,
      ], []),
    ]),
    BleService(FtmsMdnsConstants.ZWIFT_PLAY_SERVICE_UUID, [
      BleCharacteristic(FtmsMdnsConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID, [
        CharacteristicProperty.write,
      ], []),
    ]),
  ];

  ProxyDevice trainer() {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'kickr',
        name: 'KICKR CORE',
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )..services = dualProtocolServices();
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

  Future<void> pumpSection(WidgetTester tester, ProxyDevice device) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: ControlProtocolSection(
                definition: device.fitnessBike!,
                device: device,
                reconnectDevice: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String hint() => AppLocalizations.current.controlProtocolNativeShiftingAvailable;

  testWidgets('forced FTMS on a natively driven trainer offers the way back to Auto', (tester) async {
    final device = trainer();
    final def = device.fitnessBike!;
    def.setControlProtocolOverride(TrainerControlProtocol.ftms);
    await core.settings.setControlProtocolOverride(device.trainerKey, TrainerControlProtocol.ftms.name);

    await pumpSection(tester, device);
    expect(find.text(hint()), findsOneWidget);

    await tester.ensureVisible(find.text(AppLocalizations.current.controlProtocolUseAuto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.controlProtocolUseAuto));
    await tester.pumpAndSettle();

    expect(def.controlProtocolOverride, isNull);
    expect(core.settings.getControlProtocolOverride(device.trainerKey), isNull);
    expect(find.text(hint()), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Auto shows no native-shifting hint', (tester) async {
    final device = trainer();
    await pumpSection(tester, device);
    expect(find.text(hint()), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('forcing the Zwift protocol shows no native-shifting hint', (tester) async {
    final device = trainer();
    device.fitnessBike!.setControlProtocolOverride(TrainerControlProtocol.zwiftHub);
    await pumpSection(tester, device);
    expect(find.text(hint()), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });
}
