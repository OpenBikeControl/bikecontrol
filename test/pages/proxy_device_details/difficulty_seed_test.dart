// The definition is rebuilt on every connect, so the rider's calibrated
// difficulty has to be seeded from their shifting config each time, or the
// calibration would be lost on the next drop.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/transports/trainer_transport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    await core.shiftingConfigs.init();
    core.actionHandler = StubActions();
  });

  FitnessBikeDefinition connect(ProxyDevice device) {
    final def = FitnessBikeDefinition(
      connectedDevice: device.scanResult,
      connectedDeviceServices: device.services!,
      data: ValueNotifier(''),
      transport: _SilentTransport(),
    );
    addTearDown(def.dispose);
    device.debugAttachFitnessBike(def);
    device.applyTrainerSettings();
    return def;
  }

  // Distinct names per test: core.shiftingConfigs keeps the prefs instance it
  // was built with, so a config one test stores outlives the mock reset.
  ProxyDevice trainer(String name) => ProxyDevice(
    BleDevice(
      deviceId: name,
      name: name,
      services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
    ),
  )..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])];

  test('a connect seeds the stored difficulty', () async {
    final device = trainer('KICKR CORE 1');
    await core.shiftingConfigs.upsert(
      core.shiftingConfigs.activeFor(device.trainerKey).copyWith(difficultyPct: 70),
    );
    expect(connect(device).difficultyPct.value, 70);
  });

  test('a trainer that was never calibrated rides at the default', () {
    expect(connect(trainer('KICKR CORE 2')).difficultyPct.value, FitnessBikeDefinition.defaultDifficultyPct);
  });
}
