import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/material.dart';

/// Geometric description of a physical controller's silhouette. Each concrete
/// shape has a known painter in [controller_contour_painter.dart].
enum ContourShape {
  /// Circle or ellipse — e.g. Zwift Click V1.
  puck,
  /// Rounded-rect pill shape — e.g. Cycplus BC2, Zwift Click V2.
  pill,
  /// Rounded rectangle — e.g. Zwift Play grip.
  rect,
  /// Two handlebar drops joined by a flat top tube — e.g. Zwift Ride,
  /// Wahoo KICKR BIKE SHIFT.
  dropBar,
  /// Flat triangular steering pad — e.g. Elite Sterzo.
  steeringPad,
  /// Phone silhouette — e.g. Gyroscope Steering (virtual).
  phone,
  /// Zwift Play right-side grip with paired handlebar drop. Compact button
  /// panel on the left half + C-curve of a handlebar drop on the right.
  zwiftPlayRight,
  /// Mirrored zwiftPlayRight for the left-hand controller: drop curves to
  /// the left, button panel on the right half.
  zwiftPlayLeft,
}

/// Declarative layout for one physical controller. Positions use normalized
/// [0, 1] coordinates so the layout scales with the available footer width.
/// Keys are the actual [ControllerButton] instances (typed, not strings) so
/// typos are compile-time errors.
class ControllerLayout {
  final double aspectRatio;
  final ContourShape shape;
  final Map<ControllerButton, Offset> positions;

  const ControllerLayout({
    required this.aspectRatio,
    required this.shape,
    required this.positions,
  });
}
