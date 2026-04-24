import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:flutter/material.dart';

/// Strokes a light silhouette of the controller behind the positioned
/// buttons. Stroke-only (no fill) so the buttons remain the focal point.
class ControllerContourPainter extends CustomPainter {
  final ContourShape shape;
  final Color color;

  const ControllerContourPainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    switch (shape) {
      case ContourShape.puck:
        canvas.drawOval(Offset.zero & size, paint);
        break;
      case ContourShape.pill:
        final r = size.height / 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)),
          paint,
        );
        break;
      case ContourShape.rect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
          paint,
        );
        break;
      case ContourShape.dropBar:
        _paintDropBar(canvas, size, paint);
        break;
      case ContourShape.steeringPad:
        _paintSteeringPad(canvas, size, paint);
        break;
      case ContourShape.phone:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28)),
          paint,
        );
        break;
      case ContourShape.zwiftPlayRight:
        _paintZwiftPlay(canvas, size, paint, mirror: false);
        break;
      case ContourShape.zwiftPlayLeft:
        _paintZwiftPlay(canvas, size, paint, mirror: true);
        break;
    }
  }

  /// Zwift Play silhouette: a rounded button-panel grip on one side and a
  /// C-shaped handlebar drop sweeping to the other. [mirror] flips the two
  /// halves for the left-hand variant.
  void _paintZwiftPlay(Canvas canvas, Size size, Paint paint, {required bool mirror}) {
    final w = size.width;
    final h = size.height;

    double fx(double x) => mirror ? (1.0 - x) * w : x * w;
    double fy(double y) => y * h;

    // Button-panel grip (rounded rect in the 0..0.5 band, pre-mirror).
    final gripLeft = mirror ? fx(0.48) : fx(0.02);
    final gripRight = mirror ? fx(0.02) : fx(0.48);
    canvas.drawRRect(
      RRect.fromLTRBR(
        gripLeft < gripRight ? gripLeft : gripRight,
        fy(0.10),
        gripLeft < gripRight ? gripRight : gripLeft,
        fy(0.68),
        const Radius.circular(20),
      ),
      paint,
    );

    // Handlebar-drop C-curve on the opposite half. Normalized points (pre-
    // mirror). Traces: top-of-drop → round right corner → down outer edge →
    // round bottom corner → inward along bottom → up to meet the grip.
    final path = Path()
      ..moveTo(fx(0.45), fy(0.10))
      ..lineTo(fx(0.82), fy(0.10))
      ..quadraticBezierTo(fx(0.98), fy(0.10), fx(0.98), fy(0.28))
      ..lineTo(fx(0.98), fy(0.82))
      ..quadraticBezierTo(fx(0.98), fy(0.95), fx(0.85), fy(0.95))
      ..lineTo(fx(0.55), fy(0.95))
      ..quadraticBezierTo(fx(0.45), fy(0.95), fx(0.45), fy(0.85))
      ..lineTo(fx(0.45), fy(0.10));
    canvas.drawPath(path, paint);
  }

  void _paintDropBar(Canvas canvas, Size size, Paint paint) {
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
    canvas.drawPath(path, paint);
  }

  void _paintSteeringPad(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.15, midY - h * 0.15, w * 0.7, h * 0.3),
        const Radius.circular(10),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ControllerContourPainter old) =>
      old.shape != shape || old.color != color;
}
