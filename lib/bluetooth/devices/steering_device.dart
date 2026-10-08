import 'package:flutter/foundation.dart';
import 'package:bike_control/utils/keymap/buttons.dart';

/// A device that reports a steering angle and drives steerLeft/steerRight —
/// used to render the shared SteeringGauge (phone steering, Elite Sterzo, Rizer).
abstract interface class SteeringDevice {
  /// Live calibrated steering angle in degrees, in the gauge's convention:
  /// positive ⇒ steering LEFT, negative ⇒ steering RIGHT (as phone steering
  /// reports it). Devices whose physical angle is the other way round negate it.
  ValueListenable<double> get steeringAngle;

  /// True once the device has finished its initial calibration.
  ValueListenable<bool> get steeringCalibrated;

  /// Dead-zone threshold in degrees.
  double get steeringThreshold;

  /// Clear the current neutral reference and learn a new one from live input.
  void recalibrate();

  ControllerButton get steerLeftButton;
  ControllerButton get steerRightButton;
}
