import 'dart:async';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_rizer_protocol.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/bluetooth/incline/manual_incline_device.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

/// Rizer steering tuning (duplicated from the Sterzo pattern intentionally).
const double _rizerSteerThreshold = 10.0;
const double _rizerLevelDegreeStep = 10.0;
const int _rizerMaxLevels = 5;
const int _rizerCalibrationSamples = 10;
const int _rizerKeyRepeatMs = 40;

/// Pure steering decision: given a calibrated, rounded angle, returns null
/// (center) or a (direction, levels). Unit-tested.
class RizerSteer {
  RizerSteer(this.right, this.levels);
  final bool right;
  final int levels;
}

RizerSteer? rizerSteerDecision(int roundedAngle) {
  if (roundedAngle.abs() <= _rizerSteerThreshold) return null;
  final levels = (roundedAngle.abs() / _rizerLevelDegreeStep).floor().clamp(1, _rizerMaxLevels);
  return RizerSteer(roundedAngle > 0, levels);
}

class RizerButtons {
  static final ControllerButton leftSteer = ControllerButton('leftSteer', action: InGameAction.steerLeft);
  static final ControllerButton rightSteer = ControllerButton('rightSteer', action: InGameAction.steerRight);
  static List<ControllerButton> get values => [leftSteer, rightSteer];
}

/// Elite Rizer — a beta device that simulates incline (driven by the bridge's
/// grade, via [ManualInclineDevice]) and steering (angle float from the
/// steering characteristic). It is a standalone BLE device, so it works
/// with any trainer.
class EliteRizer extends BluetoothDevice with ManualInclineDevice implements SteeringDevice, RecalibratableSteering {
  EliteRizer(super.scanResult) : super(availableButtons: RizerButtons.values, isBeta: true);

  @visibleForTesting
  Future<void> Function(Uint8List bytes)? debugWriteSink;

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 2.4,
    shape: ContourShape.steeringPad,
    positions: {
      RizerButtons.leftSteer: const Offset(0.2, 0.5),
      RizerButtons.rightSteer: const Offset(0.8, 0.5),
    },
  );

  // Steering calibration state
  final List<double> _calibrationSamples = [];
  double _calibrationOffset = 0.0;
  bool _isCalibrated = false;
  int? _lastRoundedAngle;
  bool _isProcessingKeypresses = false;
  int _keypressGeneration = 0;

  // SteeringDevice listenable state
  final ValueNotifier<double> steeringAngle = ValueNotifier(0.0);
  final ValueNotifier<bool> steeringCalibratedN = ValueNotifier(false);

  // SteeringDevice interface
  @override
  ValueListenable<bool> get steeringCalibrated => steeringCalibratedN;
  @override
  double get steeringThreshold => _rizerSteerThreshold;
  @override
  ControllerButton get steerLeftButton => RizerButtons.leftSteer;
  @override
  ControllerButton get steerRightButton => RizerButtons.rightSteer;

  @override
  void recalibrate() {
    _keypressGeneration++;
    _isProcessingKeypresses = false;
    _calibrationSamples.clear();
    _calibrationOffset = 0.0;
    _isCalibrated = false;
    steeringCalibratedN.value = false;
    steeringAngle.value = 0.0;
    _lastRoundedAngle = null;
    unawaited(handleButtonsClicked([]));
  }

  @override
  Future<void> handleServices(List<BleService> services) async {
    for (final s in services) {
      debugPrint('[Rizer] service ${s.uuid} chars=${s.characteristics.map((c) => c.uuid).toList()}');
    }
    final service = services.firstOrNullWhere((e) => e.uuid == eliteRizerServiceUuid);
    if (service == null) {
      debugPrint('[Rizer] service $eliteRizerServiceUuid not found — incompatible device');
      return;
    }
    final write = service.characteristics.firstOrNullWhere((e) => e.uuid == eliteRizerWriteCharacteristicUuid);
    if (write == null) {
      debugPrint('[Rizer] write char $eliteRizerWriteCharacteristicUuid not found — incompatible device');
      return;
    }
    // Enable notifications on status, current-incline, and steering.
    for (final uuid in [
      eliteRizerStatusCharacteristicUuid,
      eliteRizerInclineCharacteristicUuid,
      eliteRizerSteeringCharacteristicUuid,
    ]) {
      final ch = service.characteristics.firstOrNullWhere((e) => e.uuid == uuid);
      if (ch != null) {
        try {
          await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, ch.uuid);
        } catch (e, s) {
          recordError(e, s, context: 'EliteRizer: subscribe $uuid failed');
        }
      }
    }
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic == eliteRizerStatusCharacteristicUuid) {
      debugPrint('[Rizer] status: $bytes'); // byte[2]==2 => success
    } else if (characteristic == eliteRizerInclineCharacteristicUuid) {
      debugPrint('[Rizer] current incline: $bytes');
    } else if (characteristic == eliteRizerSteeringCharacteristicUuid) {
      _handleSteering(bytes);
    } else {
      debugPrint('[Rizer] notify $characteristic: $bytes');
    }
  }

  void _handleSteering(Uint8List bytes) {
    if (bytes.length < 4) return;
    final raw = ByteData.sublistView(bytes).getFloat32(0, Endian.little);
    if (raw.isNaN) return;
    if (!_isCalibrated) {
      _calibrationSamples.add(raw);
      if (_calibrationSamples.length >= _rizerCalibrationSamples) {
        _calibrationOffset = _calibrationSamples.reduce((a, b) => a + b) / _calibrationSamples.length;
        _isCalibrated = true;
        steeringCalibratedN.value = true;
      }
      return;
    }
    final calibrated = raw - _calibrationOffset;
    // Gauge convention is positive ⇒ left; the Rizer's positive angle steers
    // right, so negate for the gauge (steering actions use `rounded` below).
    steeringAngle.value = -calibrated;
    final rounded = calibrated.round();
    if (_lastRoundedAngle == rounded) return;
    _lastRoundedAngle = rounded;
    final decision = rizerSteerDecision(rounded);
    if (decision == null) {
      handleButtonsClicked([]);
    } else {
      unawaited(_repeatKeypresses(decision.right ? RizerButtons.rightSteer : RizerButtons.leftSteer, decision.levels));
    }
  }

  Future<void> _repeatKeypresses(ControllerButton button, int levels) async {
    if (_isProcessingKeypresses) return;
    final generation = _keypressGeneration;
    _isProcessingKeypresses = true;
    try {
      for (var i = 0; i < levels; i++) {
        await Future.delayed(Duration(milliseconds: _rizerKeyRepeatMs));
        if (generation != _keypressGeneration) {
          return;
        }
        unawaited(handleButtonsClicked([button]));
      }
    } finally {
      if (generation == _keypressGeneration) {
        _isProcessingKeypresses = false;
      }
    }
  }

  @override
  Future<bool> writeInclineRaw(int grade001Pct) async {
    try {
      final bytes = rizerInclineToBytes(grade001Pct);
      if (debugWriteSink != null) {
        await debugWriteSink!(bytes);
      } else {
        await UniversalBle.write(
          device.deviceId,
          eliteRizerServiceUuid,
          eliteRizerWriteCharacteristicUuid,
          bytes,
          withoutResponse: false,
        );
      }
      return true;
    } catch (e, s) {
      recordError(e, s, context: 'EliteRizer: writeIncline failed');
      return false;
    }
  }
}
