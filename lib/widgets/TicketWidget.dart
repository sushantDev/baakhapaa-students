import 'package:flutter/material.dart';

/// A custom clipper that creates a ticket-shaped container with scalloped edges and notches
class TicketClipper extends CustomClipper<Path> {
  final double notchRadius;
  final double notchDepth;
  final double scallopRadius;
  final int scallopCount;

  const TicketClipper({
    this.notchRadius = 8,
    this.notchDepth = 6,
    this.scallopRadius = 4,
    this.scallopCount = 6,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Calculate scallop spacing
    final horizontalScallopSpacing = w / scallopCount;
    final verticalScallopCount = (scallopCount * (h / w)).round();
    final verticalScallopSpacing = h / verticalScallopCount;

    // Start at top-left
    path.moveTo(scallopRadius, 0);

    // Top edge with scallops
    for (int i = 0; i < scallopCount; i++) {
      final x = i * horizontalScallopSpacing;
      final nextX = (i + 1) * horizontalScallopSpacing;
      final midX = (x + nextX) / 2;

      path.lineTo(midX - scallopRadius, 0);
      path.arcToPoint(
        Offset(midX + scallopRadius, 0),
        radius: Radius.circular(scallopRadius),
        clockwise: false,
      );
    }
    path.lineTo(w, 0);

    // Right edge with scallops (and middle notch)
    path.lineTo(w, scallopRadius);

    for (int i = 0; i < verticalScallopCount; i++) {
      final y = i * verticalScallopSpacing;
      final nextY = (i + 1) * verticalScallopSpacing;
      final midY = (y + nextY) / 2;

      // Check if we're at the middle section (for the notch)
      if (midY > h / 2 - notchRadius - scallopRadius &&
          midY < h / 2 + notchRadius + scallopRadius) {
        // Skip scallops in the notch area
        if (midY < h / 2 - notchRadius) {
          path.lineTo(w, midY - scallopRadius);
          path.arcToPoint(
            Offset(w, midY + scallopRadius),
            radius: Radius.circular(scallopRadius),
            clockwise: true,
          );
        } else if (midY > h / 2 + notchRadius) {
          path.lineTo(w, midY - scallopRadius);
          path.arcToPoint(
            Offset(w, midY + scallopRadius),
            radius: Radius.circular(scallopRadius),
            clockwise: true,
          );
        }
      } else {
        path.lineTo(w, midY - scallopRadius);
        path.arcToPoint(
          Offset(w, midY + scallopRadius),
          radius: Radius.circular(scallopRadius),
          clockwise: true,
        );
      }
    }

    // Right middle notch
    path.lineTo(w, h / 2 - notchRadius);
    path.quadraticBezierTo(
      w - notchDepth,
      h / 2 - notchRadius / 2,
      w - notchDepth,
      h / 2,
    );
    path.quadraticBezierTo(
      w - notchDepth,
      h / 2 + notchRadius / 2,
      w,
      h / 2 + notchRadius,
    );

    path.lineTo(w, h - scallopRadius);

    // Bottom edge with scallops
    path.lineTo(w, h);
    for (int i = scallopCount; i > 0; i--) {
      final x = i * horizontalScallopSpacing;
      final prevX = (i - 1) * horizontalScallopSpacing;
      final midX = (x + prevX) / 2;

      path.lineTo(midX + scallopRadius, h);
      path.arcToPoint(
        Offset(midX - scallopRadius, h),
        radius: Radius.circular(scallopRadius),
        clockwise: false,
      );
    }
    path.lineTo(0, h);

    // Left edge with scallops (and middle notch)
    path.lineTo(0, h - scallopRadius);

    for (int i = verticalScallopCount; i > 0; i--) {
      final y = i * verticalScallopSpacing;
      final prevY = (i - 1) * verticalScallopSpacing;
      final midY = (y + prevY) / 2;

      // Check if we're at the middle section (for the notch)
      if (midY > h / 2 - notchRadius - scallopRadius &&
          midY < h / 2 + notchRadius + scallopRadius) {
        // Skip scallops in the notch area
        if (midY > h / 2 + notchRadius) {
          path.lineTo(0, midY + scallopRadius);
          path.arcToPoint(
            Offset(0, midY - scallopRadius),
            radius: Radius.circular(scallopRadius),
            clockwise: true,
          );
        } else if (midY < h / 2 - notchRadius) {
          path.lineTo(0, midY + scallopRadius);
          path.arcToPoint(
            Offset(0, midY - scallopRadius),
            radius: Radius.circular(scallopRadius),
            clockwise: true,
          );
        }
      } else {
        path.lineTo(0, midY + scallopRadius);
        path.arcToPoint(
          Offset(0, midY - scallopRadius),
          radius: Radius.circular(scallopRadius),
          clockwise: true,
        );
      }
    }

    // Left middle notch
    path.lineTo(0, h / 2 + notchRadius);
    path.quadraticBezierTo(
      notchDepth,
      h / 2 + notchRadius / 2,
      notchDepth,
      h / 2,
    );
    path.quadraticBezierTo(
      notchDepth,
      h / 2 - notchRadius / 2,
      0,
      h / 2 - notchRadius,
    );

    path.lineTo(0, scallopRadius);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// A convenience widget that applies the TicketClipper to a child widget
class TicketShape extends StatelessWidget {
  final Widget child;
  final double notchRadius;
  final double notchDepth;
  final double scallopRadius;
  final int scallopCount;
  final double? width;
  final double? height;

  const TicketShape({
    Key? key,
    required this.child,
    this.notchRadius = 8,
    this.notchDepth = 6,
    this.scallopRadius = 4,
    this.scallopCount = 6,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipPath(
        clipper: TicketClipper(
          notchRadius: notchRadius,
          notchDepth: notchDepth,
          scallopRadius: scallopRadius,
          scallopCount: scallopCount,
        ),
        child: child,
      ),
    );
  }
}
