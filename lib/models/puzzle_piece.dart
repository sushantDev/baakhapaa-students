import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PuzzlePiece {
  final int correctRow;
  final int correctCol;
  int currentRow;
  int currentCol;
  final ui.Image sourceImage;
  final Rect sourceRect;
  final int totalRows;
  final int totalCols;
  Offset position;
  bool isPlaced;

  PuzzlePiece({
    required this.correctRow,
    required this.correctCol,
    required this.sourceImage,
    required this.sourceRect,
    required this.totalRows,
    required this.totalCols,
    this.currentRow = -1,
    this.currentCol = -1,
    this.position = Offset.zero,
    this.isPlaced = false,
  });

  bool get isCorrect =>
      isPlaced && currentRow == correctRow && currentCol == correctCol;

  /// Unique key for this piece
  String get key => '${correctRow}_$correctCol';
}
