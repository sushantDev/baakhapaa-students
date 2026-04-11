import 'dart:convert';
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

import '../../models/game_mode.dart';
import '../../models/puzzle_piece.dart';
import '../../models/url.dart';
import '../../providers/auth.dart';
import '../../providers/story.dart';
import '../../utils/debug_logger.dart';
import '../../utils/image_puzzle_generator.dart';
import '../story/win_screen.dart';
import '../story/loose_screen.dart';

/// Cost in coins for one image puzzle hint (auto-place a piece)
const int kImagePuzzleHintCost = 5;

/// Cost in coins to view the full reference image
const int kReferencePeekCost = 15;

class ImagePuzzleScreen extends StatefulWidget {
  static const routeName = '/image-puzzle-screen';

  const ImagePuzzleScreen({Key? key}) : super(key: key);

  @override
  State<ImagePuzzleScreen> createState() => _ImagePuzzleScreenState();
}

class _ImagePuzzleScreenState extends State<ImagePuzzleScreen>
    with TickerProviderStateMixin {
  late Map<String, dynamic> episode;
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

  // Grid of placed piece keys (null = empty slot)
  late List<List<String?>> _grid;

  // Animation
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late AnimationController _completionController;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Pieces placed via hint (golden glow border)
  final Set<String> _hintedPieceKeys = {};

  // Rewarded ad for free hints
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  final _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-8105529278923041/8001756243'
      : 'ca-app-pub-8105529278923041/5550852727';

  // Drag state

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      final story = Provider.of<Story>(context, listen: false);
      episode = story.episode;
      story.setGameModeSilently(GameMode.imagePuzzle);

      final baseLives = episode['base_lives'] as int? ?? 3;
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

      // Priority 1: Extract a random frame from the video for variety
      final videoSource = episode['video_source']?.toString();
      final videoUrl = episode['video_url']?.toString();
      if (videoSource != 'youtube' && _isValidImageUrl(videoUrl)) {
        try {
          final fullVideoUrl = videoUrl!.startsWith('http')
              ? videoUrl
              : '${Url.mediaUrl}/$videoUrl';
          final duration =
              int.tryParse(episode['duration']?.toString() ?? '') ?? 0;
          // Pick a random time between 10% and 80% of the video
          final timeMs = duration > 2
              ? ((duration * 1000) * (0.1 + Random().nextDouble() * 0.7))
                  .toInt()
              : 5000; // Default to 5 seconds in if duration unknown
          DebugLogger.info(
              '🎬 Extracting video frame at ${timeMs}ms from $fullVideoUrl');
          bytes = await VideoThumbnail.thumbnailData(
            video: fullVideoUrl,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 512,
            quality: 75,
            timeMs: timeMs,
          ).timeout(const Duration(seconds: 15), onTimeout: () => null);
          if (bytes != null && bytes.length < 5000) {
            // Too small, likely a blank/corrupt frame
            DebugLogger.error(
                '🎬 Video frame too small (${bytes.length} bytes), discarding');
            bytes = null;
          }
        } catch (e) {
          DebugLogger.error('🎬 Video frame extraction failed: $e');
        }
      }
      // Try YouTube thumbnail if YouTube video
      if ((bytes == null || bytes.isEmpty) &&
          videoSource == 'youtube' &&
          _isValidImageUrl(videoUrl)) {
        // YouTube has multiple thumbnail resolutions
        final ytThumbs = [
          'https://img.youtube.com/vi/$videoUrl/maxresdefault.jpg',
          'https://img.youtube.com/vi/$videoUrl/sddefault.jpg',
          'https://img.youtube.com/vi/$videoUrl/hqdefault.jpg',
        ];
        for (final url in ytThumbs) {
          bytes = await _downloadImage(url);
          if (bytes != null && bytes.isNotEmpty) break;
        }
      }

      // Priority 2: Fall back to thumbnail/image URLs
      if (bytes == null || bytes.isEmpty) {
        final candidateUrls = <String>[];

        final episodeThumbnail = episode['thumbnail']?.toString();
        if (_isValidImageUrl(episodeThumbnail)) {
          candidateUrls.add(episodeThumbnail!);
        }

        final episodeImage = episode['image']?.toString();
        if (_isValidImageUrl(episodeImage)) {
          candidateUrls.add(episodeImage!);
        }

        final images = episode['images'];
        if (images is List && images.isNotEmpty) {
          for (final img in images) {
            final imgUrl =
                img['thumbnail']?.toString() ?? img['url']?.toString();
            if (_isValidImageUrl(imgUrl)) {
              candidateUrls.add(imgUrl!);
              break;
            }
          }
        }

        // For readable content: use page images from the episode
        final story = Provider.of<Story>(context, listen: false);
        final episodePages = story.episodePages;
        if (episodePages.isNotEmpty) {
          // Shuffle to pick a random page image for variety
          final pagesWithImages = episodePages
              .where((p) => _isValidImageUrl(p['image_url']?.toString()))
              .toList();
          if (pagesWithImages.isNotEmpty) {
            pagesWithImages.shuffle();
            candidateUrls.add(pagesWithImages.first['image_url'].toString());
          }
        }

        final season = story.selectedSeason;
        final seasonThumbnail = season['thumbnail']?.toString();
        if (_isValidImageUrl(seasonThumbnail)) {
          candidateUrls.add(seasonThumbnail!);
        }
        final seasonImage = season['image']?.toString();
        if (_isValidImageUrl(seasonImage)) {
          candidateUrls.add(seasonImage!);
        }
        final seasonImages = season['images'];
        if (seasonImages is List && seasonImages.isNotEmpty) {
          for (final img in seasonImages) {
            final imgUrl =
                img['thumbnail']?.toString() ?? img['url']?.toString();
            if (_isValidImageUrl(imgUrl)) {
              candidateUrls.add(imgUrl!);
              break;
            }
          }
        }

        for (final url in candidateUrls) {
          bytes = await _downloadImage(url);
          if (bytes != null && bytes.isNotEmpty) break;
        }
      }

      if (bytes == null || bytes.isEmpty || !mounted) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadError = 'No image available for this episode';
          });
        }
        return;
      }

      _imageBytes = bytes;
      _sourceImage = await ImagePuzzleGenerator.decodeImage(bytes);

      // Validate image is large enough for a good puzzle experience
      if (_sourceImage != null &&
          (_sourceImage!.width < 200 || _sourceImage!.height < 200)) {
        DebugLogger.error(
            '🧩 Image too small for puzzle: ${_sourceImage!.width}x${_sourceImage!.height}');
        _sourceImage = null;
        _imageBytes = null;
      }

      // Check if image is mostly uniform (black/blank frame)
      if (_sourceImage != null && _imageBytes != null) {
        final isUsable = await _isImageUsableForPuzzle(_imageBytes!);
        if (!isUsable) {
          DebugLogger.error(
              '🧩 Image is too uniform/dark for puzzle, discarding');
          _sourceImage = null;
          _imageBytes = null;
        }
      }

      // If primary image failed validation, try fallback thumbnails
      if (_sourceImage == null) {
        final fallbackBytes = await _loadFallbackImage();
        if (fallbackBytes != null) {
          _imageBytes = fallbackBytes;
          _sourceImage = await ImagePuzzleGenerator.decodeImage(fallbackBytes);
        }
      }

      if (mounted && _sourceImage != null) {
        _autoSelectDifficulty();
        setState(() {
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      DebugLogger.error('Failed to load puzzle image: $e');
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

  /// Check if an image has enough visual variety for a puzzle.
  /// Rejects mostly-black, mostly-white, or uniform-color images.
  Future<bool> _isImageUsableForPuzzle(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 32, targetHeight: 32);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return true; // can't check, allow it

      final pixels = byteData.buffer.asUint8List();
      int darkPixels = 0;
      int totalPixels = pixels.length ~/ 4;

      // Sample pixel brightness
      for (int i = 0; i < pixels.length; i += 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final brightness = (r * 299 + g * 587 + b * 114) ~/ 1000;
        if (brightness < 25) darkPixels++;
      }

      // If >80% of pixels are very dark, image is too dark for a puzzle
      final darkRatio = darkPixels / totalPixels;
      if (darkRatio > 0.8) {
        DebugLogger.info(
            '🧩 Image darkness ratio: ${(darkRatio * 100).toStringAsFixed(0)}% - too dark');
        return false;
      }
      return true;
    } catch (e) {
      return true; // on error, allow the image
    }
  }

  /// Try to load a fallback image from season/episode thumbnails.
  Future<Uint8List?> _loadFallbackImage() async {
    final story = Provider.of<Story>(context, listen: false);
    final season = story.selectedSeason;

    final candidateUrls = <String>[];

    // Collect all available image URLs
    final seasonThumbnail = season['thumbnail']?.toString();
    if (_isValidImageUrl(seasonThumbnail)) candidateUrls.add(seasonThumbnail!);

    final seasonImage = season['image']?.toString();
    if (_isValidImageUrl(seasonImage)) candidateUrls.add(seasonImage!);

    final seasonImages = season['images'];
    if (seasonImages is List) {
      for (final img in seasonImages) {
        final url = img['thumbnail']?.toString() ?? img['url']?.toString();
        if (_isValidImageUrl(url)) candidateUrls.add(url!);
      }
    }

    final episodeThumbnail = episode['thumbnail']?.toString();
    if (_isValidImageUrl(episodeThumbnail))
      candidateUrls.add(episodeThumbnail!);

    final episodeImage = episode['image']?.toString();
    if (_isValidImageUrl(episodeImage)) candidateUrls.add(episodeImage!);

    for (final url in candidateUrls) {
      final bytes = await _downloadImage(url);
      if (bytes != null && bytes.length > 5000) {
        // Verify it's not too dark
        final usable = await _isImageUsableForPuzzle(bytes);
        if (usable) {
          DebugLogger.info('🧩 Using fallback image: $url');
          return bytes;
        }
      }
    }

    // Last resort: load a bundled asset image
    try {
      final assetBytes = await rootBundle.load('assets/images/logo.png');
      final bytes = assetBytes.buffer.asUint8List();
      if (bytes.length > 1000) {
        DebugLogger.info('🧩 Using bundled logo as fallback puzzle image');
        return bytes;
      }
    } catch (e) {
      DebugLogger.error('🧩 Failed to load bundled fallback: $e');
    }

    return null;
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      String fullUrl = url;
      if (!url.startsWith('http')) {
        fullUrl = '${Url.mediaUrl}/$url';
      }
      DebugLogger.info('🖼️ Downloading puzzle image: $fullUrl');
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      DebugLogger.error(
          '🖼️ Image download failed with status: ${response.statusCode}');
    } catch (e) {
      DebugLogger.error('🖼️ Image download error: $e');
    }
    return null;
  }

  void _autoSelectDifficulty() {
    if (_sourceImage == null) return;

    // Count completed episodes in the current season
    final story = Provider.of<Story>(context, listen: false);
    final season = story.selectedSeason;
    final episodes = season['episodes'] as List? ?? [];
    final completedCount = episodes.where((e) => e['watched'] == true).length;

    // Progressive difficulty based on user's progress
    int rows, cols;
    if (completedCount >= 8) {
      rows = 5;
      cols = 5; // Hard: 25 pieces
    } else if (completedCount >= 4) {
      rows = 4;
      cols = 4; // Medium: 16 pieces
    } else {
      rows = 3;
      cols = 3; // Easy: 9 pieces
    }

    DebugLogger.info(
        '🧩 Auto-difficulty: $completedCount eps completed → ${rows}x$cols grid');
    _selectDifficulty(rows, cols);
  }

  void _selectDifficulty(int rows, int cols) {
    if (_sourceImage == null) return;

    _rows = rows;
    _cols = cols;
    _pieces = ImagePuzzleGenerator.generatePieces(_sourceImage!, rows, cols);
    _grid = List.generate(rows, (_) => List<String?>.filled(cols, null));
    _placedCount = 0;

    setState(() {
      _difficultySelected = true;
    });
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
    setState(() {
      lives--;
    });

    _heartController.forward(from: 0);

    // 3-burst haptic
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

  /// Use a hint to auto-place one random unplaced piece.
  void _useHint() {
    final auth = Provider.of<Auth>(context, listen: false);
    final coins = auth.userAvailableCoins;

    final unplaced = _pieces.where((p) => !p.isPlaced).toList();
    if (unplaced.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All pieces are already placed!')),
      );
      return;
    }

    _showHintBottomSheet(auth, coins, unplaced);
  }

  /// Show bottom sheet to unlock reference image via coins or ad.
  void _showReferencePeekSheet() {
    final auth = Provider.of<Auth>(context, listen: false);
    final coins = auth.userAvailableCoins;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasEnoughCoins = coins >= kReferencePeekCost;
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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
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
              'Unlock the reference image to see what you\'re building',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildHintOption(
              ctx: ctx,
              icon: Icons.monetization_on_rounded,
              iconColor: const Color(0xFFFFD700),
              title: 'Use Coins',
              subtitle: hasEnoughCoins
                  ? '$kReferencePeekCost coins  •  Balance: $coins'
                  : 'Not enough coins ($coins/$kReferencePeekCost)',
              enabled: hasEnoughCoins,
              gradient: const [Color(0xFFFFD700), Color(0xFFFFA000)],
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _unlockReference(auth, freeFromAd: false);
              },
            ),
            const SizedBox(height: 12),
            _buildHintOption(
              ctx: ctx,
              icon: Icons.play_circle_filled_rounded,
              iconColor: const Color(0xFF4CAF50),
              title: 'Watch an Ad',
              subtitle: hasAd ? 'Free unlock after watching' : 'Loading ad...',
              enabled: hasAd,
              gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _showRewardedAdForReference();
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

  void _unlockReference(Auth auth, {required bool freeFromAd}) {
    if (!freeFromAd) {
      auth.deductCoinsLocally(kReferencePeekCost);
      // Log coin transaction on server
      http.post(
        Uri.parse(Url.baakhapaaApi('/coin-transaction')),
        headers: Url.baakhapaaAuthHeaders(
            Provider.of<Story>(context, listen: false).authToken),
        body: json.encode({
          'status': 'spent',
          'coin': kReferencePeekCost,
          'remarks':
              'Used $kReferencePeekCost coins for image puzzle reference peek',
        }),
      );
    }
    if (!mounted) return;
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
      final auth = Provider.of<Auth>(context, listen: false);
      _unlockReference(auth, freeFromAd: true);
    });
  }

  void _showHintBottomSheet(Auth auth, int coins, List<PuzzlePiece> unplaced) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasEnoughCoins = coins >= kImagePuzzleHintCost;
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
            // Puzzle piece icon with glow
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
              child: const Icon(Icons.extension, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Need Help?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Auto-place a puzzle piece in its correct spot',
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
                  ? '$kImagePuzzleHintCost coins  •  Balance: $coins'
                  : 'Not enough coins ($coins/$kImagePuzzleHintCost)',
              enabled: hasEnoughCoins,
              gradient: const [Color(0xFFFFD700), Color(0xFFFFA000)],
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _executeImageHint(auth, unplaced, freeFromAd: false);
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
                _showRewardedAdForHint(unplaced);
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

    _rewardedAd!.show(onUserEarnedReward: (_, reward) {
      _executeImageHint(
        Provider.of<Auth>(context, listen: false),
        unplaced,
        freeFromAd: true,
      );
    });
  }

  void _executeImageHint(Auth auth, List<PuzzlePiece> unplaced,
      {required bool freeFromAd}) {
    final rng = Random();
    final piece = unplaced[rng.nextInt(unplaced.length)];

    // Track as hinted for golden glow
    _hintedPieceKeys.add(piece.key);

    // Place the piece in its correct position
    _onCorrectPlacement(piece, piece.correctRow, piece.correctCol);

    if (!freeFromAd) {
      // Deduct coins locally for immediate UI feedback
      auth.deductCoinsLocally(kImagePuzzleHintCost);

      // Log transaction on backend and sync balance from response
      final story = Provider.of<Story>(context, listen: false);
      http
          .post(
        Uri.parse(Url.baakhapaaApi('/coin-transaction')),
        headers: Url.baakhapaaAuthHeaders(story.authToken),
        body: json.encode({
          'status': 'spent',
          'coin': kImagePuzzleHintCost,
          'remarks': 'Image puzzle hint used',
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
            // Backend rejected - revert local deduction
            if (mounted) auth.addCoinsLocally(kImagePuzzleHintCost);
            DebugLogger.error(
                'Image puzzle hint transaction rejected: ${responseData['message']}');
          }
        } catch (e) {
          DebugLogger.error('Image puzzle hint response parse error: $e');
        }
      }).catchError((e) {
        // Network error - revert local deduction
        if (mounted) auth.addCoinsLocally(kImagePuzzleHintCost);
        DebugLogger.error('Image puzzle hint transaction network error: $e');
      });
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    _completionController.dispose();
    _audioPlayer.dispose();
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
          episode['title']?.toString() ?? 'Image Puzzle',
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
                  : 'Unlock reference ($kReferencePeekCost coins)',
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
              tooltip: 'Hint ($kImagePuzzleHintCost coins)',
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
              : !_difficultySelected
                  ? _buildDifficultySelector(isDark)
                  : Stack(
                      children: [
                        _buildPuzzleGame(isDark),
                        if (_showReference && _imageBytes != null)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _showReference = false),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.7),
                                child: Center(
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.8,
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                              0.5,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFFFD700),
                                          width: 2),
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
                                painter: _PuzzleConfettiPainter(
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

  Widget _buildDifficultySelector(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview image
            if (_imageBytes != null)
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 32),
            Text(
              'Select Difficulty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            _buildDifficultyButton(
              'Easy',
              '9 pieces',
              3,
              3,
              const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              isDark,
            ),
            const SizedBox(height: 12),
            _buildDifficultyButton(
              'Medium',
              '16 pieces',
              4,
              4,
              const [Color(0xFFFF9800), Color(0xFFE65100)],
              isDark,
            ),
            const SizedBox(height: 12),
            _buildDifficultyButton(
              'Hard',
              '25 pieces',
              5,
              5,
              const [Color(0xFFF44336), Color(0xFFB71C1C)],
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(
    String label,
    String subtitle,
    int rows,
    int cols,
    List<Color> gradient,
    bool isDark,
  ) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () => _selectDifficulty(rows, cols),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              // Mini grid preview
              Container(
                width: 40,
                height: 40,
                child: GridView.count(
                  crossAxisCount: cols,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(
                    rows * cols,
                    (_) => Container(
                      margin: const EdgeInsets.all(0.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        // Puzzle board
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
                  // Grid slots
                  ...List.generate(_rows, (r) {
                    return List.generate(_cols, (c) {
                      return _buildGridSlot(r, c, slotSize, isDark);
                    });
                  }).expand((e) => e),
                  // Placed pieces
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

class _PuzzleConfettiPainter extends CustomPainter {
  final double progress;
  static final _rng = Random(42);
  static final _particles = List.generate(
    40,
    (_) => _PConfetti(
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

  _PuzzleConfettiPainter({required this.progress});

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
  bool shouldRepaint(covariant _PuzzleConfettiPainter old) =>
      old.progress != progress;
}

class _PConfetti {
  final double x, speed, size, drift;
  final Color color;
  _PConfetti({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.drift,
  });
}
