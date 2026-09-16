// The virtual-shifting mode picker used to show three bare labels (Target
// Power / Track Resistance / Basic) with no explanation of what each one
// does or which one a given trainer should use — a top support-chat driver
// ("switch Target Power → Track Resistance"), and at least one rider assumed
// Basic was the standard setting. This file pins:
//   * the capability-based default mode is marked "Recommended" on its card;
//   * a description of the *currently selected* mode is shown and updates
//     when the rider picks a different one;
//   * a mode the connected trainer does not actually support has its
//     description prefixed with a "not supported by this trainer" notice.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/ftms/ftms.dart';
import 'package:prop/transports/trainer_transport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// Keeps the definition's upstream writes off the real BLE stack. Mirrors
/// `test/pages/proxy_device_details/control_protocol_select_test.dart`'s
/// `_SilentTransport`: seeding a definition and switching virtual-shifting
/// mode both re-issue the current control state immediately, and the real
/// `universal_ble` transport parks a 10s timeout timer per write, which a
/// widget test would then fail on as a pending timer.
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

  /// A trainer driven over FE-C-over-BLE with no FTMS Control Point — case 1
  /// of `_isFecBleTrainer`'s doc comment (a non-FTMS smart trainer). Every
  /// virtual-shifting mode is carriable ([supportsVirtualShiftingMode] short
  /// circuits to true for any non-FTMS `controlProtocol`), and native grade
  /// shifters default to Track Resistance regardless of any FTMS feature probe.
  ProxyDevice fecTrainer() {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'fec-trainer',
        name: 'FE-C Smart Trainer',
        services: const [
          FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID,
          FitnessBikeDefinition.FEC_BLE_SERVICE_UUID,
        ],
      ),
    )..services = [
      BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, []),
      BleService(FitnessBikeDefinition.FEC_BLE_SERVICE_UUID, []),
    ];
    final fbd = FitnessBikeDefinition(
      connectedDevice: device.scanResult,
      connectedDeviceServices: device.services!,
      data: ValueNotifier(''),
      transport: _SilentTransport(),
    );
    device.debugAttachFitnessBike(fbd);
    return device;
  }

  /// A plain FTMS trainer whose Machine Feature probe reports it can hold a
  /// power target but cannot simulate grade — the capability-based default is
  /// Target Power, and Track Resistance is unsupported.
  ProxyDevice ftmsNoGradeTrainer() {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'old-ftms-trainer',
        name: 'Old FTMS Trainer',
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )..services = [
      BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [
        BleCharacteristic(FitnessBikeDefinition.FITNESS_MACHINE_CONTROL_POINT_UUID, [
          CharacteristicProperty.write,
          CharacteristicProperty.indicate,
        ], []),
      ]),
    ];
    final fbd = FitnessBikeDefinition(
      connectedDevice: device.scanResult,
      connectedDeviceServices: device.services!,
      data: ValueNotifier(''),
      transport: _SilentTransport(),
    );
    fbd.setTrainerFeatureForTesting(
      MachineFeature(MachineFeature.build(targetSettings: {TargetSettingFlag.powerTargetSettingFlag})),
    );
    device.debugAttachFitnessBike(fbd);
    return device;
  }

  Future<void> pumpCard(WidgetTester tester, ProxyDevice device) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(
          child: VirtualShiftingModeCard(definition: device.fitnessBike!, device: device),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the capability-based default mode is Recommended and its description shows', (tester) async {
    final device = fecTrainer();
    final def = device.fitnessBike!;
    // Sanity on the fixture itself before asserting on the widget.
    expect(def.defaultVirtualShiftingMode, VirtualShiftingMode.trackResistance);
    expect(def.virtualShiftingMode.value, VirtualShiftingMode.trackResistance);

    await pumpCard(tester, device);

    final trackResistanceCard = find.byWidgetPredicate(
      (w) => w is RadioCard<VirtualShiftingMode> && w.value == VirtualShiftingMode.trackResistance,
    );
    expect(trackResistanceCard, findsOneWidget);
    expect(
      find.descendant(of: trackResistanceCard, matching: find.text(AppLocalizations.current.vsModeRecommended)),
      findsOneWidget,
    );
    expect(find.text(AppLocalizations.current.vsModeTrackResistanceDesc), findsOneWidget);
  });

  testWidgets('selecting Target Power switches the description', (tester) async {
    final device = fecTrainer();
    await pumpCard(tester, device);
    expect(find.text(AppLocalizations.current.vsModeTrackResistanceDesc), findsOneWidget);

    await tester.tap(find.text(AppLocalizations.current.targetPowerMode));
    await tester.pump();

    expect(find.text(AppLocalizations.current.vsModeTargetPowerDesc), findsOneWidget);
    expect(find.text(AppLocalizations.current.vsModeTrackResistanceDesc), findsNothing);

    // The mode switch re-issues the current control state immediately (see
    // FitnessBikeDefinition.setVirtualShiftingMode), which parks a control-write
    // bookkeeping timer; drain it so the binding's pending-timer check passes —
    // mirrors control_protocol_select_test.dart's identical fixture note.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets("an unsupported mode's description is prefixed with the unsupported notice", (tester) async {
    final device = ftmsNoGradeTrainer();
    final def = device.fitnessBike!;
    expect(def.defaultVirtualShiftingMode, VirtualShiftingMode.targetPower);
    expect(def.supportsVirtualShiftingMode(VirtualShiftingMode.trackResistance), isFalse);
    // Mirrors a rider whose saved preference (Track Resistance, from a more
    // capable trainer) survived a reconnect onto this lesser one.
    def.setVirtualShiftingMode(VirtualShiftingMode.trackResistance);

    await pumpCard(tester, device);

    expect(
      find.text('${AppLocalizations.current.vsModeUnsupported}${AppLocalizations.current.vsModeTrackResistanceDesc}'),
      findsOneWidget,
    );

    // Drain the control-write bookkeeping timer (generic 1s) plus the FTMS
    // control-point handshake's own fallback timer (400ms) that this fixture's
    // write additionally parks — both must clear before teardown.
    await tester.pump(const Duration(seconds: 1));
  });
}
