// The Zwift gear-echo watchdog's verdict is the only thing that explains a
// trainer which accepts gear commands and acknowledges none of them. When the
// rider has forced a protocol by hand the definition deliberately leaves that
// choice alone (ZwiftGearEchoVerdict.riderOverrideKept) — which pins them to a
// wire the trainer ignores, with nothing on screen to say so. A beta tester
// found it by toggling transports at random; these tests pin the two halves of
// the fix: the verdict is told to the rider, and it is told once.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/trainer_settings_section.dart';
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

  test('re-seeding a definition does not stack another verdict listener', () async {
    // applyTrainerSettings re-seeds the *existing* definition on every settings
    // change, and the seeding funnel is where the verdict listener is attached.
    // Without a guard, one verdict fans out into one notification per seed —
    // which is exactly what a real bundle showed: five identical lines in the
    // same second.
    final device = trainer();
    final logs = <String>[];
    final sub = core.connection.actionStream.listen((n) {
      if (n is LogNotification && n.message.contains('acknowledge gear changes')) {
        logs.add(n.message);
      }
    });

    device.applyTrainerSettings();
    device.applyTrainerSettings();
    device.applyTrainerSettings();

    device.fitnessBike!.gearEchoVerdict.value = ZwiftGearEchoVerdict.riderOverrideKept;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(logs, hasLength(1));
  });

  test('a SIM-grade refusal is put in the support log once, across re-seeds', () async {
    final device = trainer();
    final logs = <String>[];
    final sub = core.connection.actionStream.listen((n) {
      if (n is LogNotification && n.message.contains('grade simulation')) {
        logs.add(n.message);
      }
    });

    device.applyTrainerSettings();
    device.applyTrainerSettings();

    device.fitnessBike!.trackResistanceRefused.value = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(logs, hasLength(1));
    expect(logs.single, contains('switched to Target Power'));
  });

  Future<void> pumpSection(WidgetTester tester, ProxyDevice device) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: TrainerSettingsSection(
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

  testWidgets('a kept override that the trainer ignores is surfaced with a way out', (tester) async {
    final device = trainer();
    final def = device.fitnessBike!;
    def.setControlProtocolOverride(TrainerControlProtocol.zwiftHub);

    await pumpSection(tester, device);
    expect(find.text(AppLocalizations.current.controlProtocolIgnored), findsNothing);

    def.gearEchoVerdict.value = ZwiftGearEchoVerdict.riderOverrideKept;
    await tester.pump();
    expect(find.text(AppLocalizations.current.controlProtocolIgnored), findsOneWidget);

    // The whole point is a one-tap way off the dead wire. The notice sits
    // below the fold in this viewport, so scroll it in first.
    await tester.ensureVisible(find.text(AppLocalizations.current.controlProtocolUseAuto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.controlProtocolUseAuto));
    await tester.pumpAndSettle();

    expect(def.controlProtocolOverride, isNull);
    expect(core.settings.getControlProtocolOverride(device.trainerKey), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a trainer with nothing to fall back to is told, without a useless CTA', (tester) async {
    final device = trainer();
    final def = device.fitnessBike!;

    await pumpSection(tester, device);
    def.gearEchoVerdict.value = ZwiftGearEchoVerdict.noFtmsToFallBackTo;
    await tester.pump();

    expect(find.text(AppLocalizations.current.controlProtocolIgnoredNoFallback), findsOneWidget);
    expect(find.text(AppLocalizations.current.controlProtocolUseAuto), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a healthy trainer shows no verdict notice', (tester) async {
    final device = trainer();
    await pumpSection(tester, device);
    expect(find.textContaining('acknowledg'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });
}
