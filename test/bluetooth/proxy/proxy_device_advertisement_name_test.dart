import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_unlock.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/tacx.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:prop/prop.dart' show mdnsSerialNumber;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// The name and bind behaviour the bridge picks per trainer app. What each
/// endpoint advertises is covered in `prop`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });
  tearDown(() => zwiftUnlockInProgress.value = false);

  ProxyDevice deviceNamed(String? name) => ProxyDevice(BleDevice(deviceId: 'trainer', name: name));

  test('is the trainer name with a neutral suffix', () {
    core.settings.setTrainerApp(Rouvy());

    expect(deviceNamed('Wahoo KICKR 1EB7').bridgeAdvertisementName(), 'Wahoo KICKR 1EB7 - Bridge');
  });

  test('is neutral whatever the trainer is called', () {
    core.settings.setTrainerApp(Rouvy());

    for (final name in ['Wahoo KICKR 1EB7', 'BikeControl V2', 'bikecontrol', null, '']) {
      expect(
        deviceNamed(name).bridgeAdvertisementName()!.toLowerCase(),
        isNot(contains('bikecontrol')),
        reason: 'trainer named "$name"',
      );
    }
  });

  test('falls back to the bare suffix when the trainer has no usable name', () {
    core.settings.setTrainerApp(Rouvy());

    expect(deviceNamed(null).bridgeAdvertisementName(), 'Bridge');
    expect(deviceNamed('').bridgeAdvertisementName(), 'Bridge');
    expect(deviceNamed('BikeControl V2').bridgeAdvertisementName(), 'Bridge');
  });

  group('Zwift', () {
    setUp(() => core.settings.setTrainerApp(Zwift()));

    test('is BikeControl plus the trainer\'s trailing identifier', () {
      expect(deviceNamed('KICKR CORE 73D3').bridgeAdvertisementName(), 'BikeControl 73D3');
      expect(deviceNamed('Wahoo KICKR 1EB7').bridgeAdvertisementName(), 'BikeControl 1EB7');
    });

    test('is plain BikeControl when the trainer has no name', () {
      expect(deviceNamed(null).bridgeAdvertisementName(), 'BikeControl');
      expect(deviceNamed('').bridgeAdvertisementName(), 'BikeControl');
      expect(deviceNamed('   ').bridgeAdvertisementName(), 'BikeControl');
    });

    test('is plain BikeControl when the name has no trailing identifier', () {
      expect(deviceNamed('KICKR').bridgeAdvertisementName(), 'BikeControl');
      expect(deviceNamed('Wahoo KICKR').bridgeAdvertisementName(), 'BikeControl');
    });

    test('neither contains the trainer name nor is contained in it', () {
      for (final name in [
        'KICKR CORE 73D3',
        'Wahoo KICKR 1EB7',
        'KICKR',
        '73D3',
        'BikeControl',
        'bikecontrol',
        'BikeControl 73D3',
        'BikeControl V2',
        'My BikeControl Bridge 2',
      ]) {
        final advertised = deviceNamed(name).bridgeAdvertisementName()!.toLowerCase();
        final trainer = name.toLowerCase();
        expect(advertised, isNot(contains(trainer)), reason: 'trainer named "$name"');
        expect(trainer, isNot(contains(advertised)), reason: 'trainer named "$name"');
      }
    });

    test('a trainer named like BikeControl gets a name that does not overlap', () {
      expect(deviceNamed('BikeControl').bridgeAdvertisementName(), 'Bridge');
      expect(deviceNamed('BikeControl 73D3').bridgeAdvertisementName(), 'Bridge');
    });
  });

  test('is not imposed on any other trainer app', () {
    for (final app in [MyWhoosh(), TrainingPeaks(), Tacx()]) {
      core.settings.setTrainerApp(app);
      expect(deviceNamed('Wahoo KICKR 1EB7').bridgeAdvertisementName(), isNull, reason: app.name);
    }
  });

  test('MyWhoosh keeps the trainer name with the BikeControl suffix', () {
    core.settings.setTrainerApp(MyWhoosh());
    final device = deviceNamed('KICKR CORE 73D3');
    final emulator = DirconEmulator()
      ..deviceName = (() => 'KICKR CORE 73D3')
      ..advertisementNameOverride = device.bridgeAdvertisementName;

    expect(emulator.advertisementName, 'KICKR CORE 73D3 - BikeControl');
  });

  test('the advertised name follows the trainer app as it changes', () {
    final device = deviceNamed('KICKR CORE 73D3');
    final emulator = DirconEmulator()
      ..deviceName = (() => 'KICKR CORE 73D3')
      ..advertisementNameOverride = device.bridgeAdvertisementName;

    core.settings.setTrainerApp(Zwift());
    expect(emulator.advertisementName, 'BikeControl 73D3');

    core.settings.setTrainerApp(Rouvy());
    expect(emulator.advertisementName, 'KICKR CORE 73D3 - Bridge');

    core.settings.setTrainerApp(MyWhoosh());
    expect(emulator.advertisementName, 'KICKR CORE 73D3 - BikeControl');

    core.settings.setTrainerApp(Zwift());
    expect(emulator.advertisementName, 'BikeControl 73D3');
  });

  test('binds IPv4-only for Rouvy and dual-stack for everyone else', () {
    core.settings.setTrainerApp(Rouvy());
    expect(deviceNamed('Wahoo KICKR 1EB7').rouvyNeedsIPv4(), isTrue);

    core.settings.setTrainerApp(Zwift());
    expect(deviceNamed('Wahoo KICKR 1EB7').rouvyNeedsIPv4(), isFalse);
  });

  group('serial number', () {
    const deviceId = 'E4:3B:1C:73:D3:01';
    String serialOf(ProxyDevice device) => String.fromCharCodes(device.trainerMdnsTxt()['serial-number']!);
    ProxyDevice deviceIn(RetrofitMode mode, {String id = deviceId}) =>
        ProxyDevice(BleDevice(deviceId: id, name: 'KICKR CORE 73D3'))..setRetrofitMode(mode);

    test('the Zwift-named bridge gets its own stable, all-digit serial', () {
      core.settings.setTrainerApp(Zwift());
      for (final mode in [RetrofitMode.wifi, RetrofitMode.bluetooth]) {
        final serial = serialOf(deviceIn(mode));
        expect(serial, matches(RegExp(r'^[0-9]+$')), reason: mode.name);
        expect(serial, isNot(mdnsSerialNumber(deviceId)), reason: mode.name);
        expect(serialOf(deviceIn(mode)), serial, reason: 'same trainer, same serial');
      }
      expect(serialOf(deviceIn(RetrofitMode.wifi, id: 'other')), isNot(serialOf(deviceIn(RetrofitMode.wifi))));
    });

    test('proxy mode keeps the device serial for Zwift', () {
      core.settings.setTrainerApp(Zwift());
      expect(serialOf(deviceIn(RetrofitMode.proxy)), mdnsSerialNumber(deviceId));
    });

    test('every other trainer app keeps the device serial', () {
      for (final app in [MyWhoosh(), Rouvy(), TrainingPeaks(), Tacx()]) {
        core.settings.setTrainerApp(app);
        for (final mode in RetrofitMode.values) {
          expect(serialOf(deviceIn(mode)), mdnsSerialNumber(deviceId), reason: '${app.name} ${mode.name}');
        }
      }
    });

    test('follows the trainer app as it changes', () {
      final device = deviceIn(RetrofitMode.wifi);

      core.settings.setTrainerApp(MyWhoosh());
      expect(serialOf(device), mdnsSerialNumber(deviceId));

      core.settings.setTrainerApp(Zwift());
      expect(serialOf(device), isNot(mdnsSerialNumber(deviceId)));

      core.settings.setTrainerApp(Rouvy());
      expect(serialOf(device), mdnsSerialNumber(deviceId));
    });

    // universal_ble 3 reports ids lower-case; trainer apps paired the serial
    // derived from the id as universal_ble 2 reported it, so it must not move.
    group('survives the lower-case device ids of universal_ble 3', () {
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]) {
        test(platform.name, () {
          debugDefaultTargetPlatformOverride = platform;
          for (final app in [MyWhoosh(), Zwift()]) {
            core.settings.setTrainerApp(app);
            for (final mode in RetrofitMode.values) {
              expect(
                serialOf(deviceIn(mode, id: deviceId.toLowerCase())),
                serialOf(deviceIn(mode)),
                reason: '${app.name} ${mode.name}',
              );
            }
          }
        });
      }

      test('windows, which always reported lower-case', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        core.settings.setTrainerApp(MyWhoosh());
        expect(
          serialOf(deviceIn(RetrofitMode.wifi, id: deviceId.toLowerCase())),
          mdnsSerialNumber(deviceId.toLowerCase()),
        );
      });
    });

    test('keeps the mac-address and app fields alongside it', () {
      core.settings.setTrainerApp(Zwift());
      expect(deviceIn(RetrofitMode.wifi).trainerMdnsTxt().keys, containsAll(['mac-address', 'serial-number']));
      core.settings.setTrainerApp(Tacx());
      expect(deviceIn(RetrofitMode.wifi).trainerMdnsTxt().keys, contains('product-id'));
    });
  });

  // While an unlock page waits for Zwift, the bridge has to be listable in
  // Zwift, whatever trainer app is selected — and only then.
  group('while a controller is being unlocked', () {
    const deviceId = 'E4:3B:1C:73:D3:01';
    String serialOf(ProxyDevice device) => String.fromCharCodes(device.trainerMdnsTxt()['serial-number']!);
    ProxyDevice bridged() =>
        ProxyDevice(BleDevice(deviceId: deviceId, name: 'KICKR CORE 73D3'))..setRetrofitMode(RetrofitMode.wifi);
    DirconEmulator emulatorFor(ProxyDevice device) => DirconEmulator()
      ..deviceName = (() => 'KICKR CORE 73D3')
      ..advertisementNameOverride = device.bridgeAdvertisementName;

    test('MyWhoosh: the Zwift name and serial during the unlock, exactly the old ones after', () {
      core.settings.setTrainerApp(MyWhoosh());
      final device = bridged();
      final emulator = emulatorFor(device);
      final normalSerial = serialOf(device);
      expect(emulator.advertisementName, 'KICKR CORE 73D3 - BikeControl');
      expect(normalSerial, mdnsSerialNumber(deviceId));

      zwiftUnlockInProgress.value = true;
      expect(emulator.advertisementName, 'BikeControl 73D3');
      core.settings.setTrainerApp(Zwift());
      final zwiftSerial = serialOf(device);
      core.settings.setTrainerApp(MyWhoosh());
      expect(serialOf(device), zwiftSerial);

      zwiftUnlockInProgress.value = false;
      expect(emulator.advertisementName, 'KICKR CORE 73D3 - BikeControl');
      expect(serialOf(device), normalSerial);
    });

    test('other trainer apps behave like MyWhoosh', () {
      for (final app in [TrainingPeaks(), Tacx()]) {
        core.settings.setTrainerApp(app);
        final emulator = emulatorFor(bridged());
        zwiftUnlockInProgress.value = true;
        expect(emulator.advertisementName, 'BikeControl 73D3', reason: app.name);
        zwiftUnlockInProgress.value = false;
        expect(emulator.advertisementName, 'KICKR CORE 73D3 - BikeControl', reason: app.name);
      }
    });

    test('Zwift is unchanged', () {
      core.settings.setTrainerApp(Zwift());
      final device = bridged();
      final emulator = emulatorFor(device);
      final serial = serialOf(device);
      zwiftUnlockInProgress.value = true;
      expect(emulator.advertisementName, 'BikeControl 73D3');
      expect(serialOf(device), serial);
    });

    test('Rouvy keeps its own name and the device serial', () {
      core.settings.setTrainerApp(Rouvy());
      final device = bridged();
      final emulator = emulatorFor(device);
      zwiftUnlockInProgress.value = true;
      expect(emulator.advertisementName, 'KICKR CORE 73D3 - Bridge');
      expect(serialOf(device), mdnsSerialNumber(deviceId));
    });

    test('proxy mode keeps the device serial', () {
      core.settings.setTrainerApp(MyWhoosh());
      final device = ProxyDevice(BleDevice(deviceId: deviceId, name: 'KICKR CORE 73D3'))
        ..setRetrofitMode(RetrofitMode.proxy);
      zwiftUnlockInProgress.value = true;
      expect(serialOf(device), mdnsSerialNumber(deviceId));
    });
  });

  group('beginning and ending the unlock', () {
    late _CountingEmulator emulator;
    setUp(() {
      core.settings.setTrainerApp(MyWhoosh());
      final device = ProxyDevice(BleDevice(deviceId: 'trainer', name: 'KICKR CORE 73D3'))
        ..setRetrofitMode(RetrofitMode.wifi);
      emulator = _CountingEmulator()
        ..deviceName = (() => 'KICKR CORE 73D3')
        ..advertisementNameOverride = device.bridgeAdvertisementName
        ..isStarted.value = true;
    });

    test('re-advertises a running bridge on the way in and on the way out', () async {
      await setZwiftUnlockInProgress(true, emulator: emulator);
      expect(zwiftUnlockInProgress.value, isTrue);
      expect(emulator.restarts, 1);
      expect(emulator.namesAtRestart, ['BikeControl 73D3']);

      await setZwiftUnlockInProgress(false, emulator: emulator);
      expect(zwiftUnlockInProgress.value, isFalse);
      expect(emulator.restarts, 2);
      expect(emulator.namesAtRestart.last, 'KICKR CORE 73D3 - BikeControl');
    });

    test('leaves the bridge alone when nothing it advertises changes', () async {
      core.settings.setTrainerApp(Zwift());
      await setZwiftUnlockInProgress(true, emulator: emulator);
      await setZwiftUnlockInProgress(false, emulator: emulator);
      expect(emulator.restarts, 0);
    });

    test('does not start a bridge that is not running', () async {
      emulator.isStarted.value = false;
      await setZwiftUnlockInProgress(true, emulator: emulator);
      expect(zwiftUnlockInProgress.value, isTrue);
      expect(emulator.restarts, 0);
    });

    test('a failed re-advertise is reported, and the state still changes', () async {
      emulator.failRestart = true;
      await setZwiftUnlockInProgress(true, emulator: emulator);
      expect(zwiftUnlockInProgress.value, isTrue);
      await setZwiftUnlockInProgress(false, emulator: emulator);
      expect(zwiftUnlockInProgress.value, isFalse);
    });
  });
}

class _CountingEmulator extends DirconEmulator {
  int restarts = 0;
  bool failRestart = false;
  final namesAtRestart = <String>[];

  @override
  Future<void> restart() async {
    restarts++;
    namesAtRestart.add(advertisementName);
    if (failRestart) throw StateError('restart failed');
  }
}
