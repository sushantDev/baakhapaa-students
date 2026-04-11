import 'dart:math';

import '../models/crossword_puzzle.dart';

class CrosswordGenerator {
  static const int _maxGridSize = 30;

  /// Generate a crossword puzzle from episode questions.
  /// Each question's correct answer becomes a word in the crossword.
  /// [difficulty] 0.0 = easiest (fewer words, shorter), 1.0 = hardest (all words).
  static CrosswordPuzzle generate(List<dynamic> questions,
      {double difficulty = 0.5}) {
    final entries = _extractEntries(questions);
    if (entries.isEmpty) {
      return CrosswordPuzzle(
        grid: [[]],
        acrossClues: [],
        downClues: [],
        gridWidth: 0,
        gridHeight: 0,
      );
    }

    // Sort by answer length: shortest first for progressive ordering
    entries.sort((a, b) => a.normalized.length.compareTo(b.normalized.length));

    // In easy mode, limit to shorter/fewer words; hard mode uses all
    final maxWords = max(3, (entries.length * (0.5 + difficulty * 0.5)).ceil());
    final selectedEntries =
        entries.take(min(maxWords, entries.length)).toList();

    // Sort longest first for better grid placement
    selectedEntries
        .sort((a, b) => b.normalized.length.compareTo(a.normalized.length));

    final placements = <_Placement>[];
    // Use a large working grid; we'll compact later
    final workGrid = List.generate(
        _maxGridSize, (_) => List<String?>.filled(_maxGridSize, null));

    // Place first word horizontally at center
    final first = selectedEntries[0];
    final startRow = _maxGridSize ~/ 2;
    final startCol = (_maxGridSize - first.normalized.length) ~/ 2;
    _placeWord(
        workGrid, first.normalized, startRow, startCol, ClueDirection.across);
    placements.add(_Placement(
      entry: first,
      row: startRow,
      col: startCol,
      direction: ClueDirection.across,
    ));

    // Place remaining words
    for (int i = 1; i < selectedEntries.length; i++) {
      final entry = selectedEntries[i];
      final best = _findBestPlacement(workGrid, entry.normalized, placements);
      if (best != null) {
        _placeWord(
            workGrid, entry.normalized, best.row, best.col, best.direction);
        placements.add(_Placement(
          entry: entry,
          row: best.row,
          col: best.col,
          direction: best.direction,
        ));
      }
    }

    // Compact grid
    return _compactAndBuild(workGrid, placements);
  }

  /// Common stop words filtered out when extracting keywords from sentence answers.
  static const _stopWords = {
    'a',
    'an',
    'the',
    'is',
    'am',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'may',
    'might',
    'shall',
    'can',
    'need',
    'dare',
    'ought',
    'used',
    'he',
    'she',
    'it',
    'we',
    'they',
    'i',
    'you',
    'me',
    'him',
    'her',
    'us',
    'them',
    'my',
    'your',
    'his',
    'its',
    'our',
    'their',
    'mine',
    'yours',
    'hers',
    'ours',
    'theirs',
    'this',
    'that',
    'these',
    'those',
    'in',
    'on',
    'at',
    'by',
    'for',
    'with',
    'about',
    'against',
    'between',
    'through',
    'during',
    'before',
    'after',
    'above',
    'below',
    'to',
    'from',
    'up',
    'down',
    'of',
    'off',
    'over',
    'under',
    'again',
    'further',
    'then',
    'once',
    'and',
    'but',
    'or',
    'nor',
    'not',
    'so',
    'yet',
    'both',
    'either',
    'neither',
    'each',
    'every',
    'all',
    'any',
    'few',
    'more',
    'most',
    'other',
    'some',
    'such',
    'no',
    'only',
    'own',
    'same',
    'than',
    'too',
    'very',
    'just',
    'there',
    'here',
    'when',
    'where',
    'why',
    'how',
    'what',
    'which',
    'who',
    'whom',
    'into',
    'also',
    'back',
    'even',
    'still',
    'well',
    'much',
    'got',
    'get',
  };

  /// Maximum allowed length for a crossword answer.
  static const int _maxAnswerLength = 15;

  /// Extract the most meaningful keyword from a long sentence answer.
  /// e.g. "He was there for employment" → "employment"
  /// e.g. "She reminded him of his mom" → "reminded"
  static String _extractKeyWord(String original) {
    final words =
        original.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // Filter: remove stop words, keep alphanumeric words with 3+ chars
    final meaningful = words
        .where((w) => !_stopWords.contains(w.toLowerCase()))
        .where((w) => RegExp(r'^[A-Za-z0-9]+$').hasMatch(w))
        .where((w) => w.length >= 3)
        .toList();

    if (meaningful.isEmpty) {
      // Fallback: pick the longest alphanumeric word
      final sorted = words
          .where((w) => RegExp(r'[A-Za-z0-9]').hasMatch(w))
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      return sorted.isNotEmpty ? sorted.first : original;
    }

    // Pick the longest meaningful word
    meaningful.sort((a, b) => b.length.compareTo(a.length));
    return meaningful.first;
  }

  /// Extract and normalize correct answers from questions
  static List<_WordEntry> _extractEntries(List<dynamic> questions) {
    final entries = <_WordEntry>[];

    for (final q in questions) {
      final answers = q['answers'] as List<dynamic>? ?? [];
      String? correctAnswer;
      for (final a in answers) {
        if (a['is_correct'] == 1 || a['is_correct'] == true) {
          correctAnswer = a['answer']?.toString();
          break;
        }
      }
      if (correctAnswer == null) continue;

      final original = correctAnswer.trim();
      final words = original.split(RegExp(r'\s+'));
      final isSentence = words.length > 2;

      // For short answers (1-2 words), use as-is with word boundaries
      // For sentence answers (3+ words), extract the keyword
      String displayAnswer;
      String finalNormalized;
      List<int> finalBoundaries;

      if (isSentence) {
        // Extract the most meaningful keyword from the sentence
        final keyWord = _extractKeyWord(original);
        displayAnswer = keyWord;
        finalNormalized =
            keyWord.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        finalBoundaries = []; // Single word, no boundaries
      } else {
        displayAnswer = original;
        finalNormalized =
            original.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        // Compute word boundaries for 2-word answers
        finalBoundaries = <int>[];
        int pos = 0;
        for (int c = 0; c < original.length; c++) {
          if (original[c] == ' ') {
            finalBoundaries.add(pos);
          } else if (RegExp(r'[A-Za-z]').hasMatch(original[c])) {
            pos++;
          }
        }
      }

      if (finalNormalized.length < 2) continue;

      // Cap at max length
      if (finalNormalized.length > _maxAnswerLength) {
        finalNormalized = finalNormalized.substring(0, _maxAnswerLength);
      }

      entries.add(_WordEntry(
        questionText: q['question']?.toString() ?? '',
        nepaliQuestionText: q['nepali_question']?.toString(),
        originalAnswer: displayAnswer,
        normalized: finalNormalized,
        wordBoundaries: finalBoundaries,
      ));
    }

    return entries;
  }

  static void _placeWord(
    List<List<String?>> grid,
    String word,
    int row,
    int col,
    ClueDirection direction,
  ) {
    for (int i = 0; i < word.length; i++) {
      if (direction == ClueDirection.across) {
        grid[row][col + i] = word[i];
      } else {
        grid[row + i][col] = word[i];
      }
    }
  }

  static _PlacementCandidate? _findBestPlacement(
    List<List<String?>> grid,
    String word,
    List<_Placement> existing,
  ) {
    _PlacementCandidate? best;
    int bestScore = -1;

    // Try to intersect with existing words
    for (final placed in existing) {
      for (int pi = 0; pi < placed.entry.normalized.length; pi++) {
        for (int wi = 0; wi < word.length; wi++) {
          if (placed.entry.normalized[pi] != word[wi]) continue;

          // Candidate direction is opposite of placed word
          final candidateDir = placed.direction == ClueDirection.across
              ? ClueDirection.down
              : ClueDirection.across;

          int candidateRow, candidateCol;
          if (placed.direction == ClueDirection.across) {
            // Placed word is across, we go down
            candidateRow = placed.row - wi;
            candidateCol = placed.col + pi;
          } else {
            // Placed word is down, we go across
            candidateRow = placed.row + pi;
            candidateCol = placed.col - wi;
          }

          if (_canPlace(grid, word, candidateRow, candidateCol, candidateDir)) {
            // Score: prefer more intersections
            final score = _countIntersections(
                grid, word, candidateRow, candidateCol, candidateDir);
            if (score > bestScore) {
              bestScore = score;
              best = _PlacementCandidate(
                row: candidateRow,
                col: candidateCol,
                direction: candidateDir,
              );
            }
          }
        }
      }
    }

    return best;
  }

  static bool _canPlace(
    List<List<String?>> grid,
    String word,
    int row,
    int col,
    ClueDirection direction,
  ) {
    final len = word.length;

    // Check bounds
    if (row < 0 || col < 0) return false;
    if (direction == ClueDirection.across && col + len > _maxGridSize)
      return false;
    if (direction == ClueDirection.down && row + len > _maxGridSize)
      return false;

    // Check cell before word start (must be empty)
    if (direction == ClueDirection.across) {
      if (col > 0 && grid[row][col - 1] != null) return false;
      if (col + len < _maxGridSize && grid[row][col + len] != null)
        return false;
    } else {
      if (row > 0 && grid[row - 1][col] != null) return false;
      if (row + len < _maxGridSize && grid[row + len][col] != null)
        return false;
    }

    for (int i = 0; i < len; i++) {
      int r = direction == ClueDirection.across ? row : row + i;
      int c = direction == ClueDirection.across ? col + i : col;

      final existing = grid[r][c];
      if (existing != null) {
        // Must match the letter at this position
        if (existing != word[i]) return false;
      } else {
        // Check adjacent cells perpendicular to direction
        if (direction == ClueDirection.across) {
          if (r > 0 && grid[r - 1][c] != null) return false;
          if (r < _maxGridSize - 1 && grid[r + 1][c] != null) return false;
        } else {
          if (c > 0 && grid[r][c - 1] != null) return false;
          if (c < _maxGridSize - 1 && grid[r][c + 1] != null) return false;
        }
      }
    }

    return true;
  }

  static int _countIntersections(
    List<List<String?>> grid,
    String word,
    int row,
    int col,
    ClueDirection direction,
  ) {
    int count = 0;
    for (int i = 0; i < word.length; i++) {
      int r = direction == ClueDirection.across ? row : row + i;
      int c = direction == ClueDirection.across ? col + i : col;
      if (grid[r][c] != null && grid[r][c] == word[i]) {
        count++;
      }
    }
    return count;
  }

  static CrosswordPuzzle _compactAndBuild(
    List<List<String?>> workGrid,
    List<_Placement> placements,
  ) {
    if (placements.isEmpty) {
      return CrosswordPuzzle(
        grid: [[]],
        acrossClues: [],
        downClues: [],
        gridWidth: 0,
        gridHeight: 0,
      );
    }

    // Find bounding box
    int minRow = _maxGridSize, maxRow = 0, minCol = _maxGridSize, maxCol = 0;
    for (final p in placements) {
      final endRow = p.direction == ClueDirection.down
          ? p.row + p.entry.normalized.length - 1
          : p.row;
      final endCol = p.direction == ClueDirection.across
          ? p.col + p.entry.normalized.length - 1
          : p.col;
      minRow = min(minRow, p.row);
      maxRow = max(maxRow, endRow);
      minCol = min(minCol, p.col);
      maxCol = max(maxCol, endCol);
    }

    final height = maxRow - minRow + 1;
    final width = maxCol - minCol + 1;

    // Build compacted grid
    final grid = List.generate(
      height,
      (r) => List.generate(width, (c) => workGrid[r + minRow][c + minCol]),
    );

    // Build clues with adjusted positions
    final acrossClues = <CrosswordClue>[];
    final downClues = <CrosswordClue>[];
    int clueNumber = 1;

    // Assign numbers based on position (top-to-bottom, left-to-right)
    final sortedPlacements = List<_Placement>.from(placements)
      ..sort((a, b) {
        final rowCmp = a.row.compareTo(b.row);
        if (rowCmp != 0) return rowCmp;
        return a.col.compareTo(b.col);
      });

    // Track which cells get numbers
    final numberedCells = <String, int>{};

    for (final p in sortedPlacements) {
      final adjRow = p.row - minRow;
      final adjCol = p.col - minCol;
      final cellKey = '$adjRow,$adjCol';

      int num;
      if (numberedCells.containsKey(cellKey)) {
        num = numberedCells[cellKey]!;
      } else {
        num = clueNumber++;
        numberedCells[cellKey] = num;
      }

      final clue = CrosswordClue(
        number: num,
        direction: p.direction,
        questionText: p.entry.questionText,
        nepaliQuestionText: p.entry.nepaliQuestionText,
        correctAnswer: p.entry.normalized,
        originalAnswer: p.entry.originalAnswer,
        startRow: adjRow,
        startCol: adjCol,
        length: p.entry.normalized.length,
        wordBoundaries: p.entry.wordBoundaries,
      );

      if (p.direction == ClueDirection.across) {
        acrossClues.add(clue);
      } else {
        downClues.add(clue);
      }
    }

    acrossClues.sort((a, b) => a.number.compareTo(b.number));
    downClues.sort((a, b) => a.number.compareTo(b.number));

    return CrosswordPuzzle(
      grid: grid,
      acrossClues: acrossClues,
      downClues: downClues,
      gridWidth: width,
      gridHeight: height,
    );
  }
}

class _WordEntry {
  final String questionText;
  final String? nepaliQuestionText;
  final String originalAnswer;
  final String normalized;
  final List<int> wordBoundaries;

  _WordEntry({
    required this.questionText,
    this.nepaliQuestionText,
    required this.originalAnswer,
    required this.normalized,
    required this.wordBoundaries,
  });
}

class _Placement {
  final _WordEntry entry;
  final int row;
  final int col;
  final ClueDirection direction;

  _Placement({
    required this.entry,
    required this.row,
    required this.col,
    required this.direction,
  });
}

class _PlacementCandidate {
  final int row;
  final int col;
  final ClueDirection direction;

  _PlacementCandidate({
    required this.row,
    required this.col,
    required this.direction,
  });
}
