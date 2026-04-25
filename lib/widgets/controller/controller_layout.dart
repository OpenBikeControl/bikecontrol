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

  /// Zwift Click V2 is two separate pucks (nav + ABYZ) each with a small
  /// "chin" extending downward for the shift button. Two independent
  /// outlines — no unification between the halves.
  zwiftClickV2,
}

/// Declarative layout for one physical controller. Positions use normalized
/// [0, 1] coordinates so the layout scales with the available footer width.
/// Keys are the actual [ControllerButton] instances (typed, not strings) so
/// typos are compile-time errors.
class ControllerLayout {
  final double aspectRatio;
  final ContourShape shape;
  final double padding;
  final Map<ControllerButton, Offset> positions;

  /// Optional asset path to an SVG silhouette in `assets/contours/`. When set,
  /// the canvas renders that SVG behind the buttons instead of the procedural
  /// [ControllerContourPainter] for [shape].
  final String? svgAsset;

  /// Rotates the SVG silhouette by this many degrees (90° increments only).
  /// [aspectRatio] and [positions] are interpreted in the post-rotation frame
  /// — i.e. the on-screen canvas. Useful when the source SVG is portrait but
  /// the device sits landscape on the bar (e.g. ThinkRider VS200).
  final double rotation;

  /// Horizontally mirrors the SVG silhouette. Used to share a single source
  /// SVG between mirror-image device pairs (e.g. Zwift Play left vs right).
  /// [positions] still refer to the on-screen frame, so the buttons aren't
  /// flipped — only the silhouette art is.
  final bool mirrorX;

  const ControllerLayout({
    required this.aspectRatio,
    required this.shape,
    required this.positions,
    this.svgAsset,
    this.rotation = 0,
    this.padding = 0,
    this.mirrorX = false,
  });
}
