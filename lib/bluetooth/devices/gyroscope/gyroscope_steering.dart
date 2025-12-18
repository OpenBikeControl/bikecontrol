import 'dart:async';
import 'dart:math';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Gyroscope and Accelerometer based steering device
/// Detects handlebar movement when the phone is mounted on the handlebar
class GyroscopeSteering extends BaseDevice {
  GyroscopeSteering() : super('Gyroscope Steering', availableButtons: GyroscopeSteeringButtons.values);

  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Calibration state
  final List<double> _calibrationSamplesYaw = [];
  final List<double> _calibrationSamplesRoll = [];
  double _calibrationOffsetYaw = 0.0;
  double _calibrationOffsetRoll = 0.0;
  bool _isCalibrated = false;

  // Current orientation
  double _currentYaw = 0.0;
  double _currentRoll = 0.0;
  double _currentPitch = 0.0;

  // Accelerometer raw data
  double _accelX = 0.0;
  double _accelY = 0.0;
  double _accelZ = 0.0;
  bool _hasAccelData = false;

  // Time tracking for integration
  DateTime? _lastGyroUpdate;

  // Filtered angle for steering
  double _filteredSteeringAngle = 0.0;

  // Last rounded angle for change detection
  int? _lastRoundedAngle;

  // Debounce timer for PWM-like keypress behavior
  Timer? _keypressTimer;
  bool _isProcessingKeypresses = false;

  // Configuration (can be made customizable later)
  static const int CALIBRATION_SAMPLE_COUNT = 30;
  static const double STEERING_THRESHOLD = 15.0; // degrees
  static const double LEVEL_DEGREE_STEP = 10.0; // degrees per level
  static const int MAX_LEVELS = 5;
  static const int KEY_REPEAT_INTERVAL_MS = 40;
  static const double COMPLEMENTARY_FILTER_ALPHA = 0.98; // Weight for gyroscope
  static const double LOW_PASS_FILTER_ALPHA = 0.9; // Smoothing factor

  @override
  Future<void> connect() async {
    if (isConnected) {
      return;
    }

    try {
      // Start listening to sensors
      _gyroscopeSubscription = gyroscopeEventStream().listen(
        _handleGyroscopeEvent,
        onError: (error) {
          actionStreamInternal.add(LogNotification('Gyroscope error: $error'));
        },
      );

      _accelerometerSubscription = accelerometerEventStream().listen(
        _handleAccelerometerEvent,
        onError: (error) {
          actionStreamInternal.add(LogNotification('Accelerometer error: $error'));
        },
      );

      isConnected = true;
      actionStreamInternal.add(LogNotification('Gyroscope Steering: Connected - Calibrating...'));

      // Reset calibration
      _isCalibrated = false;
      _hasAccelData = false;
      _calibrationSamplesYaw.clear();
      _calibrationSamplesRoll.clear();
      _calibrationOffsetYaw = 0.0;
      _calibrationOffsetRoll = 0.0;
      _lastGyroUpdate = null;
    } catch (e) {
      actionStreamInternal.add(LogNotification('Failed to connect Gyroscope Steering: $e'));
      isConnected = false;
      rethrow;
    }
  }

  void _handleGyroscopeEvent(GyroscopeEvent event) {
    final now = DateTime.now();

    // Skip if we haven't received accelerometer data yet
    if (!_hasAccelData) {
      _lastGyroUpdate = now;
      return;
    }

    // Calculate time delta
    final dt = _lastGyroUpdate != null ? (now.difference(_lastGyroUpdate!).inMicroseconds / 1000000.0) : 0.0;
    _lastGyroUpdate = now;

    if (dt > 0 && dt < 1.0) {
      // Assuming phone is mounted on handlebar in landscape mode
      // - event.z (yaw rate) represents rotation around vertical axis (steering)
      // - event.x (roll rate) can be used as backup/additional input
      // - event.y (pitch rate) represents forward/backward rotation

      // Integrate gyroscope to get angles (in degrees)
      final gyroYawDelta = event.z * dt * (180.0 / pi);
      final gyroRollDelta = event.x * dt * (180.0 / pi);

      // Update yaw and roll from gyroscope
      _currentYaw += gyroYawDelta;
      _currentRoll += gyroRollDelta;

      // Apply complementary filter: combine gyroscope and accelerometer
      // Gyroscope provides short-term accuracy, accelerometer provides long-term stability
      _currentRoll = COMPLEMENTARY_FILTER_ALPHA * _currentRoll + (1 - COMPLEMENTARY_FILTER_ALPHA) * _getAccelRoll();

      if (!_isCalibrated) {
        _collectCalibrationSamples();
      } else {
        _processSteeringAngle();
      }
    }
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    // Store accelerometer readings for complementary filter
    _accelX = event.x;
    _accelY = event.y;
    _accelZ = event.z;
    _hasAccelData = true;

    // Calculate roll and pitch from accelerometer
    // Assuming phone is in landscape orientation on handlebar
    _currentPitch = atan2(event.y, sqrt(event.x * event.x + event.z * event.z)) * (180.0 / pi);
  }

  double _getAccelRoll() {
    // Calculate roll from accelerometer data
    // Roll is rotation around the longitudinal axis (phone's length)
    // For landscape orientation: roll = atan2(accelY, accelZ)
    return atan2(_accelY, _accelZ) * (180.0 / pi);
  }

  void _collectCalibrationSamples() {
    _calibrationSamplesYaw.add(_currentYaw);
    _calibrationSamplesRoll.add(_currentRoll);

    if (_calibrationSamplesYaw.length >= CALIBRATION_SAMPLE_COUNT) {
      // Compute average offset from collected samples
      _calibrationOffsetYaw = _calibrationSamplesYaw.reduce((a, b) => a + b) / _calibrationSamplesYaw.length;
      _calibrationOffsetRoll = _calibrationSamplesRoll.reduce((a, b) => a + b) / _calibrationSamplesRoll.length;
      _isCalibrated = true;

      actionStreamInternal.add(
        LogNotification(
          'Gyroscope Steering: Calibration complete. '
          'Yaw offset: ${_calibrationOffsetYaw.toStringAsFixed(2)}°, '
          'Roll offset: ${_calibrationOffsetRoll.toStringAsFixed(2)}°',
        ),
      );

      // Reset integrated angles to start from calibrated zero
      _currentYaw = 0.0;
      _currentRoll = 0.0;
    }
  }

  void _processSteeringAngle() {
    // Apply calibration offset to yaw (primary steering input)
    final calibratedYaw = _currentYaw - _calibrationOffsetYaw;

    // Apply low-pass filter to smooth out noise
    _filteredSteeringAngle = LOW_PASS_FILTER_ALPHA * _filteredSteeringAngle + (1 - LOW_PASS_FILTER_ALPHA) * calibratedYaw;

    // Round to whole degrees to reduce noise
    final roundedAngle = _filteredSteeringAngle.round();

    // Only process steering when rounded value changes
    if (_lastRoundedAngle != roundedAngle) {
      if (kDebugMode) {
        actionStreamInternal.add(LogNotification('Steering angle: $roundedAngle°'));
      }
      _lastRoundedAngle = roundedAngle;

      // Apply PWM-like steering behavior
      _applyPWMSteering(roundedAngle);
    }
  }

  /// Applies PWM-like steering behavior with repeated keypresses proportional to angle magnitude
  void _applyPWMSteering(int roundedAngle) {
    // Cancel any pending keypress timer
    _keypressTimer?.cancel();

    // Determine if we're steering
    if (roundedAngle.abs() > STEERING_THRESHOLD) {
      // Determine direction
      final button = roundedAngle > 0 ? GyroscopeSteeringButtons.rightSteer : GyroscopeSteeringButtons.leftSteer;

      // Calculate number of keypress levels based on angle magnitude
      final levels = _calculateKeypressLevels(roundedAngle.abs());

      // Schedule repeated keypresses
      _scheduleRepeatedKeypresses(button, levels);
    } else {
      // Center position - release any held buttons
      handleButtonsClicked([]);
    }
  }

  /// Calculates the number of keypress levels based on angle magnitude
  int _calculateKeypressLevels(int absAngle) {
    final levels = ((absAngle - STEERING_THRESHOLD) / LEVEL_DEGREE_STEP).floor() + 1;
    return levels.clamp(1, MAX_LEVELS);
  }

  /// Schedules repeated keypresses to simulate PWM behavior
  Future<void> _scheduleRepeatedKeypresses(ControllerButton button, int levels) async {
    // Don't overlap keypress sequences
    if (_isProcessingKeypresses) {
      return;
    }

    _isProcessingKeypresses = true;

    // Send keypresses in sequence with delays between them
    for (int i = 0; i < levels; i++) {
      // Send keypress immediately on first iteration, then wait before subsequent ones
      handleButtonsClicked([button]);
      
      // Don't wait after the last keypress
      if (i < levels - 1) {
        await Future.delayed(Duration(milliseconds: KEY_REPEAT_INTERVAL_MS));
      }
    }

    _isProcessingKeypresses = false;
  }

  @override
  Future<void> disconnect() async {
    await _gyroscopeSubscription?.cancel();
    await _accelerometerSubscription?.cancel();
    _gyroscopeSubscription = null;
    _accelerometerSubscription = null;
    _keypressTimer?.cancel();
    isConnected = false;
    _isCalibrated = false;
    _hasAccelData = false;
    _calibrationSamplesYaw.clear();
    _calibrationSamplesRoll.clear();
    actionStreamInternal.add(LogNotification('Gyroscope Steering: Disconnected'));
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
