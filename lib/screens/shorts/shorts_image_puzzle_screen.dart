import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/puzzle_piece.dart';
import '../../models/url.dart';
import '../../providers/auth.dart';
import '../../providers/video_state_provider.dart';
import '../../utils/debug_logger.dart';
import '../../utils/image_puzzle_generator.dart';
import './shorts_win_screen.dart';
import './shorts_loose_screen.dart';

/// Cost in coins for one image puzzle hint (auto-place a piece)
const int kShortsPuzzleHintCost = 5;

/// Cost in coins to view the full reference image
const int kShortsReferencePeekCost = 15;

class ShortsImagePuzzleScreen extends StatefulWidget {
  static const routeName = '/shorts-image-puzzle-screen';

  const ShortsImagePuzzleScreen({Key? key}) : super(key: key);

  @override
  State<ShortsImagePuzzleScreen> createState() =>
      _ShortsImagePuzzleScreenState();
}

class _ShortsImagePuzzleScreenState extends State<ShortsImagePuzzleScreen>
    with TickerProviderStateMixin {
  late Map<String, dynamic> _shortsData;
  bool _isInit = false;
  bool _isLoading = true;
  bool _difficultySelected = false;
  bool _gameComplete = false;
  String? _loadError;
  bool _showReference = false;
  bool _referenceUnlocked = false;

  int _rows = 3;
  int _cols = 3;
  late int lives;
  late int maxLives;
  int _placedCount = 0;

  List<PuzzlePiece> _pieces = [];
  ui.Image? _sourceImage;
  Uint8List? _imageBytes;

  late List<List<String?>> _grid;

  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late AnimationController _completionController;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _hintedPieceKeys = {};

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  final _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-8105529278923041/8001756243'
      : 'ca-app-pub-8105529278923041/5550852727';

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      _shortsData =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;

      final baseLives = _shortsData['lives'] as int? ?? 3;
      lives = baseLives;
      maxLives = baseLives;

      _initAnimations();
      _loadImage();
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
    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
  }

  Future<void> _loadImage() async {
    try {
      Uint8List? bytes;

      // Try to extract a frame from the shorts video
      final videoUrl = _shortsData['video_url']?.toString();
      if (videoUrl != null && videoUrl.isNotEmpty) {
        try {
          final fullVideoUrl = videoUrl.startsWith('http')
              ? videoUrl
              : '${Url.mediaUrl}/$videoUrl';
          final timeMs = 3000 + Random().nextInt(5000);
          DebugLogger.info(
              '🎬 Shorts puzzle: Extracting video frame at ${timeMs}ms');
          bytes = await VideoThumbnail.thumbnailData(
            video: fullVideoUrl,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 512,
            quality: 75,
            timeMs: timeMs,
          ).timeout(const Duration(seconds: 15), onTimeout: () => null);
          if (bytes != null && bytes.length < 5000) {
            bytes = null;
          }
        } catch (e) {
          DebugLogger.error('🎬 Shorts video frame extraction failed: $e');
        }
      }

      // Try user image / thumbnail
      if (bytes == null || bytes.isEmpty) {
        final userImage = _shortsData['user_image']?.toString();
        if (_isValidImageUrl(userImage)) {
          bytes = await _downloadImage(userImage!);
        }
      }

      if (bytes == null || bytes.isEmpty || !mounted) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadError = 'No image available for this short';
          });
        }
        return;
      }

      _imageBytes = bytes;
      _sourceImage = await ImagePuzzleGenerator.decodeImage(bytes);

      if (_sourceImage != null &&
          (_sourceImage!.width < 200 || _sourceImage!.height < 200)) {
        _sourceImage = null;
        _imageBytes = null;
      }

      if (_sourceImage != null && _imageBytes != null) {
        final isUsable = await _isImageUsableForPuzzle(_imageBytes!);
        if (!isUsable) {
          _sourceImage = null;
          _imageBytes = null;
        }
      }

      // Fallback to bundled logo
      if (_sourceImage == null) {
        try {
          final assetBytes = await rootBundle.load('assets/images/logo.png');
          final fallbackBytes = assetBytes.buffer.asUint8List();
          if (fallbackBytes.length > 1000) {
            _imageBytes = fallbackBytes;
            _sourceImage =
                await ImagePuzzleGenerator.decodeImage(fallbackBytes);
          }
        } catch (e) {
          DebugLogger.error('🧩 Failed to load bundled fallback: $e');
        }
      }

      if (mounted && _sourceImage != null) {
        // Auto-select easy difficulty for shorts
        _selectDifficulty(3, 3);
        setState(() => _isLoading = false);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      DebugLogger.error('Failed to load shorts puzzle image: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Failed to load image';
        });
      }
    }
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url == 'None' || url == 'null') return false;
    return true;
  }

  Future<bool> _isImageUsableForPuzzle(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 32, targetHeight: 32);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return true;

      final pixels = byteData.buffer.asUint8List();
      int darkPixels = 0;
      int totalPixels = pixels.length ~/ 4;

      for (int i = 0; i < pixels.length; i += 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final brightness = (r * 299 + g * 587 + b * 114) ~/ 1000;
        if (brightness < 25) darkPixels++;
      }

      final darkRatio = darkPixels / totalPixels;
      return darkRatio <= 0.8;
    } catch (e) {
      return true;
    }
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      String fullUrl = url;
      if (!url.startsWith('http')) {
        fullUrl = '${Url.mediaUrl}/$url';
      }
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (e) {
      DebugLogger.error('🖼️ Image download error: $e');
    }
    return null;
  }

  void _selectDifficulty(int rows, int cols) {
    if (_sourceImage == null) return;

    _rows = rows;
    _cols = cols;
    _pieces = ImagePuzzleGenerator.generatePieces(_sourceImage!, rows, cols);
    _grid = List.generate(rows, (_) => List<String?>.filled(cols, null));
    _placedCount = 0;

    setState(() => _difficultySelected = true);
    HapticFeedback.mediumImpact();
  }

  void _onPieceDroppedOnSlot(PuzzlePiece piece, int targetRow, int targetCol) {
    if (piece.isPlaced) return;
    if (_grid[targetRow][targetCol] != null) return;

    if (piece.correctRow == targetRow && piece.correctCol == targetCol) {
      _onCorrectPlacement(piece, targetRow, targetCol);
    } else {
      _onWrongPlacement(piece);
    }
  }

  void _onCorrectPlacement(
      PuzzlePiece piece, int targetRow, int targetCol) async {
    setState(() {
      piece.isPlaced = true;
      piece.currentRow = targetRow;
      piece.currentCol = targetCol;
      _grid[targetRow][targetCol] = piece.key;
      _placedCount++;
    });

    HapticFeedback.mediumImpact();
    await _audioPlayer.play(AssetSource('sounds/correct.wav'));

    if (_placedCount == _rows * _cols) {
      _onGameComplete();
    }
  }

  void _onWrongPlacement(PuzzlePiece piece) async {
    setState(() => lives--);

    _heartController.forward(from: 0);
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();

    await _audioPlayer.play(AssetSource('sounds/wrong.wav'));

    if (lives <= 0) {
      _onGameOver();
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

    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    videoStateProvider.exitQuiz();
    videoStateProvider.enterResultScreen();

    Navigator.of(context).pushReplacementNamed(
      ShortsWinScreen.routeName,
      arguments: {
        'shortsId': _shortsData['shortsId'],
        'coins': _shortsData['coins'],
        'title': _shortsData['title'],
        'coins_users': _shortsData['coins_users'],
      },
    );
  }

  void _onGameOver() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    videoStateProvider.exitQuiz();
    videoStateProvider.enterResultScreen();

    Navigator.of(context).pushReplacementNamed(
      ShortsLooseScreen.routeName,
      arguments: {
        'shortsId': _shortsData['shortsId'],
        'title': _shortsData['title'],
      },
    );
  }

  void _useHint() {
    final auth = Provider.of<Auth>(context, listen: false);
    final coins = auth.userAvailableCoins;

    final unplaced = _pieces.where((p) => !p.isPlaced).toList();
    if (unplaced.isEmpty) return;

    _showHintBottomSheet(auth, coins, unplaced);
  }

  void _showHintBottomSheet(Auth auth, int coins, List<PuzzlePiece> unplaced) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasEnoughCoins = coins >= kShortsPuzzleHintCost;
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.lightbulb, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Use a Hint',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Auto-place one puzzle piece',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            // Coin option
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: hasEnoughCoins
                    ? () {
                        Navigator.pop(ctx);
                        _placeHintPiece(unplaced, auth);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasEnoughCoins ? const Color(0xFFFFD700) : Colors.grey,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  hasEnoughCoins
                      ? '$kShortsPuzzleHintCost coins  •  Balance: $coins'
                      : 'Not enough coins ($coins/$kShortsPuzzleHintCost)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Ad option — always show, with loading state if ad not ready
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: hasAd
                    ? () {
                        Navigator.pop(ctx);
                        _showRewardedAdForHint(unplaced);
                      }
                    : _isAdLoading
                        ? null
                        : () {
                            _loadRewardedAd();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Loading ad, try again shortly...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                icon: Icon(
                  hasAd
                      ? Icons.play_circle_outline
                      : (_isAdLoading ? Icons.hourglass_top : Icons.refresh),
                  size: 20,
                ),
                label: Text(hasAd
                    ? 'Watch Ad for FREE Hint'
                    : (_isAdLoading ? 'Loading Ad...' : 'Tap to Load Ad')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReferencePeekSheet() {
    final auth = Provider.of<Auth>(context, listen: false);
    final coins = auth.userAvailableCoins;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasEnoughCoins = coins >= kShortsReferencePeekCost;
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child:
                  const Icon(Icons.image_search, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'View Full Picture',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'See the complete image as reference',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: hasEnoughCoins
                    ? () {
                        Navigator.pop(ctx);
                        _unlockReference(auth);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasEnoughCoins ? const Color(0xFF42A5F5) : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  hasEnoughCoins
                      ? '$kShortsReferencePeekCost coins  •  Balance: $coins'
                      : 'Not enough coins ($coins/$kShortsReferencePeekCost)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Ad option — always show, with loading state if ad not ready
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: hasAd
                    ? () {
                        Navigator.pop(ctx);
                        _showRewardedAdForReference();
                      }
                    : _isAdLoading
                        ? null
                        : () {
                            _loadRewardedAd();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Loading ad, try again shortly...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                icon: Icon(
                  hasAd
                      ? Icons.play_circle_outline
                      : (_isAdLoading ? Icons.hourglass_top : Icons.refresh),
                  size: 20,
                ),
                label: Text(hasAd
                    ? 'Watch Ad to Unlock'
                    : (_isAdLoading ? 'Loading Ad...' : 'Tap to Load Ad')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _unlockReference(Auth auth) {
    auth.deductCoinsLocally(kShortsReferencePeekCost);
    setState(() {
      _referenceUnlocked = true;
      _showReference = true;
    });
  }

  void _showRewardedAdForReference() {
    if (_rewardedAd == null) return;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
    );
    _rewardedAd!.show(onUserEarnedReward: (_, __) {
      if (mounted) {
        setState(() {
          _referenceUnlocked = true;
          _showReference = true;
        });
      }
    });
    _rewardedAd = null;
  }

  void _placeHintPiece(List<PuzzlePiece> unplaced, Auth auth) {
    final piece = unplaced[Random().nextInt(unplaced.length)];
    auth.deductCoinsLocally(kShortsPuzzleHintCost);

    setState(() {
      piece.isPlaced = true;
      piece.currentRow = piece.correctRow;
      piece.currentCol = piece.correctCol;
      _grid[piece.correctRow][piece.correctCol] = piece.key;
      _placedCount++;
      _hintedPieceKeys.add(piece.key);
    });

    HapticFeedback.mediumImpact();
    _audioPlayer.play(AssetSource('sounds/correct.wav'));

    if (_placedCount == _rows * _cols) {
      _onGameComplete();
    }
  }

  void _showRewardedAdForHint(List<PuzzlePiece> unplaced) {
    if (_rewardedAd == null) return;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
    );
    _rewardedAd!.show(onUserEarnedReward: (_, __) {
      if (mounted) {
        final remaining = _pieces.where((p) => !p.isPlaced).toList();
        if (remaining.isNotEmpty) {
          final piece = remaining[Random().nextInt(remaining.length)];
          setState(() {
            piece.isPlaced = true;
            piece.currentRow = piece.correctRow;
            piece.currentCol = piece.correctCol;
            _grid[piece.correctRow][piece.correctCol] = piece.key;
            _placedCount++;
            _hintedPieceKeys.add(piece.key);
          });
          HapticFeedback.mediumImpact();
          _audioPlayer.play(AssetSource('sounds/correct.wav'));

          if (_placedCount == _rows * _cols) {
            _onGameComplete();
          }
        }
      }
    });
    _rewardedAd = null;
  }

  @override
  void dispose() {
    _heartController.dispose();
    _completionController.dispose();
    _audioPlayer.dispose();
    _rewardedAd?.dispose();

    // Exit quiz state when disposing to ensure video can resume
    try {
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      videoStateProvider.exitQuiz();
    } catch (e) {
      // Ignore errors during dispose
    }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          _shortsData['title']?.toString() ?? 'Image Puzzle',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_difficultySelected && _imageBytes != null)
            IconButton(
              icon: Icon(
                _showReference ? Icons.image : Icons.image_outlined,
                color: _showReference
                    ? const Color(0xFFFFD700)
                    : (isDark ? Colors.white70 : Colors.black54),
                size: 20,
              ),
              tooltip: _referenceUnlocked
                  ? 'Reference image'
                  : 'Unlock reference ($kShortsReferencePeekCost coins)',
              onPressed: _gameComplete
                  ? () => setState(() => _showReference = !_showReference)
                  : () {
                      if (_referenceUnlocked) {
                        setState(() => _showReference = !_showReference);
                      } else {
                        _showReferencePeekSheet();
                      }
                    },
            ),
          if (_difficultySelected)
            IconButton(
              icon: const Icon(Icons.lightbulb_outline, size: 20),
              tooltip: 'Hint ($kShortsPuzzleHintCost coins)',
              color: const Color(0xFFFFD700),
              onPressed: _gameComplete ? null : _useHint,
            ),
          if (_difficultySelected)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_placedCount/${_rows * _cols}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sourceImage == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _loadError ?? 'Failed to load image',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _loadError = null;
                            });
                            _loadImage();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    _buildPuzzleGame(isDark),
                    if (_showReference && _imageBytes != null)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _showReference = false),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.7),
                            child: Center(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.8,
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFFFD700), width: 2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(_imageBytes!,
                                      fit: BoxFit.contain),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_gameComplete)
                      AnimatedBuilder(
                        animation: _completionController,
                        builder: (_, __) => IgnorePointer(
                          child: CustomPaint(
                            painter: _ShortsPuzzleConfettiPainter(
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

  Widget _buildPuzzleGame(bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth - 32;
    final slotSize = boardSize / _cols;

    return Column(
      children: [
        const SizedBox(height: 8),
        Expanded(
          flex: 3,
          child: Center(
            child: Container(
              width: boardSize,
              height: slotSize * _rows,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              child: Stack(
                children: [
                  ...List.generate(_rows, (r) {
                    return List.generate(_cols, (c) {
                      return _buildGridSlot(r, c, slotSize, isDark);
                    });
                  }).expand((e) => e),
                  ..._pieces.where((p) => p.isPlaced).map((p) {
                    final isHinted = _hintedPieceKeys.contains(p.key);
                    return Positioned(
                      left: p.currentCol * slotSize,
                      top: p.currentRow * slotSize,
                      width: slotSize,
                      height: slotSize,
                      child: isHinted
                          ? Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFFFD700),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  _buildPieceWidget(p, slotSize),
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFD700),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildPieceWidget(p, slotSize),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        // Piece tray
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF263238) : const Color(0xFFECEFF1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildPieceTray(slotSize * 0.85, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildGridSlot(int row, int col, double size, bool isDark) {
    final isOccupied = _grid[row][col] != null;

    return Positioned(
      left: col * size,
      top: row * size,
      width: size,
      height: size,
      child: DragTarget<PuzzlePiece>(
        onWillAcceptWithDetails: (details) => !isOccupied,
        onAcceptWithDetails: (details) {
          _onPieceDroppedOnSlot(details.data, row, col);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isHovering
                    ? const Color(0xFFFFD700)
                    : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                width: isHovering ? 2 : 0.5,
              ),
              color: isHovering
                  ? const Color(0xFFFFD700).withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            child: isOccupied
                ? null
                : Center(
                    child: Text(
                      '${row * _cols + col + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildPieceWidget(PuzzlePiece piece, double size) {
    return ClipPath(
      clipper: JigsawClipper(
        row: piece.correctRow,
        col: piece.correctCol,
        totalRows: _rows,
        totalCols: _cols,
      ),
      child: CustomPaint(
        painter: PuzzlePiecePainter(
          piece: piece,
          displayWidth: size,
          displayHeight: size,
        ),
        size: Size(size, size),
      ),
    );
  }

  Widget _buildPieceTray(double pieceDisplaySize, bool isDark) {
    final unplacedPieces = _pieces.where((p) => !p.isPlaced).toList();

    if (unplacedPieces.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                  : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: isDark ? 0.3 : 0.15),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: isDark
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFF2E7D32),
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'All pieces placed!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFF81C784)
                      : const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Great job solving the puzzle! 🎉',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : const Color(0xFF388E3C),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            'Drag pieces to the grid  •  ${unplacedPieces.length} remaining',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: unplacedPieces.map((piece) {
                return Draggable<PuzzlePiece>(
                  data: piece,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Opacity(
                      opacity: 0.9,
                      child: SizedBox(
                        width: pieceDisplaySize,
                        height: pieceDisplaySize,
                        child: _buildPieceWidget(piece, pieceDisplaySize),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: SizedBox(
                      width: pieceDisplaySize * 0.7,
                      height: pieceDisplaySize * 0.7,
                      child: _buildPieceWidget(piece, pieceDisplaySize * 0.7),
                    ),
                  ),
                  onDragStarted: () => HapticFeedback.selectionClick(),
                  child: SizedBox(
                    width: pieceDisplaySize * 0.7,
                    height: pieceDisplaySize * 0.7,
                    child: _buildPieceWidget(piece, pieceDisplaySize * 0.7),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortsPuzzleConfettiPainter extends CustomPainter {
  final double progress;
  static final _rng = Random(42);
  static final _particles = List.generate(
    40,
    (_) => _SPConfetti(
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

  _ShortsPuzzleConfettiPainter({required this.progress});

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
  bool shouldRepaint(covariant _ShortsPuzzleConfettiPainter old) =>
      old.progress != progress;
}

class _SPConfetti {
  final double x, speed, size, drift;
  final Color color;
  _SPConfetti({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.drift,
  });
}
