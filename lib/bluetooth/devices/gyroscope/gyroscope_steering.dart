import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/steering_estimator.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Gyroscope and Accelerometer based steering device
/// Detects handlebar movement when the phone is mounted on the handlebar
class GyroscopeSteering extends BaseDevice implements SteeringDevice, RecalibratableSteering {
  GyroscopeSteering()
    : super(
        'Phone Steering',
        availableButtons: GyroscopeSteeringButtons.values,
        isBeta: true,
        uniqueId: 'gyroscope_steering_device',
        buttonPrefix: 'gyro',
        icon: LucideIcons.phone,
      );

  /// 'Phone Steering' stays the device's id in logs; riders see it in their
  /// language.
  @override
  String displayName(BuildContext context) => AppLocalizations.of(context).phoneSteeringName;

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 0.5,
    shape: ContourShape.phone,
    positions: {
      GyroscopeSteeringButtons.leftSteer: const Offset(0.25, 0.5),
      GyroscopeSteeringButtons.rightSteer: const Offset(0.75, 0.5),
    },
  );

  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  /// Integrates the gyroscope about the up axis, learns its bias and — with
  /// the compass on — takes the drift out. See [SteeringEstimator].
  final SteeringEstimator _estimator = SteeringEstimator();
  bool _isCalibrated = false;
  ControllerButton? _lastSteeringButton;

  /// Live signed steering angle (degrees) for the UI gauge. Positive ⇒ steer
  /// LEFT, negative ⇒ steer RIGHT (see [_applyPWMSteering]).
  @override
  final ValueNotifier<double> steeringAngle = ValueNotifier(0.0);

  /// Mirrors [_isCalibrated] for the UI gauge.
  final ValueNotifier<bool> isCalibratedNotifier = ValueNotifier(false);

  /// True once the compass has learned the mount's magnetic offset from a
  /// left and a right turn and corrects the gyroscope's drift.
  final ValueNotifier<bool> magnetometerLocked = ValueNotifier(false);

  // SteeringDevice interface
  @override
  ValueListenable<bool> get steeringCalibrated => isCalibratedNotifier;
  @override
  double get steeringThreshold => core.settings.getPhoneSteeringThreshold();
  @override
  ControllerButton get steerLeftButton => GyroscopeSteeringButtons.leftSteer;
  @override
  ControllerButton get steerRightButton => GyroscopeSteeringButtons.rightSteer;

  /// Timestamp of the previous gyroscope sample, from the sensor itself, so
  /// the integration measures the samples' own spacing rather than delivery
  /// jitter.
  DateTime? _lastGyroTimestamp;

  // Last rounded angle for change detection
  int? _lastRoundedAngle;

  // Debounce timer for PWM-like keypress behavior
  Timer? _keypressTimer;

  bool? _useMagnetometer;

  /// Dead zone, degrees, when the rider has not set one.
  static const double STEERING_THRESHOLD = 5.0;

  /// Stillness after which the sensors count as calibrated.
  static const double calibrationStillSec = 0.6;

  /// sensors_plus delivers 5 Hz unless asked; steering wants 50 Hz.
  static const Duration samplingPeriod = SensorInterval.gameInterval;

  /// Start listening to the sensors: gyroscope and accelerometer always, the
  /// magnetometer on top when the compass is on.
  Future<void> _startSensorStreams() async {
    await _stopSensorStreams();

    _gyroscopeSubscription = gyroscopeEventStream(samplingPeriod: samplingPeriod).listen(
      _handleGyroscopeEvent,
      onError: (error) {
        actionStreamInternal.add(LogNotification('Gyroscope error: $error'));
      },
    );
    _accelerometerSubscription = accelerometerEventStream(samplingPeriod: samplingPeriod).listen(
      _handleAccelerometerEvent,
      onError: (error) {
        actionStreamInternal.add(LogNotification('Accelerometer error: $error'));
      },
    );
    if (useMagnetometer) {
      _magnetometerSubscription = magnetometerEventStream(samplingPeriod: samplingPeriod).listen(
        _handleMagnetometerEvent,
        onError: (error) {
          actionStreamInternal.add(LogNotification('Magnetometer error: $error'));
        },
      );
    }
    actionStreamInternal.add(
      LogNotification('Started gyroscope and accelerometer streams${useMagnetometer ? " and magnetometer" : ""}'),
    );
  }

  Future<void> _stopSensorStreams() async {
    await _gyroscopeSubscription?.cancel();
    await _accelerometerSubscription?.cancel();
    await _magnetometerSubscription?.cancel();
    _gyroscopeSubscription = null;
    _accelerometerSubscription = null;
    _magnetometerSubscription = null;
  }

  @override
  Future<void> connect() async {
    if (isConnected) {
      return;
    }

    try {
      await _startSensorStreams();

      isConnected = true;
      actionStreamInternal.add(LogNotification('Gyroscope Steering: Connected - Calibrating...'));

      _resetEstimation();
    } catch (e) {
      actionStreamInternal.add(LogNotification('Failed to connect Gyroscope Steering: $e'));
      isConnected = false;
      rethrow;
    }
  }

  void _handleGyroscopeEvent(GyroscopeEvent event) {
    final previous = _lastGyroTimestamp;
    _lastGyroTimestamp = event.timestamp;
    if (previous == null) return;

    final dt = event.timestamp.difference(previous).inMicroseconds / 1000000.0;
    if (dt <= 0 || dt >= 1.0) {
      return;
    }

    final angleDeg = _estimator.updateGyro(x: event.x, y: event.y, z: event.z, dt: dt);

    if (!_isCalibrated) {
      // Calibrated once the phone has been still for a moment: that window
      // seeds the gyro bias and freezes the up axis.
      if (_estimator.stillTimeSec >= calibrationStillSec) {
        _estimator.calibrate();
        _setCalibrated(true);
      }
      return;
    }

    _processSteeringAngle(angleDeg);
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    _estimator.updateAccel(x: event.x, y: event.y, z: event.z);
  }

  void _handleMagnetometerEvent(MagnetometerEvent event) {
    _estimator.updateMag(x: event.x, y: event.y, z: event.z);
    final locked = _estimator.magnetometerLocked;
    if (locked != magnetometerLocked.value) {
      magnetometerLocked.value = locked;
      actionStreamInternal.add(LogNotification(locked ? 'Compass locked on the mount' : 'Compass lost its lock'));
    }
  }

  void _processSteeringAngle(double steeringAngleDeg) {
    steeringAngle.value = steeringAngleDeg;
    final roundedAngle = steeringAngleDeg.round();

    if (_lastRoundedAngle != roundedAngle) {
      if (kDebugMode) {
        actionStreamInternal.add(
          LogNotification(
            'Steering angle: $roundedAngle° (yaw bias=${_estimator.yawBiasRadPerSec.toStringAsFixed(4)} rad/s'
            '${magnetometerLocked.value ? ", compass" : ""})',
          ),
        );
      }
      _lastRoundedAngle = roundedAngle;
      _applyPWMSteering(roundedAngle);
    }
  }

  /// Applies PWM-like steering behavior with repeated keypresses proportional to angle magnitude
  void _applyPWMSteering(int roundedAngle) {
    // Cancel any pending keypress timer
    _keypressTimer?.cancel();

    // Determine if we're steering
    if (roundedAngle.abs() > core.settings.getPhoneSteeringThreshold()) {
      // Determine direction
      final button = roundedAngle < 0 ? GyroscopeSteeringButtons.rightSteer : GyroscopeSteeringButtons.leftSteer;

      if (_lastSteeringButton != button) {
        // New steering direction - reset any previous state
        _lastSteeringButton = button;
      } else {
        return;
      }

      handleButtonsClicked([button]);
    } else {
      _lastSteeringButton = null;
      // Center position - release any held buttons
      handleButtonsClicked([]);
    }
  }

  @override
  Future<void> disconnect() async {
    await _stopSensorStreams();
    _keypressTimer?.cancel();
    isConnected = false;
    _resetEstimation();
    actionStreamInternal.add(LogNotification('Gyroscope Steering: Disconnected'));
  }

  void _setCalibrated(bool value) {
    _isCalibrated = value;
    isCalibratedNotifier.value = value;
  }

  /// Back to square one: uncalibrated, bias and compass model forgotten, so
  /// the next still moment re-learns the neutral reference.
  void _resetEstimation() {
    _setCalibrated(false);
    _estimator.reset();
    _lastGyroTimestamp = null;
    _lastRoundedAngle = null;
    _lastSteeringButton = null;
    steeringAngle.value = 0.0;
    magnetometerLocked.value = false;
  }

  /// Reset calibration so the sensors re-learn their neutral reference. Safe to
  /// call any time (also used by the assignable Calibrate action).
  @override
  void recalibrate() {
    _keypressTimer?.cancel();
    _resetEstimation();
    unawaited(handleButtonsClicked([]));
  }

  /// Lets the compass correct the gyroscope's slow drift — for long rides,
  /// and phones whose gyroscope drifts.
  bool get useMagnetometer => _useMagnetometer ??= core.settings.getPhoneSteeringMagnetometer();

  /// Switches the compass on or off, remembers it, and calibrates afresh.
  Future<void> setUseMagnetometer(bool value) async {
    if (value == useMagnetometer) return;
    _useMagnetometer = value;
    core.settings.setPhoneSteeringMagnetometer(value);
    recalibrate();
    if (isConnected) {
      await _startSensorStreams();
      actionStreamInternal.add(LogNotification('Compass ${value ? "on" : "off"}'));
    }
  }
}

class GyroscopeSteeringButtons {
  static final ControllerButton leftSteer = ControllerButton(
    'gyroLeftSteer',
    action: InGameAction.steerLeft,
  );
  static final ControllerButton rightSteer = ControllerButton(
    'gyroRightSteer',
    action: InGameAction.steerRight,
  );

  static List<ControllerButton> get values => [
    leftSteer,
    rightSteer,
  ];
}
