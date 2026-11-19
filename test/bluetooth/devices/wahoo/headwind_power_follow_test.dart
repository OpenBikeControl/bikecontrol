import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// The Headwind following the trainer's power: BikeControl keeps the fan in
/// manual mode and moves its speed with the (smoothed) watts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<List<int>> writes;
  late int? watts;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    writes = [];
    watts = null;
  });

  WahooKickrHeadwind fan() => WahooKickrHeadwind(BleDevice(deviceId: 'hw-1', name: 'HEADWIND'))
    ..debugWriteSink = ((Uint8List b) async => writes.add(b.toList()))
    ..powerProvider = () => watts;

  /// Follow on without the 1 Hz timer, so each test drives the ticks itself.
  Future<WahooKickrHeadwind> following() async {
    final device = fan();
    device.follow.value = HeadwindFollow.power;
    return device;
  }

  group('speedForPower', () {
    test('is linear from 0 W to the full-speed power, in 5% steps', () {
      expect(WahooKickrHeadwind.speedForPower(0, 300), 0);
      expect(WahooKickrHeadwind.speedForPower(150, 300), 50);
      expect(WahooKickrHeadwind.speedForPower(100, 300), 35); // 33.3 → 35
      expect(WahooKickrHeadwind.speedForPower(300, 300), 100);
    });

    test('never goes past 100%', () {
      expect(WahooKickrHeadwind.speedForPower(900, 300), 100);
    });
  });

  test('the first tick puts the fan into manual mode at the speed for the power', () async {
    final device = await following();
    watts = 150;

    await device.powerTick();

    expect(writes, [
      [0x04, 0x04],
      [0x02, 50],
    ]);
    expect(device.speed.value, 50);
  });

  test('small power changes leave the fan alone', () async {
    final device = await following();
    watts = 150;
    await device.powerTick();
    writes.clear();

    watts = 165; // smoothed ≈ 154.5 W → 50%
    await device.powerTick();

    expect(writes, isEmpty);
  });

  test('a lasting power change moves the fan, smoothed', () async {
    final device = await following();
    watts = 150;
    await device.powerTick();
    writes.clear();

    watts = 300;
    await device.powerTick(); // 195 W → 65%
    expect(writes, [
      [0x02, 65],
    ]);
  });

  test('no power reading keeps the speed it has', () async {
    final device = await following();
    watts = null;

    await device.powerTick();

    expect(writes, isEmpty);
  });

  test('stopping pedalling eventually stops the fan', () async {
    final device = await following();
    watts = 150;
    await device.powerTick();
    watts = 0;
    for (var i = 0; i < 20; i++) {
      await device.powerTick();
    }

    expect(device.speed.value, 0);
  });

  test('setting a speed by hand ends power following', () async {
    final device = await following();

    await device.setSpeed(75);

    expect(device.followsPower, isFalse);
    expect(core.settings.getHeadwindFollowPower(), isFalse);
    expect(device.speed.value, 75);
  });

  test('the full-speed power is clamped and remembered', () async {
    final device = fan();

    await device.setFullPowerWatts(5000);

    expect(device.fullPowerWatts.value, WahooKickrHeadwind.maxFullPowerWatts);
    expect(core.settings.getHeadwindFullPowerWatts(), WahooKickrHeadwind.maxFullPowerWatts);
  });

  test('controller steps from a power-set speed stay valid', () async {
    final device = await following();
    watts = 100;
    await device.powerTick(); // 35%

    await device.setSpeed(60);

    expect(device.speed.value, 60);
  });

  group('ramp', () {
    test('is off up to the start, full from the full point, even in between', () {
      expect(WahooKickrHeadwind.speedForRamp(90, 100, 170), 0);
      expect(WahooKickrHeadwind.speedForRamp(100, 100, 170), 0);
      expect(WahooKickrHeadwind.speedForRamp(135, 100, 170), 50);
      expect(WahooKickrHeadwind.speedForRamp(170, 100, 170), 100);
      expect(WahooKickrHeadwind.speedForRamp(190, 100, 170), 100);
    });

    test('a power start point keeps the fan off at low watts', () async {
      final device = await following();
      await device.setStartPowerWatts(100);
      watts = 80;

      await device.powerTick();

      expect(device.speed.value, 0);
      expect(device.followInput.value, 80);
    });

    test('start and full points stay apart and are remembered', () async {
      final device = fan();

      await device.setStartPowerWatts(290);
      expect(device.startPowerWatts.value, 300 - WahooKickrHeadwind.minPowerRampWatts);
      await device.setFullPowerWatts(100);
      expect(device.fullPowerWatts.value, 250 + WahooKickrHeadwind.minPowerRampWatts);

      await device.setFullHeartRate(105);
      expect(device.fullHeartRate.value, 100 + WahooKickrHeadwind.minHeartRateRamp);
      expect(core.settings.getHeadwindFullHeartRate(), 110);
    });
  });

  group('heart rate', () {
    late int? bpm;

    WahooKickrHeadwind hrFan() {
      bpm = null;
      final device = fan()..heartRateProvider = (() => bpm);
      device.follow.value = HeadwindFollow.heartRate;
      return device;
    }

    test('sets the fan from the heart rate on its ramp', () async {
      final device = hrFan();
      bpm = 135;

      await device.followTick();

      expect(writes, [
        [0x04, 0x04],
        [0x02, 50],
      ]);
      expect(device.followInput.value, 135);
    });

    test('no heart rate keeps the speed and clears the reading', () async {
      final device = hrFan();

      await device.followTick();

      expect(writes, isEmpty);
      expect(device.followInput.value, isNull);
    });

    test('switching to heart rate ends power following and is remembered', () async {
      final device = await following();

      await device.setFollowHeartRate(true);
      expect(device.followsPower, isFalse);
      expect(core.settings.getHeadwindFollow(), 'heartRate');

      await device.setFollow(HeadwindFollow.none);
    });

    test('the controller heart-rate action follows the heart rate', () async {
      final device = hrFan()..follow.value = HeadwindFollow.none;
      bpm = 170;

      await device.handleKeypair(
        KeyPair(
          buttons: const [],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.headwindHeartRateMode,
        ),
        isKeyDown: true,
      );

      await pumpEventQueue();

      expect(device.followsHeartRate, isTrue);
      expect(device.speed.value, 100);
      await device.setFollow(HeadwindFollow.none);
    });
  });

  test('an old power-follow setting still reads as following power', () async {
    SharedPreferences.setMockInitialValues({'headwind_follow_power': true});
    core.settings.prefs = await SharedPreferences.getInstance();

    expect(core.settings.getHeadwindFollow(), 'power');
  });
}
