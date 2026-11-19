import 'dart:async';
import 'dart:math' as math;

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class WahooKickrHeadwind extends BluetoothDevice with Accessory {
  /// The speeds the page offers in manual mode, in percent.
  static const allowedSpeeds = [0, 25, 50, 75, 100];

  /// What the fan reports (or was last told) it is doing — the page's direct
  /// controls render from these.
  final ValueNotifier<HeadwindMode> mode = ValueNotifier(HeadwindMode.unknown);
  final ValueNotifier<int> speed = ValueNotifier(0);

  HeadwindMode get _currentMode => mode.value;
  set _currentMode(HeadwindMode value) => mode.value = value;
  int get _currentSpeed => speed.value;
  set _currentSpeed(int value) => speed.value = value;

  /// What BikeControl drives the fan from, if anything. While following, the
  /// fan sits in manual mode and gets a new speed whenever its input moves
  /// enough.
  final ValueNotifier<HeadwindFollow> follow = ValueNotifier(HeadwindFollow.none);

  /// Whether the fan follows the trainer's power — see [follow].
  bool get followsPower => follow.value == HeadwindFollow.power;

  /// Whether the fan follows the rider's heart rate — see [follow].
  bool get followsHeartRate => follow.value == HeadwindFollow.heartRate;

  /// The ramp for power: off up to [startPowerWatts], 100% from
  /// [fullPowerWatts], evenly in between.
  final ValueNotifier<int> startPowerWatts = ValueNotifier(defaultStartPowerWatts);
  final ValueNotifier<int> fullPowerWatts = ValueNotifier(defaultFullPowerWatts);

  /// The ramp for heart rate: off up to [startHeartRate], 100% from
  /// [fullHeartRate], evenly in between.
  final ValueNotifier<int> startHeartRate = ValueNotifier(defaultStartHeartRate);
  final ValueNotifier<int> fullHeartRate = ValueNotifier(defaultFullHeartRate);

  /// The smoothed input (watts or bpm) the last speed came from; null while
  /// not following or while nothing reports a reading. Shown on the page so
  /// the rider sees why the fan runs at the speed it does.
  final ValueNotifier<int?> followInput = ValueNotifier(null);

  static const defaultStartPowerWatts = 0;
  static const defaultFullPowerWatts = 300;
  static const minStartPowerWatts = 0;
  static const minFullPowerWatts = 100;
  static const maxFullPowerWatts = 1000;

  /// The full-speed point stays at least this far above the start.
  static const minPowerRampWatts = 50;

  static const defaultStartHeartRate = 100;
  static const defaultFullHeartRate = 170;
  static const minStartHeartRate = 50;
  static const minFullHeartRate = 100;
  static const maxFullHeartRate = 220;
  static const minHeartRateRamp = 10;

  /// The current power in watts, null when nothing reports one. Defaults to
  /// the connected trainer (or a power meter); tests swap it.
  @visibleForTesting
  int? Function() powerProvider = () => core.rideSource()?.powerW.value;

  /// The current heart rate in bpm, null when nothing reports one. Defaults
  /// to what the ride records (trainer or strap), else any connected strap;
  /// tests swap it.
  @visibleForTesting
  int? Function() heartRateProvider = _currentHeartRate;

  static int? _currentHeartRate() {
    final fromRide = core.rideSource()?.heartRateBpm.value;
    if (fromRide != null && fromRide > 0) return fromRide;
    final now = DateTime.now();
    final sources = core.sensors.sources.where((s) => s.provides.contains(SensorQuantity.heartRate)).toList();
    final chosen = core.sensors.selectionFor(SensorQuantity.heartRate);
    sources.sort((a, b) => (a.id == chosen ? 0 : 1) - (b.id == chosen ? 0 : 1));
    for (final source in sources) {
      final reading = source.readingFor(SensorQuantity.heartRate).value;
      if (reading != null && reading.value > 0 && now.difference(reading.timestamp) <= source.ttl) {
        return reading.value;
      }
    }
    return null;
  }

  Timer? _followTimer;
  double? _smoothed;
  bool _ticking = false;

  /// Speeds are written in 5% steps, and only once they move this far, so the
  /// fan doesn't hunt with every pedal stroke.
  static const speedStep = 5;
  static const speedHysteresis = 10;

  /// Weight of the newest sample in the moving average (1 Hz ticks: ~5 s).
  static const _smoothing = 0.3;

  /// The fan speed (0–100, in [speedStep] steps) for [value] on a ramp that
  /// is off up to [start] and full from [full].
  @visibleForTesting
  static int speedForRamp(double value, int start, int full) {
    if (full <= start) return value >= full ? 100 : 0;
    final fraction = ((value - start) / (full - start)).clamp(0.0, 1.0);
    return ((fraction * 100) / speedStep).round() * speedStep;
  }

  /// The fan speed for [watts] with [fullPower] at 100%, ramping from 0 W.
  @visibleForTesting
  static int speedForPower(double watts, int fullPower) => speedForRamp(watts, 0, fullPower);

  /// The speed the current ramp asks for at [value].
  int speedFor(double value) => switch (follow.value) {
    HeadwindFollow.power => speedForRamp(value, startPowerWatts.value, fullPowerWatts.value),
    HeadwindFollow.heartRate => speedForRamp(value, startHeartRate.value, fullHeartRate.value),
    HeadwindFollow.none => _currentSpeed,
  };

  /// Starts following [source] (or stops, for [HeadwindFollow.none]) and
  /// remembers the choice.
  Future<void> setFollow(HeadwindFollow source) async {
    final changed = follow.value != source;
    follow.value = source;
    if (core.settings.isInitialized) await core.settings.setHeadwindFollow(source.name);
    if (source == HeadwindFollow.none) {
      _stopFollow();
    } else if (changed || _followTimer == null) {
      _startFollow();
    }
  }

  /// Starts or stops following the power, and remembers the choice.
  Future<void> setFollowPower(bool on) => setFollow(on ? HeadwindFollow.power : HeadwindFollow.none);

  /// Starts or stops following the heart rate, and remembers the choice.
  Future<void> setFollowHeartRate(bool on) => setFollow(on ? HeadwindFollow.heartRate : HeadwindFollow.none);

  Future<void> setStartPowerWatts(int watts) async {
    startPowerWatts.value = watts.clamp(minStartPowerWatts, fullPowerWatts.value - minPowerRampWatts);
    if (core.settings.isInitialized) await core.settings.setHeadwindStartPowerWatts(startPowerWatts.value);
    if (followsPower) await followTick(force: true);
  }

  Future<void> setFullPowerWatts(int watts) async {
    fullPowerWatts.value = watts.clamp(
      math.max(minFullPowerWatts, startPowerWatts.value + minPowerRampWatts),
      maxFullPowerWatts,
    );
    if (core.settings.isInitialized) await core.settings.setHeadwindFullPowerWatts(fullPowerWatts.value);
    if (followsPower) await followTick(force: true);
  }

  Future<void> setStartHeartRate(int bpm) async {
    startHeartRate.value = bpm.clamp(minStartHeartRate, fullHeartRate.value - minHeartRateRamp);
    if (core.settings.isInitialized) await core.settings.setHeadwindStartHeartRate(startHeartRate.value);
    if (followsHeartRate) await followTick(force: true);
  }

  Future<void> setFullHeartRate(int bpm) async {
    fullHeartRate.value = bpm.clamp(
      math.max(minFullHeartRate, startHeartRate.value + minHeartRateRamp),
      maxFullHeartRate,
    );
    if (core.settings.isInitialized) await core.settings.setHeadwindFullHeartRate(fullHeartRate.value);
    if (followsHeartRate) await followTick(force: true);
  }

  void _startFollow() {
    _smoothed = null;
    followInput.value = null;
    _followTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => followTick());
    unawaited(followTick());
  }

  void _stopFollow() {
    _followTimer?.cancel();
    _followTimer = null;
    _smoothed = null;
    followInput.value = null;
  }

  /// One step of following: smooth the input and, when the speed it asks for
  /// differs enough from the fan's, set it. No reading, no change.
  @visibleForTesting
  Future<void> followTick({bool force = false}) async {
    final source = follow.value;
    if (source == HeadwindFollow.none || _ticking) return;
    final value = source == HeadwindFollow.power ? powerProvider() : heartRateProvider();
    if (value == null) {
      followInput.value = null;
      return;
    }
    _ticking = true;
    try {
      final previous = _smoothed;
      final smoothed = previous == null ? value.toDouble() : previous + _smoothing * (value - previous);
      _smoothed = smoothed;
      followInput.value = smoothed.round();
      final target = speedFor(smoothed);
      final current = _currentSpeed;
      final atEnd = (target == 0 || target == 100) && target != current;
      if (force || _currentMode != HeadwindMode.manual || atEnd || (target - current).abs() >= speedHysteresis) {
        if (target != current || _currentMode != HeadwindMode.manual) await _writeManualSpeed(target);
      }
    } catch (e, s) {
      recordError(e, s, context: 'Headwind follow ${source.name}');
    } finally {
      _ticking = false;
    }
  }

  /// Kept for the power tests: one tick of following.
  @visibleForTesting
  Future<void> powerTick({bool force = false}) => followTick(force: force);

  /// Captures writes in tests instead of sending them over BLE.
  @visibleForTesting
  Future<void> Function(Uint8List bytes)? debugWriteSink;

  Future<void> _write(Uint8List data) {
    final sink = debugWriteSink;
    if (sink != null) return sink(data);
    return UniversalBle.write(
      device.deviceId,
      WahooKickrHeadwindConstants.SERVICE_UUID.toLowerCase(),
      WahooKickrHeadwindConstants.CHARACTERISTIC_UUID.toLowerCase(),
      data,
      withoutResponse: true,
    );
  }

  WahooKickrHeadwind(super.scanResult)
    : super(
        availableButtons: const [],
        icon: LucideIcons.fan,
        isBeta: true,
      );

  @override
  List<InGameAction> get assignableActions => const [
    InGameAction.headwindSpeed,
    InGameAction.headwindSpeedInc,
    InGameAction.headwindSpeedDec,
    InGameAction.headwindSpeedCyclicInc,
    InGameAction.headwindSpeedCyclicDec,
    InGameAction.headwindHeartRateMode,
  ];

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (e) => e.uuid == WahooKickrHeadwindConstants.SERVICE_UUID.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${WahooKickrHeadwindConstants.SERVICE_UUID}'),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid == WahooKickrHeadwindConstants.CHARACTERISTIC_UUID.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${WahooKickrHeadwindConstants.CHARACTERISTIC_UUID}'),
    );

    // Subscribe to notifications for status updates
    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);

    // Pick up where the rider left off: what the fan follows, at their ramps.
    if (core.settings.isInitialized) {
      startPowerWatts.value = core.settings.getHeadwindStartPowerWatts();
      fullPowerWatts.value = core.settings.getHeadwindFullPowerWatts();
      startHeartRate.value = core.settings.getHeadwindStartHeartRate();
      fullHeartRate.value = core.settings.getHeadwindFullHeartRate();
      final saved = HeadwindFollow.values.asNameMap()[core.settings.getHeadwindFollow()] ?? HeadwindFollow.none;
      if (saved != HeadwindFollow.none) {
        follow.value = saved;
        _startFollow();
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _stopFollow();
    await super.disconnect();
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    // Analyze the received bytes to determine current state
    if (bytes.length >= 4 && bytes[0] == 0xFD && bytes[1] == 0x01) {
      final mode = bytes[3];
      final speed = bytes[2];

      switch (mode) {
        case 0x02:
          _currentMode = HeadwindMode.heartRate;
          break;
        case 0x03:
          _currentMode = HeadwindMode.speed;
          break;
        case 0x01:
          _currentMode = HeadwindMode.off;
          break;
        case 0x04:
          _currentMode = HeadwindMode.manual;
          _currentSpeed = speed;
          break;
      }
    }
    return Future.value();
  }

  /// Sets the fan to [speedPercent] by hand, which ends following.
  Future<void> setSpeed(int speedPercent) async {
    // The fan takes 0–100%; the 25% steps are only what the page offers.
    if (speedPercent < 0 || speedPercent > 100) {
      throw ArgumentError('Speed must be between 0 and 100, got $speedPercent');
    }
    if (follow.value != HeadwindFollow.none) await setFollow(HeadwindFollow.none);
    await _writeManualSpeed(speedPercent);
  }

  Future<void> _writeManualSpeed(int speedPercent) async {
    // Check if manual mode is enabled, if not enable it first
    if (_currentMode != HeadwindMode.manual) {
      await _write(Uint8List.fromList([0x04, 0x04]));
      _currentMode = HeadwindMode.manual;

      // Small delay to ensure mode change is processed before speed command
      if (debugWriteSink == null) await Future.delayed(const Duration(milliseconds: 100));
    }

    // Command format: [0x02, speed_value]
    // Speed value: 0x00 to 0x64 (0-100 in hex)
    await _write(Uint8List.fromList([0x02, speedPercent]));
    _currentSpeed = speedPercent;
  }

  /// Hands the fan to its own heart-rate mode, which uses the strap and the
  /// zones set up in the Wahoo app. The page uses [setFollowHeartRate]
  /// instead, whose ramp the rider can see and adjust.
  Future<void> setHeartRateMode() async {
    if (follow.value != HeadwindFollow.none) await setFollow(HeadwindFollow.none);
    // Command format: [0x04, 0x02] for HR mode
    await _write(Uint8List.fromList([0x04, 0x02]));
    _currentMode = HeadwindMode.heartRate;
  }

  Future<ActionResult> handleKeypair(KeyPair keyPair, {required bool isKeyDown}) async {
    if (!isKeyDown) {
      return NotHandled(
        '',
        button: keyPair.buttons.firstOrNull,
      );
    }

    try {
      if (keyPair.inGameAction == InGameAction.headwindSpeed) {
        final speed = keyPair.inGameActionValue ?? 0;
        await setSpeed(speed);
        return Success(
          'Headwind speed set to $speed%',
          button: keyPair.buttons.firstOrNull,
        );
      } else if (keyPair.inGameAction == InGameAction.headwindSpeedInc ||
          keyPair.inGameAction == InGameAction.headwindSpeedDec ||
          keyPair.inGameAction == InGameAction.headwindSpeedCyclicInc ||
          keyPair.inGameAction == InGameAction.headwindSpeedCyclicDec) {
        final step = 25;
        int speed = 0;
        switch (keyPair.inGameAction) {
          case InGameAction.headwindSpeedInc:
            speed = _currentSpeed + step > 100 ? 100 : _currentSpeed + step;
          case InGameAction.headwindSpeedDec:
            speed = _currentSpeed - step < 0 ? 0 : _currentSpeed - step;
          case InGameAction.headwindSpeedCyclicInc:
            speed = _currentSpeed + step > 100 ? (_currentSpeed < 100 ? 100 : 0) : _currentSpeed + step;
          case InGameAction.headwindSpeedCyclicDec:
            speed = _currentSpeed - step < 0 ? (_currentSpeed > 0 ? 0 : 100) : _currentSpeed - step;
          default:
            return Error(
              'Failed to control Headwind: Unknown action',
              button: keyPair.buttons.firstOrNull,
            );
        }
        await setSpeed(speed);
        _currentSpeed = speed;
        return Success(
          'Headwind speed set to $speed%',
          button: keyPair.buttons.firstOrNull,
        );
      } else if (keyPair.inGameAction == InGameAction.headwindHeartRateMode) {
        await setFollowHeartRate(true);
        return Success(
          'Headwind set to Heart Rate mode',
          button: keyPair.buttons.firstOrNull,
        );
      }
    } catch (e) {
      return Error(
        'Failed to control Headwind: $e',
        button: keyPair.buttons.firstOrNull,
      );
    }

    return NotHandled(
      '',
      button: keyPair.buttons.firstOrNull,
    );
  }
}

class WahooKickrHeadwindConstants {
  // Wahoo KICKR Headwind service and characteristic UUIDs
  // These are standard Wahoo fitness equipment UUIDs
  static const String SERVICE_UUID = "A026EE0C-0A7D-4AB3-97FA-F1500F9FEB8B";
  static const String CHARACTERISTIC_UUID = "A026E038-0A7D-4AB3-97FA-F1500F9FEB8B";
}

/// What BikeControl drives the fan's speed from.
enum HeadwindFollow { none, power, heartRate }

enum HeadwindMode {
  unknown,
  heartRate, // HR mode (0x02)
  speed, // Speed mode (0x03)
  off, // OFF mode (0x01)
  manual, // Manual speed mode (0x04)
}
