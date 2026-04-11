import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../models/crossword_puzzle.dart';
import '../../models/game_mode.dart';
import '../../models/url.dart';
import '../../providers/auth.dart';
import '../../utils/debug_logger.dart';
import '../../providers/story.dart';
import '../../utils/crossword_generator.dart';
import '../story/win_screen.dart';
import '../story/loose_screen.dart';

/// Cost in coins for one crossword hint (reveal a letter)
const int kCrosswordHintCost = 5;

class CrosswordScreen extends StatefulWidget {
  static const routeName = '/crossword-screen';

  const CrosswordScreen({Key? key}) : super(key: key);

  @override
  State<CrosswordScreen> createState() => _CrosswordScreenState();
}

class _CrosswordScreenState extends State<CrosswordScreen>
    with TickerProviderStateMixin {
  late Map<String, dynamic> episode;
  late CrosswordPuzzle puzzle;
  late int lives;
  late int maxLives;
  bool _isInit = false;
  bool _gameComplete = false;

  // User input grid
  late List<List<String?>> _userGrid;

  // Currently selected clue
  CrosswordClue? _selectedClue;

  // Focus tracking
  int _focusedCellRow = -1;
  int _focusedCellCol = -1;

  // Animation controllers
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late AnimationController _correctController;
  late AnimationController _wrongController;
  late Animation<double> _wrongShake;
  late AnimationController _completionController;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Cells that are pre-filled as hints (not editable)
  Set<String> _hintCells = {};

  // Cells revealed by purchased hints (golden glow)
  Set<String> _purchasedHintCells = {};

  // Cells that are currently animating as correct
  Set<String> _correctCells = {};
  // Cells that are currently animating as wrong
  Set<String> _wrongCells = {};

  // Rewarded ad for free hints
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  final _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-8105529278923041/8001756243'
      : 'ca-app-pub-8105529278923041/5550852727';

  // The text input controller for the "type" overlay
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  // Difficulty level (0.0 = easiest, 1.0 = hardest)
  double _difficulty = 0.5;

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      final story = Provider.of<Story>(context, listen: false);
      episode = story.episode;
      story.setGameModeSilently(GameMode.crossword);

      final questions = episode['questions'] as List<dynamic>? ?? [];

      // Calculate difficulty from completed episodes in the season
      final seasonEpisodes =
          (story.selectedSeason['episodes'] as List<dynamic>?) ?? [];
      final completedCount =
          seasonEpisodes.where((e) => e['watched'] == true).length;
      if (completedCount <= 2) {
        _difficulty = 0.2; // Easy: fewer words, more hints
      } else if (completedCount <= 5) {
        _difficulty = 0.5; // Medium
      } else if (completedCount <= 8) {
        _difficulty = 0.75; // Hard
      } else {
        _difficulty = 1.0; // Expert: all words, fewer hints
      }

      puzzle = CrosswordGenerator.generate(questions, difficulty: _difficulty);

      final baseLives = episode['base_lives'] as int? ?? 3;
      lives = baseLives;
      maxLives = baseLives;

      _userGrid = List.generate(
        puzzle.gridHeight,
        (_) => List<String?>.filled(puzzle.gridWidth, null),
      );

      _generateHints();
      _initAnimations();
      _loadRewardedAd();
      _isInit = true;
    }
    super.didChangeDependencies();
  }

  void _initAnimations() {
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heartScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: Curves.easeOutBack,
      ),
    );

    _correctController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _wrongController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _wrongShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 8), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 25),
    ]).animate(CurvedAnimation(
      parent: _wrongController,
      curve: Curves.easeOut,
    ));

    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
  }

  /// Pre-fill hints based on difficulty level.
  /// Easy = ~50% hints, Medium = ~35%, Hard = ~20%, Expert = ~10%
  void _generateHints() {
    final rng = Random();
    final hintPercent = 0.5 - (_difficulty * 0.4); // 0.5 at easy, 0.1 at expert
    for (final clue in puzzle.allClues) {
      final cells = puzzle.getClueCells(clue);
      final hintCount = max(1, (cells.length * hintPercent).ceil());

      // Collect indices that aren't already hinted (from intersecting words)
      final availableIndices = <int>[];
      for (int i = 0; i < cells.length; i++) {
        final key = '${cells[i][0]},${cells[i][1]}';
        if (!_hintCells.contains(key)) {
          availableIndices.add(i);
        }
      }

      // Shuffle and pick hint indices
      availableIndices.shuffle(rng);
      final toHint = min(hintCount, availableIndices.length);
      for (int h = 0; h < toHint; h++) {
        final idx = availableIndices[h];
        final row = cells[idx][0];
        final col = cells[idx][1];
        final key = '$row,$col';
        _hintCells.add(key);
        _userGrid[row][col] = clue.correctAnswer[idx];
      }
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    _correctController.dispose();
    _wrongController.dispose();
    _completionController.dispose();
    _audioPlayer.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _loadRewardedAd() {
    if (_isAdLoading) return;
    _isAdLoading = true;
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
          _isAdLoading = false;
        },
      ),
    );
  }

  void _selectClue(CrosswordClue clue) {
    if (clue.isSolved) return;
    setState(() {
      _selectedClue = clue;
      // Focus on first non-hint, non-filled cell
      final cells = puzzle.getClueCells(clue);
      _focusedCellRow = clue.startRow;
      _focusedCellCol = clue.startCol;
      for (final c in cells) {
        final key = '${c[0]},${c[1]}';
        if (!_hintCells.contains(key) &&
            !_correctCells.contains(key) &&
            _userGrid[c[0]][c[1]] == null) {
          _focusedCellRow = c[0];
          _focusedCellCol = c[1];
          break;
        }
      }
    });
    // Pre-fill input with only user-typed letters (not hints)
    final cells = puzzle.getClueCells(clue);
    final inputBuf = StringBuffer();
    for (final c in cells) {
      final key = '${c[0]},${c[1]}';
      if (_hintCells.contains(key) || _correctCells.contains(key)) continue;
      final letter = _userGrid[c[0]][c[1]];
      if (letter != null) inputBuf.write(letter);
    }
    _inputController.text = inputBuf.toString();
    // Delay focus request to ensure the widget tree has settled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  void _onCellTapped(int row, int col) {
    // Find a clue that contains this cell
    if (puzzle.grid[row][col] == null) return;

    for (final clue in puzzle.allClues) {
      if (clue.isSolved) continue;
      final cells = puzzle.getClueCells(clue);
      if (cells.any((c) => c[0] == row && c[1] == col)) {
        _selectClue(clue);
        return;
      }
    }
  }

  void _onInputChanged(String value) {
    if (_selectedClue == null) return;
    final clue = _selectedClue!;
    final cells = puzzle.getClueCells(clue);
    final upperValue = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Collect indices of editable (non-hint, non-correct) cells
    final editableCells = <int>[];
    for (int i = 0; i < cells.length; i++) {
      final key = '${cells[i][0]},${cells[i][1]}';
      if (!_hintCells.contains(key) && !_correctCells.contains(key)) {
        editableCells.add(i);
      }
    }

    // Smart input: if user typed more chars than editable cells, they may
    // have typed the full answer including pre-filled letters. Strip the
    // pre-filled letters from input so "HEWAS" with H_W_S → editable "EA".
    String effectiveInput = upperValue;
    if (upperValue.length > editableCells.length) {
      final stripped = StringBuffer();
      int inputIdx = 0;
      for (int i = 0; i < cells.length && inputIdx < upperValue.length; i++) {
        final key = '${cells[i][0]},${cells[i][1]}';
        final isPreFilled =
            _hintCells.contains(key) || _correctCells.contains(key);
        if (isPreFilled) {
          final preFilledLetter = _userGrid[cells[i][0]][cells[i][1]];
          if (upperValue[inputIdx] == preFilledLetter) {
            inputIdx++; // Skip matching pre-filled letter in input
          }
          // If doesn't match, skip the pre-filled cell without consuming input
        } else {
          stripped.write(upperValue[inputIdx]);
          inputIdx++;
        }
      }
      effectiveInput = stripped.toString();
    }

    setState(() {
      // Map effective input characters to editable cells sequentially
      for (int e = 0; e < editableCells.length; e++) {
        final cellIdx = editableCells[e];
        if (e < effectiveInput.length) {
          _userGrid[cells[cellIdx][0]][cells[cellIdx][1]] = effectiveInput[e];
        } else {
          _userGrid[cells[cellIdx][0]][cells[cellIdx][1]] = null;
        }
      }

      // Update focus position to next empty editable cell
      for (int e = 0; e < editableCells.length; e++) {
        final cellIdx = editableCells[e];
        if (e >= effectiveInput.length) {
          _focusedCellRow = cells[cellIdx][0];
          _focusedCellCol = cells[cellIdx][1];
          break;
        }
      }
    });

    // Auto-submit when all editable cells filled
    if (effectiveInput.length >= editableCells.length) {
      _submitWord();
    }
  }

  void _submitWord() {
    if (_selectedClue == null) return;
    final clue = _selectedClue!;
    final cells = puzzle.getClueCells(clue);
    final userAnswer = cells.map((c) => _userGrid[c[0]][c[1]] ?? '').join();

    if (userAnswer.length < clue.length) return;

    if (puzzle.validateWord(clue, userAnswer)) {
      _onCorrectWord(clue, cells);
    } else {
      _onWrongWord(clue, cells);
    }
  }

  void _onCorrectWord(CrosswordClue clue, List<List<int>> cells) async {
    setState(() {
      clue.isSolved = true;
      for (final c in cells) {
        _correctCells.add('${c[0]},${c[1]}');
        // Fill in the correct letter (in case they typed something slightly different)
        final idx = cells.indexOf(c);
        _userGrid[c[0]][c[1]] = clue.correctAnswer[idx];
      }
      _selectedClue = null;
    });

    _correctController.forward(from: 0);
    HapticFeedback.mediumImpact();
    await _audioPlayer.play(AssetSource('sounds/correct.wav'));
    _inputFocusNode.unfocus();

    // Check completion
    if (puzzle.isComplete) {
      _onGameComplete();
    }
  }

  void _onWrongWord(CrosswordClue clue, List<List<int>> cells) async {
    setState(() {
      for (final c in cells) {
        _wrongCells.add('${c[0]},${c[1]}');
      }
      lives--;
    });

    _wrongController.forward(from: 0);
    _heartController.forward(from: 0);

    // 3-burst haptic
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();

    await _audioPlayer.play(AssetSource('sounds/wrong.wav'));

    // Clear wrong cells after animation
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      for (final c in cells) {
        final key = '${c[0]},${c[1]}';
        _wrongCells.remove(key);
        if (!_correctCells.contains(key) && !_hintCells.contains(key)) {
          _userGrid[c[0]][c[1]] = null;
        }
      }
      _inputController.clear();
    });

    if (lives <= 0) {
      _onGameOver();
    }
  }

  /// Use a hint to reveal one random unrevealed letter.
  void _useHint() {
    final auth = Provider.of<Auth>(context, listen: false);
    final coins = auth.userAvailableCoins;

    // Collect all unrevealed cells across all unsolved clues
    final revealable = <MapEntry<CrosswordClue, int>>[];
    for (final clue in puzzle.allClues) {
      if (clue.isSolved) continue;
      final cells = puzzle.getClueCells(clue);
      for (int i = 0; i < cells.length; i++) {
        final key = '${cells[i][0]},${cells[i][1]}';
        if (!_hintCells.contains(key) &&
            !_correctCells.contains(key) &&
            !_purchasedHintCells.contains(key)) {
          revealable.add(MapEntry(clue, i));
        }
      }
    }

    if (revealable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more letters to reveal!')),
      );
      return;
    }

    _showHintBottomSheet(auth, coins, revealable);
  }

  void _showHintBottomSheet(
      Auth auth, int coins, List<MapEntry<CrosswordClue, int>> revealable) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasEnoughCoins = coins >= kCrosswordHintCost;
    final hasAd = _rewardedAd != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Lightbulb icon with glow
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.lightbulb, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Need a Hint?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reveal a letter to help you solve the puzzle',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            // Coin option
            _buildHintOption(
              ctx: ctx,
              icon: Icons.monetization_on_rounded,
              iconColor: const Color(0xFFFFD700),
              title: 'Use Coins',
              subtitle: hasEnoughCoins
                  ? '$kCrosswordHintCost coins  •  Balance: $coins'
                  : 'Not enough coins ($coins/$kCrosswordHintCost)',
              enabled: hasEnoughCoins,
              gradient: const [Color(0xFFFFD700), Color(0xFFFFA000)],
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _executeHint(auth, revealable, freeFromAd: false);
              },
            ),
            const SizedBox(height: 12),
            // Watch ad option
            _buildHintOption(
              ctx: ctx,
              icon: Icons.play_circle_filled_rounded,
              iconColor: const Color(0xFF4CAF50),
              title: 'Watch an Ad',
              subtitle: hasAd ? 'Free hint after watching' : 'Loading ad...',
              enabled: hasAd,
              gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _showRewardedAdForHint(revealable);
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintOption({
    required BuildContext ctx,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool enabled,
    required List<Color> gradient,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? gradient[0].withValues(alpha: 0.4)
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            ),
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled
                      ? gradient[0].withValues(alpha: 0.15)
                      : (isDark ? Colors.grey[800] : Colors.grey[200]),
                ),
                child: Icon(icon,
                    color: enabled ? iconColor : Colors.grey, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        )),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: enabled
                    ? (isDark ? Colors.white38 : Colors.black38)
                    : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRewardedAdForHint(List<MapEntry<CrosswordClue, int>> revealable) {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        // Always restore keyboard focus after fullscreen ad closes,
        // even if the hint auto-completed a word (which clears _selectedClue)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !puzzle.isComplete) {
            _inputFocusNode.requestFocus();
          }
        });
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (_, reward) {
      _executeHint(
        Provider.of<Auth>(context, listen: false),
        revealable,
        freeFromAd: true,
      );
    });
  }

  void _executeHint(Auth auth, List<MapEntry<CrosswordClue, int>> revealable,
      {required bool freeFromAd}) {
    final rng = Random();
    final pick = revealable[rng.nextInt(revealable.length)];
    final clue = pick.key;
    final idx = pick.value;
    final cells = puzzle.getClueCells(clue);
    final row = cells[idx][0];
    final col = cells[idx][1];

    setState(() {
      final key = '$row,$col';
      _hintCells.add(key);
      _purchasedHintCells.add(key);
      _userGrid[row][col] = clue.correctAnswer[idx];
    });

    HapticFeedback.mediumImpact();

    if (!freeFromAd) {
      // Deduct coins locally for immediate UI feedback
      auth.deductCoinsLocally(kCrosswordHintCost);

      // Log transaction on backend and sync balance from response
      final story = Provider.of<Story>(context, listen: false);
      http
          .post(
        Uri.parse(Url.baakhapaaApi('/coin-transaction')),
        headers: Url.baakhapaaAuthHeaders(story.authToken),
        body: json.encode({
          'status': 'spent',
          'coin': kCrosswordHintCost,
          'remarks': 'Crossword hint used',
        }),
      )
          .then((response) {
        try {
          final responseData = json.decode(response.body);
          final balances = responseData['data']?['updated_balances'];
          if (responseData['success'] == true && balances != null) {
            final newBalance = balances['available_coins'];
            if (newBalance != null && mounted) {
              auth.syncAvailableCoins(newBalance as int);
            }
          } else if (responseData['success'] != true) {
            if (mounted) auth.addCoinsLocally(kCrosswordHintCost);
            DebugLogger.error(
                'Crossword hint transaction rejected: ${responseData['message']}');
          }
        } catch (e) {
          DebugLogger.error('Crossword hint response parse error: $e');
        }
      }).catchError((e) {
        if (mounted) auth.addCoinsLocally(kCrosswordHintCost);
        DebugLogger.error('Crossword hint transaction network error: $e');
      });
    }

    // Check if revealed letter completes any word
    for (final c in puzzle.allClues) {
      if (c.isSolved) continue;
      final cCells = puzzle.getClueCells(c);
      final allFilled = cCells.every((cell) {
        final key = '${cell[0]},${cell[1]}';
        return _hintCells.contains(key) || _correctCells.contains(key);
      });
      if (allFilled) {
        final userAnswer =
            cCells.map((cell) => _userGrid[cell[0]][cell[1]] ?? '').join();
        if (puzzle.validateWord(c, userAnswer)) {
          _onCorrectWord(c, cCells);
        }
      }
    }
  }

  void _onGameComplete() async {
    setState(() {
      _gameComplete = true;
    });
    _completionController.forward();

    HapticFeedback.heavyImpact();
    await _audioPlayer.play(AssetSource('sounds/correct.wav'));
    await Future.delayed(const Duration(milliseconds: 200));
    await _audioPlayer.play(AssetSource('sounds/correct.wav'));

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final navArgs = ModalRoute.of(context)?.settings.arguments;
    Navigator.of(context).pushReplacementNamed(
      WinScreen.routeName,
      arguments: navArgs,
    );
  }

  void _onGameOver() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final navArgs = ModalRoute.of(context)?.settings.arguments;
    Navigator.of(context).pushReplacementNamed(
      LooseScreen.routeName,
      arguments: navArgs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isInit || puzzle.gridWidth == 0) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
        appBar: AppBar(title: const Text('Crossword')),
        body:
            const Center(child: Text('No questions available for crossword.')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          episode['title']?.toString() ?? 'Crossword',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Word progress indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${puzzle.allClues.where((c) => c.isSolved).length}/${puzzle.allClues.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          // Hint button
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, size: 20),
            tooltip: 'Hint ($kCrosswordHintCost coins)',
            color: const Color(0xFFFFD700),
            onPressed: _gameComplete ? null : _useHint,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AnimatedBuilder(
              animation: _heartController,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(min(maxLives, 5), (i) {
                  final isFilled = i < lives;
                  return Transform.scale(
                    scale: isFilled && _heartController.isAnimating
                        ? _heartScale.value
                        : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        isFilled ? Icons.favorite : Icons.favorite_border,
                        color: isFilled ? Colors.red : Colors.grey,
                        size: 18,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Crossword grid
              Expanded(
                flex: 3,
                child: _buildGrid(isDark),
              ),
              // Hidden text field for keyboard input
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 1,
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    onChanged: _onInputChanged,
                    textCapitalization: TextCapitalization.characters,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    enableSuggestions: false,
                    scribbleEnabled: false,
                    style: const TextStyle(fontSize: 1),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
              // Clues panel
              Expanded(
                flex: 2,
                child: _buildCluesPanel(isDark),
              ),
            ],
          ),
          // Confetti overlay
          if (_gameComplete)
            AnimatedBuilder(
              animation: _completionController,
              builder: (_, __) => IgnorePointer(
                child: CustomPaint(
                  painter: _CrosswordConfettiPainter(
                    progress: _completionController.value,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(bool isDark) {
    final cellSize = _calculateCellSize();

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_correctController, _wrongController]),
          builder: (_, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(puzzle.gridHeight, (row) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(puzzle.gridWidth, (col) {
                  return _buildCell(row, col, cellSize, isDark);
                }),
              );
            }),
          ),
        ),
      ),
    );
  }

  double _calculateCellSize() {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    final screenHeight = MediaQuery.of(context).size.height * 0.45;
    final maxCellWidth = screenWidth / max(puzzle.gridWidth, 1);
    final maxCellHeight = screenHeight / max(puzzle.gridHeight, 1);
    return min(min(maxCellWidth, maxCellHeight), 40.0);
  }

  Widget _buildCell(int row, int col, double size, bool isDark) {
    final letter = puzzle.grid[row][col];
    if (letter == null) {
      return SizedBox(width: size, height: size);
    }

    final cellKey = '$row,$col';
    final isCorrect = _correctCells.contains(cellKey);
    final isWrong = _wrongCells.contains(cellKey);
    final isPurchasedHint = _purchasedHintCells.contains(cellKey);
    final isHint = _hintCells.contains(cellKey) && !isPurchasedHint;
    final isSelected = _selectedClue != null &&
        puzzle
            .getClueCells(_selectedClue!)
            .any((c) => c[0] == row && c[1] == col);
    final isFocused = _focusedCellRow == row && _focusedCellCol == col;

    final userLetter = _userGrid[row][col];

    Color bgColor;
    if (isCorrect) {
      bgColor = isDark ? const Color(0xFF1B5E20) : const Color(0xFFE8F5E9);
    } else if (isWrong) {
      bgColor = isDark ? const Color(0xFFB71C1C) : const Color(0xFFFFEBEE);
    } else if (isPurchasedHint) {
      // Golden amber for purchased hints — stands out from green pre-fills
      bgColor = isDark ? const Color(0xFF5D4037) : const Color(0xFFFFF8E1);
    } else if (isHint) {
      bgColor = isDark ? const Color(0xFF33691E) : const Color(0xFFF1F8E9);
    } else if (isFocused) {
      bgColor = isDark ? const Color(0xFF0D47A1) : const Color(0xFFBBDEFB);
    } else if (isSelected) {
      bgColor = isDark ? const Color(0xFF1A237E) : const Color(0xFFE3F2FD);
    } else {
      bgColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    }

    // Find clue number for this cell
    String? clueNum;
    for (final clue in puzzle.allClues) {
      if (clue.startRow == row && clue.startCol == col) {
        clueNum = clue.number.toString();
        break;
      }
    }

    double shakeOffset = 0;
    if (isWrong && _wrongController.isAnimating) {
      shakeOffset = _wrongShake.value;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTapped(row, col),
      child: Transform.translate(
        offset: Offset(shakeOffset, 0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(
              color: isPurchasedHint
                  ? const Color(0xFFFFD700)
                  : isFocused
                      ? const Color(0xFF2196F3)
                      : (isDark ? Colors.grey[700]! : Colors.grey[400]!),
              width: isPurchasedHint ? 1.5 : (isFocused ? 2 : 0.5),
            ),
          ),
          child: Stack(
            children: [
              if (clueNum != null)
                Positioned(
                  left: 2,
                  top: 1,
                  child: Text(
                    clueNum,
                    style: TextStyle(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
              Center(
                child: Text(
                  userLetter ?? '',
                  style: TextStyle(
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.bold,
                    color: isCorrect
                        ? const Color(0xFF2E7D32)
                        : isPurchasedHint
                            ? const Color(
                                0xFFFF8F00) // Amber for purchased hints
                            : isHint
                                ? (isDark
                                    ? const Color(0xFF81C784)
                                    : const Color(0xFF558B2F))
                                : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
              if (isCorrect)
                Positioned(
                  right: 2,
                  bottom: 1,
                  child: Icon(
                    Icons.check,
                    size: size * 0.25,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              if (isPurchasedHint)
                Positioned(
                  right: 1,
                  bottom: 0,
                  child: Icon(
                    Icons.auto_awesome,
                    size: size * 0.22,
                    color: const Color(0xFFFFD700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCluesPanel(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // Instruction or selected clue area
          if (_selectedClue != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _selectedClue!.direction == ClueDirection.across
                          ? const Color(0xFF2196F3)
                          : const Color(0xFF9C27B0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_selectedClue!.number} ${_selectedClue!.direction == ClueDirection.across ? "→" : "↓"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedClue!.questionText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_selectedClue!.nepaliQuestionText != null &&
                            _selectedClue!.nepaliQuestionText!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _selectedClue!.nepaliQuestionText!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitWord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Submit',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          if (_selectedClue == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.touch_app,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap a clue below or a cell in the grid to start filling',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: isDark ? Colors.white : Colors.black87,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF2196F3),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_forward, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Across  ${puzzle.acrossClues.where((c) => c.isSolved).length}/${puzzle.acrossClues.length}',
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Down  ${puzzle.downClues.where((c) => c.isSolved).length}/${puzzle.downClues.length}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildClueList(puzzle.acrossClues, isDark),
                        _buildClueList(puzzle.downClues, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClueList(List<CrosswordClue> clues, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: clues.length,
      itemBuilder: (_, i) {
        final clue = clues[i];
        final isSelected = _selectedClue == clue;

        return GestureDetector(
          onTap: () => _selectClue(clue),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF0D47A1) : const Color(0xFFE3F2FD))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: clue.isSolved
                        ? const Color(0xFF4CAF50)
                        : (isDark ? Colors.grey[800] : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: clue.isSolved
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${clue.number}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: clue.questionText,
                              style: TextStyle(
                                fontSize: 13,
                                color: clue.isSolved
                                    ? Colors.grey
                                    : (isDark ? Colors.white : Colors.black87),
                                decoration: clue.isSolved
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (!clue.isSolved)
                              TextSpan(
                                text: '  (${clue.length})',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (clue.nepaliQuestionText != null &&
                          clue.nepaliQuestionText!.isNotEmpty &&
                          !clue.isSolved)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            clue.nepaliQuestionText!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Letter preview strip showing known/unknown letters
                      if (!clue.isSolved) _buildLetterPreview(clue, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLetterPreview(CrosswordClue clue, bool isDark) {
    final cells = puzzle.getClueCells(clue);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(clue.length, (i) {
          final key = '${cells[i][0]},${cells[i][1]}';
          final isPurchased = _purchasedHintCells.contains(key);
          final isHint = _hintCells.contains(key) && !isPurchased;
          final isCorrectCell = _correctCells.contains(key);
          final letter = _userGrid[cells[i][0]][cells[i][1]];
          final hasLetter = letter != null && letter.isNotEmpty;

          return Container(
            width: 18,
            height: 22,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: isPurchased
                  ? (isDark ? const Color(0xFF5D4037) : const Color(0xFFFFF8E1))
                  : (isHint || isCorrectCell)
                      ? (isDark
                          ? const Color(0xFF33691E)
                          : const Color(0xFFE8F5E9))
                      : (isDark ? Colors.grey[800] : Colors.grey[100]),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: isPurchased
                    ? const Color(0xFFFFD700)
                    : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                width: isPurchased ? 1 : 0.5,
              ),
            ),
            child: Center(
              child: Text(
                hasLetter ? letter : '_',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: hasLetter
                      ? (isPurchased
                          ? const Color(0xFFFF8F00)
                          : isHint
                              ? (isDark
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFF558B2F))
                              : (isDark ? Colors.white70 : Colors.black54))
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CrosswordConfettiPainter extends CustomPainter {
  final double progress;
  static final _rng = Random(42);
  static final _particles = List.generate(
    40,
    (_) => _CParticle(
      x: _rng.nextDouble(),
      speed: 0.3 + _rng.nextDouble() * 0.7,
      size: 4 + _rng.nextDouble() * 6,
      color: [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.purple,
        Colors.orange,
      ][_rng.nextInt(6)],
      drift: (_rng.nextDouble() - 0.5) * 2,
    ),
  );

  _CrosswordConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final y = -20 + (size.height + 40) * progress * p.speed;
      final x = p.x * size.width + sin(progress * 10 + p.drift) * 30 * p.drift;
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - progress).clamp(0, 1))
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 5 * p.drift);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CrosswordConfettiPainter old) =>
      old.progress != progress;
}

class _CParticle {
  final double x, speed, size, drift;
  final Color color;
  _CParticle({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.drift,
  });
}
