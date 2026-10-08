import 'package:flutter/foundation.dart';
import 'package:bike_control/utils/keymap/buttons.dart';

/// A device that reports a steering angle and drives steerLeft/steerRight —
/// an analog input, not buttons. Rendered by the shared SteeringGauge (phone
/// steering, Elite Sterzo, Rizer) on Ride and on its steering page.
abstract interface class SteeringDevice {
  /// Live calibrated steering angle in degrees, in the gauge's convention:
  /// positive ⇒ steering LEFT, negative ⇒ steering RIGHT (as phone steering
  /// reports it). Devices whose physical angle is the other way round negate it.
  /// OpenBikeControl's `0x1B` Steering Angle is positive ⇒ RIGHT; the
  /// ObcSteeringAngleBroadcaster flips the sign on the way out.
  ValueListenable<double> get steeringAngle;

  /// True once the device has finished its initial calibration.
  ValueListenable<bool> get steeringCalibrated;

  /// Dead-zone threshold in degrees.
  double get steeringThreshold;

  ControllerButton get steerLeftButton;
  ControllerButton get steerRightButton;
}

/// A [SteeringDevice] whose straight-ahead reference the rider can set again
/// (phone steering drifts; it re-learns centre while the bars are still).
abstract interface class RecalibratableSteering {
  void recalibrate();
}
