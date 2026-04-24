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
    }
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
