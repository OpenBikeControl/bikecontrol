import 'dart:async';
import 'dart:math';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/steering_estimator.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/pages/device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:bike_control/widgets/ui/device_info.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Gyroscope and Accelerometer based steering device
/// Detects handlebar movement when the phone is mounted on the handlebar
class GyroscopeSteering extends BaseDevice {
  GyroscopeSteering()
    : super(
        'Phone Steering',
        availableButtons: GyroscopeSteeringButtons.values,
        isBeta: true,
        uniqueId: 'gyroscope_steering_device',
        buttonPrefix: 'gyro',
      );

  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  // Calibration state
  final SteeringEstimator _estimator = SteeringEstimator();
  bool _isCalibrated = false;
  ControllerButton? _lastSteeringButton;

  // Accelerometer raw data
  bool _hasAccelData = false;

  // Time tracking for integration
  DateTime? _lastGyroUpdate;

  // Last rounded angle for change detection
  int? _lastRoundedAngle;

  // Debounce timer for PWM-like keypress behavior
  Timer? _keypressTimer;

  // Magnetometer mode
  bool _useMagnetometer = false;
  double? _magnetometerCalibrationHeading;
  double _currentMagnetometerAngle = 0.0;
  final List<double> _magnetometerCalibrationSamples = [];

  // Magnetometer filtering state
  double? _filteredMagX;
  double? _filteredMagY;
  static const double _magnetometerFilterAlpha = 0.15; // Lower = more smoothing

  // Configuration (can be made customizable later)
  static const double STEERING_THRESHOLD = 5.0; // degrees
  static const double LEVEL_DEGREE_STEP = 10.0; // degrees per level
  static const int MAX_LEVELS = 5;
  static const int KEY_REPEAT_INTERVAL_MS = 40;
  static const double COMPLEMENTARY_FILTER_ALPHA = 0.98; // Weight for gyroscope
  static const double LOW_PASS_FILTER_ALPHA = 0.9; // Smoothing factor

  /// Start listening to the appropriate sensors based on the current mode
  Future<void> _startSensorStreams() async {
    // Cancel all existing subscriptions first
    await _gyroscopeSubscription?.cancel();
    await _accelerometerSubscription?.cancel();
    await _magnetometerSubscription?.cancel();
    _gyroscopeSubscription = null;
    _accelerometerSubscription = null;
    _magnetometerSubscription = null;

    if (_useMagnetometer) {
      // Magnetometer mode: only listen to magnetometer
      _magnetometerSubscription = magnetometerEventStream().listen(
        _handleMagnetometerEvent,
        onError: (error) {
          actionStreamInternal.add(LogNotification('Magnetometer error: $error'));
        },
      );
      actionStreamInternal.add(LogNotification('Started magnetometer stream'));
    } else {
      // Gyroscope mode: listen to gyroscope and accelerometer
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
      actionStreamInternal.add(LogNotification('Started gyroscope and accelerometer streams'));
    }
  }

  @override
  Future<void> connect() async {
    if (isConnected) {
      return;
    }

    try {
      // Start listening to sensors based on current mode
      await _startSensorStreams();

      isConnected = true;
      actionStreamInternal.add(LogNotification('Gyroscope Steering: Connected - Calibrating...'));

      // Reset calibration/estimator
      _isCalibrated = false;
      _hasAccelData = false;
      _estimator.reset();
      _lastGyroUpdate = null;
      _lastRoundedAngle = null;
      _lastSteeringButton = null;
    } catch (e) {
      actionStreamInternal.add(LogNotification('Failed to connect Gyroscope Steering: $e'));
      isConnected = false;
      rethrow;
    }
  }

  void _handleGyroscopeEvent(GyroscopeEvent event) {
    final now = DateTime.now();

    if (!_hasAccelData) {
      _lastGyroUpdate = now;
      return;
    }

    final dt = _lastGyroUpdate != null ? (now.difference(_lastGyroUpdate!).inMicroseconds / 1000000.0) : 0.0;
    _lastGyroUpdate = now;

    if (dt <= 0 || dt >= 1.0) {
      return;
    }

    // iOS drift fix:
    // - integrate bias-corrected gyro z (yaw) into an estimator
    // - learn bias while the device is still
    final angleDeg = _estimator.updateGyro(wz: event.z, dt: dt);

    if (!_isCalibrated) {
      // Consider calibration complete once we have a bit of stillness and sensor data.
      // This gives the bias estimator time to settle.
      if (_estimator.stillTimeSec >= 0.6) {
        _estimator.calibrate(seedBiasZRadPerSec: _estimator.biasZRadPerSec);
        _isCalibrated = true;
        /*actionStreamInternal.add(
          AlertNotification(LogLevel.LOGLEVEL_INFO, 'Calibration complete.'),
        );*/
      }
      return;
    }

    _processSteeringAngle(angleDeg);
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    _hasAccelData = true;
    _estimator.updateAccel(x: event.x, y: event.y, z: event.z);
  }

  void _handleMagnetometerEvent(MagnetometerEvent event) {
    // Magnetometer mode: calculate heading from X and Y components
    // This is more stable than using a single axis

    // Apply low-pass filter to reduce noise
    if (_filteredMagX == null || _filteredMagY == null) {
      // Initialize on first reading
      _filteredMagX = event.x;
      _filteredMagY = event.y;
    } else {
      // Exponential moving average (low-pass filter)
      _filteredMagX = _magnetometerFilterAlpha * event.x + (1 - _magnetometerFilterAlpha) * _filteredMagX!;
      _filteredMagY = _magnetometerFilterAlpha * event.y + (1 - _magnetometerFilterAlpha) * _filteredMagY!;
    }

    // Calculate heading from filtered X and Y components
    // atan2(y, x) gives the angle in radians, convert to degrees
    double heading = atan2(_filteredMagY!, _filteredMagX!) * (180 / pi);

    // Normalize heading to 0-360 range
    if (heading < 0) heading += 360;

    if (kDebugMode) {
      print(
        'Magnetometer - X: ${event.x.toStringAsFixed(2)}, Y: ${event.y.toStringAsFixed(2)}, '
        'Filtered X: ${_filteredMagX!.toStringAsFixed(2)}, Filtered Y: ${_filteredMagY!.toStringAsFixed(2)}, '
        'Heading: ${heading.toStringAsFixed(2)}°',
      );
    }

    // During calibration, collect heading samples
    if (!_isCalibrated) {
      _magnetometerCalibrationSamples.add(heading);

      // After 30 samples (~1 second at typical rates), calculate calibration heading
      if (_magnetometerCalibrationSamples.length >= 30) {
        // For heading, we need to handle the circular nature (0° and 360° are the same)
        // Use circular mean calculation
        double sumSin = 0, sumCos = 0;
        for (var h in _magnetometerCalibrationSamples) {
          final radians = h * (pi / 180);
          sumSin += sin(radians);
          sumCos += cos(radians);
        }
        final avgSin = sumSin / _magnetometerCalibrationSamples.length;
        final avgCos = sumCos / _magnetometerCalibrationSamples.length;
        _magnetometerCalibrationHeading = atan2(avgSin, avgCos) * (180 / pi);
        if (_magnetometerCalibrationHeading! < 0)
          _magnetometerCalibrationHeading = _magnetometerCalibrationHeading! + 360;

        _magnetometerCalibrationSamples.clear();
        _isCalibrated = true;
        actionStreamInternal.add(
          LogNotification(
            'Magnetometer calibration complete. Reference heading: ${_magnetometerCalibrationHeading!.toStringAsFixed(2)}°',
          ),
        );
      }
      return;
    }

    // Calculate steering angle relative to calibrated heading
    // This is the angular difference, accounting for wrap-around
    double angleDeg = heading - _magnetometerCalibrationHeading!;

    // Normalize to -180 to +180 range
    if (angleDeg > 180) {
      angleDeg -= 360;
    } else if (angleDeg < -180) {
      angleDeg += 360;
    }

    _currentMagnetometerAngle = angleDeg;

    _processSteeringAngle(angleDeg);
  }

  void _processSteeringAngle(double steeringAngleDeg) {
    final roundedAngle = steeringAngleDeg.round();

    if (_lastRoundedAngle != roundedAngle) {
      if (kDebugMode) {
        actionStreamInternal.add(
          LogNotification(
            'Steering angle: $roundedAngle° (biasZ=${_estimator.biasZRadPerSec.toStringAsFixed(4)} rad/s)',
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
    await _gyroscopeSubscription?.cancel();
    await _accelerometerSubscription?.cancel();
    await _magnetometerSubscription?.cancel();
    _gyroscopeSubscription = null;
    _accelerometerSubscription = null;
    _magnetometerSubscription = null;
    _keypressTimer?.cancel();
    isConnected = false;
    _isCalibrated = false;
    _hasAccelData = false;
    _estimator.reset();
    _magnetometerCalibrationHeading = null;
    _magnetometerCalibrationSamples.clear();
    _currentMagnetometerAngle = 0.0;
    _filteredMagX = null;
    _filteredMagY = null;
    actionStreamInternal.add(LogNotification('Gyroscope Steering: Disconnected'));
  }

  @override
  Widget showInformation(BuildContext context) {
    return StatefulBuilder(
      builder: (c, setState) => Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            spacing: 12,
            children: [
              Text(
                toString().screenshot,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (isBeta) BetaPill(),
            ],
          ),
          // Magnetometer mode toggle
          Checkbox(
            trailing: Expanded(child: Text('Use Magnetometer Mode')),
            state: _useMagnetometer ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: (value) async {
              setState(() {
                _useMagnetometer = value == CheckboxState.checked;
                // Reset calibration when switching modes
                _isCalibrated = false;
                _hasAccelData = false;
                _estimator.reset();
                _lastGyroUpdate = null;
                _lastRoundedAngle = null;
                _lastSteeringButton = null;
                _magnetometerCalibrationHeading = null;
                _magnetometerCalibrationSamples.clear();
                _currentMagnetometerAngle = 0.0;
                _filteredMagX = null;
                _filteredMagY = null;
              });

              // Restart sensor streams if device is connected
              if (isConnected) {
                await _startSensorStreams();
                actionStreamInternal.add(
                  LogNotification(
                    'Switched to ${_useMagnetometer ? "magnetometer" : "gyroscope + accelerometer"} mode',
                  ),
                );
              }
            },
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              DeviceInfo(
                title: 'Calibration',
                icon: BootstrapIcons.wrenchAdjustable,
                value: _isCalibrated ? 'Complete' : 'In Progress',
              ),
              DeviceInfo(
                title: 'Steering Angle',
                icon: RadixIcons.angle,
                value: _isCalibrated
                    ? '${(_useMagnetometer ? _currentMagnetometerAngle : _estimator.angleDeg).toStringAsFixed(2)}°'
                    : 'Calibrating...',
              ),
              if (kDebugMode && !_useMagnetometer)
                DeviceInfo(
                  title: 'Gyro Bias',
                  icon: BootstrapIcons.speedometer,
                  value: '${_estimator.biasZRadPerSec.toStringAsFixed(4)} rad/s',
                ),
              if (kDebugMode && _useMagnetometer && _magnetometerCalibrationHeading != null)
                DeviceInfo(
                  title: 'Mag Heading',
                  icon: BootstrapIcons.compass,
                  value: '${_magnetometerCalibrationHeading!.toStringAsFixed(2)}°',
                ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              PrimaryButton(
                size: ButtonSize.small,
                leading: !_isCalibrated ? SmallProgressIndicator() : null,
                onPressed: !_isCalibrated
                    ? null
                    : () {
                        // Reset calibration
                        _isCalibrated = false;
                        if (_useMagnetometer) {
                          _magnetometerCalibrationHeading = null;
                          _magnetometerCalibrationSamples.clear();
                          _currentMagnetometerAngle = 0.0;
                          _filteredMagX = null;
                          _filteredMagY = null;
                        } else {
                          _hasAccelData = false;
                          _estimator.reset();
                          _lastGyroUpdate = null;
                        }
                        _lastRoundedAngle = null;
                        _lastSteeringButton = null;
                        setState(() {});
                      },
                child: Text(_isCalibrated ? 'Calibrate' : 'Calibrating...'),
              ),
              Builder(
                builder: (context) {
                  return PrimaryButton(
                    size: ButtonSize.small,
                    trailing: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.destructive,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${core.settings.getPhoneSteeringThreshold().toInt()}°'),
                    ),
                    onPressed: () {
                      final values = [for (var i = 3; i <= 12; i += 1) i];
                      showDropdown(
                        context: context,
                        builder: (b) => DropdownMenu(
                          children: values
                              .map(
                                (v) => MenuButton(
                                  child: Text('$v°'),
                                  onPressed: (c) {
                                    core.settings.setPhoneSteeringThreshold(v);
                                    setState(() {});
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                    child: Text('Trigger Threshold:'),
                  );
                },
              ),
            ],
          ),
          if (!_isCalibrated)
            Text(
              _useMagnetometer
                  ? 'Calibrating the magnetometer now. Attach your phone/tablet on your handlebar and keep it still for a second.'
                  : 'Calibrating the sensors now. Attach your phone/tablet on your handlebar and keep it still for a second.',
            ).xSmall,
        ],
      ),
    );
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
