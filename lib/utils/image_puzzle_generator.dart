import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/puzzle_piece.dart';

class ImagePuzzleGenerator {
  /// Decode image bytes into a ui.Image
  static Future<ui.Image> decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Generate puzzle pieces from a decoded image
  static List<PuzzlePiece> generatePieces(ui.Image image, int rows, int cols) {
    final pieces = <PuzzlePiece>[];
    final pieceWidth = image.width / cols;
    final pieceHeight = image.height / rows;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        pieces.add(PuzzlePiece(
          correctRow: r,
          correctCol: c,
          sourceImage: image,
          sourceRect: Rect.fromLTWH(
            c * pieceWidth,
            r * pieceHeight,
            pieceWidth,
            pieceHeight,
          ),
          totalRows: rows,
          totalCols: cols,
        ));
      }
    }

    // Shuffle the pieces
    pieces.shuffle(Random());
    return pieces;
  }
}

/// Paints a single puzzle piece from the source image
class PuzzlePiecePainter extends CustomPainter {
  final PuzzlePiece piece;
  final double displayWidth;
  final double displayHeight;

  PuzzlePiecePainter({
    required this.piece,
    required this.displayWidth,
    required this.displayHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = piece.sourceRect;
    final dstRect = Rect.fromLTWH(0, 0, displayWidth, displayHeight);
    canvas.drawImageRect(piece.sourceImage, srcRect, dstRect, Paint());
  }

  @override
  bool shouldRepaint(covariant PuzzlePiecePainter oldDelegate) {
    return oldDelegate.piece != piece;
  }
}

/// A jigsaw-shaped clipper for puzzle pieces
class JigsawClipper extends CustomClipper<Path> {
  final int row;
  final int col;
  final int totalRows;
  final int totalCols;

  JigsawClipper({
    required this.row,
    required this.col,
    required this.totalRows,
    required this.totalCols,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final tabSize = min(w, h) * 0.12;

    // Start at top-left
    path.moveTo(0, 0);

    // Top edge
    if (row == 0) {
      path.lineTo(w, 0);
    } else {
      path.lineTo(w * 0.35, 0);
      path.cubicTo(
        w * 0.35,
        -tabSize,
        w * 0.65,
        -tabSize,
        w * 0.65,
        0,
      );
      path.lineTo(w, 0);
    }

    // Right edge
    if (col == totalCols - 1) {
      path.lineTo(w, h);
    } else {
      path.lineTo(w, h * 0.35);
      path.cubicTo(
        w + tabSize,
        h * 0.35,
        w + tabSize,
        h * 0.65,
        w,
        h * 0.65,
      );
      path.lineTo(w, h);
    }

    // Bottom edge
    if (row == totalRows - 1) {
      path.lineTo(0, h);
    } else {
      path.lineTo(w * 0.65, h);
      path.cubicTo(
        w * 0.65,
        h + tabSize,
        w * 0.35,
        h + tabSize,
        w * 0.35,
        h,
      );
      path.lineTo(0, h);
    }

    // Left edge
    if (col == 0) {
      path.lineTo(0, 0);
    } else {
      path.lineTo(0, h * 0.65);
      path.cubicTo(
        -tabSize,
        h * 0.65,
        -tabSize,
        h * 0.35,
        0,
        h * 0.35,
      );
      path.lineTo(0, 0);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant JigsawClipper oldClipper) {
    return oldClipper.row != row || oldClipper.col != col;
  }
}
