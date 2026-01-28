import 'dart:async';

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
import 'package:prop/prop.dart';
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
  bool _isProcessingKeypresses = false;

  // Configuration (can be made customizable later)
  static const double STEERING_THRESHOLD = 5.0; // degrees
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
        actionStreamInternal.add(
          AlertNotification(LogLevel.LOGLEVEL_INFO, 'Calibration complete.'),
        );
      }
      return;
    }

    _processSteeringAngle(angleDeg);
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    _hasAccelData = true;
    _estimator.updateAccel(x: event.x, y: event.y, z: event.z);
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
    _gyroscopeSubscription = null;
    _accelerometerSubscription = null;
    _keypressTimer?.cancel();
    isConnected = false;
    _isCalibrated = false;
    _hasAccelData = false;
    _estimator.reset();
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
                value: _isCalibrated ? '${_estimator.angleDeg.toStringAsFixed(2)}°' : 'Calibrating...',
              ),
              if (kDebugMode)
                DeviceInfo(
                  title: 'Gyro Bias',
                  icon: BootstrapIcons.speedometer,
                  value: '${_estimator.biasZRadPerSec.toStringAsFixed(4)} rad/s',
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
                        _hasAccelData = false;
                        _estimator.reset();
                        _lastGyroUpdate = null;
                        _lastRoundedAngle = null;
                        _lastSteeringButton = null;
                        actionStreamInternal.add(
                          AlertNotification(LogLevel.LOGLEVEL_INFO, 'Calibrating the sensors now.'),
                        );
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
              'Calibrating the sensors now. Attach your phone/tablet on your handlebar and keep it still for a second.',
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
