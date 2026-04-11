import 'package:flutter/material.dart';

class LevelConnectorPainter extends CustomPainter {
  final bool isCompleted;
  final bool isFirst;
  final bool isLast;
  final bool isAlternateLeft;
  final bool nextAlternateLeft;
  final bool isCurrent;

  LevelConnectorPainter({
    required this.isCompleted,
    required this.isFirst,
    required this.isLast,
    required this.isAlternateLeft,
    required this.nextAlternateLeft,
    required this.isCurrent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintDotted = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw vertical dotted line through center ONLY for non-completed levels
    if (!isCompleted) {
      double centerX = size.width / 2;
      double dashHeight = 5, dashSpace = 5;
      double startY = 0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(centerX, startY),
          Offset(centerX, (startY + dashHeight).clamp(0, size.height)),
          paintDotted,
        );
        startY += dashHeight + dashSpace;
      }
    }

    if (isCompleted || isCurrent) {
      final paintCurve = Paint()
        ..color = const Color(0xFFFF9F1C)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      double xCenter = size.width / 2;
      double xLeft = size.width * 0.35; // Narrowed further from 0.25
      double xRight = size.width * 0.65; // Narrowed further from 0.75

      double xTop = (isCurrent || !isCompleted)
          ? xCenter
          : (isAlternateLeft ? xLeft : xRight);
      double xBottom = (isLast || !isCompleted)
          ? xCenter
          : (nextAlternateLeft ? xLeft : xRight);

      final path = Path();
      path.moveTo(xTop, 0);
      // Use cubic Bezier for an even flatter, straighter diagonal transition
      path.cubicTo(
        xTop,
        size.height * 0.2, // Closer to 0 for a more direct turn
        xBottom,
        size.height * 0.8, // Closer to 1 for a more direct turn
        xBottom,
        size.height,
      );

      // Draw glow
      final paintGlow = Paint()
        ..color = const Color(0xFFFF9F1C).withOpacity(0.4)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(path, paintGlow);

      // Draw main line
      canvas.drawPath(path, paintCurve);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
