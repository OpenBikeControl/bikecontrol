// The transport a fresh connect starts in is decided in one place for the
// auto-connect path and the connection card alike, so a Bluetooth choice the
// card would never offer under Target.thisDevice can't sneak back in via
// auto-connect on the next launch and run a bridge the app on this device
// cannot see.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  Future<void> seed({String? target, String? savedMode, String? trainerApp}) async {
    SharedPreferences.setMockInitialValues({
      if (target != null) 'last_target': target,
      if (trainerApp != null) 'trainer_app': trainerApp,
      if (savedMode != null) 'retrofit_mode_KICKR CORE': savedMode,
    });
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  }

  ProxyDevice smartTrainer() => ProxyDevice(
    BleDevice(
      deviceId: 'y',
      name: 'KICKR CORE',
      services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
    ),
  );

  test('a saved Bluetooth transport becomes WiFi while the trainer app runs on this device', () async {
    await seed(target: 'thisDevice', savedMode: 'bluetooth');
    expect(smartTrainer().savedRetrofitMode, RetrofitMode.wifi);
  });

  test('the same saved Bluetooth transport stays Bluetooth for another device', () async {
    await seed(target: 'otherDevice', savedMode: 'bluetooth');
    expect(smartTrainer().savedRetrofitMode, RetrofitMode.bluetooth);
  });

  test('WiFi and Proxy pass through untouched on this device', () async {
    await seed(target: 'thisDevice', savedMode: 'wifi');
    expect(smartTrainer().savedRetrofitMode, RetrofitMode.wifi);

    await seed(target: 'thisDevice', savedMode: 'proxy');
    expect(smartTrainer().savedRetrofitMode, RetrofitMode.proxy);
  });

  test('nothing saved falls back to the default transport', () async {
    await seed(target: 'thisDevice');
    // No trainer connection enabled → the smart-trainer default is VS over WiFi.
    expect(smartTrainer().savedRetrofitMode, RetrofitMode.wifi);
  });

  // Biketerra takes its trainer over Bluetooth only: a saved or default WiFi
  // transport would start a bridge it never finds.
  test('a saved WiFi transport becomes Bluetooth for a Bluetooth-only trainer app', () async {
    await seed(target: 'otherDevice', savedMode: 'wifi', trainerApp: 'Biketerra');
    expect(smartTrainer().savedRetrofitMode, RetrofitMode.bluetooth);
  });

  test('the WiFi default becomes Bluetooth for a Bluetooth-only trainer app', () async {
    await seed(target: 'otherDevice', trainerApp: 'Biketerra');
    expect(smartTrainer().savedRetrofitMode, RetrofitMode.bluetooth);
  });

  test('a saved Proxy becomes Bluetooth Virtual Shifting for a Bluetooth-only trainer app', () async {
    // Proxy mirrors the trainer over WiFi only — just as unreachable.
    await seed(target: 'otherDevice', savedMode: 'proxy', trainerApp: 'Biketerra');
    expect(smartTrainer().savedRetrofitMode, RetrofitMode.bluetooth);
  });

  test('a WiFi-capable trainer app keeps a saved WiFi transport and Proxy', () async {
    await seed(target: 'otherDevice', savedMode: 'wifi', trainerApp: 'MyWhoosh');
    expect(smartTrainer().savedRetrofitMode, RetrofitMode.wifi);
    await seed(target: 'otherDevice', savedMode: 'proxy', trainerApp: 'MyWhoosh');
    expect(smartTrainer().savedRetrofitMode, RetrofitMode.proxy);
  });
}
