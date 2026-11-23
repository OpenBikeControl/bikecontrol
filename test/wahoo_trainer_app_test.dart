import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_unlock.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/wahoo.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// The Wahoo app takes no controller input; BikeControl is a trainer to it,
/// doing the virtual shifting itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });
  tearDown(() => zwiftUnlockInProgress.value = false);

  /// The trainer names the Wahoo app lists a network trainer under.
  final listedName = RegExp(r'^Wahoo KICKR [0-9a-fA-F]{4,5}$');

  ProxyDevice deviceNamed(String? name) => ProxyDevice(BleDevice(deviceId: 'trainer', name: name));

  test('is offered in the trainer-app chooser', () {
    expect(SupportedApp.supportedApps.whereType<WahooApp>(), hasLength(1));
  });

  test('offers no controller connection method', () {
    final app = WahooApp();
    expect(app.connections, isEmpty);
    for (final method in AppConnectionMethod.values) {
      expect(app.supports(method), isFalse, reason: '$method');
    }
  });

  test('finds the bridge over Bluetooth and WiFi, on this or another device', () {
    final app = WahooApp();
    expect(app.virtualShiftingTransports, {TrainerConnectionType.bluetooth, TrainerConnectionType.wifi});
    expect(vsSameDeviceBlock(app), isNull);
    expect(Target.supportedFor(app), Target.values);
  });

  group('bridge name', () {
    setUp(() => core.settings.setTrainerApp(WahooApp()));

    test('is one the Wahoo app lists', () {
      for (final name in ['KICKR CORE 73D3', 'Wahoo KICKR 1EB7', 'Tacx Neo 2T 12345', 'Zwift Hub', 'KICKR', null, '']) {
        expect(deviceNamed(name).bridgeAdvertisementName(), matches(listedName), reason: 'trainer named "$name"');
      }
    });

    test('keeps the trainer\'s identifier with a B for Bridge', () {
      expect(deviceNamed('KICKR CORE 73D3').bridgeAdvertisementName(), 'Wahoo KICKR 73D3B');
      expect(deviceNamed('Wahoo KICKR 1EB7').bridgeAdvertisementName(), 'Wahoo KICKR 1EB7B');
    });

    test('never equals the trainer\'s own name', () {
      for (final name in ['Wahoo KICKR 1EB7', 'Wahoo KICKR 1EB7B', 'Wahoo KICKR BC000', 'Wahoo KICKR']) {
        expect(deviceNamed(name).bridgeAdvertisementName(), isNot(name), reason: 'trainer named "$name"');
      }
    });

    test('is stable for the same trainer and differs between trainers', () {
      final a = deviceNamed('Elite Suito').bridgeAdvertisementName();
      expect(deviceNamed('Elite Suito').bridgeAdvertisementName(), a);
      expect(deviceNamed('Elite Direto').bridgeAdvertisementName(), isNot(a));
    });

    test('drives the advertised name and follows the trainer app', () {
      final device = deviceNamed('KICKR CORE 73D3');
      final emulator = DirconEmulator()
        ..deviceName = (() => 'KICKR CORE 73D3')
        ..advertisementNameOverride = device.bridgeAdvertisementName;

      expect(emulator.advertisementName, 'Wahoo KICKR 73D3B');

      core.settings.setTrainerApp(Zwift());
      expect(emulator.advertisementName, 'BikeControl 73D3');
    });

    test('gives way to the Zwift name while a controller is unlocked', () {
      zwiftUnlockInProgress.value = true;
      expect(deviceNamed('KICKR CORE 73D3').bridgeAdvertisementName(), 'BikeControl 73D3');
    });
  });
}
