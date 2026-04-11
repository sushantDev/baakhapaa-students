import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../utils/debug_logger.dart';
import 'skeleton_loading.dart';

class SimpleYouTubePlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final bool mute;
  final Function(int progressSeconds)? onProgressUpdate;
  final Function(int durationSeconds)? onDurationReceived;
  final int? resumeFromSeconds;

  const SimpleYouTubePlayer({
    Key? key,
    required this.videoId,
    this.autoPlay = true,
    this.mute = false,
    this.onProgressUpdate,
    this.onDurationReceived,
    this.resumeFromSeconds,
  }) : super(key: key);

  @override
  State<SimpleYouTubePlayer> createState() => _SimpleYouTubePlayerState();
}

class _SimpleYouTubePlayerState extends State<SimpleYouTubePlayer>
    with AutomaticKeepAliveClientMixin {
  YoutubePlayerController? _controller;
  bool _hasError = false;
  String? _errorMessage;
  Timer? _progressTimer;
  bool _hasResumed = false;

  @override
  bool get wantKeepAlive => true; // Keep the player alive when scrolling

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    try {
      _controller = YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: YoutubePlayerFlags(
          autoPlay: widget.autoPlay,
          mute: widget.mute,
          enableCaption: false,
          hideControls: false,
          controlsVisibleAtStart: true,
          loop: false,
        ),
      );

      _controller!.addListener(_playerListener);

      // Start progress tracking timer
      _startProgressTracking();
    } catch (e) {
      DebugLogger.error('Failed to initialize YouTube player: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to initialize video player';
      });
    }
  }

  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_controller != null && mounted) {
        final position = _controller!.value.position;
        final duration = _controller!.metadata.duration;

        // Resume from saved position (only once)
        if (!_hasResumed &&
            widget.resumeFromSeconds != null &&
            widget.resumeFromSeconds! > 0 &&
            position.inSeconds < 2) {
          _hasResumed = true;
          _controller!.seekTo(Duration(seconds: widget.resumeFromSeconds!));
          DebugLogger.info(
              "Resumed YouTube video from ${widget.resumeFromSeconds}s");
        }

        // Report progress
        if (widget.onProgressUpdate != null && _controller!.value.isPlaying) {
          widget.onProgressUpdate!(position.inSeconds);
        }

        // Report duration when available
        if (widget.onDurationReceived != null && duration.inSeconds > 0) {
          widget.onDurationReceived!(duration.inSeconds);
        }
      }
    });
  }

  void _playerListener() {
    if (_controller == null || !mounted) return;

    // Check for errors
    if (_controller!.value.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error code: ${_controller!.value.errorCode}';
      });
      DebugLogger.error("YouTube player error: $_errorMessage");
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller?.removeListener(_playerListener);
    _controller?.dispose();
    super.dispose();
  }

  void _retryVideo() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _hasResumed = false;
    });
    _controller?.dispose();
    _initializePlayer();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // If there's an error, show the fallback widget
    if (_hasError) {
      return _buildErrorFallbackWidget();
    }

    if (_controller == null) {
      return _buildLoadingWidget();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        progressColors: ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
        ),
        onReady: () {
          DebugLogger.info('YouTube player ready');
        },
        onEnded: (metaData) {
          DebugLogger.info('YouTube video ended');
        },
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const ShimmerLoading(
      child: SkeletonBox(width: double.infinity, height: 225, borderRadius: 8),
    );
  }

  Widget _buildErrorFallbackWidget() {
    return Container(
      width: double.infinity,
      height: 225,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              'Video failed to load',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to play this video',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _retryVideo,
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _openYouTubeInBrowser,
                  icon: Icon(Icons.open_in_new, size: 18),
                  label: Text('Open in YouTube'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openYouTubeInBrowser() {
    // Show a message with the video ID
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Please copy this video ID and search in YouTube: ${widget.videoId}'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
