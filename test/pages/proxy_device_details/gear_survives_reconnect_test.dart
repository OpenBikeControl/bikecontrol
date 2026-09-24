// A trainer that drops and reconnects used to hand the rider back the middle
// gear every time. On a Van Rysel HT dropping every ~55 s that made virtual
// shifting unusable: the rider's gear was wiped within the minute, the overlay
// read a permanent 15/30, and the resistance never followed a shift because
// there was nothing left to follow. The definition is rebuilt per connection,
// so the gear has to be remembered outside it.
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
    core.actionHandler = StubActions();
    ProxyDevice.debugClearRememberedGears();
  });

  ProxyDevice trainer({String name = 'VANRYSEL-HT-0e66'}) {
    final device = ProxyDevice(
      BleDevice(
        deviceId: name,
        name: name,
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )..services = [BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [])];
    return device;
  }

  /// What a connect does: a brand-new definition, seeded from stored settings.
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

  test('the rider keeps their gear across a reconnect of the same trainer', () async {
    final device = trainer();
    final first = connect(device);
    final neutral = first.currentGear.value;

    first.setTargetGear(neutral + 6);
    await pumpEventQueue();
    final chosen = first.currentGear.value;
    expect(chosen, neutral + 6);

    // The drop: a fresh definition for the same trainer.
    final second = connect(device);

    expect(second.currentGear.value, chosen,
        reason: 'a reconnect must not hand back the middle gear');
  });

  test('a first connection still starts at the neutral gear', () async {
    final def = connect(trainer());
    expect(def.currentGear.value, def.neutralGear);
  });

  test('another trainer does not inherit the remembered gear', () async {
    final vanRysel = trainer();
    final first = connect(vanRysel);
    first.setTargetGear(first.currentGear.value + 4);
    await pumpEventQueue();

    final kickr = connect(trainer(name: 'KICKR CORE 5775'));
    expect(kickr.currentGear.value, kickr.neutralGear);
  });

  test('a remembered gear above the configured range is clamped, not dropped', () async {
    final device = trainer();
    final first = connect(device);
    first.setMaxGear(30);
    first.setTargetGear(28);
    await pumpEventQueue();

    // The rider then cuts the gear count down; the old gear no longer exists.
    await core.shiftingConfigs.upsert(
      core.shiftingConfigs.activeFor(device.trainerKey).copyWith(maxGear: 12, isActive: true),
    );
    final second = connect(device);

    expect(second.currentGear.value, lessThanOrEqualTo(second.maxGear));
    expect(second.currentGear.value, greaterThan(0));
  });
}
