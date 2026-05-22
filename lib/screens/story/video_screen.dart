import 'dart:async';
import 'dart:convert';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/popup.dart';
import 'package:baakhapaa/widgets/rating_sheet.dart';
import 'package:baakhapaa/widgets/rating_summary.dart';
import 'package:baakhapaa/widgets/share_with_qr_modal.dart';
import 'package:baakhapaa/widgets/simple_youtube_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:provider/provider.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../providers/story.dart';
import '../../providers/auth.dart';
import '../../providers/shop.dart';
import '../../models/game_mode.dart';
import '../../widgets/game_mode_selector.dart';
import '../../widgets/product.dart';
import '../../widgets/skeleton_loading.dart';
import './story_screen.dart';
import './question_screen.dart';
import './crossword_screen.dart';
import './image_puzzle_screen.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import '../../services/subscription_service.dart';
import '../../models/subscription.dart';
import '../../widgets/affilated_product.dart';
import './episode_screen.dart';
import '../shorts/single_shorts_screen.dart';
import '../../utils/guest_auth_helper.dart';

class VideoScreen extends StatefulWidget {
  static const routeName = '/video-screen';

  const VideoScreen({Key? key}) : super(key: key);

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen>
    with PuppetInteractionMixin, WidgetsBindingObserver {
  late Map<String, dynamic> episode = {};
  bool _showAllComments = false; // top-level comments
  Map<int, bool> _expandedReplies = {}; // replies per comment
  var _navArgs;
  Timer? countdownTimer; // Made nullable
  late Duration myDuration = Duration(seconds: 1);
  var _isInit = false;
  var _countdownCompleted = false;
  FlickManager? flickManager; // Made nullable
  bool _flickManagerDisposed = false; // Track disposal state
  bool _youtubePlayerError = false;
  bool _videoLoadingError = false; // Add video loading error state
  bool _isFullScreen = false; // Track fullscreen state for iOS screen protector

  // Duration skip usage state
  bool _isUsingDurationSkip = false;
  // Store Story provider reference for safe access in dispose
  Story? _storyProvider;

  // Resume override for My Courses feature
  int? _resumeOverrideSeconds;

  // Episode progress tracking variables
  Timer? _progressTimer;
  int _currentProgressSeconds = 0;
  int _lastReportedProgress = 0;
  int _actualVideoDurationSeconds =
      0; // Track actual video duration from player
  static const int _progressUpdateInterval =
      5; // Update progress every 5 seconds
  static const int _progressReportThreshold =
      10; // Report progress every 10 seconds
  final donationController = TextEditingController();
  final donationCommentController = TextEditingController();
  Key _listKey = UniqueKey();
  final commentController = TextEditingController();
  var parentCommentId = 0;
  FocusNode commentFocus = FocusNode();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<dynamic> _products = [];
  late List<dynamic> _episodeComments = [];
  final ScrollController _scrollController = ScrollController();
  GlobalKey keyNavigation = GlobalKey();
  var _isLoading = true;
  late String landedFrom;
  late List<dynamic> _popups = [];
  UserBenefitUsage? _skipTimerBenefit;

  // Navigation properties
  List<dynamic> _allEpisodes = [];
  int _currentEpisodeIndex = 0;

  // Linked content properties
  List<dynamic> _relatedShorts = [];
  List<dynamic> _relatedEpisodes = [];
  List<dynamic> _affiliateProducts = [];

  Future<void> secureScreen() async {
    try {
      await ScreenProtector.protectDataLeakageOn();
      await ScreenProtector.preventScreenshotOn();
      DebugLogger.info('🔒 Screen protection enabled');
    } catch (e) {
      DebugLogger.error('❌ Failed to enable screen protection: $e');
    }
  }

  Future<void> disableScreenProtection() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.preventScreenshotOff();
      DebugLogger.info('🔓 Screen protection disabled for fullscreen');
    } catch (e) {
      DebugLogger.error('❌ Failed to disable screen protection: $e');
    }
  }

  Future<void> _showReportEpisodeDialog() async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      await GuestAuthHelper.showGuestLoginDialog(
          context, 'report this episode');
      return;
    }

    final int? episodeId = episode['id'] is int
        ? episode['id'] as int
        : int.tryParse(episode['id']?.toString() ?? '');
    if (episodeId == null || episodeId <= 0) {
      _showEpisodeSnackBar('Invalid episode for reporting.', Colors.red);
      return;
    }

    String selectedReason = 'Inappropriate content';
    final reasons = [
      'Spam',
      'Harassment or bullying',
      'Hate speech',
      'Inappropriate content',
      'Misinformation',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.flag_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Report Episode'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you reporting ${episode['title'] ?? 'this episode'}?',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...reasons.map(
                (reason) => RadioListTile<String>(
                  dense: true,
                  title: Text(reason, style: const TextStyle(fontSize: 13)),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await auth.reportContent(
                    type: 'episode',
                    targetId: episodeId,
                    reason: selectedReason,
                  );
                  if (mounted) {
                    _showEpisodeSnackBar(
                      'Report submitted. Thank you.',
                      Colors.green,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    _showEpisodeSnackBar(
                      e.toString().replaceFirst('Exception: ', ''),
                      Colors.red,
                    );
                  }
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEpisodeSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  void initState() {
    secureScreen();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Report progress when app goes to background or is paused
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_currentProgressSeconds > 0) {
        _reportProgressToAPI();
      }
    }
  }

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      try {
        DebugLogger.info('🎬 VideoScreen: didChangeDependencies called');
        _navArgs = ModalRoute.of(context)!.settings.arguments;
        DebugLogger.info('🎬 VideoScreen: Route arguments: $_navArgs');
        var story = Provider.of<Story>(context, listen: false);

        // Store Story provider reference for safe access in dispose
        _storyProvider = story;

        final tutorialProvider =
            Provider.of<TutorialFlowProvider>(context, listen: false);
        if (tutorialProvider.currentStep == 6) {
          tutorialProvider.nextStep().then((_) {
            if (mounted) {
              tutorialProvider.showCurrentStepMessage(context);
            }
          });
        }

        if (_navArgs.runtimeType == int) {
          final episodeId = _navArgs as int;
          story.fetchEpisode(episodeId).then((_) {
            if (mounted) {
              setState(() {
                episode = story.episode;
                landedFrom = 'deep_link';
              });
              _initializeEpisodeNavigation();
              initializer();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  DebugLogger.info(
                      '🎭 🎭 SCREEN: Setting puppet context for episode $episodeId');
                  // Set puppet context for this specific episode
                  setPuppetEpisodeContext(episodeId);
                }
              });
            }
          }).catchError((error) {
            DebugLogger.api("Error fetching episode: $error");
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          });
        } else if (_navArgs is Map) {
          // Handle episode map - ALWAYS fetch fresh data to get duration skip fields
          final rawEpisodeId = (_navArgs as Map)['id'];
          final resumeAtSeconds =
              (_navArgs as Map)['resumeAtSeconds'] as int? ?? 0;

          // Store resume override if provided (from My Courses feature)
          if (resumeAtSeconds > 0) {
            _resumeOverrideSeconds = resumeAtSeconds;
            DebugLogger.info(
                '🎯 Resume override set for My Courses: ${_resumeOverrideSeconds}s');
          }

          final episodeId = rawEpisodeId is int
              ? rawEpisodeId
              : int.tryParse(rawEpisodeId?.toString() ?? '');
          if (episodeId != null) {
            DebugLogger.info(
                '🔄 VideoScreen: Fetching fresh episode data for ID: $episodeId (resume at ${resumeAtSeconds}s)');
            // DON'T use old episode data - wait for fresh fetch
            // Fetch both episode and popups in parallel for fresh data
            Future.wait([
              story.fetchEpisode(episodeId),
              story.fetchEpisodePopups(episodeId),
            ]).then((_) {
              if (mounted) {
                setState(() {
                  // Use fresh episode data from provider (includes duration skip fields AND watched status)
                  episode = story.episode;
                  _popups = context.read<Story>().episodePopups;
                  landedFrom = 'episodes';
                  _initializeEpisodeNavigation();
                  initializer();

                  DebugLogger.success(
                      '✅ VideoScreen: Episode data refreshed - Max Duration Skips: ${episode['max_duration_skips']}, Cost: ${episode['duration_skip_cost']}');

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      DebugLogger.info(
                          '🎭 🎭 SCREEN: Setting puppet context for episode $episodeId');
                      // Set puppet context for this specific episode
                      setPuppetEpisodeContext(episodeId);
                    }
                  });
                });
              }
            }).catchError((error) {
              DebugLogger.error("Error fetching episode data: $error");
              if (mounted) {
                setState(() {
                  _initializeEpisodeNavigation();
                  initializer();
                });
              }
            });
          } else {
            DebugLogger.warning(
                'Episode ID is null or invalid, skipping popup fetch');
            if (mounted) {
              setState(() {
                _initializeEpisodeNavigation();
                initializer();
              });
            }
          }
        } else if (_navArgs is String) {
          // Handle landedFrom string (e.g., from LooseScreen)
          DebugLogger.info(
              '🎬 VideoScreen: Received landedFrom: $_navArgs, using current episode');
          landedFrom = _navArgs;
          if (episode.isNotEmpty) {
            final episodeId = episode['id'];
            if (episodeId != null && episodeId is int) {
              story.fetchEpisodePopups(episodeId).then((_) {
                if (mounted) {
                  setState(() {
                    _popups = context.read<Story>().episodePopups;
                    _initializeEpisodeNavigation();
                    initializer();

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        DebugLogger.info(
                            '🎭 🎭 SCREEN: Setting puppet context for episode $episodeId');
                        // Set puppet context for this specific episode
                        setPuppetEpisodeContext(episodeId);
                      }
                    });
                  });
                }
              }).catchError((error) {
                DebugLogger.error("Error fetching episode popups: $error");
                if (mounted) {
                  setState(() {
                    _initializeEpisodeNavigation();
                    initializer();
                  });
                }
              });
            } else {
              DebugLogger.warning(
                  'Episode ID is null or invalid in landedFrom flow');
              if (mounted) {
                setState(() {
                  _initializeEpisodeNavigation();
                  initializer();
                });
              }
            }
          } else {
            DebugLogger.info(
                '🎬 VideoScreen: No current episode available, setting loading false');
            // Still try to initialize navigation even if episode is empty
            _initializeEpisodeNavigation();
            setState(() {
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        DebugLogger.error("Error in didChangeDependencies: $e");
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
    _isInit = true;
    super.didChangeDependencies();
  }

  void _initializeEpisodeNavigation() {
    try {
      DebugLogger.info('🧭 VideoScreen: Initializing episode navigation...');
      final story = Provider.of<Story>(context, listen: false);
      final season = story.selectedSeason;

      DebugLogger.info('🧭 VideoScreen: Season data: ${season.toString()}');

      if (season['episodes'] != null && season['episodes'] is List) {
        _allEpisodes = List<dynamic>.from(season['episodes'] as List<dynamic>);
        DebugLogger.info(
            '🧭 VideoScreen: Found ${_allEpisodes.length} episodes in season');

        _currentEpisodeIndex = _allEpisodes.indexWhere(
          (ep) => ep != null && ep['id'] == episode['id'],
        );
        if (_currentEpisodeIndex == -1) _currentEpisodeIndex = 0;

        DebugLogger.info(
            '🧭 VideoScreen: Current episode index: $_currentEpisodeIndex');
        DebugLogger.info(
            '🧭 VideoScreen: Navigation will ${_allEpisodes.length > 1 ? "be shown" : "be hidden"} (${_allEpisodes.length} episodes)');
      } else {
        _allEpisodes = [];
        _currentEpisodeIndex = 0;
        DebugLogger.warning(
            '🧭 VideoScreen: No episodes found in season, navigation disabled');
      }
    } catch (e) {
      DebugLogger.error("Error initializing episode navigation: $e");
      _allEpisodes = [];
      _currentEpisodeIndex = 0;
    }
  }

  bool get _hasPreviousEpisode => _currentEpisodeIndex > 0;
  bool get _hasNextEpisode => _currentEpisodeIndex < _allEpisodes.length - 1;

  void _navigateToEpisode(int direction) {
    if (_allEpisodes.isEmpty) {
      DebugLogger.error('🧭 Navigation failed: _allEpisodes is empty');
      return;
    }

    int newIndex = _currentEpisodeIndex + direction;
    if (newIndex < 0 || newIndex >= _allEpisodes.length) {
      DebugLogger.warning(
          '🧭 Navigation out of bounds: index $newIndex, length ${_allEpisodes.length}');
      return;
    }

    final newEpisode = _allEpisodes[newIndex];
    if (newEpisode == null) {
      DebugLogger.error(
          '🧭 Navigation failed: episode at index $newIndex is null');
      return;
    }

    // Report final progress and stop tracking before navigation
    if (_currentProgressSeconds > 0) {
      _reportProgressToAPI();
    }
    _stopProgressTracking();

    // Dispose current video safely
    try {
      if (episode.isNotEmpty && episode['video_source'] != 'youtube') {
        try {
          if (flickManager != null && !_flickManagerDisposed) {
            // Remove progress listener before disposing
            flickManager?.flickVideoManager?.videoPlayerController
                ?.removeListener(_onVideoProgressChanged);
            flickManager?.dispose();
            _flickManagerDisposed = true;
            DebugLogger.info('🗑️ Navigation: flickManager disposed');
          }
        } catch (e) {
          DebugLogger.error(
              "Error disposing flickManager during navigation: $e");
        }
      }
      countdownTimer?.cancel();
    } catch (e) {
      DebugLogger.error("Error disposing video: $e");
    }

    // CRITICAL FIX: Ensure selectedSeason maintains episodes list for next navigation
    try {
      final story = Provider.of<Story>(context, listen: false);
      final currentSeason = Map<String, dynamic>.from(story.selectedSeason);

      // Preserve episodes list if not already present
      if (!currentSeason.containsKey('episodes') ||
          currentSeason['episodes'] == null) {
        currentSeason['episodes'] = _allEpisodes;
        DebugLogger.info(
            '🧭 Navigation: Updated selectedSeason with ${_allEpisodes.length} episodes');
      }

      story.setSelectedSeason(currentSeason);
    } catch (e) {
      DebugLogger.error("Error updating selectedSeason before navigation: $e");
    }

    // Navigate to new episode with post-frame callback for safety
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            VideoScreen.routeName,
            arguments: newEpisode,
          );
        }
      });
    } catch (e) {
      DebugLogger.error("Error navigating to episode: $e");
    }
  }

  @override
  void dispose() {
    DebugLogger.info('🗑️ VideoScreen: dispose(); called');
    WidgetsBinding.instance.removeObserver(this);

    try {
      // Report final progress before disposing
      if (_currentProgressSeconds > 0) {
        _reportProgressToAPI();
      }

      // Stop progress tracking
      _stopProgressTracking();

      // Dispose video controllers safely
      if (episode.isNotEmpty && episode['video_source'] != 'youtube') {
        try {
          if (flickManager != null && !_flickManagerDisposed) {
            // Remove listeners before disposing
            flickManager?.flickControlManager
                ?.removeListener(_onFullscreenChange);
            flickManager?.flickVideoManager?.videoPlayerController
                ?.removeListener(_onVideoProgressChanged);
            flickManager?.dispose();
            _flickManagerDisposed = true;
            DebugLogger.info('🗑️ VideoScreen: flickManager disposed');
          }
        } catch (e) {
          DebugLogger.error("Error disposing flickManager: $e");
        }
      }

      // Dispose text controllers safely
      try {
        donationController.dispose();
        donationCommentController.dispose();
        commentController.dispose();
        DebugLogger.info('🗑️ VideoScreen: text controllers disposed');
      } catch (e) {
        DebugLogger.error("Error disposing text controllers: $e");
      }

      // Cancel timer safely
      try {
        countdownTimer?.cancel();
        DebugLogger.info('🗑️ VideoScreen: timer cancelled');
      } catch (e) {
        DebugLogger.error("Error cancelling timer: $e");
      }
    } catch (e) {
      DebugLogger.error("Error in dispose: $e");
    }

    // Clean up screen protector asynchronously without waiting
    _cleanupScreenProtector();

    super.dispose();
    DebugLogger.info('🗑️ VideoScreen: super.dispose(); called');
  }

  void _cleanupScreenProtector() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.preventScreenshotOff();
      DebugLogger.info('🗑️ VideoScreen: screen protector cleaned up');
    } catch (e) {
      DebugLogger.error("Error in screen protector cleanup: $e");
    }
  }

  void initializer() {
    try {
      int duration = episode['duration'] as int? ?? 0;

      // Reset countdown state properly
      _countdownCompleted = false;
      myDuration = Duration(seconds: duration);

      DebugLogger.info(
          '⏰ VideoScreen: Episode duration set to: $duration seconds');
      DebugLogger.success(
          '⏰ VideoScreen: _countdownCompleted reset to: $_countdownCompleted');

      // Cancel any existing timer first
      countdownTimer?.cancel();

      // Extract linked content from episode map
      _relatedShorts = episode['related_shorts'] ?? [];
      _relatedEpisodes = episode['related_episodes'] ?? [];
      _affiliateProducts = episode['affiliate_products'] ?? [];

      initializeVideo();
      startTimer();
      getEpisodeProducts();
      getEpisodeComments();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      DebugLogger.error("Error in initializer: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void initializeVideo() {
    try {
      if (episode.isNotEmpty && episode['video_source'] != 'youtube') {
        final videoUrl = '${Url.mediaUrl}/${episode['video_url']}';
        DebugLogger.info('🎥 Initializing video with URL: $videoUrl');

        // Reset error states
        _videoLoadingError = false;
        _flickManagerDisposed = false;

        final videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          videoPlayerOptions: VideoPlayerOptions(
            allowBackgroundPlayback: false,
            mixWithOthers: false,
            // Enable software decoding as fallback when hardware fails
            // This helps devices with limited hardware capabilities
          ),
        );

        // Add error listener with fallback attempt
        videoPlayerController.addListener(() {
          if (videoPlayerController.value.hasError) {
            DebugLogger.error(
                '❌ Video player error: ${videoPlayerController.value.errorDescription}');
            if (mounted) {
              setState(() {
                _videoLoadingError = true;
                _youtubePlayerError = true; // Use existing error state for UI
              });
            }
          }
        });

        flickManager = FlickManager(
          videoPlayerController: videoPlayerController,
          autoInitialize: true,
          autoPlay: true,
        );

        // Add fullscreen change listener to manage screen protector on iOS
        flickManager!.flickControlManager?.addListener(_onFullscreenChange);

        // Add progress listener for Flick video player
        videoPlayerController.addListener(_onVideoProgressChanged);

        // Resume from previous position after FlickManager is created
        // Use a small delay to ensure FlickManager has finished initialization
        Future.delayed(Duration(milliseconds: 500), () {
          _resumeFromPreviousPosition(videoPlayerController);
        });

        DebugLogger.success('FlickManager initialized successfully');
      }
      // YouTube player is initialized in the SimpleYouTubePlayer widget
      // Progress tracking for YouTube is handled in the SimpleYouTubePlayer widget

      // Start progress tracking timer
      _startProgressTracking();
    } catch (e) {
      DebugLogger.error("Error in initializeVideo: $e");
      if (mounted) {
        setState(() {
          _videoLoadingError = true;
          _youtubePlayerError = true; // Use existing error state for UI
        });
      }
    }
  }

  void _onFullscreenChange() {
    if (flickManager?.flickControlManager != null) {
      final isCurrentlyFullscreen =
          flickManager!.flickControlManager!.isFullscreen;

      // Only act on actual state changes
      if (_isFullScreen != isCurrentlyFullscreen) {
        _isFullScreen = isCurrentlyFullscreen;

        if (_isFullScreen) {
          // Entering fullscreen - disable screen protector on iOS to prevent crash
          DebugLogger.info(
              '📺 Entering fullscreen mode - disabling screen protector');
          disableScreenProtection();
        } else {
          // Exiting fullscreen - re-enable screen protector
          DebugLogger.info(
              '📱 Exiting fullscreen mode - re-enabling screen protector');
          secureScreen();
        }
      }
    }
  }

  void _onVideoProgressChanged() {
    if (flickManager?.flickVideoManager?.videoPlayerController != null) {
      final controller =
          flickManager!.flickVideoManager!.videoPlayerController!;
      if (controller.value.isInitialized) {
        final position = controller.value.position;
        final duration = controller.value.duration;
        _updateCurrentProgress(position.inSeconds);

        // Update actual video duration if it's different
        if (_actualVideoDurationSeconds != duration.inSeconds) {
          _actualVideoDurationSeconds = duration.inSeconds;
          DebugLogger.info(
              '📹 Video duration updated: ${_actualVideoDurationSeconds}s');
        }
      }
    }
  }

  void _updateCurrentProgress(int progressSeconds) {
    _currentProgressSeconds = progressSeconds;

    // Report progress if threshold is met
    if (_currentProgressSeconds - _lastReportedProgress >=
        _progressReportThreshold) {
      _reportProgressToAPI();
    }
  }

  Future<void> _resumeFromPreviousPosition(
      VideoPlayerController? controller) async {
    try {
      // Check if there's a resume override from My Courses feature (highest priority)
      int progressSeconds = 0;

      if (_resumeOverrideSeconds != null && _resumeOverrideSeconds! > 0) {
        progressSeconds = _resumeOverrideSeconds!;
        DebugLogger.info(
            '🎯 Using My Courses resume override: ${progressSeconds}s');
      } else if (episode['progress_seconds'] != null) {
        progressSeconds =
            int.tryParse(episode['progress_seconds'].toString()) ?? 0;
        DebugLogger.info(
            '📹 Found direct progress_seconds: ${progressSeconds}s');
      } else if (episode['completion_percent'] != null &&
          episode['duration'] != null) {
        final completionPercent =
            double.tryParse(episode['completion_percent'].toString()) ?? 0.0;
        final duration = int.tryParse(episode['duration'].toString()) ?? 0;

        if (completionPercent > 0 && duration > 0) {
          progressSeconds = ((completionPercent / 100.0) * duration).round();
          DebugLogger.info(
              '📹 Calculated progress from completion_percent: ${completionPercent}% of ${duration}s = ${progressSeconds}s');
        }
      }

      if (progressSeconds > 0 && controller != null) {
        DebugLogger.info(
            '📹 Resuming video from previous position: ${progressSeconds}s');

        // Wait for the controller to be initialized (FlickManager handles initialization)
        // We'll listen for when it's ready and then seek
        void seekWhenReady() {
          if (controller.value.isInitialized) {
            // Controller is ready, now check if we need to recalculate with actual duration
            final actualDuration = controller.value.duration.inSeconds;
            final episodeDuration =
                int.tryParse(episode['duration'].toString()) ?? 0;
            int finalProgressSeconds = progressSeconds;

            // If actual duration differs significantly from episode duration, recalculate progress
            if (actualDuration > 0 &&
                episodeDuration > 0 &&
                (actualDuration - episodeDuration).abs() > 5) {
              final completionPercent =
                  double.tryParse(episode['completion_percent'].toString()) ??
                      0.0;
              if (completionPercent > 0) {
                finalProgressSeconds =
                    ((completionPercent / 100.0) * actualDuration).round();
                DebugLogger.info(
                    '📹 Recalculating with actual duration: ${completionPercent}% of ${actualDuration}s = ${finalProgressSeconds}s (was ${progressSeconds}s)');
              }
            }

            // Seek to the calculated position
            controller
                .seekTo(Duration(seconds: finalProgressSeconds))
                .then((_) {
              // Update current progress to match resume position
              _currentProgressSeconds = finalProgressSeconds;
              DebugLogger.success(
                  '📹 Video resumed at ${finalProgressSeconds}s');
            }).catchError((error) {
              DebugLogger.error('❌ Error seeking to position: $error');
            });
          } else {
            // Not ready yet, wait a bit and try again
            Future.delayed(Duration(milliseconds: 100), seekWhenReady);
          }
        }

        // Start the seek process
        seekWhenReady();
      } else {
        DebugLogger.info(
            '📹 No previous progress found, starting from beginning');
      }
    } catch (e) {
      DebugLogger.error('❌ Error resuming video: $e');
    }
  }

  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      Duration(seconds: _progressUpdateInterval),
      (timer) => _reportProgressToAPI(),
    );
    DebugLogger.info('📊 Started episode progress tracking');
  }

  void _stopProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = null;
    DebugLogger.info('📊 Stopped episode progress tracking');
  }

  Future<void> _reportProgressToAPI() async {
    if (episode.isEmpty || _currentProgressSeconds <= 0) return;

    try {
      final rawId = episode['id'];
      if (rawId == null) return;
      final episodeId = rawId is int ? rawId : int.tryParse(rawId.toString());
      if (episodeId == null) return;
      int actualVideoDuration = _actualVideoDurationSeconds;

      // If we don't have the actual duration yet, try to get it from the player
      if (actualVideoDuration == 0) {
        if (episode['video_source'] != 'youtube') {
          // For Flick video player (non-YouTube videos)
          if (flickManager?.flickVideoManager?.videoPlayerController != null) {
            final controller =
                flickManager!.flickVideoManager!.videoPlayerController!;
            if (controller.value.isInitialized) {
              actualVideoDuration = controller.value.duration.inSeconds;
              _actualVideoDurationSeconds = actualVideoDuration;
            }
          }
        } else {
          // For YouTube videos, we'll use episode duration as fallback for now
          // TODO: Implement YouTube player duration callback
          actualVideoDuration = episode['duration'] as int? ?? 0;
        }
      }

      // Use stored provider reference instead of context access
      final story = _storyProvider;
      if (story == null) {
        DebugLogger.error('❌ Story provider not available for progress report');
        return;
      }

      // Update progress locally first for immediate UI feedback
      story.updateEpisodeProgressLocally(
          episodeId, _currentProgressSeconds, actualVideoDuration);

      await story.updateEpisodeProgress(
          episodeId, _currentProgressSeconds, actualVideoDuration);
      _lastReportedProgress = _currentProgressSeconds;

      DebugLogger.success(
          '📊 Reported progress: ${_currentProgressSeconds}s/${actualVideoDuration}s (actual) for episode $episodeId');
    } catch (e) {
      DebugLogger.error('❌ Failed to report progress: $e');
    }
  }

  Future<void> _triggerContinueWatchingRefresh() async {
    try {
      // Use stored provider reference instead of context access
      final story = _storyProvider;
      if (story == null) {
        DebugLogger.error(
            '❌ Story provider not available for continue watching refresh');
        return;
      }

      await story.fetchContinueWatching();
      DebugLogger.success(
          '⏯️ Triggered continue watching refresh before navigation');
    } catch (e) {
      DebugLogger.error('⏯️ Error triggering continue watching refresh: $e');
    }
  }

  void getEpisodeProducts() {
    try {
      final rawId = episode['id'];
      if (rawId == null || rawId is! int) return;
      var shop = Provider.of<Shop>(context, listen: false);
      shop.getEpisodeProducts(rawId).then((value) {
        if (mounted) {
          setState(() {
            _products = shop.productsOnly;
          });
        }
      }).catchError((error) {
        DebugLogger.error("Error getting episode products: $error");
      });
    } catch (e) {
      DebugLogger.error("Error in getEpisodeProducts: $e");
    }
  }

  void getEpisodeComments() {
    try {
      final rawId = episode['id'];
      if (rawId == null || rawId is! int) return;
      var story = Provider.of<Story>(context, listen: false);
      story.getEpisodeComments(rawId).then((value) {
        if (mounted) {
          setState(() {
            _episodeComments = story.episodeComments;
          });
        }
      }).catchError((error) {
        DebugLogger.error("Error getting episode comments: $error");
      });

      story.episodeSeasonPurchased(rawId).then((value) {
        if (!story.isEpisodeSeasonPurchased) {
          showDialog(
            context: context,
            builder: (ctx) {
              const Duration autoCloseDuration = Duration(seconds: 5);

              final dialogContext = ctx;

              Future.delayed(autoCloseDuration, () {
                Navigator.of(dialogContext).pop();
                // Trigger continue watching refresh before navigation
                _triggerContinueWatchingRefresh().then((_) {
                  Navigator.of(dialogContext)
                      .pushReplacementNamed(StoryScreen.routeName);
                });
              });

              return AlertDialog(
                title: Text('An error occurred'),
                content: Text("You have not purchased this episode's season"),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      // Trigger continue watching refresh before navigation
                      _triggerContinueWatchingRefresh().then((_) {
                        Navigator.of(ctx)
                            .pushReplacementNamed(StoryScreen.routeName);
                      });
                    },
                    child: Text('Okay'),
                  ),
                ],
              );
            },
          );
        }
      }).catchError((error) {
        DebugLogger.error("Error checking episode season purchase: $error");
      });
    } catch (e) {
      DebugLogger.error("Error in getEpisodeComments: $e");
    }
  }

  void setCountDown() {
    final reduceSecondsBy = 1;
    if (!mounted) return; // Safety check

    setState(() {
      final seconds = myDuration.inSeconds - reduceSecondsBy;
      if (seconds <= 0) {
        // Timer completed
        _countdownCompleted = true;
        myDuration = Duration(seconds: 0); // Set to 0 exactly
        countdownTimer?.cancel();
        DebugLogger.success(
            '⏰ VideoScreen: Countdown completed, button should be enabled');
      } else {
        myDuration = Duration(seconds: seconds);
      }
    });
  }

  // Helper to complete skip action (shared by all skip methods)
  void _completeSkip() {
    setState(() {
      _countdownCompleted = true;
      myDuration = Duration.zero;
    });
    countdownTimer?.cancel();
  }

  // Unified skip options dialog - shows all available skip methods
  void _showSkipOptionsDialog() {
    final auth = Provider.of<Auth>(context, listen: false);
    final durationSkipsBought = episode['duration_skips_bought'] as int? ?? 0;
    final costToUnlock = (episode['duration_skip_cost'] ?? 0) as int;
    final remainingPurchases =
        (episode['duration_skips_remaining'] ?? 0) as int;

    final hasSubscriptionSkip = _skipTimerBenefit != null &&
        (_skipTimerBenefit!.usage.isUnlimited ||
            _skipTimerBenefit!.usage.remaining > 0);

    final canBuy =
        auth.userAvailableCoins >= costToUnlock && remainingPurchases > 0;
    final hasOwnedSkip = durationSkipsBought > 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.fast_forward, color: Color(0xFF0066FF), size: 28),
            SizedBox(width: 10),
            Text(
              'Skip Timer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose how you want to skip the countdown timer.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // INFO BADGES - HORIZONTAL SCROLL
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (hasSubscriptionSkip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _skipTimerBenefit!.usage.isUnlimited
                                ? 'Benefit skips: ∞'
                                : 'Benefit skips: ${_skipTimerBenefit!.usage.remaining}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  if (hasOwnedSkip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fast_forward,
                              color: Colors.orange, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Owned skips: $durationSkipsBought',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  if (canBuy)
                    // Current balance badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0066FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF0066FF).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/coins.png',
                            width: 16,
                            height: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Balance: ${auth.userAvailableCoins}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ✅ ACTION BUTTONS - VERTICAL COLUMN (NO OVERLAP!)
            // Priority order: Free (subscription) → Use owned → Buy new
            if (hasSubscriptionSkip) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _useSubscriptionSkipImmediately();
                  },
                  icon: const Icon(Icons.flash_on, size: 20),
                  label: const Text(
                    'Skip Free (Subscription)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (hasOwnedSkip) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _useOwnedSkipImmediately();
                  },
                  icon: const Icon(Icons.fast_forward, size: 20),
                  label: Text(
                    'Use Skip ($durationSkipsBought remaining)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (canBuy) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _buyAndSkipImmediately();
                  },
                  icon: const Icon(Icons.shopping_cart, size: 20),
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Buy Skip for ',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.monetization_on,
                          color: Colors.amber, size: 16),
                      Text(
                        ' $costToUnlock',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Cancel button at bottom
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Use owned skip and skip immediately
  Future<void> _useOwnedSkipImmediately() async {
    final rawId = episode['id'];
    if (rawId == null || rawId is! int) return;
    setState(() => _isUsingDurationSkip = true);

    try {
      final story = Provider.of<Story>(context, listen: false);
      final response = await story.useDurationSkip(rawId);

      if (response['success'] == true && mounted) {
        setState(() {
          episode['duration_skips_bought'] =
              response['data']['duration_skips_bought'];
          episode['duration_skips_remaining'] =
              response['data']['duration_skips_remaining'];
        });

        _completeSkip();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏭️ Skip used! Quiz unlocked.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        DebugLogger.success('⏭️ Duration skip used successfully');
      } else {
        throw Exception(response['message'] ?? 'Failed to use duration skip');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to use skip: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      DebugLogger.error('❌ Failed to use duration skip: $error');
    }
  }

  // Buy skip and skip immediately (no second click)
  Future<void> _buyAndSkipImmediately() async {
    try {
      DebugLogger.info('🛍️ Buying duration skip...');

      final storyProvider = Provider.of<Story>(context, listen: false);
      final result = await storyProvider.buyDurationSkip(episode['id']);

      if (mounted) {
        setState(() {
          episode['duration_skips_bought'] =
              result['data']['duration_skips_bought'];
          episode['duration_skips_remaining'] =
              result['data']['duration_skips_remaining'];
        });

        _completeSkip();

        DebugLogger.success('✅ Duration skip purchased and applied!');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('⏭️ Skip purchased and applied!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      DebugLogger.error('❌ Failed to buy duration skip: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to purchase skip: $error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void startTimer() {
    DebugLogger.info(
        '⏰ VideoScreen: Starting timer with duration: ${myDuration.inSeconds} seconds');
    countdownTimer = Timer.periodic(
      Duration(seconds: 1),
      (_) => setCountDown(),
    );

    // Initial check for skip timer benefit
    _checkSkipTimerBenefit();
  }

  void _checkSkipTimerBenefit() async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (!auth.isSubscribed) {
      return;
    }

    try {
      final subService = SubscriptionService(context: context);
      final response = await subService.getUserBenefitStatus();
      if (mounted && response.success && response.items.isNotEmpty) {
        setState(() {
          try {
            _skipTimerBenefit = response.items.first.benefits.firstWhere(
              (b) => b.benefitType.id == 4, // 4 is Skip Timer
            );
          } catch (_) {
            _skipTimerBenefit = null;
          }
        });
      }
    } catch (e) {
      DebugLogger.error('Error checking skip timer benefit: $e');
    }
  }

  // Use subscription benefit and skip immediately
  Future<void> _useSubscriptionSkipImmediately() async {
    if (_skipTimerBenefit == null) return;

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final subService =
          SubscriptionService(context: context, authToken: auth.token);

      await subService.updateUserBenefitUsage(
        userBenefitUsageId: _skipTimerBenefit!.id,
        episodeId: (episode['id'] is int ? episode['id'] as int : 0),
      );

      if (!mounted) return;

      _completeSkip();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ Skip used for free! Quiz unlocked.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      DebugLogger.success('⚡ Subscription skip used successfully');

      // Refresh benefit status
      _checkSkipTimerBenefit();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to use subscription skip: $e');
      }
      DebugLogger.error('❌ Failed to use subscription skip: $e');
    }
  }

  // Legacy method for the side button - redirects to unified dialog
  // Future<void> _useSkipTimerBenefit() async {
  //   _showSkipOptionsDialog();
  // }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('An error occurred'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('Okay'),
          ),
        ],
      ),
    );
  }

  void _showGameModeSelector(int episodeId) async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest || !auth.isAuth) {
      await GuestAuthHelper.showGuestLoginDialog(context, 'take quizzes');
      return;
    }

    final story = Provider.of<Story>(context, listen: false);
    final availableModes =
        await story.availableGameModesForEpisode(episodeId);
    if (!mounted) return;

    if (availableModes.isEmpty) {
      _showErrorDialog(
          'You have completed all challenges for this episode. Great job!');
      return;
    }

    final selectedMode = await GameModeSelector.show(
      context,
      allowedModes: availableModes,
      bottomLift: 120,
    );
    if (selectedMode == null || !mounted) return;

    story.selectedGameMode = selectedMode;

    switch (selectedMode) {
      case GameMode.quiz:
        goToQuestionScreen(episodeId);
        break;
      case GameMode.crossword:
        _navigateToGameScreen(episodeId, CrosswordScreen.routeName);
        break;
      case GameMode.imagePuzzle:
        _navigateToGameScreen(episodeId, ImagePuzzleScreen.routeName);
        break;
    }
  }

  void _navigateToGameScreen(int episodeId, String routeName) async {
    try {
      if (_currentProgressSeconds > 0) {
        await _reportProgressToAPI();
      }
      _stopProgressTracking();

      // Dispose video BEFORE async operations to prevent "used after disposed" errors
      if (flickManager != null && !_flickManagerDisposed) {
        flickManager?.flickControlManager?.removeListener(_onFullscreenChange);
        flickManager?.flickVideoManager?.videoPlayerController
            ?.removeListener(_onVideoProgressChanged);
        flickManager?.dispose();
        _flickManagerDisposed = true;
      }

      if (!mounted) return;

      final episodeData = Provider.of<Story>(context, listen: false);
      await episodeData.fetchEpisode(episodeId);

      if (!mounted) return;

      DebugLogger.info('🎮 VideoScreen: Navigating to $routeName');
      Navigator.of(context).pushReplacementNamed(
        routeName,
        arguments: landedFrom,
      );
    } catch (error) {
      DebugLogger.error('❌ Failed to navigate to game screen: $error');
      if (mounted) {
        _showErrorDialog('Failed to start game: ${error.toString()}');
      }
    }
  }

  void goToQuestionScreen(int episodeId) async {
    try {
      // Report final progress and stop tracking before navigation
      if (_currentProgressSeconds > 0) {
        await _reportProgressToAPI();
      }
      _stopProgressTracking();

      bool _isOk = true;
      final episodeData = Provider.of<Story>(context, listen: false);
      await episodeData.fetchEpisode(episodeId);
      final episode = episodeData.episode;

      if (episodeData.isQuizCompletedFromEpisode(episode)) {
        _showErrorDialog(
            'You have already completed the quiz for this episode. Please choose another challenge.');
        return;
      }

      List questions = episode['questions'] as List? ?? [];

      if (questions.isEmpty) {
        _showErrorDialog('Sorry no questions are available.');
        _isOk = false;
      }
      if (_isOk) {
        // Add null safety check for video_source
        final videoSource = episode['video_source'];
        if (videoSource != null && videoSource != 'youtube') {
          if (flickManager != null && !_flickManagerDisposed) {
            // Remove progress listener before disposing
            flickManager?.flickVideoManager?.videoPlayerController
                ?.removeListener(_onVideoProgressChanged);
            flickManager?.dispose();
            _flickManagerDisposed = true;
          }
        }
        DebugLogger.info('🎯 VideoScreen: Navigating to QuestionScreen');
        DebugLogger.info('🎯 Episode data: ');
        Navigator.of(context).pushReplacementNamed(QuestionScreen.routeName,
            arguments: landedFrom);
      }
    } catch (error, stackTrace) {
      DebugLogger.error('❌ Failed to navigate to QuestionScreen: $error');
      DebugLogger.error('Stack trace: $stackTrace');
      _showErrorDialog('Failed to start quiz: ${error.toString()}');
      rethrow;
    }
  }

  void donate() async {
    if (_formKey.currentState!.validate()) {
      await Provider.of<Auth>(context, listen: false)
          .donation(
        int.parse(donationController.text),
        episode['id'] as int,
        donationCommentController.text,
        'episode',
      )
          .then((value) {
        Navigator.pop(context);
        donationController.clear();
        donationCommentController.clear();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Thank you for your support.'),
        ));
      });
    }
  }

  void comment() {
    var user = Provider.of<Auth>(context, listen: false);
    if (user.userAvailableCoins >= user.commentPoints) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Note!'),
          content: Text(
              '${user.commentPoints} baakhapaa points will be deducted to post a comment.'),
          actions: [
            TextButton(
              onPressed: () {
                commentController.clear();
                Navigator.of(ctx).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                var story = Provider.of<Story>(context, listen: false);
                await story
                    .storeEpisodeComments(episode['id'] as int,
                        commentController.text, parentCommentId)
                    .then((value) {
                  _episodeComments = story.episodeComments;
                  commentController.clear();
                  _listKey = UniqueKey();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Your comment is Posted.'),
                  ));
                });
                Navigator.of(ctx).pop();
              },
              child: Text('Okay'),
            ),
          ],
        ),
      );
    } else {
      _showErrorDialog(
          'You need ${user.commentPoints} baakhapaa points to post a comment.');
    }
  }

  void openDonateModal() {
    final userAvailableCoins =
        Provider.of<Auth>(context, listen: false).userAvailableCoins;
    showModalBottomSheet<void>(
      isScrollControlled: true,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 0,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Header section
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.pink.shade400, Colors.red.shade400],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.supportCreator,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              'Help support this content creator',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 32),

                  // Available points info
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/coins.png',
                          width: 24,
                          height: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Available Points: ',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$userAvailableCoins',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${context.l10n.supportCreator} ${context.l10n.points}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          controller: donationController,
                          decoration: InputDecoration(
                            hintText: 'Enter points amount',
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(12),
                              child: Image.asset(
                                'assets/images/coins.png',
                                width: 20,
                                height: 20,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: Colors.amber.shade400, width: 2),
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter points amount';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            if (int.parse(value) <= 0) {
                              return 'Please enter a positive amount';
                            }
                            if (int.parse(value) > userAvailableCoins) {
                              return 'Insufficient points. Maximum: $userAvailableCoins';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Support Message (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: donationCommentController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Write a supportive message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: Colors.amber.shade400, width: 2),
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade50,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),

                  // Action buttons
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: donate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.pink.shade400,
                                  Colors.red.shade400
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.pink.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.favorite_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    // 'Send Support',
                                    context.l10n.sendButton,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade50,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var _authProvider = Provider.of<Auth>(context, listen: false);
    // Debug logging for navigation state
    final story = Provider.of<Story>(context, listen: false);
    final selectedSeason = story.selectedSeason;
    final season = selectedSeason['title'] ??
        episode['season_title'] ??
        episode['title'] ??
        'Video';
    DebugLogger.info(
        '🎬 VideoScreen: Build called - Episodes: ${_allEpisodes.length}, Current index: $_currentEpisodeIndex, Loading: $_isLoading, $season');

    return Scaffold(
      appBar: header(
        context: context,
        titleText: _isLoading ? '${context.l10n.loading}....' : season,
      ),
      body: _isLoading
          ? const VideoScreenSkeleton()
          : SingleChildScrollView(
              controller: _scrollController,
              child: Popup(
                popupArr: _popups,
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: 900,
                    minWidth: 300,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: Column(
                      children: <Widget>[
                        // Modern stats header
                        Row(
                          children: [
                            Text(
                              episode['title'] != null
                                  ? (episode['title'].toString().length > 30
                                      ? episode['title']
                                              .toString()
                                              .substring(0, 30) +
                                          '...'
                                      : episode['title'].toString())
                                  : '',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(width: 12),
                            Text(
                              '${_currentEpisodeIndex + 1} of ${_allEpisodes.length}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Color(0xFF242424),
                              width: 4,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              child: episode.isEmpty
                                  ? const SizedBox(
                                      height: 200,
                                      child: ShimmerLoading(
                                        child: SkeletonBox(
                                            width: double.infinity,
                                            height: 200,
                                            borderRadius: 8),
                                      ))
                                  : episode['video_source'] == 'youtube'
                                      ? _youtubePlayerError
                                          ? _buildYoutubeErrorWidget()
                                          : _buildYoutubePlayerWidget()
                                      : _videoLoadingError
                                          ? _buildVideoErrorWidget()
                                          : (flickManager != null &&
                                                  !_flickManagerDisposed
                                              ? FlickVideoPlayer(
                                                  flickManager: flickManager!,
                                                  flickVideoWithControls:
                                                      FlickVideoWithControls(
                                                    videoFit: BoxFit.contain,
                                                    controls:
                                                        const FlickPortraitControls(),
                                                  ),
                                                  flickVideoWithControlsFullscreen:
                                                      FlickVideoWithControls(
                                                    videoFit: BoxFit.contain,
                                                    controls:
                                                        const FlickLandscapeControls(),
                                                  ),
                                                )
                                              : const SizedBox(
                                                  height: 200,
                                                  child: ShimmerLoading(
                                                    child: SkeletonBox(
                                                        width: double.infinity,
                                                        height: 200,
                                                        borderRadius: 8),
                                                  ))),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        // Episode Navigation Controls Card - Always show for Go To Questions button
                        Builder(builder: (context) {
                          DebugLogger.info(
                              '🧭 VideoScreen: Navigation check - Episodes: ${_allEpisodes.length}, Always showing navigation card');
                          return _buildNavigationCard();
                        }),

                        SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => RatingSheet(
                                          ratingType: RatingType.episode,
                                          currentUserId: _authProvider.userId,
                                          authToken: _authProvider.token,
                                          ratingId: episode['id'],
                                          ratingTitle: episode['title'],
                                        ),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/images/carbon_review.png',
                                          width: 30,
                                          height: 30,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ShaderMask(
                                                shaderCallback: (bounds) =>
                                                    const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFF24F5EE),
                                                    Color(0xFF1877F2),
                                                    Color(0xFF1877F2),
                                                    Color(0xFF24F5EE),
                                                  ],
                                                  stops: [0.0, 0.5, 0.75, 1.0],
                                                ).createShader(bounds),
                                                child: const Text(
                                                  'Review Now',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors
                                                        .white, // required for ShaderMask
                                                  ),
                                                ),
                                              ),
                                              RatingSummery(
                                                starSize: 16,
                                                ratingTo: RatingTo.episode,
                                                ratingId: episode['id'],
                                                authToken: _authProvider.token,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: FaIcon(
                                    FontAwesomeIcons.handHoldingHeart,
                                    size: 24,
                                  ),
                                  onPressed: openDonateModal,
                                ),
                                Text(
                                  'Vote',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                )
                              ],
                            ),
                            SizedBox(width: 20),
                            Column(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.share_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: () async {
                                    // Generate share text for episode
                                    String bs64str1 = base64Url.encode(utf8
                                        .encode(json.encode(episode['id'])));
                                    final shareText =
                                        'Watch "${episode['title']}" on Baakhapaa! ${Url.deepLink('/episode/$bs64str1')}';

                                    await showModalBottomSheet(
                                      context: context,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(24)),
                                      ),
                                      builder: (BuildContext context) {
                                        return _buildShareModal(
                                            context, shareText);
                                      },
                                    );
                                  },
                                ),
                                Text(
                                  'Share',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 20),
                            Column(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.flag,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: _showReportEpisodeDialog,
                                ),
                                Text(
                                  'Report',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        // Comments Section
                        Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${context.l10n.comments}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      '${_episodeComments.length}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color.fromARGB(
                                                255, 59, 59, 59)
                                            : const Color.fromARGB(
                                                221, 45, 44, 44),
                                      ),
                                    ),
                                    Spacer(),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                height: 1,
                                color: Colors.white, // white separator line
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8), // optional padding
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Consumer<Auth>(
                                      builder: (context, auth, child) {
                                        String imageUrl =
                                            'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
                                        if (auth.image != null &&
                                            auth.image!.isNotEmpty) {
                                          imageUrl =
                                              auth.image!.first['thumbnail'] ??
                                                  imageUrl;
                                        }
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(right: 10),
                                          child: CircleAvatar(
                                            radius: 18,
                                            backgroundImage:
                                                NetworkImage(imageUrl),
                                            child: ClipOval(
                                              child: Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                width: 36,
                                                height: 36,
                                                errorBuilder: (_, __, ___) =>
                                                    Icon(
                                                  Icons.person,
                                                  color: Colors.grey.shade400,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    Expanded(
                                        child: Container(
                                      height: 50,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF2A2A2A)
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              focusNode: commentFocus,
                                              controller: commentController,
                                              cursorColor: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : Colors.black,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 14,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    '${context.l10n.shareYourThoughts}...',
                                                hintStyle: TextStyle(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 14,
                                                ),
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                disabledBorder:
                                                    InputBorder.none,
                                                errorBorder: InputBorder.none,
                                                focusedErrorBorder:
                                                    InputBorder.none,
                                                isCollapsed: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              maxLines: 1,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: comment,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              child: Text(
                                                'Send',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                              Container(
                                constraints: BoxConstraints(
                                  // When collapsed show a small area (one comment),
                                  // when expanded allow full height.
                                  maxHeight: _showAllComments
                                      ? (_episodeComments.isEmpty ? 120 : 400)
                                      : 120,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey.shade900
                                          .withValues(alpha: 0.2)
                                      : Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: _episodeComments.isEmpty
                                    ? Center(
                                        child: Container(
                                          padding: EdgeInsets.all(10),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.chat_bubble_outline,
                                                      size: 20,
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'No comments yet',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                  ]),
                                              SizedBox(height: 8),
                                              Text(
                                                'Be the first to share your thoughts!',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        key: _listKey,
                                        shrinkWrap: true,
                                        padding: EdgeInsets.all(16),
                                        // If not expanded, show only the latest comment
                                        itemCount: _showAllComments
                                            ? _episodeComments.length
                                            : 1,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          // When collapsed, always show the latest comment
                                          if (!_showAllComments) {
                                            final latest =
                                                _episodeComments.last;
                                            return Container(
                                              margin:
                                                  EdgeInsets.only(bottom: 12),
                                              child: buildCommentWidget(latest),
                                            );
                                          }

                                          return Container(
                                            margin: EdgeInsets.only(bottom: 12),
                                            child: buildCommentWidget(
                                                _episodeComments[index]),
                                          );
                                        },
                                      ),
                              ),
                              if (_episodeComments.length > 1)
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _showAllComments = !_showAllComments;
                                      });
                                    },
                                    child: Text(
                                      _showAllComments
                                          ? 'Hide comments'
                                          : 'Show all comments',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        SizedBox(height: 40),

                        _buildLinkedShortsSection(),
                        _buildLinkedEpisodesSection(),
                        _buildAffiliateProductsSection(),

                        // Featured Products Section (only show if products exist)
                        if (_products.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            margin: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Color(0xFF1E1E1E)
                                  : Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.amber.shade400,
                                              Colors.orange.shade400
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: FaIcon(FontAwesomeIcons.store,
                                            color: Colors.white, size: 20),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Attached Products',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                SizedBox(height: 6),
                                                Text(
                                                  'Products featured in this episode',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? Colors.white70
                                                        : Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // SizedBox(height: 16),
                                  Container(
                                    height: 320,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey.shade900
                                              .withValues(alpha: 0.3)
                                          : Colors.grey.shade50,
                                    ),
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      itemCount: _products.length,
                                      itemBuilder: (context, index) {
                                        return ProductItem(_products[index]);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 32),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLinkedShortsSection() {
    if (_relatedShorts.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Linked Shorts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _relatedShorts.length,
            itemBuilder: (context, index) {
              final short = _relatedShorts[index];
              return buildShortsThumbnailCard(short);
            },
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget buildShortsThumbnailCard(Map<String, dynamic> short) {
    final String imageUrl = short['thumbnail']?.toString() ?? '';
    final String title = short['title']?.toString() ?? 'Short';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          SingleShortsScreen.routeName,
          arguments: short['id'],
        );
      },
      child: Container(
        width: 100,
        margin: EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                  ),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 32,
                          ),
                        )
                      : Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),
            ),
            SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedEpisodesSection() {
    if (_relatedEpisodes.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Linked Episodes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 140, // Height for EpisodeThumbnailCard
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _relatedEpisodes.length,
            itemBuilder: (context, index) {
              final relEpisode = _relatedEpisodes[index];
              return Container(
                width: 160, // Fixed width for horizontal list
                margin: EdgeInsets.only(right: 12),
                child: EpisodeThumbnailCard(
                  imageUrl: relEpisode['thumbnail'] ?? '',
                  label: 'EP ${relEpisode['episode_number'] ?? (index + 1)}',
                  episode: relEpisode,
                ),
              );
            },
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAffiliateProductsSection() {
    if (_affiliateProducts.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Recommended Products',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ),
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: AffiliatedProduct(
            height: 160,
            itemWidth: 140,
            color: Colors.amber,
            products: _affiliateProducts,
            affiliateId: episode['affiliate_id'],
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget buildCommentsList(List<Map<String, dynamic>> comments) {
    if (comments.isEmpty) return SizedBox();

    // Show only the latest comment if _showAllComments is false
    final commentsToShow = _showAllComments ? comments : [comments.last];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...commentsToShow.map((c) => buildCommentWidget(c)),
        if (comments.length > 1)
          InkWell(
            onTap: () {
              setState(() {
                _showAllComments = !_showAllComments;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _showAllComments
                    ? 'Hide all comments'
                    : 'View all ${comments.length} comments',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[700]),
              ),
            ),
          ),
      ],
    );
  }

  int _extractCommentUserId(
      Map<String, dynamic> comment, Map<String, dynamic> user) {
    final dynamic rawUserId = comment['user_id'] ?? user['id'];
    if (rawUserId is int) return rawUserId;
    return int.tryParse(rawUserId?.toString() ?? '') ?? 0;
  }

  String _extractCommentUsername(Map<String, dynamic> user) {
    return (user['username'] ?? user['name'] ?? '').toString().trim();
  }

  Future<void> _showReportCommentUserDialog({
    required int userId,
    required String username,
  }) async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      await GuestAuthHelper.showGuestLoginDialog(context, 'report this user');
      return;
    }

    if (userId <= 0) {
      _showEpisodeSnackBar('Unable to report this user.', Colors.red);
      return;
    }

    String selectedReason = 'Harassment or bullying';
    final reasons = [
      'Spam',
      'Harassment or bullying',
      'Hate speech',
      'Inappropriate content',
      'Misinformation',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why are you reporting @$username?'),
              const SizedBox(height: 12),
              ...reasons.map(
                (reason) => RadioListTile<String>(
                  dense: true,
                  title: Text(reason, style: const TextStyle(fontSize: 13)),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await auth.reportContent(
                    type: 'user',
                    targetId: userId,
                    reason: selectedReason,
                  );
                  if (mounted) {
                    _showEpisodeSnackBar(
                        'Report submitted. Thank you.', Colors.green);
                  }
                } catch (e) {
                  if (mounted) {
                    _showEpisodeSnackBar(
                      e.toString().replaceFirst('Exception: ', ''),
                      Colors.red,
                    );
                  }
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBlockCommentUser({required String username}) async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      await GuestAuthHelper.showGuestLoginDialog(context, 'block this user');
      return;
    }

    if (username.trim().isEmpty) {
      _showEpisodeSnackBar('Unable to block this user.', Colors.red);
      return;
    }

    final shouldBlock = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Block User'),
            content: Text('Block @$username and hide their content?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Block'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldBlock) return;

    try {
      await auth.blockUser(username);
      if (mounted) {
        _showEpisodeSnackBar('@$username has been blocked.', Colors.green);
        getEpisodeComments();
      }
    } catch (e) {
      if (mounted) {
        _showEpisodeSnackBar(
          e.toString().replaceFirst('Exception: ', ''),
          Colors.red,
        );
      }
    }
  }

  Widget buildCommentWidget(Map<String, dynamic> commentArr) {
    final Map<String, dynamic> comment = commentArr['comment'];
    final List<Map<String, dynamic>> replies =
        List<Map<String, dynamic>>.from(commentArr['replies'] ?? []);
    final Map<String, dynamic> user = comment['user'];
    final username = _extractCommentUsername(user);
    final commentUserId = _extractCommentUserId(comment, user);
    final currentUserId = Provider.of<Auth>(context, listen: false).userId;
    final bool isOwnComment = currentUserId == commentUserId;
    final commentId = comment['id'] as int;

    final bool isExpanded = _expandedReplies[commentId] ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment row, actions, etc.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[800],
                backgroundImage: (user['image']?.toString().isNotEmpty ?? false)
                    ? CachedNetworkImageProvider(user['image'].toString())
                        as ImageProvider
                    : const AssetImage('assets/images/logo.png')
                        as ImageProvider,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(username,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black87)),
                        ),
                        if (!isOwnComment && username.isNotEmpty)
                          PopupMenuButton<String>(
                            tooltip: 'Comment actions',
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                            ),
                            onSelected: (value) {
                              if (value == 'report_user') {
                                _showReportCommentUserDialog(
                                  userId: commentUserId,
                                  username: username,
                                );
                              } else if (value == 'block_user') {
                                _confirmBlockCommentUser(username: username);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem<String>(
                                value: 'report_user',
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_outlined,
                                        color: Colors.orange),
                                    SizedBox(width: 10),
                                    Text('Report User'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'block_user',
                                child: Row(
                                  children: [
                                    Icon(Icons.block, color: Colors.red),
                                    SizedBox(width: 10),
                                    Text('Block User'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(comment['body'].toString(),
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[300]
                                    : Colors.black87)),
                    SizedBox(height: 6),
                    // Reply button & like button
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            parentCommentId = commentId;
                            commentController.text = '@$username ';
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                            commentFocus.requestFocus();
                          },
                          child: Text('Reply',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[700])),
                        ),
                        if (replies.isNotEmpty)
                          InkWell(
                            onTap: () {
                              setState(() {
                                _expandedReplies[commentId] =
                                    !(_expandedReplies[commentId] ?? false);
                              });
                            },
                            child: Padding(
                              padding: EdgeInsets.only(left: 22, top: 6),
                              child: Text(
                                isExpanded
                                    ? 'Hide replies'
                                    : 'View ${replies.length} ${replies.length > 1 ? 'replies' : 'reply'}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[400]
                                        : Colors.grey[700]),
                              ),
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),

          // Replies if expanded
          if (isExpanded)
            Container(
              margin: EdgeInsets.only(left: 42, top: 4),
              child: Column(
                  children: replies.map((r) => buildReplyWidget(r)).toList()),
            ),
        ],
      ),
    );
  }

  Widget buildReplyWidget(Map<String, dynamic> replyArr) {
    final Map<String, dynamic> reply =
        replyArr['comment'] as Map<String, dynamic>;
    final Map<String, dynamic> user = reply['user'] as Map<String, dynamic>;
    final username = _extractCommentUsername(user);
    final replyUserId = _extractCommentUserId(reply, user);
    final currentUserId = Provider.of<Auth>(context, listen: false).userId;
    final bool isOwnReply = currentUserId == replyUserId;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[800],
              backgroundImage: (user['image']?.toString().isNotEmpty ?? false)
                  ? CachedNetworkImageProvider(user['image'].toString())
                      as ImageProvider
                  : const AssetImage('assets/images/logo.png') as ImageProvider,
            ),
          ),
          SizedBox(width: 12),

          // Reply content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and timestamp
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _formatTimestamp(reply['created_at'].toString()),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[500]
                            : Colors.grey[600],
                      ),
                    ),
                    if (!isOwnReply && username.isNotEmpty)
                      PopupMenuButton<String>(
                        tooltip: 'Reply actions',
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[700],
                        ),
                        onSelected: (value) {
                          if (value == 'report_user') {
                            _showReportCommentUserDialog(
                              userId: replyUserId,
                              username: username,
                            );
                          } else if (value == 'block_user') {
                            _confirmBlockCommentUser(username: username);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem<String>(
                            value: 'report_user',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined, color: Colors.orange),
                                SizedBox(width: 10),
                                Text('Report User'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'block_user',
                            child: Row(
                              children: [
                                Icon(Icons.block, color: Colors.red),
                                SizedBox(width: 10),
                                Text('Block User'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                SizedBox(height: 4),

                // Reply text
                Text(
                  reply['body'].toString(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[300]
                        : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final DateTime dateTime = DateTime.parse(timestamp);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${(difference.inDays / 7).floor()}w ago';
      }
    } catch (e) {
      return timestamp;
    }
  }

  Widget _buildYoutubePlayerWidget() {
    try {
      // Check if episode is empty first
      if (episode.isEmpty) {
        return const SizedBox(
            height: 200,
            child: ShimmerLoading(
              child: SkeletonBox(
                  width: double.infinity, height: 200, borderRadius: 8),
            ));
      }

      // Calculate resume seconds from progress_seconds or completion_percent
      int? resumeSeconds;

      if (_resumeOverrideSeconds != null && _resumeOverrideSeconds! > 0) {
        resumeSeconds = _resumeOverrideSeconds;
        DebugLogger.info(
            '🎯 YouTube: Using My Courses resume override: ${resumeSeconds}s');
      } else if (episode['progress_seconds'] != null) {
        resumeSeconds = int.tryParse(episode['progress_seconds'].toString());
        DebugLogger.info(
            '📹 YouTube: Found direct progress_seconds: ${resumeSeconds}s');
      } else if (episode['completion_percent'] != null &&
          episode['duration'] != null) {
        final completionPercent =
            double.tryParse(episode['completion_percent'].toString()) ?? 0.0;
        final duration = int.tryParse(episode['duration'].toString()) ?? 0;

        if (completionPercent > 0 && duration > 0) {
          resumeSeconds = ((completionPercent / 100.0) * duration).round();
          DebugLogger.info(
              '📹 YouTube: Calculated progress from completion_percent: ${completionPercent}% of ${duration}s = ${resumeSeconds}s');
        }
      }

      // Use the pod player implementation
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SimpleYouTubePlayer(
            videoId: episode['video_url'].toString(),
            autoPlay: true,
            resumeFromSeconds: resumeSeconds,
            onProgressUpdate: (progressSeconds) {
              _updateCurrentProgress(progressSeconds);
            },
            onDurationReceived: (durationSeconds) {
              setState(() {
                _actualVideoDurationSeconds = durationSeconds;
              });
              DebugLogger.info(
                  "YouTube video duration received: ${durationSeconds}s");
            },
          ),
        ),
      );
    } catch (e) {
      DebugLogger.error("Error building YouTube player: $e");
      return _buildYoutubeErrorWidget();
    }
  }

  Widget _buildYoutubeErrorWidget() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'YouTube video playback unavailable',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          ElevatedButton.icon(
            icon: Icon(Icons.open_in_new),
            label: Text('Watch on YouTube'),
            onPressed: () {
              final url =
                  'https://www.youtube.com/watch?v=${episode['video_url']}';
              _launchYouTubeUrl(url);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoErrorWidget() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Video playback failed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Unable to load video content',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            onPressed: () {
              setState(() {
                _videoLoadingError = false;
                _youtubePlayerError = false;
              });
              initializeVideo();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchYouTubeUrl(String url) async {
    try {
      DebugLogger.info("Would launch URL: $url");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening YouTube video in external app...')),
      );
    } catch (e) {
      DebugLogger.error("Error launching URL: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Could not open YouTube video. Please try again later.')),
      );
    }
  }

  // Widget _buildNavigationCard() {
  //   return Row(
  //     children: [
  //       // Previous Episode Button - only show if multiple episodes
  //       if (_allEpisodes.length > 1) ...[
  //         Expanded(
  //           flex: 2,
  //           child: _hasPreviousEpisode
  //               ? InkWell(
  //                   onTap: () => _navigateToEpisode(-1),
  //                   borderRadius: BorderRadius.circular(40),
  //                   child: Container(
  //                     padding:
  //                         EdgeInsets.symmetric(vertical: 14, horizontal: 16),
  //                     decoration: BoxDecoration(
  //                       color: Colors.grey.shade700,
  //                       borderRadius: BorderRadius.circular(40),
  //                     ),
  //                     child: Row(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       children: [
  //                         Icon(
  //                           Icons.skip_previous_rounded,
  //                           color: Colors.white70,
  //                           size: 20,
  //                         ),
  //                         Flexible(
  //                           child: Text(
  //                             context.l10n.previous,
  //                             style: TextStyle(
  //                               color: Colors.white70,
  //                               fontWeight: FontWeight.w600,
  //                               fontSize: 10,
  //                             ),
  //                             overflow: TextOverflow.ellipsis,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 )
  //               : Container(
  //                   padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey.shade800,
  //                     borderRadius: BorderRadius.circular(40),
  //                   ),
  //                   child: Row(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     children: [
  //                       Icon(
  //                         Icons.skip_previous_rounded,
  //                         color: Colors.grey.shade600,
  //                         size: 20,
  //                       ),
  //                       SizedBox(width: 6),
  //                       Flexible(
  //                         child: Text(
  //                           context.l10n.previous,
  //                           style: TextStyle(
  //                             color: Colors.grey.shade600,
  //                             fontWeight: FontWeight.w600,
  //                             fontSize: 13,
  //                           ),
  //                           overflow: TextOverflow.ellipsis,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //         ),
  //         SizedBox(width: 8),
  //       ],

  //       // Quiz Status Button - show completion or start quiz
  //       Expanded(
  //         flex: _allEpisodes.length > 1
  //             ? 3
  //             : 1, // Take full width if single episode
  //         child: Consumer<TutorialFlowProvider>(
  //           builder: (context, tutorial, _) {
  //             // Check if episode is already watched (quiz completed)
  //             final bool isQuizCompleted = episode['watched'] ?? false;

  //             if (isQuizCompleted) {
  //               // Show quiz completed status
  //               return Container(
  //                 padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
  //                 decoration: BoxDecoration(
  //                   gradient: LinearGradient(
  //                     begin: Alignment.bottomCenter,
  //                     end: Alignment.topCenter,
  //                     colors: [
  //                       Color(0xFF0DFF00),
  //                       Color(0xFF0D9900),
  //                     ],
  //                   ),
  //                   borderRadius: BorderRadius.circular(40),
  //                   boxShadow: [
  //                     BoxShadow(
  //                       color: Color.fromARGB(255, 54, 57, 55)
  //                           .withValues(alpha: 0.5),
  //                       blurRadius: 15,
  //                       offset: Offset(0, 5),
  //                     ),
  //                   ],
  //                 ),
  //                 child: Row(
  //                   mainAxisAlignment: MainAxisAlignment.center,
  //                   children: [
  //                     Icon(
  //                       Icons.check_circle,
  //                       color: Colors.white,
  //                       size: 20,
  //                     ),
  //                     SizedBox(width: 8),
  //                     Flexible(
  //                       child: Text(
  //                         'Quiz Completed',
  //                         style: TextStyle(
  //                           fontSize: 15,
  //                           color: Colors.white,
  //                           fontWeight: FontWeight.bold,
  //                           letterSpacing: 0.3,
  //                         ),
  //                         overflow: TextOverflow.ellipsis,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               );
  //             }

  //             // Show timer or start quiz button for uncompleted quiz
  //             final durationSkipsBought =
  //                 episode['duration_skips_bought'] as int? ?? 0;
  //             final maxDurationSkips =
  //                 episode['max_duration_skips'] as int? ?? 0;
  //             final durationSkipsRemaining =
  //                 episode['duration_skips_remaining'] as int? ?? 0;
  //             final durationSkipCost =
  //                 episode['duration_skip_cost'] as int? ?? 0;

  //             // Debug logging for skip button visibility
  //             DebugLogger.info(
  //                 '⏱️ Skip Button Check - Countdown: $_countdownCompleted, '
  //                 'Bought: $durationSkipsBought, Max: $maxDurationSkips, '
  //                 'Remaining: $durationSkipsRemaining, Cost: $durationSkipCost');

  //             final bool canUseSkip =
  //                 !_countdownCompleted && durationSkipsBought > 0;
  //             final bool canBuySkip = !_countdownCompleted &&
  //                 maxDurationSkips > 0 &&
  //                 durationSkipCost > 0 &&
  //                 durationSkipsRemaining > 0;

  //             if (canUseSkip) {
  //               DebugLogger.success('✅ Showing USE SKIP button');
  //             } else if (canBuySkip) {
  //               DebugLogger.success('✅ Showing BUY SKIP button');
  //             } else {
  //               if (_countdownCompleted && maxDurationSkips > 0) {
  //                 DebugLogger.warning(
  //                     '⏰ Skip button hidden - Timer completed! (Duration skips were available)');
  //               } else if (maxDurationSkips == 0) {
  //                 DebugLogger.warning(
  //                     '⚠️ Skip button hidden - Episode has no duration skips configured');
  //               }
  //             }

  //             return Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 // Duration Skip Button - show when countdown is active
  //                 if (!_countdownCompleted) ...[
  //                   // Show unified skip dialog for all skip options
  //                   if (canUseSkip || canBuySkip)
  //                     InkWell(
  //                       onTap: _isUsingDurationSkip
  //                           ? null
  //                           : _showSkipOptionsDialog,
  //                       borderRadius: BorderRadius.circular(20),
  //                       child: Container(
  //                         padding:
  //                             EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  //                         margin: EdgeInsets.only(bottom: 8),
  //                         decoration: BoxDecoration(
  //                           gradient: LinearGradient(
  //                               begin: Alignment.topLeft,
  //                               end: Alignment.bottomRight,
  //                               colors:
  //                                   // canUseSkip
  //                                   //     ?
  //                                   [Color(0xFFFF6B00), Color(0xFFFF9900)]
  //                               // : [Color(0xFF0066FF), Color(0xFF0099FF)],
  //                               ),
  //                           borderRadius: BorderRadius.circular(20),
  //                           boxShadow: [
  //                             BoxShadow(
  //                               color: (
  //                                       // canUseSkip
  //                                       //       ?
  //                                       Color(0xFFFF6B00)
  //                                   // : Color(0xFF0066FF)
  //                                   )
  //                                   .withValues(alpha: 0.4),
  //                               blurRadius: 8,
  //                               offset: Offset(0, 3),
  //                             ),
  //                           ],
  //                         ),
  //                         child: Row(
  //                           mainAxisSize: MainAxisSize.min,
  //                           mainAxisAlignment: MainAxisAlignment.center,
  //                           children: [
  //                             Icon(
  //                               canUseSkip
  //                                   ? Icons.fast_forward
  //                                   : Icons.flash_on,
  //                               color: Colors.white,
  //                               size: 16,
  //                             ),
  //                             SizedBox(width: 6),
  //                             Text(
  //                               canUseSkip
  //                                   ? 'Skip ($durationSkipsBought)'
  //                                   : 'Skip',
  //                               style: TextStyle(
  //                                 fontSize: 13,
  //                                 color: Colors.white,
  //                                 fontWeight: FontWeight.bold,
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                       ),
  //                     ),
  //                 ],

  //                 // Main countdown/quiz button
  //                 Stack(
  //                   children: [
  //                     InkWell(
  //                       onTap: !_countdownCompleted || episode.isEmpty
  //                           ? () {
  //                               DebugLogger.success(
  //                                   '🚫 VideoScreen: Button tapped but disabled - countdownCompleted: $_countdownCompleted, episode.isEmpty: ${episode.isEmpty}');
  //                             }
  //                           : () {
  //                               DebugLogger.success(
  //                                   '✅ VideoScreen: Go To Questions button tapped');
  //                               goToQuestionScreen(episode['id'] as int);
  //                             },
  //                       borderRadius: BorderRadius.circular(40),
  //                       child: Container(
  //                         padding: EdgeInsets.symmetric(
  //                             vertical: 14, horizontal: 20),
  //                         decoration: BoxDecoration(
  //                           gradient: !_countdownCompleted || episode.isEmpty
  //                               ? LinearGradient(
  //                                   colors: [
  //                                     Colors.grey.shade700,
  //                                     Colors.grey.shade800,
  //                                   ],
  //                                 )
  //                               : LinearGradient(
  //                                   begin: Alignment.bottomCenter,
  //                                   end: Alignment.topCenter,
  //                                   colors: [
  //                                     Color(0xFF0DFF00),
  //                                     Color(0xFF0D9900),
  //                                   ],
  //                                 ),
  //                           borderRadius: BorderRadius.circular(40),
  //                           boxShadow: !_countdownCompleted || episode.isEmpty
  //                               ? []
  //                               : [
  //                                   BoxShadow(
  //                                     color: Color.fromARGB(255, 54, 57, 55)
  //                                         .withValues(alpha: 0.5),
  //                                     blurRadius: 15,
  //                                     offset: Offset(0, 5),
  //                                   ),
  //                                 ],
  //                         ),
  //                         child: Center(
  //                           child: !_countdownCompleted
  //                               ? Row(
  //                                   mainAxisAlignment: MainAxisAlignment.center,
  //                                   children: [
  //                                     Icon(
  //                                       Icons.timer_outlined,
  //                                       color: Colors.grey.shade400,
  //                                       size: 18,
  //                                     ),
  //                                     SizedBox(width: 8),
  //                                     Text(
  //                                       '${myDuration.inHours.remainder(24).toString().padLeft(2, '0')}:${myDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${myDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
  //                                       style: TextStyle(
  //                                         fontSize: 14,
  //                                         fontWeight: FontWeight.bold,
  //                                         color: Colors.grey.shade400,
  //                                       ),
  //                                     ),
  //                                   ],
  //                                 )
  //                               : Text(
  //                                   context.l10n.goToQuestion,
  //                                   key: keyNavigation,
  //                                   style: TextStyle(
  //                                     fontSize: 15,
  //                                     color: Colors.white,
  //                                     fontWeight: FontWeight.bold,
  //                                     letterSpacing: 0.3,
  //                                   ),
  //                                   overflow: TextOverflow.ellipsis,
  //                                 ),
  //                         ),
  //                       ),
  //                     ),
  //                     if (_countdownCompleted &&
  //                         tutorial.currentStep == 7 &&
  //                         tutorial.isActive)
  //                       Positioned(
  //                         top: -5,
  //                         right: 10,
  //                         child: TutorialIndicator(),
  //                       ),
  //                   ],
  //                 ),
  //                 // if (!_countdownCompleted &&
  //                 //     _skipTimerBenefit != null &&
  //                 //     (_skipTimerBenefit!.usage.availableCount > 0 ||
  //                 //         _skipTimerBenefit!.usage.isUnlimited))
  //                 //   Positioned(
  //                 //     right: 0,
  //                 //     top: 0,
  //                 //     bottom: 0,
  //                 //     child: GestureDetector(
  //                 //       onTap: _useSkipTimerBenefit,
  //                 //       child: Container(
  //                 //         padding: EdgeInsets.symmetric(horizontal: 12),
  //                 //         decoration: BoxDecoration(
  //                 //           color: Colors.amber.shade700,
  //                 //           borderRadius: BorderRadius.only(
  //                 //             topRight: Radius.circular(40),
  //                 //             bottomRight: Radius.circular(40),
  //                 //           ),
  //                 //         ),
  //                 //         child: Center(
  //                 //           child: Column(
  //                 //             mainAxisAlignment: MainAxisAlignment.center,
  //                 //             children: [
  //                 //               Icon(Icons.flash_on,
  //                 //                   color: Colors.white, size: 16),
  //                 //               Text(
  //                 //                 'Skip',
  //                 //                 style: TextStyle(
  //                 //                   color: Colors.white,
  //                 //                   fontSize: 10,
  //                 //                   fontWeight: FontWeight.bold,
  //                 //                 ),
  //                 //               ),
  //                 //             ],
  //                 //           ),
  //                 //         ),
  //                 //       ),
  //                 //     ),
  //                 //   ),
  //                 if (_countdownCompleted &&
  //                     tutorial.currentStep == 7 &&
  //                     tutorial.isActive)
  //                   Positioned(
  //                     top: -5,
  //                     right: 10,
  //                     child: TutorialIndicator(),
  //                   ),
  //               ],
  //             );
  //           },
  //         ),
  //       ),

  //       // Next Episode Button - only show if multiple episodes
  //       if (_allEpisodes.length > 1) ...[
  //         SizedBox(width: 8),
  //         Expanded(
  //           flex: 2,
  //           child: _hasNextEpisode
  //               ? InkWell(
  //                   onTap: () => _navigateToEpisode(1),
  //                   borderRadius: BorderRadius.circular(40),
  //                   child: Container(
  //                     padding:
  //                         EdgeInsets.symmetric(vertical: 14, horizontal: 16),
  //                     decoration: BoxDecoration(
  //                       color: Colors.grey.shade700,
  //                       borderRadius: BorderRadius.circular(40),
  //                     ),
  //                     child: Row(
  //                       mainAxisAlignment: MainAxisAlignment.center,
  //                       children: [
  //                         Flexible(
  //                           child: Text(
  //                             context.l10n.next,
  //                             style: TextStyle(
  //                               color: Colors.white70,
  //                               fontWeight: FontWeight.w600,
  //                               fontSize: 10,
  //                             ),
  //                             overflow: TextOverflow.ellipsis,
  //                           ),
  //                         ),
  //                         Icon(
  //                           Icons.skip_next_rounded,
  //                           color: Colors.white70,
  //                           size: 20,
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 )
  //               : Container(
  //                   padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey.shade800,
  //                     borderRadius: BorderRadius.circular(40),
  //                   ),
  //                   child: Row(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     children: [
  //                       Flexible(
  //                         child: Text(
  //                           context.l10n.next,
  //                           style: TextStyle(
  //                             color: Colors.grey.shade600,
  //                             fontWeight: FontWeight.w600,
  //                             fontSize: 13,
  //                           ),
  //                           overflow: TextOverflow.ellipsis,
  //                         ),
  //                       ),
  //                       SizedBox(width: 6),
  //                       Icon(
  //                         Icons.skip_next_rounded,
  //                         color: Colors.grey.shade600,
  //                         size: 20,
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //         ),
  //       ],
  //     ],
  //   );
  // }

  Widget _buildNavigationCard() {
    Widget _episodeButton({
      required bool isEnabled,
      required VoidCallback onTap,
      required IconData icon,
      required String label,
      bool isNext = false,
    }) {
      final bgColor = isEnabled ? Colors.grey.shade800 : Colors.grey.shade900;
      final textColor = isEnabled ? Colors.white70 : Colors.grey.shade600;

      return Expanded(
        flex: 2,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: isNext
                  ? [
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(icon, color: textColor, size: 20),
                    ]
                  : [
                      Icon(icon, color: textColor, size: 20),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
            ),
          ),
        ),
      );
    }

    Widget _mainButton() {
      return Expanded(
        flex: _allEpisodes.length > 1 ? 4 : 6,
        child: Consumer<TutorialFlowProvider>(
          builder: (context, tutorial, _) {
            final durationSkipsBought =
                episode['duration_skips_bought'] as int? ?? 0;
            final maxDurationSkips = episode['max_duration_skips'] as int? ?? 0;
            final durationSkipsRemaining =
                episode['duration_skips_remaining'] as int? ?? 0;

            final bool canUseSkip =
                !_countdownCompleted && durationSkipsBought > 0;
            final bool canBuySkip = !_countdownCompleted &&
                maxDurationSkips > 0 &&
                durationSkipsRemaining > 0;
            // ✅ Check subscription FIRST
            final hasSubscriptionSkip = _skipTimerBenefit != null &&
                (_skipTimerBenefit!.usage.isUnlimited ||
                    _skipTimerBenefit!.usage.remaining > 0);

            // Show skip if ANY method available
            final bool showSkipButton = !_countdownCompleted &&
                (hasSubscriptionSkip || canUseSkip || canBuySkip);

            return InkWell(
              onTap: _countdownCompleted && !episode.isEmpty
                  ? () {
                      final id = episode['id'];
                      final episodeId =
                          id is int ? id : int.tryParse(id?.toString() ?? '');
                      if (episodeId != null) {
                        _showGameModeSelector(episodeId);
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: _countdownCompleted
                      ? LinearGradient(
                          colors: [Color(0xFF0DFF00), Color(0xFF0D9900)],
                        )
                      : LinearGradient(
                          colors: [Colors.grey.shade800, Colors.grey.shade900],
                        ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: _countdownCompleted
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Timer in center-left
                    Expanded(
                      child: Center(
                        child: !_countdownCompleted
                            ? Text(
                                '${myDuration.inHours.remainder(24).toString().padLeft(2, '0')}:${myDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${myDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade300,
                                ),
                              )
                            : Text(
                                'Start Challenge',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    // ✅ Check subscription FIRST

                    if (showSkipButton)
                      GestureDetector(
                        onTap: _isUsingDurationSkip
                            ? null
                            : _showSkipOptionsDialog,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.4),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  canUseSkip
                                      ? Icons.fast_forward
                                      : Icons.flash_on,
                                  size: 14,
                                  color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Row(
      children: [
        if (_allEpisodes.length > 1)
          _episodeButton(
            isEnabled: _hasPreviousEpisode,
            onTap: () => _navigateToEpisode(-1),
            icon: Icons.skip_previous_rounded,
            label: context.l10n.previous,
          ),
        if (_allEpisodes.length > 1) SizedBox(width: 8),
        _mainButton(),
        if (_allEpisodes.length > 1) SizedBox(width: 8),
        if (_allEpisodes.length > 1)
          _episodeButton(
            isEnabled: _hasNextEpisode,
            onTap: () => _navigateToEpisode(1),
            icon: Icons.skip_next_rounded,
            label: context.l10n.next,
            isNext: true,
          ),
      ],
    );
  }

  Widget _buildShareModal(BuildContext context, String shareText) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Limit max height
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.all(20),
      child: SingleChildScrollView(
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
            SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.share_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Share Episode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Consumer<Auth>(
              builder: (ctx, auth, _) => FutureBuilder(
                future: auth.fetchConversations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListSkeleton(itemCount: 2);
                  }
                  final conversations = auth.conversations;
                  return Container(
                    height: 160, // Reduced from 200 to prevent overflow
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: conversations.length,
                      itemBuilder: (ctx, index) {
                        final conversation = conversations[index];
                        final userImage = conversation['user_image'] ?? '';
                        final name = conversation['name'] ?? '';
                        final username = conversation['username'];

                        return GestureDetector(
                          onTap: () {
                            final authProvider =
                                Provider.of<Auth>(context, listen: false);
                            authProvider
                                .sendMessages(
                              conversation['conversation_id'],
                              shareText,
                              'text',
                              null,
                              null,
                            )
                                .then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Shared Successfully!')),
                              );
                              Navigator.pop(context);
                            }).catchError((error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Failed to share. Please try again.')),
                              );
                            });
                          },
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: userImage.isNotEmpty
                                    ? CachedNetworkImageProvider(userImage)
                                    : null,
                                child: userImage.isEmpty
                                    ? Text(name.isEmpty ? username[0] : name[0])
                                    : null,
                              ),
                              SizedBox(height: 4),
                              Text(
                                name.isEmpty ? username : name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.share,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              title: Text('Share to Other Apps'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: shareText,
                    subject: "Join Skill Sikka and earn points!",
                    sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
                  ),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.qr_code,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              title: Text('Share using QR'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => ShareWithQrModal(
                    data: shareText,
                    subject: "Join Skill Sikka and earn points!",
                  ),
                );
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
