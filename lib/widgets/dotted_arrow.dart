import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

class CurvedDottedArrowWidget extends StatelessWidget {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final Color color;
  final double strokeWidth;

  CurvedDottedArrowWidget({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    this.color = Colors.orange,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CurvedDottedArrowPainter(
          startX, startY, endX, endY, color, strokeWidth),
      size: Size(80, 60),
    );
  }
}

class CurvedDottedArrowPainter extends CustomPainter {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final Color color;
  final double strokeWidth;

  CurvedDottedArrowPainter(this.startX, this.startY, this.endX, this.endY,
      this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Create curved path
    final Path path = Path();
    path.moveTo(startX, startY);
    path.quadraticBezierTo(
        (startX + endX) / 2 + 20, // Control point X (curved)
        (startY + endY) / 2, // Control point Y
        endX,
        endY);

    // Draw dotted line
    canvas.drawPath(
      dashPath(path,
          dashArray: CircularIntervalList<double>(<double>[8.0, 4.0])),
      paint,
    );

    // Draw arrow head
    final double arrowSize = 8.0;
    final Path arrowHead = Path();
    arrowHead.moveTo(endX - arrowSize, endY - arrowSize);
    arrowHead.lineTo(endX, endY);
    arrowHead.lineTo(endX - arrowSize, endY + arrowSize);

    final Paint arrowPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(arrowHead, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
