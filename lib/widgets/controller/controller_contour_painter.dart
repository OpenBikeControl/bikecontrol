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
      case ContourShape.zwiftClickV2:
        _paintZwiftClickV2(canvas, size, fill, stroke);
        break;
    }
  }

  /// Zwift Click V2: two identical pucks (nav on the left, ABYZ on the
  /// right). Each puck body is a rounded-corner diamond, with a narrower
  /// "chin" extending below for the shift button. Two independent outlines
  /// so the two halves read as separate physical units.
  void _paintZwiftClickV2(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final w = size.width;
    final h = size.height;

    void drawPuck(double centerXNorm) {
      final cx = centerXNorm * w;
      final cy = 0.42 * h;
      final half = 0.40 * h; // ~1.5× the original so 56-px buttons sit inside
      const r = 10.0; // corner-rounding offset, in edge-direction units

      // Rounded diamond (rotated rounded square) traced clockwise from the
      // top corner. `r` controls how much of each corner is rounded.
      final diamond = Path()
        ..moveTo(cx + r, cy - half + r)
        ..lineTo(cx + half - r, cy - r)
        ..quadraticBezierTo(cx + half, cy, cx + half - r, cy + r)
        ..lineTo(cx + r, cy + half - r)
        ..quadraticBezierTo(cx, cy + half, cx - r, cy + half - r)
        ..lineTo(cx - half + r, cy + r)
        ..quadraticBezierTo(cx - half, cy, cx - half + r, cy - r)
        ..lineTo(cx - r, cy - half + r)
        ..quadraticBezierTo(cx, cy - half, cx + r, cy - half + r)
        ..close();

      // Chin — narrow rounded rect whose top overlaps inside the lower point
      // of the diamond so the union reads as one continuous silhouette.
      final chinHalfWidth = 0.07 * w;
      final chin = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - chinHalfWidth, 0.78 * h, cx + chinHalfWidth, 0.96 * h),
            const Radius.circular(14),
          ),
        );

      final unified = Path.combine(PathOperation.union, diamond, chin);
      canvas.drawPath(unified, fill);
      canvas.drawPath(unified, stroke);
    }

    drawPuck(0.25); // left puck (navigation)
    drawPuck(0.75); // right puck (ABYZ)
  }

  /// Zwift Play silhouette: a rounded button-panel grip on one side and a
  /// slimmer handlebar-drop block on the other, merged into a single closed
  /// outline via `Path.combine(union)` so the seam between the two shapes
  /// never strokes a doubled line. [mirror] flips the two halves for the
  /// left-hand variant.
  void _paintZwiftPlay(Canvas canvas, Size size, Paint fill, Paint stroke, {required bool mirror}) {
    final w = size.width;
    final h = size.height;

    double fx(double x) => mirror ? (1.0 - x) * w : x * w;
    double fy(double y) => y * h;

    Rect rect(double x0, double y0, double x1, double y1) {
      final a = fx(x0);
      final b = fx(x1);
      return Rect.fromLTRB(a < b ? a : b, fy(y0), a < b ? b : a, fy(y1));
    }

    // Grip: tall rounded rect spanning nearly the full layout height — this
    // is the physical body the rider holds.
    final grip = Path()
      ..addRRect(RRect.fromRectAndRadius(rect(0.02, 0.05, 0.60, 0.95), const Radius.circular(20)));

    // Drop: short rounded rect aligned to the top edge of the layout. The
    // grip continues below the drop's bottom, so the shoulder between the
    // two points up (the drop is the smaller silhouette clipping around the
    // handlebar, not the main body). ~4% horizontal overlap with the grip
    // keeps the outline continuous after union.
    final drop = Path()
      ..addRRect(RRect.fromRectAndRadius(rect(0.56, 0.05, 0.98, 0.60), const Radius.circular(20)));

    final unified = Path.combine(PathOperation.union, grip, drop);
    canvas.drawPath(unified, fill);
    canvas.drawPath(unified, stroke);
  }

  /// Drop-bar contour has two open grip strokes + a connecting top bar. No
  /// closed area to fill, so this draws only the stroke.
  void _paintDropBar(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final w = size.width;
    final h = size.height;
    final gripW = w * 0.22;
    final topY = h * 0.22;
    final bottomY = h * 0.92;
    final path = Path()
      ..moveTo(0, topY)
      ..lineTo(gripW, topY)
      ..lineTo(gripW, bottomY)
      ..moveTo(w, topY)
      ..lineTo(w - gripW, topY)
      ..lineTo(w - gripW, bottomY)
      ..moveTo(gripW, topY)
      ..lineTo(w - gripW, topY);
    canvas.drawPath(path, stroke);
  }

  void _paintSteeringPad(Canvas canvas, Size size, void Function(Path) drawBoth) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;
    drawBoth(
      Path()
        ..addRRect(
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
