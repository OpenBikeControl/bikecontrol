// The rider's escape hatch for a trainer BikeControl is talking to over the
// wrong wire: a per-trainer control-protocol override living in the Virtual
// Shifting options.
//
// Three things have to hold, and each is a separate support disaster when it
// doesn't: the selector only appears when the trainer can genuinely carry more
// than one protocol (otherwise it offers a path where every write dies), the
// choice is remembered, and — because the prop-level override lives on the
// FitnessBikeDefinition, which is rebuilt from scratch on every connect — it
// comes back after a reconnect instead of silently reverting to auto.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
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

/// Keeps the definition's upstream writes off the real BLE stack. Seeding a
/// definition and switching protocols both re-issue the current control state
/// immediately, and universal_ble's command queue parks a 10 s timeout timer
/// per write — which a widget test would then fail on as a pending timer.
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
  Future<void> write(
    String service,
    String characteristic,
    Uint8List bytes, {
    bool withoutResponse = false,
  }) async {}

  @override
  Future<void> subscribe(String service, String characteristic, {required bool indicate}) async {}

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

  /// Mirrors prop's `makeDualProtocol()`: the FTMS service *with* its Control
  /// Point characteristic — `supportedControlProtocols` gates the ftms entry on
  /// the Control Point, not the service — plus the Zwift custom service. That
  /// is a Zwift-Cog KICKR CORE: two deliveries it can actually carry, so the
  /// rider gets a real choice.
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

  /// A plain FTMS trainer: one carriable delivery, so the selector has nothing
  /// to offer.
  List<BleService> singleProtocolServices() => [
    BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, []),
  ];

  /// What `ProxyDevice._buildDefinitions` produces on every connect: a fresh
  /// definition with no override set on it yet.
  FitnessBikeDefinition freshDefinition(ProxyDevice device) => FitnessBikeDefinition(
    connectedDevice: device.scanResult,
    connectedDeviceServices: device.services!,
    data: ValueNotifier(''),
    transport: _SilentTransport(),
  );

  ProxyDevice trainer(List<BleService> services, {String name = 'KICKR CORE'}) {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'kickr',
        name: name,
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )..services = services;
    device.debugAttachFitnessBike(freshDefinition(device));
    return device;
  }

  Future<void> pumpSection(
    WidgetTester tester,
    ProxyDevice device, {
    Future<void> Function()? reconnect,
  }) async {
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
                // Keep widget tests off the real connection manager.
                reconnectDevice: reconnect ?? () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Ends a test whose pick reached [FitnessBikeDefinition.setControlProtocolOverride].
  /// An accepted pick re-issues the control state at once, and that write
  /// opens the definition's one-shot control-write pacing window (a
  /// [FitnessBikeDefinition.minControlWriteInterval] timer). These trainers
  /// are in plain SIM, where nothing is deferred into the window, so it just
  /// closes; let it close rather than leave the timer pending when the test
  /// ends.
  Future<void> letControlWritePacingWindowClose(WidgetTester tester) =>
      tester.pump(FitnessBikeDefinition.minControlWriteInterval);

  testWidgets('selector hidden for single-protocol trainer', (tester) async {
    final device = trainer(singleProtocolServices());
    expect(device.fitnessBike!.supportedControlProtocols, {TrainerControlProtocol.ftms});

    await pumpSection(tester, device);

    expect(find.text(AppLocalizations.current.controlProtocolLabel), findsNothing);

    // The FTMS-only fixture's seeding write starts the control-grant 400ms
    // fallback timer (7cfedd4); drain it so the binding's timer check passes.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('selector shown for dual-protocol trainer and persists choice', (tester) async {
    final device = trainer(dualProtocolServices());
    final def = device.fitnessBike!;
    expect(def.supportedControlProtocols, {TrainerControlProtocol.ftms, TrainerControlProtocol.zwiftHub});

    await pumpSection(tester, device);
    expect(find.text(AppLocalizations.current.controlProtocolLabel), findsOneWidget);

    await tester.tap(find.byType(Select<TrainerControlProtocol?>));
    await tester.pumpAndSettle();
    // The closed select shows the Auto placeholder, so the popup entries are
    // the *later* matches.
    await tester.tap(find.text(AppLocalizations.current.controlProtocolZwift).last);
    await tester.pumpAndSettle();

    expect(def.controlProtocolOverride, TrainerControlProtocol.zwiftHub);
    expect(core.settings.getControlProtocolOverride(device.trainerKey), 'zwiftHub');
    await letControlWritePacingWindowClose(tester);
  });

  testWidgets('switching to a different effective protocol cycles the connection', (tester) async {
    final device = trainer(dualProtocolServices());
    var reconnects = 0;
    await pumpSection(tester, device, reconnect: () async => reconnects++);

    await tester.tap(find.byType(Select<TrainerControlProtocol?>));
    await tester.pumpAndSettle();
    // Auto on this fixture is zwiftHub, so forcing FTMS changes the delivery.
    await tester.tap(find.text(AppLocalizations.current.controlProtocolFtms).last);
    await tester.pumpAndSettle();

    expect(device.fitnessBike!.controlProtocol, TrainerControlProtocol.ftms);
    expect(reconnects, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an inert selection (same effective protocol) does not cycle the connection', (tester) async {
    final device = trainer(dualProtocolServices());
    var reconnects = 0;
    await pumpSection(tester, device, reconnect: () async => reconnects++);

    await tester.tap(find.byType(Select<TrainerControlProtocol?>));
    await tester.pumpAndSettle();
    // Explicitly picking "Zwift protocol" on an auto-zwiftHub trainer is the
    // documented inert choice — no delivery change, so no reconnect.
    await tester.tap(find.text(AppLocalizations.current.controlProtocolZwift).last);
    await tester.pumpAndSettle();

    expect(device.fitnessBike!.controlProtocol, TrainerControlProtocol.zwiftHub);
    expect(reconnects, 0);
    await letControlWritePacingWindowClose(tester);
  });

  testWidgets('picking Auto again clears the stored override', (tester) async {
    final device = trainer(dualProtocolServices());
    final def = device.fitnessBike!;
    await core.settings.setControlProtocolOverride(device.trainerKey, 'ftms');
    def.setControlProtocolOverride(TrainerControlProtocol.ftms);

    await pumpSection(tester, device);

    await tester.tap(find.byType(Select<TrainerControlProtocol?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.controlProtocolAuto).last);
    await tester.pumpAndSettle();

    expect(def.controlProtocolOverride, isNull);
    // Removed, not stored as the string 'null' — a stale key would out-live the
    // rider's decision to go back to auto.
    expect(core.settings.getControlProtocolOverride(device.trainerKey), isNull);
    await letControlWritePacingWindowClose(tester);
  });

  test('applyTrainerSettings applies a stored override', () async {
    SharedPreferences.setMockInitialValues({'control_protocol_KICKR CORE': 'zwiftHub'});
    core.settings.prefs = await SharedPreferences.getInstance();

    final device = trainer(dualProtocolServices());
    expect(device.fitnessBike!.controlProtocolOverride, isNull);

    device.applyTrainerSettings();

    expect(device.fitnessBike!.controlProtocolOverride, TrainerControlProtocol.zwiftHub);
  });

  test('a stored override survives the definition rebuild on reconnect', () async {
    final device = trainer(dualProtocolServices());
    // The rider forces FTMS on this Zwift-Cog trainer, exactly as the selector
    // does: prop-level override + persisted pref.
    device.fitnessBike!.setControlProtocolOverride(TrainerControlProtocol.ftms);
    await core.settings.setControlProtocolOverride(device.trainerKey, 'ftms');

    // Reconnect: ProxyDevice builds a brand-new FitnessBikeDefinition from the
    // rediscovered services, which resets the prop-level override…
    final rebuilt = freshDefinition(device);
    expect(rebuilt.controlProtocolOverride, isNull);
    device.debugAttachFitnessBike(rebuilt);

    // …and the seeding path has to put the rider's choice back, or the trainer
    // silently returns to the protocol they just told us not to use.
    device.applyTrainerSettings();

    expect(rebuilt.controlProtocolOverride, TrainerControlProtocol.ftms);
    expect(rebuilt.controlProtocol, TrainerControlProtocol.ftms);
  });

  test('an unknown stored protocol name leaves the definition on auto', () async {
    SharedPreferences.setMockInitialValues({'control_protocol_KICKR CORE': 'antPlusOverCarrierPigeon'});
    core.settings.prefs = await SharedPreferences.getInstance();

    final device = trainer(dualProtocolServices());

    device.applyTrainerSettings();

    expect(device.fitnessBike!.controlProtocolOverride, isNull);
  });
}
