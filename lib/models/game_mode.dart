enum GameMode {
  quiz,
  crossword,
  imagePuzzle;

  String toApiString() {
    switch (this) {
      case GameMode.quiz:
        return 'quiz';
      case GameMode.crossword:
        return 'crossword';
      case GameMode.imagePuzzle:
        return 'image_puzzle';
    }
  }

  String get displayName {
    switch (this) {
      case GameMode.quiz:
        return 'Quiz';
      case GameMode.crossword:
        return 'Crossword';
      case GameMode.imagePuzzle:
        return 'Image Puzzle';
    }
  }

  static GameMode fromApiString(String? value) {
    switch (value) {
      case 'crossword':
        return GameMode.crossword;
      case 'image_puzzle':
        return GameMode.imagePuzzle;
      default:
        return GameMode.quiz;
    }
  }
}
