import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:flutter/material.dart';

/// Strokes the controller silhouette with a light fill behind it so the
/// controller body stands out from the page, without competing with the
/// positioned buttons visually.
class ControllerContourPainter extends CustomPainter {
  final ContourShape shape;
  final Color color;
  final Color fillColor;

  const ControllerContourPainter({
    required this.shape,
    required this.color,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    void drawBoth(Path path) {
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }

    switch (shape) {
      case ContourShape.puck:
        drawBoth(Path()..addOval(Offset.zero & size));
        break;
      case ContourShape.pill:
        final r = size.height / 2;
        drawBoth(Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r))));
        break;
      case ContourShape.rect:
        drawBoth(Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18))));
        break;
      case ContourShape.dropBar:
        _paintDropBar(canvas, size, fill, stroke);
        break;
      case ContourShape.steeringPad:
        _paintSteeringPad(canvas, size, drawBoth);
        break;
      case ContourShape.phone:
        drawBoth(Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28))));
        break;
      case ContourShape.zwiftPlayRight:
        _paintZwiftPlay(canvas, size, fill, stroke, mirror: false);
        break;
      case ContourShape.zwiftPlayLeft:
        _paintZwiftPlay(canvas, size, fill, stroke, mirror: true);
        break;
    }
  }

  /// Zwift Play silhouette: a rounded button-panel grip on one side and a
  /// slimmer handlebar-drop block on the other, merged into a single closed
  /// outline via `Path.combine(union)` so the seam between the two shapes
  /// never strokes a doubled line. [mirror] flips the two halves for the
  /// left-hand variant. [xMin] / [xMax] restrict the Play shape to a
  /// sub-range of the canvas width — used by [_paintDropBar] to tile two
  /// Play silhouettes (left + right) onto the same canvas.
  void _paintZwiftPlay(
    Canvas canvas,
    Size size,
    Paint fill,
    Paint stroke, {
    required bool mirror,
    double xMin = 0.0,
    double xMax = 1.0,
  }) {
    final w = size.width;
    final h = size.height;
    final xRange = xMax - xMin;

    double fx(double x) => (xMin + (mirror ? (1.0 - x) : x) * xRange) * w;
    double fy(double y) => y * h;

    Rect rect(double x0, double y0, double x1, double y1) {
      final a = fx(x0);
      final b = fx(x1);
      return Rect.fromLTRB(a < b ? a : b, fy(y0), a < b ? b : a, fy(y1));
    }

    // Grip: tall rounded rect spanning nearly the full layout height — this
    // is the physical body the rider holds.
    final grip = Path()..addRRect(RRect.fromRectAndRadius(rect(0.02, 0.05, 0.60, 0.95), const Radius.circular(20)));

    // Drop: short rounded rect aligned to the top edge of the layout. The
    // grip continues below the drop's bottom, so the shoulder between the
    // two points up (the drop is the smaller silhouette clipping around the
    // handlebar, not the main body). ~4% horizontal overlap with the grip
    // keeps the outline continuous after union.
    final drop = Path()..addRRect(RRect.fromRectAndRadius(rect(0.56, 0.05, 0.98, 0.60), const Radius.circular(20)));

    final unified = Path.combine(PathOperation.union, grip, drop);
    canvas.drawPath(unified, fill);
    canvas.drawPath(unified, stroke);
  }

  /// Handlebar-integrated controllers (Zwift Ride, Wahoo KICKR BIKE SHIFT):
  /// reuse the Zwift Play left silhouette on the left half of the canvas and
  /// the Zwift Play right silhouette on the right half. The two silhouettes
  /// stay as independent closed shapes so they read as two distinct hand
  /// positions rather than a single connected bar.
  void _paintDropBar(Canvas canvas, Size size, Paint fill, Paint stroke) {
    _paintZwiftPlay(canvas, size, fill, stroke, mirror: true, xMin: 0.0, xMax: 0.5);
    _paintZwiftPlay(canvas, size, fill, stroke, mirror: false, xMin: 0.5, xMax: 1.0);
  }

  void _paintSteeringPad(Canvas canvas, Size size, void Function(Path) drawBoth) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;
    drawBoth(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.15, midY - h * 0.15, w * 0.7, h * 0.3),
          const Radius.circular(10),
        ),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant ControllerContourPainter old) =>
      old.shape != shape || old.color != color || old.fillColor != fillColor;
}
