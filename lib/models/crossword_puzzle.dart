enum ClueDirection { across, down }

class CrosswordClue {
  final int number;
  final ClueDirection direction;
  final String questionText;
  final String? nepaliQuestionText;
  final String correctAnswer; // normalized (uppercase, no spaces)
  final String originalAnswer;
  final int startRow;
  final int startCol;
  final int length;
  final List<int> wordBoundaries; // indices where original spaces were
  bool isSolved;

  CrosswordClue({
    required this.number,
    required this.direction,
    required this.questionText,
    this.nepaliQuestionText,
    required this.correctAnswer,
    required this.originalAnswer,
    required this.startRow,
    required this.startCol,
    required this.length,
    this.wordBoundaries = const [],
    this.isSolved = false,
  });
}

class CrosswordPuzzle {
  final List<List<String?>> grid;
  final List<CrosswordClue> acrossClues;
  final List<CrosswordClue> downClues;
  final int gridWidth;
  final int gridHeight;

  CrosswordPuzzle({
    required this.grid,
    required this.acrossClues,
    required this.downClues,
    required this.gridWidth,
    required this.gridHeight,
  });

  List<CrosswordClue> get allClues => [...acrossClues, ...downClues];

  bool validateWord(CrosswordClue clue, String userAnswer) {
    final normalized =
        userAnswer.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return normalized == clue.correctAnswer;
  }

  bool get isComplete => allClues.every((c) => c.isSolved);

  /// Get all cells belonging to a clue as (row, col) pairs
  List<List<int>> getClueCells(CrosswordClue clue) {
    final cells = <List<int>>[];
    for (int i = 0; i < clue.length; i++) {
      if (clue.direction == ClueDirection.across) {
        cells.add([clue.startRow, clue.startCol + i]);
      } else {
        cells.add([clue.startRow + i, clue.startCol]);
      }
    }
    return cells;
  }
}
