import 'dart:ui' as ui;

import 'package:shadcn_flutter/shadcn_flutter.dart';

Offset quadBezier(double t, Offset p0, Offset p1, Offset p2) {
  final u = 1 - t;
  return Offset(
    u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
    u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
  );
}

class HorizontalFlowPainter extends CustomPainter {
  final double bicycleX, bicycleY;
  final double logoLeftX, logoRightX, logoCenterY;
  final double trainerCenterX, trainerCenterY;
  final Color color;
  final bool isTrainerConnected;

  HorizontalFlowPainter({
    required this.bicycleX,
    required this.bicycleY,
    required this.logoLeftX,
    required this.logoRightX,
    required this.logoCenterY,
    required this.trainerCenterX,
    required this.trainerCenterY,
    required this.color,
    required this.isTrainerConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;

    // Left segment: bicycle → logo left edge
    final leftPath = ui.Path()
      ..moveTo(bicycleX, bicycleY)
      ..quadraticBezierTo((bicycleX + logoLeftX) / 2, logoCenterY, logoLeftX, logoCenterY);
    canvas.drawPath(leftPath, paint);

    // Right segment: logo right edge → trainer center
    final rightColor = isTrainerConnected ? color : const Color(0xFFEF4444);

    if (isTrainerConnected) {
      final rightPaint = Paint()
        ..color = rightColor.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..strokeCap = ui.StrokeCap.round
        ..style = ui.PaintingStyle.stroke;
      final rightPath = ui.Path()
        ..moveTo(logoRightX, logoCenterY)
        ..quadraticBezierTo((logoRightX + trainerCenterX) / 2, logoCenterY, trainerCenterX, trainerCenterY);
      canvas.drawPath(rightPath, rightPaint);
    } else {
      // Dashed line along the same Bezier curve
      final dashPaint = Paint()
        ..color = rightColor.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..strokeCap = ui.StrokeCap.round;
      final rP0 = Offset(logoRightX, logoCenterY);
      final rP1 = Offset((logoRightX + trainerCenterX) / 2, logoCenterY);
      final rP2 = Offset(trainerCenterX, trainerCenterY);
      const dashFrac = 0.03;
      const gapFrac = 0.04;
      double t = 0;
      while (t < 1.0) {
        final tEnd = (t + dashFrac).clamp(0.0, 1.0);
        final from = quadBezier(t, rP0, rP1, rP2);
        final to = quadBezier(tEnd, rP0, rP1, rP2);
        canvas.drawLine(from, to, dashPaint);
        t = tEnd + gapFrac;
      }
    }

    // Chevrons
    final chevronPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;

    final lP0 = Offset(bicycleX, bicycleY);
    final lP1 = Offset((bicycleX + logoLeftX) / 2, logoCenterY);
    final lP2 = Offset(logoLeftX, logoCenterY);
    final c1 = quadBezier(0.4, lP0, lP1, lP2);
    final chevron1 = ui.Path()
      ..moveTo(c1.dx - 4, c1.dy - 5)
      ..lineTo(c1.dx + 2, c1.dy)
      ..lineTo(c1.dx - 4, c1.dy + 5);
    canvas.drawPath(chevron1, chevronPaint);

    if (isTrainerConnected) {
      final rP0 = Offset(logoRightX, logoCenterY);
      final rP1 = Offset((logoRightX + trainerCenterX) / 2, logoCenterY);
      final rP2 = Offset(trainerCenterX, trainerCenterY);
      final c2 = quadBezier(0.6, rP0, rP1, rP2);
      final chevron2 = ui.Path()
        ..moveTo(c2.dx - 4, c2.dy - 5)
        ..lineTo(c2.dx + 2, c2.dy)
        ..lineTo(c2.dx - 4, c2.dy + 5);
      canvas.drawPath(chevron2, chevronPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HorizontalFlowPainter old) {
    return old.bicycleX != bicycleX ||
        old.bicycleY != bicycleY ||
        old.logoLeftX != logoLeftX ||
        old.logoRightX != logoRightX ||
        old.logoCenterY != logoCenterY ||
        old.trainerCenterX != trainerCenterX ||
        old.trainerCenterY != trainerCenterY ||
        old.isTrainerConnected != isTrainerConnected;
  }
}
