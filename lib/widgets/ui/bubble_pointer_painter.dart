import 'dart:ui' as ui;

import 'package:shadcn_flutter/shadcn_flutter.dart';

class BubblePointerPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  BubblePointerPainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fillColor);

    // Only draw the two diagonal sides (not the bottom, which merges into the card)
    final borderPath = ui.Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(
      borderPath,
      Paint()
        ..color = borderColor
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant BubblePointerPainter old) =>
      old.fillColor != fillColor || old.borderColor != borderColor;
}
