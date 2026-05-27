import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/providers/shorts.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/video_state_provider.dart';
import 'package:baakhapaa/utils/guest_auth_helper.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../helpers/helpers.dart';
import 'skeleton_loading.dart';
import '../utils/debug_logger.dart';

class ShortsVideoTile extends StatefulWidget {
  const ShortsVideoTile({
    Key? key,
    required this.video,
    required this.snappedPageIndex,
    required this.currentIndex,
    required this.isVideoPlaying,
    required this.onPlayPause,
    required this.shortsId,
    required this.likeAndUnlikeCallback,
    required this.isLiked,
    this.fastForwardNotifier,
  }) : super(key: key);

  final String video;
  final int snappedPageIndex;
  final int currentIndex;
  final bool isVideoPlaying;
  final VoidCallback onPlayPause;
  final int shortsId;
  final Function likeAndUnlikeCallback;
  final bool isLiked;

  /// Optional external notifier — parent screens can set true/false to
  /// start/stop 2x fast-forward from outside (e.g. when the sidebar
  /// overlaps the edge zones and absorbs the long-press touch events).
  final ValueNotifier<bool>? fastForwardNotifier;

  @override
  State<ShortsVideoTile> createState() => _ShortsVideoTileState();
}

class _ShortsVideoTileState extends State<ShortsVideoTile>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayer;
  bool _showLikeAnimation = false;
  late AnimationController _animationController;
  late bool _localLiked;
  bool _isFullscreen = false;
  bool _showPlayButton = false;
  bool _disposed = false; // Track disposal state
  bool _isCurrentVideo = false; // Track if this is the active video
  bool _isInitializing = false;
  bool _isLoading = false; // Track loading state
  String? _currentVideoUrl; // Track current video URL
  bool _hasSetActiveVideo =
      false; // Prevent multiple setCurrentActiveVideo calls
  int _retryCount = 0; // Track retry attempts
  bool _hasPlaybackError = false; // Track if video has unrecoverable error
  bool _isTapping = false; // Debounce for tap events
  DateTime? _lastTapTime; // Track last tap time for additional debounce
  bool _userPaused = false; // Track if user manually paused the video
  bool _isFastForwarding = false; // Track 2x speed state
  bool _isLongPressing = false; // Track if long press is active

  static const int maxRetryAttempts = 3;
  static const double targetAspectRatio = 16 / 9;
  static const double aspectRatioTolerance = 0.05;
  static const int tapDebounceMs = 300; // Debounce time in milliseconds
  static const int lazyLoadDistance =
      1; // Prefetch videos within 1 page of current
  static const int disposeDistance =
      3; // Dispose controllers beyond 3 pages away
  static int _activeControllerCount = 0; // Track total active controllers
  static const int _maxConcurrentControllers = 3; // Limit concurrent decoders

  @override
  void initState() {
    super.initState();
    _localLiked = widget.isLiked;

    // Initialize based on provider state instead of widget parameters
    // We'll update this properly in didChangeDependencies
    _isCurrentVideo = false;
    _currentVideoUrl = widget.video;

    // Listen to external fast-forward notifier (used when sidebar blocks edge touches)
    widget.fastForwardNotifier?.addListener(_onExternalFastForwardChange);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _initializeVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Update current video status based on provider with fallback to position logic
    if (mounted) {
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      final isProviderCurrentVideo =
          videoStateProvider.currentActiveVideoId == widget.shortsId;
      final shouldBeCurrentByPosition =
          widget.snappedPageIndex == widget.currentIndex;
      _isCurrentVideo = isProviderCurrentVideo ||
          (videoStateProvider.currentActiveVideoId == null &&
              shouldBeCurrentByPosition);
    }
  }

  Future<void> _initializeVideo() async {
    if (_disposed || _isInitializing) return;

    // Lazy loading: only initialize videos within lazyLoadDistance of current page
    final distanceFromCurrent =
        (widget.currentIndex - widget.snappedPageIndex).abs();
    if (distanceFromCurrent > lazyLoadDistance && !_isCurrentVideo) {
      DebugLogger.info(
          '⏭️ ShortsVideoTile: Skipping init for ${widget.shortsId} (distance: $distanceFromCurrent)');
      return;
    }

    setState(() {
      _isInitializing = true;
      _isLoading = true;
    });

    try {
      // Dispose old controller if exists
      if (_videoController != null) {
        _videoController!.removeListener(_videoPlayerStateListener);
        _videoController!.pause();
        await _videoController!.dispose();
        _activeControllerCount--;
        _videoController = null;
        _initializeVideoPlayer = null;
        // Allow Android buffer pools to fully release before creating new controller
        await Future.delayed(const Duration(milliseconds: 150));
      }

      if (_disposed) return;

      // Limit concurrent video controllers to prevent buffer pool exhaustion
      if (_activeControllerCount >= _maxConcurrentControllers &&
          !_isCurrentVideo) {
        DebugLogger.info(
            '⏭️ ShortsVideoTile: Max concurrent controllers reached ($_activeControllerCount), skipping ${widget.shortsId}');
        if (mounted && !_disposed) {
          setState(() {
            _isInitializing = false;
            _isLoading = false;
          });
        }
        return;
      }

      final videoUrl = '${Url.mediaUrl}/${widget.video}';

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: const {
          'Connection': 'keep-alive',
        },
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      _activeControllerCount++;

      _videoController!.setLooping(true);
      // Set lower volume initially to reduce audio decode overhead on init
      _videoController!.setVolume(1.0);
      _videoController!.addListener(_videoPlayerStateListener);

      // Initialize and wait for completion
      _initializeVideoPlayer = _videoController!.initialize();
      await _initializeVideoPlayer;

      // Ensure playback speed is reset to normal after initialization
      try {
        _videoController!.setPlaybackSpeed(1.0);
      } catch (e) {
        DebugLogger.error(
            'Failed to reset playback speed for ${widget.shortsId}: $e');
      }

      if (!_disposed && mounted) {
        setState(() {
          _isInitializing = false;
          _isLoading = false;
          _retryCount = 0;
          _hasPlaybackError = false;
        });

        // Force immediate state update
        _updateVideoPlayState();

        // If this is the current video and should be playing, start immediately
        if (_isCurrentVideo && widget.isVideoPlaying) {
          _videoController!.play();
        }
      }
    } catch (error) {
      DebugLogger.error(
          '❌ ShortsVideoTile: Error initializing video ${widget.shortsId}: $error');

      // Properly dispose the failed controller to free codec resources
      if (_videoController != null) {
        try {
          _videoController!.dispose();
        } catch (_) {}
        _activeControllerCount--;
      }

      // Reset state on error
      if (!_disposed && mounted) {
        setState(() {
          _videoController = null;
          _initializeVideoPlayer = null;
          _isLoading = false;
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  void _videoPlayerStateListener() {
    if (_disposed || !mounted || _videoController == null) return;

    // Handle video errors
    if (_videoController!.value.hasError) {
      DebugLogger.error(
          'Video ${widget.shortsId} playback error: ${_videoController!.value.errorDescription}');

      if (_retryCount >= maxRetryAttempts) {
        if (mounted) {
          setState(() {
            _hasPlaybackError = true;
            _isLoading = false;
          });
        }
        return;
      }

      _retryCount++;

      // Exponential backoff: 2s, 4s, 8s
      final delaySeconds = 2 * (1 << (_retryCount - 1));
      Future.delayed(Duration(seconds: delaySeconds), () {
        if (!_disposed && mounted && !_hasPlaybackError) {
          _initializeVideo();
        }
      });
      return;
    }

    // Update play button visibility based on actual video player state
    final shouldShowPlayButton =
        !_videoController!.value.isPlaying && _isCurrentVideo;

    if (_showPlayButton != shouldShowPlayButton) {
      if (mounted) {
        setState(() {
          _showPlayButton = shouldShowPlayButton;
        });
      }
    }
  }

  @override
  void didUpdateWidget(ShortsVideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_disposed) return;

    // Check if video URL has changed - if so, reinitialize
    if (oldWidget.video != widget.video && _currentVideoUrl != widget.video) {
      _currentVideoUrl = widget.video;
      _retryCount = 0;
      _hasPlaybackError = false;
      _initializeVideo();
      return;
    }

    if (oldWidget.isLiked != widget.isLiked) {
      _localLiked = widget.isLiked;
    }

    // Track if current video status changed
    final wasCurrentVideo = _isCurrentVideo;
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    final isProviderCurrentVideo =
        videoStateProvider.currentActiveVideoId == widget.shortsId;
    final shouldBeCurrentByPosition =
        widget.snappedPageIndex == widget.currentIndex;
    _isCurrentVideo = isProviderCurrentVideo ||
        (videoStateProvider.currentActiveVideoId == null &&
            shouldBeCurrentByPosition);

    // Handle significant state changes
    bool needsStateUpdate = false;

    if (wasCurrentVideo != _isCurrentVideo) {
      // Reset user paused flag when this video becomes the current one (page swipe)
      if (_isCurrentVideo && !wasCurrentVideo) {
        _userPaused = false;

        // Lazy init: if this video wasn't loaded yet, start loading it now
        if (_videoController == null &&
            !_isInitializing &&
            !_hasPlaybackError) {
          _initializeVideo();
        }
      }

      // Reset active video flag when this video becomes inactive
      if (!_isCurrentVideo) {
        // Reset 2x speed when swiping away
        if (_isFastForwarding) {
          _stopFastForward();
        }
        _hasSetActiveVideo = false;
        _userPaused = false;
        try {
          final videoStateProvider =
              Provider.of<VideoStateProvider>(context, listen: false);
          videoStateProvider.clearActiveVideo(widget.shortsId);
        } catch (e) {
          DebugLogger.error(
              'Error clearing active video when becoming inactive: $e');
        }
      } else {
        // Video became current - immediately register it if we have a controller
        if (_videoController != null &&
            _videoController!.value.isInitialized &&
            !_hasSetActiveVideo) {
          _hasSetActiveVideo = true;
          try {
            final videoStateProvider =
                Provider.of<VideoStateProvider>(context, listen: false);
            videoStateProvider.setActiveVideo(
                widget.shortsId, _videoController!);

            if (widget.isVideoPlaying) {
              _videoController!.play();
            }
          } catch (e) {
            DebugLogger.error(
                'Error setting video as active when becoming current: $e');
            _hasSetActiveVideo = false;
          }
        }
      }

      needsStateUpdate = true;
    }

    if (oldWidget.isVideoPlaying != widget.isVideoPlaying) {
      needsStateUpdate = true;
      // Reset user paused flag when provider explicitly requests playing
      // (e.g., after returning from quiz/puzzle)
      if (widget.isVideoPlaying && !oldWidget.isVideoPlaying) {
        _userPaused = false;
      }
    }

    if (oldWidget.snappedPageIndex != widget.snappedPageIndex) {
      needsStateUpdate = true;

      final distanceFromCurrent =
          (widget.currentIndex - widget.snappedPageIndex).abs();

      // Dispose controller for videos that are too far away to save memory
      if (distanceFromCurrent > disposeDistance &&
          _videoController != null &&
          !_isCurrentVideo) {
        _disposeController();
      }
      // When page changes, trigger lazy init for nearby videos (prefetch)
      else if (_videoController == null &&
          !_isInitializing &&
          !_hasPlaybackError) {
        if (distanceFromCurrent <= lazyLoadDistance) {
          _initializeVideo();
        }
      }
    }

    // If any significant change occurred, update video state immediately
    if (needsStateUpdate) {
      // Use immediate callback instead of postFrameCallback for faster response
      if (_videoController != null && _videoController!.value.isInitialized) {
        _updateVideoPlayState();
      }

      // Also schedule a backup update
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed &&
            mounted &&
            _videoController != null &&
            _videoController!.value.isInitialized) {
          _updateVideoPlayState();
        }
      });
    }
  }

  void _updateVideoPlayState() {
    if (_disposed ||
        !mounted ||
        _videoController == null ||
        !_videoController!.value.isInitialized) {
      return;
    }

    final shouldPlay = _isCurrentVideo && widget.isVideoPlaying;
    final isActuallyPlaying = _videoController!.value.isPlaying;

    // Respect user's manual pause - don't auto-restart if user paused
    if (_userPaused && !isActuallyPlaying) {
      return;
    }

    // Handle play state
    if (shouldPlay && !isActuallyPlaying) {
      // Only set as active video if this is the current video
      if (_isCurrentVideo && !_hasSetActiveVideo) {
        _hasSetActiveVideo = true;
        final videoStateProvider =
            Provider.of<VideoStateProvider>(context, listen: false);
        videoStateProvider.setActiveVideo(widget.shortsId, _videoController!);
      }

      _videoController!.play().then((_) {
        if (mounted && !_disposed) {
          setState(() {
            _showPlayButton = false;
          });
        }
      }).catchError((error) {
        // Retry play command once on error to handle quiz return issues
        Future.delayed(Duration(milliseconds: 500), () {
          if (!_disposed &&
              mounted &&
              _videoController != null &&
              _videoController!.value.isInitialized) {
            final retryPlay = _isCurrentVideo &&
                widget.isVideoPlaying &&
                !_videoController!.value.isPlaying;
            if (retryPlay) {
              _videoController!.play();
            }
          }
        });
      });
    }
    // Handle pause state
    else if (!shouldPlay && isActuallyPlaying) {
      // Reset speed when pausing
      if (_isFastForwarding) {
        _stopFastForward();
      }
      _hasSetActiveVideo = false;
      _videoController!.pause().then((_) {
        if (mounted && !_disposed && _isCurrentVideo) {
          setState(() {
            _showPlayButton = true;
          });
        }
      }).catchError((error) {
        DebugLogger.error('Error pausing video ${widget.shortsId}: $error');
      });
    }

    // Update play button visibility
    final shouldShowButton = _isCurrentVideo && !isActuallyPlaying;
    if (_showPlayButton != shouldShowButton) {
      if (mounted && !_disposed) {
        setState(() {
          _showPlayButton = shouldShowButton;
        });
      }
    }
  }

  /// Dispose the video controller without disposing the widget itself.
  /// Used to free memory for videos far from the current page.
  Future<void> _disposeController() async {
    if (_videoController == null) return;
    _videoController!.removeListener(_videoPlayerStateListener);
    _videoController!.pause();
    await _videoController!.dispose();
    _activeControllerCount--;
    _videoController = null;
    _initializeVideoPlayer = null;
    _hasSetActiveVideo = false;
    if (mounted && !_disposed) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;

    // Reset speed before disposing
    _isFastForwarding = false;
    _isLongPressing = false;

    // Remove external fast-forward listener
    widget.fastForwardNotifier?.removeListener(_onExternalFastForwardChange);

    // Clear this video from active tracking if it's currently active
    try {
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      videoStateProvider.clearActiveVideo(widget.shortsId);
    } catch (e) {
      // Silently handle — widget is being disposed
    }

    if (_videoController != null) {
      _videoController!.removeListener(_videoPlayerStateListener);
      try {
        _videoController!.setPlaybackSpeed(1.0);
      } catch (_) {}
      _videoController!.pause();
      _videoController!.dispose();
      _activeControllerCount--;
    }
    _animationController.dispose();
    super.dispose();
  }

  void _onExternalFastForwardChange() {
    if (widget.fastForwardNotifier == null) return;
    DebugLogger.info(
        'ShortsVideoTile: external fastForwardNotifier=${widget.fastForwardNotifier!.value} for ${widget.shortsId}');
    if (widget.fastForwardNotifier!.value) {
      _startFastForward();
    } else {
      _stopFastForward();
    }
  }

  void _startFastForward() {
    if (_disposed || !mounted || _videoController == null) return;
    if (!_videoController!.value.isInitialized) return;
    if (!_videoController!.value.isPlaying) return;

    _isLongPressing = true;
    DebugLogger.info(
        'ShortsVideoTile: startFastForward for ${widget.shortsId} (playing=${_videoController!.value.isPlaying})');
    _videoController!.setPlaybackSpeed(2.0);
    setState(() {
      _isFastForwarding = true;
    });
  }

  void _stopFastForward() {
    if (_disposed || _videoController == null) return;
    _isLongPressing = false;

    if (_videoController!.value.isInitialized) {
      _videoController!.setPlaybackSpeed(1.0);
    }
    if (mounted) {
      setState(() {
        _isFastForwarding = false;
      });
    }
  }

  void _pausePlayVideo() {
    // Basic checks
    if (_disposed || !mounted || _videoController == null) {
      return;
    }

    // Debounce rapid taps using flag
    if (_isTapping) {
      return;
    }

    // Additional time-based debounce
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < tapDebounceMs) {
      return;
    }
    _lastTapTime = now;

    // Set debounce flag
    _isTapping = true;

    // Check if video controller is initialized
    if (!_videoController!.value.isInitialized) {
      _isTapping = false;
      return;
    }

    final wasPlaying = _videoController!.value.isPlaying;

    if (wasPlaying) {
      _userPaused = true;
      _videoController!.pause().then((_) {
        if (mounted && !_disposed) {
          setState(() {
            _showPlayButton = true;
          });
        }
      }).catchError((error) {
        DebugLogger.error('Error pausing video ${widget.shortsId}: $error');
      });
    } else {
      _userPaused = false;
      _videoController!.play().then((_) {
        if (mounted && !_disposed) {
          setState(() {
            _showPlayButton = false;
          });
        }
      }).catchError((error) {
        DebugLogger.error('Error playing video ${widget.shortsId}: $error');
      });
    }

    // Call the parent callback to update provider state
    widget.onPlayPause();

    // Reset debounce flag after delay
    Future.delayed(Duration(milliseconds: tapDebounceMs), () {
      _isTapping = false;
    });
  }

  void _onDoubleTap() async {
    if (_disposed || !mounted) return;

    // Check if user is logged in first
    final authProvider = Provider.of<Auth>(context, listen: false);
    if (!authProvider.isAuth) {
      bool shouldLogin =
          await GuestAuthHelper.showGuestLoginDialog(context, 'like videos');
      if (!shouldLogin) {
        return;
      }
      return;
    }

    // Check if profile is completed
    bool isProfileCompleted = await checkAndShowProfileDialog(context);
    if (!isProfileCompleted) return;

    final shorts = Provider.of<Shorts>(context, listen: false);

    if (!_localLiked) {
      // Update local state immediately for instant feedback
      setState(() {
        _showLikeAnimation = true;
        _localLiked = true;
      });

      // Update parent state immediately (before API call)
      widget.likeAndUnlikeCallback(widget.shortsId);

      _animationController.forward().then((_) {
        _animationController.reverse().then((_) {
          if (mounted && !_disposed) {
            setState(() {
              _showLikeAnimation = false;
            });
          }
        });
      });

      // Call API in background - state is already updated
      shorts.liked(widget.shortsId);
    }
  }

  void _toggleFullscreen() {
    if (_disposed || _videoController == null) return;

    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  void _enterFullscreen() {
    if (_disposed || _videoController == null) return;

    setState(() {
      _isFullscreen = true;
    });

    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Navigate to fullscreen page
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullscreenVideoPlayer(
          videoController: _videoController!,
          onExit: _exitFullscreen,
        ),
        transitionDuration: Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _exitFullscreen() {
    if (_disposed) return;

    setState(() {
      _isFullscreen = false;
    });

    // Restore portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Show system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);

    // Pop the fullscreen page if it's open
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current active video from provider
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    final isProviderCurrentVideo =
        videoStateProvider.currentActiveVideoId == widget.shortsId;

    final shouldBeCurrentByPosition =
        widget.snappedPageIndex == widget.currentIndex;
    _isCurrentVideo = isProviderCurrentVideo ||
        (videoStateProvider.currentActiveVideoId == null &&
            shouldBeCurrentByPosition);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: _buildVideoContent(),
    );
  }

  Widget _buildVideoContent() {
    // Check if video controller is ready
    if (_videoController != null &&
        _videoController!.value.isInitialized &&
        !_disposed) {
      // Removed aggressive state management that was causing auto-restart loop
      // Video state is now managed through didUpdateWidget and user interactions only

      return Stack(
        children: [
          // Video player with long-press 2x speed on edges
          GestureDetector(
            onTap: () {
              // Don't trigger tap if we just finished a long press
              if (_isLongPressing) return;
              _pausePlayVideo();
            },
            onDoubleTap: _onDoubleTap,
            onLongPressStart: (details) {
              final screenWidth = MediaQuery.of(context).size.width;
              final tapX = details.globalPosition.dx;
              // Trigger 2x speed when long-pressing on the left or right 30% of screen
              if (tapX > screenWidth * 0.7 || tapX < screenWidth * 0.3) {
                _startFastForward();
              }
            },
            onLongPressEnd: (details) {
              if (_isFastForwarding) {
                _stopFastForward();
              }
            },
            child: SizedBox.expand(
              child: (_videoController!.value.aspectRatio - targetAspectRatio)
                          .abs() <
                      aspectRatioTolerance
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: targetAspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
            ),
          ),

          // Play button overlay
          if (_showPlayButton)
            Center(
              child: GestureDetector(
                onTap: _pausePlayVideo,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),

          // 2x speed indicator overlay — positioned at top-center to avoid covering content
          if (_isFastForwarding)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fast_forward,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '2×',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Like animation
          if (_showLikeAnimation)
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.0, end: 1.5).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.elasticOut,
                  ),
                ),
                child: Icon(
                  Icons.thumb_up,
                  color: Colors.white,
                  size: 100,
                ),
              ),
            ),

          // Fullscreen button
          if (_videoController != null &&
              (_videoController!.value.aspectRatio - targetAspectRatio).abs() <
                  aspectRatioTolerance)
            Positioned(
              left: 0,
              right: 0,
              bottom: 200,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleFullscreen,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Enter full screen',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Debug overlay for development
          if (kDebugMode)
            Positioned(
              top: 40,
              left: 16,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID: ${widget.shortsId}',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    Text(
                      'Current: $_isCurrentVideo',
                      style: TextStyle(
                        color: _isCurrentVideo ? Colors.green : Colors.red,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      'Playing: ${_videoController!.value.isPlaying}',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    } else if ((_videoController != null &&
            _videoController!.value.hasError &&
            !_disposed) ||
        _hasPlaybackError) {
      // Show error state with retry option (only if not exceeded max retries)
      return Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _hasPlaybackError ? Icons.cancel_outlined : Icons.error_outline,
              color: Colors.white54,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              _hasPlaybackError ? 'Video unavailable' : 'Failed to load video',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            if (_hasPlaybackError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'This video cannot be played on your device',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ElevatedButton(
                onPressed: _retryCount < maxRetryAttempts
                    ? () {
                        DebugLogger.info(
                            '🔄 ShortsVideoTile: Manual retry for ${widget.shortsId}');
                        _initializeVideo();
                      }
                    : null,
                child: Text('Retry'),
              ),
            if (!_hasPlaybackError && _retryCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Attempt $_retryCount of $maxRetryAttempts',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      // Show loading state
      return Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) ...[
              const Expanded(child: ShortsVideoSkeleton()),
            ] else ...[
              Icon(
                Icons.video_library_outlined,
                color: Colors.white54,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Preparing video...',
                style: TextStyle(color: Colors.white54),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  DebugLogger.info(
                      '🔄 ShortsVideoTile: Force init for ${widget.shortsId}');
                  _initializeVideo();
                },
                child: Text('Load Video'),
              ),
            ],
          ],
        ),
      );
    }
  }
}

// Enhanced Fullscreen video player widget
class FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController videoController;
  final VoidCallback onExit;

  const FullscreenVideoPlayer({
    Key? key,
    required this.videoController,
    required this.onExit,
  }) : super(key: key);

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _hideControlsAfterDelay();
  }

  void _hideControlsAfterDelay() {
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _hideControlsAfterDelay();
    }
  }

  void _pausePlayVideo() {
    if (!widget.videoController.value.isInitialized) return;

    widget.videoController.value.isPlaying
        ? widget.videoController.pause()
        : widget.videoController.play();
    setState(() {}); // Refresh UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video player taking full screen
            Center(
              child: AspectRatio(
                aspectRatio: widget.videoController.value.aspectRatio,
                child: VideoPlayer(widget.videoController),
              ),
            ),
            // Controls overlay
            if (_showControls)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Stack(
                  children: [
                    // Exit fullscreen button
                    Positioned(
                      top: 40,
                      left: 16,
                      child: SafeArea(
                        child: GestureDetector(
                          onTap: widget.onExit,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.fullscreen_exit,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Play/Pause button in center
                    Center(
                      child: GestureDetector(
                        onTap: _pausePlayVideo,
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Icon(
                            widget.videoController.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
