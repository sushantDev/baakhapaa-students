import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/screens/gift/gift_screen.dart';
import 'package:baakhapaa/screens/story/story_screen.dart';
import 'package:baakhapaa/screens/story/video_screen.dart';
import 'package:baakhapaa/screens/story/readable_episode_screen.dart';
import 'package:baakhapaa/widgets/tutorial_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/game_mode.dart';
import '../../providers/story.dart';
import '../../providers/auth.dart';
import './episode_screen.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ad_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/analytics_service.dart';
import '../../screens/subscription/subscription_screen.dart';
import '../../screens/story/reading_streak_screen.dart';

class WinScreen extends StatefulWidget {
  static const routeName = '/win-screen';

  const WinScreen({Key? key}) : super(key: key);

  @override
  State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen>
    with PuppetInteractionMixin, TickerProviderStateMixin {
  var _isInit = false;
  bool _isLoading = true;
  late Map<String, dynamic> episode = {};
  late List<dynamic> season = [];

  // Multi-step flow: loading → premiumUpsell → streak → widgetPrompt → win
  String _flowStep =
      'loading'; // loading, premiumUpsell, streak, widgetPrompt, win
  bool _isPremium = false;

  // Animations for win step
  AnimationController? _tickAnimController;
  AnimationController? _progressAnimController;
  AnimationController? _progressGlowController;
  Animation<double>? _tickScale;
  Animation<double>? _tickOpacity;
  Animation<double>? _progressAnim;
  Animation<double>? _progressGlow;

  // Streak step animations
  AnimationController? _streakCountController;
  AnimationController? _streakBarController;
  AnimationController? _streakRevealController;
  Animation<double>? _streakCountAnim;
  Animation<double>? _streakBarAnim;
  bool _streakContinueVisible = false;

  // Streak data (populated from recordChapterComplete or API)
  int _streakDays = 0;
  int _streakReward = 0;
  bool _bookCompleted = false;
  bool _hasStreakData = false;

  // Widget prompt shown count (show up to N times)
  static const int _maxWidgetPromptShows = 5;
  bool _widgetPromptCompleted = false;

  // iOS widget tutorial video
  VideoPlayerController? _tutorialVideoController;

  // Audio player for haptic-complementary sounds
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Double-points rewarded ad
  RewardedAd? _rewardedAd;
  bool _rewardedAdLoaded = false;
  bool _doublePointsClaimed = false;

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdService.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          if (mounted) setState(() => _rewardedAdLoaded = true);
        },
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
          if (mounted) setState(() => _rewardedAdLoaded = false);
        },
      ),
    );
  }

  Future<void> _showDoublePointsAd(int pointsEarned) async {
    if (_doublePointsClaimed) return;
    if (_rewardedAd == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ad is loading, please try again in a moment'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ));
      }
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        if (mounted) setState(() => _rewardedAdLoaded = false);
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _rewardedAd = null;
        if (mounted) setState(() => _rewardedAdLoaded = false);
        _loadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
        final auth = Provider.of<Auth>(context, listen: false);
        // Credit double the episode points
        await auth.coinTransaction(
          pointsEarned,
          'credited',
          'Double points reward from watching ad on win screen.',
        );
        await auth.getUser();
        if (mounted) {
          setState(() => _doublePointsClaimed = true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '🎉 +$pointsEarned bonus points! You doubled your reward!'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ));
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      try {
        int userId = Provider.of<Auth>(context, listen: false).userId;
        int fallBackPoints =
            Provider.of<Auth>(context, listen: false).fallBackPoints;
        var story = Provider.of<Story>(context, listen: false);
        episode = story.episode;

        _isPremium = AdService.isUserPremium(context);
        // Pre-load rewarded ad for double-points button (non-premium only)
        if (!_isPremium) _loadRewardedAd();

        // Load widget prompt preference (counter-based: show up to N times)
        final prefsFuture = SharedPreferences.getInstance().then((prefs) {
          final showCount = prefs.getInt('widget_prompt_show_count') ?? 0;
          _widgetPromptCompleted = showCount >= _maxWidgetPromptShows;
        });

        int episodeId;
        String episodeTitle;
        int episodeCoins;
        int episodeCoinsUsers;

        try {
          var idValue = episode['id'];
          episodeId = idValue is int ? idValue : int.parse(idValue.toString());
        } catch (e) {
          episodeId = 0;
        }

        try {
          episodeTitle = episode['title']?.toString() ?? 'Unknown Episode';
        } catch (e) {
          episodeTitle = 'Unknown Episode';
        }

        try {
          var coinsValue = episode['coins'];
          episodeCoins =
              coinsValue is int ? coinsValue : int.parse(coinsValue.toString());
        } catch (e) {
          episodeCoins = 0;
        }

        try {
          var coinsUsersValue = episode['coins_users'];
          if (coinsUsersValue is String) {
            episodeCoinsUsers = int.parse(coinsUsersValue);
          } else if (coinsUsersValue is int) {
            episodeCoinsUsers = coinsUsersValue;
          } else {
            episodeCoinsUsers = 0;
          }
        } catch (e) {
          episodeCoinsUsers = 0;
        }

        // Fetch streak data and episode watched in parallel
        final streakFuture = _fetchStreakData(story, episodeId);

        // Only award coins if episode hasn't been watched/completed before
        final alreadyWatched = episode['watched'] == true;
        final coinFuture = alreadyWatched
            ? Future.value()
            : story.episodeWatched(
                userId,
                episodeId,
                episodeTitle,
                episodeCoins,
                episodeCoinsUsers,
                fallBackPoints,
              );

        if (alreadyWatched) {
          DebugLogger.auth(
              'WinScreen: Episode already watched, skipping coin reward');
        }

        coinFuture.then((_) async {
          // Defer synchronous state update to avoid notifyListeners during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              story.updateEpisodeWatchedStatusLocally(episodeId);
            }
          });
          // Refresh continue watching list
          story.fetchContinueWatching();
          // Wait for streak data and prefs before starting flow
          await streakFuture;
          await prefsFuture;
          if (mounted) {
            _startFlow();
          }
        }).catchError((error) async {
          DebugLogger.auth('Error in episodeWatched: $error');
          await streakFuture;
          await prefsFuture;
          if (mounted) {
            _startFlow();
          }
        });

        final tutorialProvider =
            Provider.of<TutorialFlowProvider>(context, listen: false);
        if (tutorialProvider.currentStep == 9) {
          tutorialProvider.nextStep().then((_) {
            if (mounted) {
              tutorialProvider.showCurrentStepMessage(context);
            }
          });
        }
        _isInit = true;

        // Track quiz completed event for episode
        AnalyticsService.logQuizCompleted(
          quizType: 'episode',
          won: true,
        );
      } catch (e) {
        DebugLogger.auth('Error in didChangeDependencies: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _flowStep = 'win';
          });
        }
      }
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _tickAnimController?.dispose();
    _progressAnimController?.dispose();
    _progressGlowController?.dispose();
    _streakCountController?.dispose();
    _streakBarController?.dispose();
    _streakRevealController?.dispose();
    _tutorialVideoController?.dispose();
    _audioPlayer.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> _fetchStreakData(Story story, int episodeId) async {
    try {
      // Determine content type: use video-complete for video seasons, chapter-complete for readable
      final season = story.selectedSeason;
      final contentType = season['content_type'] ?? 'video';
      final isReadable = contentType == 'readable';

      DebugLogger.auth(
          'WinScreen: Recording streak for episodeId=$episodeId, contentType=$contentType, isReadable=$isReadable');

      if (episodeId <= 0) {
        DebugLogger.error(
            'WinScreen: Invalid episodeId=$episodeId, skipping streak recording');
        // Still try to fetch existing streak via GET
        await _fetchStreakFallback(story);
        return;
      }

      final result = isReadable
          ? await story.recordChapterComplete(episodeId)
          : await story.recordVideoComplete(episodeId);

      DebugLogger.auth('WinScreen: Streak POST result=$result');

      if (result.isNotEmpty && mounted) {
        _streakDays = result['current_streak'] ?? 0;
        _streakReward = result['reward'] ?? 0;
        _bookCompleted = result['book_completed'] ?? false;

        // Only show streak step once per day
        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final lastShown = prefs.getString('last_streak_shown_date') ?? '';
        if (lastShown != today) {
          _hasStreakData = true;
          // Note: last_streak_shown_date is set when user actually sees the streak step
          // (in _advanceToNextStep) to avoid marking as shown if user closes app early
        }

        DebugLogger.auth(
            'WinScreen: Streak data set: days=$_streakDays, reward=$_streakReward, bookCompleted=$_bookCompleted, shownToday=${lastShown == today}');

        // Update home screen widget with latest streak data
        HomeWidgetService.updateWidget(
          currentStreak: _streakDays,
          totalChapters: result['total_chapters_read'] ?? 0,
          totalBooks: result['total_books_completed'] ?? 0,
          lastBookTitle: episode['season_title'] ?? season['title'] ?? '',
        );
      } else if (mounted) {
        DebugLogger.auth('WinScreen: POST returned empty, falling back to GET');
        await _fetchStreakFallback(story);
      }
    } catch (e) {
      DebugLogger.error('WinScreen: Failed to fetch streak: $e');
      // Last resort: try GET fallback
      if (mounted) {
        await _fetchStreakFallback(story);
      }
    }
  }

  Future<void> _fetchStreakFallback(Story story) async {
    try {
      await story.fetchReadingStreak();
      final streak = story.readingStreak;
      DebugLogger.auth('WinScreen: GET fallback streak=$streak');
      if (streak.isNotEmpty) {
        _streakDays = streak['current_streak'] ?? 0;
        // Only show streak step if it hasn't been shown today
        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final lastShown = prefs.getString('last_streak_shown_date') ?? '';
        if (lastShown != today) {
          _hasStreakData = true;
        }
      }
    } catch (e) {
      DebugLogger.error('WinScreen: GET fallback also failed: $e');
    }
  }

  void _startFlow() {
    if (!_isPremium &&
        AdService().quizCompletionAdsEnabled &&
        AdService().isInterstitialReady) {
      AdService().showInterstitial(
        context: context,
        onAdDismissed: () {
          if (mounted) _advanceToNextStep('loading');
        },
      );
    } else {
      _advanceToNextStep('loading');
    }
  }

  void _advanceToNextStep(String currentStep) {
    if (!mounted) return;
    String nextStep;
    switch (currentStep) {
      case 'loading':
        // Premium upsell first (if not premium), then streak, then widget prompt
        nextStep = !_isPremium
            ? 'premiumUpsell'
            : (_hasStreakData
                ? 'streak'
                : (_widgetPromptCompleted ? 'win' : 'widgetPrompt'));
        break;
      case 'premiumUpsell':
        nextStep = _hasStreakData
            ? 'streak'
            : (_widgetPromptCompleted ? 'win' : 'widgetPrompt');
        break;
      case 'streak':
        nextStep = _widgetPromptCompleted ? 'win' : 'widgetPrompt';
        break;
      case 'widgetPrompt':
        nextStep = 'win';
        break;
      default:
        nextStep = 'win';
    }
    setState(() {
      _flowStep = nextStep;
      _isLoading = false;
    });
    if (nextStep == 'win') {
      _startWinAnimations();
    } else if (nextStep == 'streak') {
      // Mark streak as shown today so it won't show again
      SharedPreferences.getInstance().then((prefs) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        prefs.setString('last_streak_shown_date', today);
      });
      _startStreakAnimations();
    }
  }

  void _startWinAnimations() {
    // Tick animation: scale from 0 → 1.15 → 1.0 with bounce
    _tickAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _tickScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _tickAnimController!,
      curve: Curves.easeOut,
    ));
    _tickOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _tickAnimController!,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Progress bar animation: fills up over 1.5s with 2-second delay
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressAnimController!,
      curve: Curves.easeInOut,
    );

    // Pulsing glow for progress bar (red-amber mix)
    _progressGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _progressGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressGlowController!,
        curve: Curves.easeInOut,
      ),
    );

    // Start tick immediately, then progress bar after 2-second delay
    _tickAnimController!.forward();

    // Haptic: satisfying pop when tick check mark appears
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      // Bounce-back micro-tap
      if (mounted) HapticFeedback.selectionClick();
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _progressAnimController!.forward();
        // Haptic: progress bar starts filling
        HapticFeedback.lightImpact();
        // Haptic at ~50% of bar (750ms into 1500ms)
        Future.delayed(const Duration(milliseconds: 750), () {
          if (mounted) HapticFeedback.selectionClick();
        });
        // Stop glow pulsing when progress animation completes
        _progressAnimController!.addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            _progressGlowController?.stop();
            _progressGlowController?.value = 0.0;
            // Haptic + sound: progress bar fully filled
            HapticFeedback.mediumImpact();
            Future.delayed(const Duration(milliseconds: 80), () {
              if (mounted) {
                _audioPlayer.play(AssetSource('sounds/correct.wav'));
              }
            });
          }
        });
      }
    });
  }

  void goToEpisode(BuildContext context) {
    var _navArgs;
    _navArgs = ModalRoute.of(context)!.settings.arguments;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Update episode watched status in the Story provider
    _updateEpisodeWatchedStatus();

    if (_navArgs != 'deep_link') {
      Navigator.pushReplacementNamed(context, EpisodeScreen.routeName);
    } else {
      Navigator.of(context)
        ..pop()
        ..pop();
    }
  }

  void _goToNextEpisode(BuildContext context) {
    try {
      final story = Provider.of<Story>(context, listen: false);
      final episodes = story.selectedSeason['episodes'] as List<dynamic>? ?? [];
      final currentEpisodeId = episode['id'] as int;

      // Update current episode watched status first
      _updateEpisodeWatchedStatus();

      // Find current episode index
      int currentIndex =
          episodes.indexWhere((ep) => ep['id'] == currentEpisodeId);

      if (currentIndex != -1 && currentIndex < episodes.length - 1) {
        // Navigate to next episode — use ReadableEpisodeScreen for readable content
        final nextEpisode = episodes[currentIndex + 1];
        final season = story.selectedSeason;
        final isReadable = (season['content_type'] ?? 'video') == 'readable';
        Navigator.of(context).pushNamedAndRemoveUntil(
          isReadable ? ReadableEpisodeScreen.routeName : VideoScreen.routeName,
          (route) =>
              route.settings.name == EpisodeScreen.routeName || route.isFirst,
          arguments: nextEpisode,
        );
      } else {
        // No more episodes, go to episodes list
        goToEpisode(context);
      }
    } catch (e) {
      // Fallback to episodes list
      goToEpisode(context);
    }
  }

  /// Updates the watched status of the current episode in the Story provider
  /// This ensures the episode shows as watched in the episode screen even before API refresh
  void _updateEpisodeWatchedStatus() {
    try {
      final story = Provider.of<Story>(context, listen: false);
      final currentEpisodeId = episode['id'] as int;

      // Use the provider method to update episode status and notify listeners
      story.updateEpisodeWatchedStatusLocally(currentEpisodeId);
    } catch (e) {
      DebugLogger.error(
          '❌ WinScreen: Failed to update episode watched status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    final story = Provider.of<Story>(context, listen: false);
    // Determine actual earned points: if coins_users == 0, user gets fallback points
    final int episodeCoins = (episode['coins'] ?? 0) is int
        ? (episode['coins'] ?? 0) as int
        : int.tryParse(episode['coins'].toString()) ?? 0;
    final int episodeCoinsUsers = (episode['coins_users'] ?? 0) is int
        ? (episode['coins_users'] ?? 0) as int
        : int.tryParse(episode['coins_users'].toString()) ?? 0;
    final int fallBackPts = auth.fallBackPoints > 0 ? auth.fallBackPoints : 1;
    final bool isFallbackEarning = episodeCoinsUsers == 0;
    final int pointsEarned = isFallbackEarning ? fallBackPts : episodeCoins;
    final username = auth.userName.isEmpty ? 'Player' : auth.userName;
    final gameMode = story.selectedGameMode;

    if (_isLoading || _flowStep == 'loading') {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
      );
    }

    // Step 2: Full-screen premium upsell
    if (_flowStep == 'premiumUpsell') {
      return _buildPremiumUpsellStep();
    }

    // Step 3: Streak celebration
    if (_flowStep == 'streak') {
      return _buildStreakStep();
    }

    // Step 4: Widget prompt (both Android & iOS, after streak)
    if (_flowStep == 'widgetPrompt') {
      return _buildWidgetPromptStep();
    }

    // Step 5: Win content
    return _buildWinStep(pointsEarned, isFallbackEarning, username, gameMode);
  }

  Widget _buildPremiumUpsellStep() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF1B2D4F),
              Color(0xFF2A3F6F),
              Color(0xFF1B2D4F),
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button top-right
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => _advanceToNextStep('premiumUpsell'),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Premium badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.workspace_premium_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'PREMIUM',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Crown icon with glow
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.amber.withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                            radius: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFFFD700),
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 24),

                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Color(0xFFE0E0FF)],
                        ).createShader(bounds),
                        child: Text(
                          'Bye, Ads',
                          style: GoogleFonts.poppins(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.inter(
                              fontSize: 16, color: Colors.white70),
                          children: [
                            const TextSpan(text: 'Enjoy '),
                            TextSpan(
                              text: 'uninterrupted learning',
                              style: TextStyle(
                                color: const Color(0xFF4ADE80),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: '\nwith premium features!'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Benefits
                      _buildBenefitRow(Icons.block, 'No more ads'),
                      const SizedBox(height: 14),
                      _buildBenefitRowWidget(
                          Image.asset('assets/images/coins.png',
                              width: 22, height: 22),
                          'Bonus points daily'),
                      const SizedBox(height: 14),
                      _buildBenefitRow(
                          Icons.lock_open_rounded, 'Exclusive content access'),
                      const SizedBox(height: 14),
                      _buildBenefitRow(Icons.speed_rounded, 'Priority support'),

                      const SizedBox(height: 32),

                      // Limited-time pricing
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timer_outlined,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Only ',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              'Rs 90',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber,
                              ),
                            ),
                            Text(
                              ' for limited time!',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // CTA button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context)
                                .pushNamed(SubscriptionScreen.routeName)
                                .then((_) {
                              if (mounted) _advanceToNextStep('premiumUpsell');
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF4A6CF7),
                                  Color(0xFF6366F1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4A6CF7)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'GET PREMIUM — Rs 90',
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => _advanceToNextStep('premiumUpsell'),
                        child: Text(
                          'NO THANKS',
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4ADE80), size: 22),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitRowWidget(Widget iconWidget, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: iconWidget),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Returns the fraction [0.0, 1.0] of progress within the current 7-day cycle.
  double _cycleFraction(int days) {
    const int n = 7;
    if (days <= 0) return 0.0;
    final mod = days % n;
    return (mod == 0 ? n : mod) / n.toDouble();
  }

  void _startStreakAnimations() {
    final prevDays = (_streakDays - 1).clamp(0, _streakDays);

    // Count-up animation: previous streak → current streak
    _streakCountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _streakCountAnim = Tween<double>(
      begin: prevDays.toDouble(),
      end: _streakDays.toDouble(),
    ).animate(CurvedAnimation(
      parent: _streakCountController!,
      curve: Curves.easeOutCubic,
    ));

    // Progress bar animation: within current 7-day cycle
    _streakBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _streakBarAnim = Tween<double>(
      begin: _cycleFraction(prevDays),
      end: _cycleFraction(_streakDays),
    ).animate(CurvedAnimation(
      parent: _streakBarController!,
      curve: Curves.easeInOut,
    ));

    // Reveal controller for staggered timing
    _streakRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _streakContinueVisible = false;

    // Staggered sequence: flame visible from start → count animates at 400ms → bar at 800ms → continue at 2000ms
    _streakRevealController!.forward();

    // Haptic: subtle arrival tap when flame appears
    HapticFeedback.lightImpact();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _streakCountController!.forward();
        // Haptic: count-up starts — ticking feel every ~140ms
        HapticFeedback.selectionClick();
      }
    });

    // Tick haptics during count-up (simulates counter clicking)
    for (int i = 1; i <= 6; i++) {
      Future.delayed(Duration(milliseconds: 400 + i * 140), () {
        if (mounted) HapticFeedback.selectionClick();
      });
    }

    Future.delayed(const Duration(milliseconds: 1450), () {
      // Count-up complete — satisfying medium impact
      if (mounted) HapticFeedback.mediumImpact();
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _streakBarController!.forward();
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() => _streakContinueVisible = true);
        // Haptic + sound: "you earned it" moment when continue appears
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 80), () {
          if (mounted) {
            _audioPlayer.play(AssetSource('sounds/correct.wav'));
          }
        });
      }
    });
  }

  Widget _buildStreakStep() {
    const int streakGoal = 7;
    // Compute position within the current 7-day cycle
    final int cyclePos = _streakDays > 0
        ? (_streakDays % streakGoal == 0
            ? streakGoal
            : _streakDays % streakGoal)
        : 0;
    final int cycleNumber =
        _streakDays > 0 ? ((_streakDays - 1) ~/ streakGoal) + 1 : 1;
    final bool cycleComplete = cyclePos >= streakGoal;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: GestureDetector(
          onTap: _streakContinueVisible
              ? () => _advanceToNextStep('streak')
              : null,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated flame
                  AnimatedFlame(size: 90, isActive: _streakDays > 0),
                  const SizedBox(height: 20),

                  // Animated streak count
                  AnimatedBuilder(
                    animation:
                        _streakCountController ?? kAlwaysCompleteAnimation,
                    builder: (context, child) {
                      final value =
                          _streakCountAnim?.value ?? _streakDays.toDouble();
                      return Text(
                        '${value.round()}',
                        style: GoogleFonts.poppins(
                          fontSize: 80,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber,
                          height: 1.0,
                          letterSpacing: -3,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withValues(alpha: 0.2),
                          Colors.orange.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'DAY STREAK',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  // Week indicator for streaks beyond the first 7 days
                  if (cycleNumber > 1) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Week $cycleNumber',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.withValues(alpha: 0.7),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 7-day progress bar with day markers
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation:
                              _streakBarController ?? kAlwaysCompleteAnimation,
                          builder: (context, child) {
                            final barValue = _streakBarAnim?.value ??
                                _cycleFraction(_streakDays);
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: barValue.clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  cycleComplete
                                      ? const Color(0xFF22C55E)
                                      : Colors.amber,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(streakGoal, (i) {
                            // Show absolute day numbers for the current cycle
                            // Week 1 → 1-7, Week 2 → 8-14, Week 3 → 15-21, etc.
                            final absoluteDayNum =
                                (cycleNumber - 1) * streakGoal + i + 1;
                            final isCompleted = (i + 1) <= cyclePos;
                            return Text(
                              '$absoluteDayNum',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: isCompleted
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color:
                                    isCompleted ? Colors.amber : Colors.white24,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // "Keep up your streak!" message
                  Text(
                    cycleComplete
                        ? '🔥 Week $cycleNumber complete!'
                        : 'Keep up your streak!',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (_streakReward > 0) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2D2200),
                            const Color(0xFF1A1400),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.1),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/images/coins.png',
                              width: 28, height: 28),
                          const SizedBox(width: 12),
                          Text(
                            '+$_streakReward coins!',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_bookCompleted) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2618),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.greenAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📚', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Text(
                            'Book Completed!',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 36),

                  // Continue button — appears after animations complete
                  AnimatedOpacity(
                    opacity: _streakContinueVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: AnimatedSlide(
                      offset: _streakContinueVisible
                          ? Offset.zero
                          : const Offset(0, 0.3),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _streakContinueVisible
                              ? () => _advanceToNextStep('streak')
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Continue',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_streakContinueVisible) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Tap anywhere to continue',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white24,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetPromptStep() {
    final isAndroid = Platform.isAndroid;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Title
              Text(
                '📱 Track Your Streak',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isAndroid
                    ? 'Add a widget to your home screen and never miss a day!'
                    : 'Add a widget to stay motivated every day!',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white54,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              if (isAndroid) ...[
                // Android: Mini widget preview card
                Container(
                  width: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101010),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.08),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 26)),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_streakDays',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'day streak',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('📄 0',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.white38)),
                          const SizedBox(width: 16),
                          Text('📚 0',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.white38)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Start your streak!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Widget Preview',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white24,
                  ),
                ),
              ] else ...[
                // iOS: Compact tutorial video (constrained height)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _buildTutorialVideo(),
                  ),
                ),
                const SizedBox(height: 16),
                // Compact steps
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildMiniStep('1', 'Long press'),
                      _buildMiniStep('2', 'Tap +'),
                      _buildMiniStep('3', 'Search app'),
                      _buildMiniStep('4', 'Add'),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 1),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (isAndroid) {
                      HomeWidgetService.requestPinWidget();
                    }
                    // Increment counter (same as skip) so prompt shows up to N times total
                    final prefs = await SharedPreferences.getInstance();
                    final count = prefs.getInt('widget_prompt_show_count') ?? 0;
                    await prefs.setInt('widget_prompt_show_count', count + 1);
                    _advanceToNextStep('widgetPrompt');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isAndroid ? Icons.add_rounded : Icons.check_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isAndroid ? 'Add Widget' : 'Got it!',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  // Increment show counter so it eventually stops showing
                  final prefs = await SharedPreferences.getInstance();
                  final count = prefs.getInt('widget_prompt_show_count') ?? 0;
                  await prefs.setInt('widget_prompt_show_count', count + 1);
                  _advanceToNextStep('widgetPrompt');
                },
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.inter(
                    color: Colors.white30,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStep(String num, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                num,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialVideo() {
    if (_tutorialVideoController == null) {
      _tutorialVideoController = VideoPlayerController.networkUrl(
        Uri.parse(
            'https://bkp-v1.blr1.cdn.digitaloceanspaces.com/AddWidgetTutorialiOS.mov'),
      )..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _tutorialVideoController!.setLooping(true);
            _tutorialVideoController!.play();
          }
        });
    }

    final controller = _tutorialVideoController!;
    if (!controller.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          color: Colors.white.withValues(alpha: 0.05),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildWinStep(dynamic pointsEarned, bool isFallbackEarning,
      String username, GameMode? gameMode) {
    final story = Provider.of<Story>(context, listen: false);
    final seasonData = story.selectedSeason;
    final episodes = seasonData['episodes'] as List<dynamic>? ?? [];
    final seasonTitle = seasonData['title']?.toString() ?? '';
    final episodeTitle = episode['title']?.toString() ?? 'This Chapter';

    // Calculate episode progression
    int currentIndex = -1;
    try {
      final currentId = episode['id'];
      currentIndex = episodes.indexWhere((ep) => ep['id'] == currentId);
    } catch (_) {}
    final totalEpisodes = episodes.length;
    final completedEpisode = currentIndex >= 0 ? currentIndex + 1 : 1;
    final progress = totalEpisodes > 0 ? completedEpisode / totalEpisodes : 0.0;
    final isSeasonComplete = completedEpisode >= totalEpisodes;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Column(
                    children: [
                      // Animated completion badge (tick)
                      AnimatedBuilder(
                        animation:
                            _tickAnimController ?? kAlwaysCompleteAnimation,
                        builder: (context, child) {
                          final scale = _tickScale?.value ?? 1.0;
                          final opacity = _tickOpacity?.value ?? 1.0;
                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF22C55E),
                                      Color(0xFF16A34A)
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF22C55E)
                                          .withValues(alpha: 0.3 * opacity),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.check_rounded,
                                    color: Colors.white, size: 40),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 16),

                      // "Chapter Complete!" title
                      Text(
                        isSeasonComplete
                            ? 'SEASON COMPLETE!'
                            : 'CHAPTER COMPLETE!',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        episodeTitle,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (gameMode != null) ...[
                        SizedBox(height: 20),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            gameMode == GameMode.crossword
                                ? '✏️ Crossword Completed!'
                                : gameMode == GameMode.imagePuzzle
                                    ? '🧩 Puzzle Solved!'
                                    : '✅ Quiz Completed!',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      // Puppet expression GIF
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(
                          imageUrl:
                              'https://bkp-v1.blr1.cdn.digitaloceanspaces.com/puppet/puppet_expression_win_screen.gif',
                          height: 200,
                          fit: BoxFit.contain,
                          // CachedNetworkImage uses errorWidget instead of errorBuilder
                          errorWidget: (context, url, error) =>
                              const SizedBox.shrink(),
                        ),
                      ),

                      // Season progress section
                      if (totalEpisodes > 0) ...[
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      seasonTitle.isNotEmpty
                                          ? seasonTitle
                                          : 'Season Progress',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.white54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '$completedEpisode / $totalEpisodes',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final barWidth = constraints.maxWidth;
                                  const barHeight = 14.0;
                                  const avatarSize = 32.0;
                                  final auth =
                                      Provider.of<Auth>(context, listen: false);
                                  String userImage = '';
                                  if (auth.image != null &&
                                      auth.image!.isNotEmpty) {
                                    userImage =
                                        auth.image!.first['thumbnail'] ?? '';
                                  }

                                  return AnimatedBuilder(
                                    animation: Listenable.merge([
                                      _progressAnimController ??
                                          kAlwaysCompleteAnimation,
                                      _progressGlowController ??
                                          kAlwaysCompleteAnimation,
                                    ]),
                                    builder: (context, child) {
                                      final prevProgress = totalEpisodes > 0
                                          ? ((completedEpisode - 1)
                                                  .clamp(0, totalEpisodes)) /
                                              totalEpisodes
                                          : 0.0;
                                      final animValue =
                                          _progressAnim?.value ?? 1.0;
                                      final animatedProgress = prevProgress +
                                          (progress - prevProgress) * animValue;
                                      final glowValue =
                                          _progressGlow?.value ?? 0.0;
                                      final isAnimating =
                                          _progressAnimController
                                                  ?.isAnimating ??
                                              false;

                                      // Animated color: amber → red-amber mix during animation
                                      final barColor = isAnimating
                                          ? Color.lerp(
                                              Colors.amber,
                                              Color(0xFFFF4500),
                                              glowValue * 0.6,
                                            )!
                                          : (isSeasonComplete
                                              ? Color(0xFF22C55E)
                                              : Colors.amber);

                                      final filledWidth =
                                          animatedProgress * barWidth;
                                      final avatarLeft = (filledWidth -
                                              avatarSize / 2)
                                          .clamp(0.0, barWidth - avatarSize);

                                      return SizedBox(
                                        height: avatarSize + 4,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // Bar background
                                            Positioned(
                                              top: (avatarSize - barHeight) / 2,
                                              left: 0,
                                              right: 0,
                                              child: Container(
                                                height: barHeight,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(7),
                                                  color: Colors.white
                                                      .withValues(alpha: 0.08),
                                                ),
                                              ),
                                            ),
                                            // Filled bar with glow
                                            Positioned(
                                              top: (avatarSize - barHeight) / 2,
                                              left: 0,
                                              child: Container(
                                                height: barHeight,
                                                width: filledWidth.clamp(
                                                    0.0, barWidth),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(7),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      barColor.withValues(
                                                          alpha: 0.8),
                                                      barColor,
                                                    ],
                                                  ),
                                                  boxShadow: isAnimating
                                                      ? [
                                                          BoxShadow(
                                                            color: Color.lerp(
                                                              Colors.amber,
                                                              Color(0xFFFF2D00),
                                                              glowValue,
                                                            )!
                                                                .withValues(
                                                                    alpha: 0.5 +
                                                                        glowValue *
                                                                            0.3),
                                                            blurRadius: 10 +
                                                                glowValue * 8,
                                                            spreadRadius:
                                                                glowValue * 2,
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            // User avatar at the progress tip
                                            Positioned(
                                              top: 0,
                                              left: avatarLeft,
                                              child: Container(
                                                width: avatarSize,
                                                height: avatarSize,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: barColor,
                                                    width: 2.5,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color:
                                                          barColor.withValues(
                                                              alpha: 0.5),
                                                      blurRadius: isAnimating
                                                          ? 8 + glowValue * 6
                                                          : 4,
                                                      spreadRadius: isAnimating
                                                          ? glowValue * 2
                                                          : 0,
                                                    ),
                                                  ],
                                                ),
                                                child: ClipOval(
                                                  child: userImage.isNotEmpty
                                                      ? Image.network(
                                                          userImage,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (_, __, ___) =>
                                                                  Container(
                                                            color: Colors
                                                                .grey.shade800,
                                                            child: Icon(
                                                              Icons.person,
                                                              color: Colors
                                                                  .white54,
                                                              size: 18,
                                                            ),
                                                          ),
                                                        )
                                                      : Container(
                                                          color: Colors
                                                              .grey.shade800,
                                                          child: Icon(
                                                            Icons.person,
                                                            color:
                                                                Colors.white54,
                                                            size: 18,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              SizedBox(height: 8),
                              Text(
                                isSeasonComplete
                                    ? '🎉 You finished the entire season!'
                                    : '${(progress * 100).toInt()}% complete',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isSeasonComplete
                                      ? Color(0xFF22C55E)
                                      : Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 18),
                      ],

                      // "1% Smarter" section
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Color(0xFF60A5FA),
                            Color(0xFF34D399),
                            Color(0xFFFBBF24),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'You\'re 1% smarter now',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 6),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '"Improve 1% every day — small, consistent improvements compound into massive results."',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white38,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: 18),

                      // Points earned (compact)
                      Column(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF2D2200),
                                  Color(0xFF1A1400),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/images/coins.png',
                                    width: 28, height: 28),
                                SizedBox(width: 12),
                                Text(
                                  '+$pointsEarned',
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.amber,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'points',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.amber.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isFallbackEarning) ...[
                            SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 12, color: Colors.white38),
                                SizedBox(width: 4),
                                Text(
                                  'Fallback points (creator pool used)',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      SizedBox(height: 16),

                      // Double points rewarded ad button (non-premium, not yet claimed)
                      if (!_isPremium && !_doublePointsClaimed)
                        GestureDetector(
                          onTap: () => _showDoublePointsAd(pointsEarned),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1A2A00), Color(0xFF0D1F0A)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      Color(0xFF22C55E).withValues(alpha: 0.4),
                                  width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.play_circle_filled_rounded,
                                    color: Color(0xFF22C55E), size: 22),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Watch ad to double your points',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF22C55E),
                                        ),
                                      ),
                                      Text(
                                        '+$pointsEarned bonus points',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Color(0xFF22C55E)
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_rewardedAdLoaded)
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF22C55E)),
                                  )
                                else
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      color: Color(0xFF22C55E), size: 14),
                              ],
                            ),
                          ),
                        ),

                      if (!_isPremium && _doublePointsClaimed)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: Colors.white12, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF22C55E), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Bonus points claimed! 🎉',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Banner ad slot (non-premium users only)
              if (!_isPremium) const BaakhaBannerAd(),

              // Bottom buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    // Home button
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 56,
                        margin: EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            _updateEpisodeWatchedStatus();
                            Navigator.pushReplacement(
                              context,
                              PageTransition(
                                child: StoryScreen(),
                                type: PageTransitionType.fade,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home_rounded,
                                  color: Colors.white, size: 28),
                              SizedBox(height: 4),
                              Text(
                                'Home',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Claim Now button
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 56,
                        margin: EdgeInsets.symmetric(horizontal: 6),
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '$pointsEarned Baakhapaa points claimed!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            _goToNextEpisode(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade400,
                                  Colors.orange.shade500
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/coins.png',
                                    width: 25,
                                    height: 25,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Next Chapter\n+$pointsEarned pts',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Gift button
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 56,
                        margin: EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade700.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Consumer<TutorialFlowProvider>(
                          builder: (context, tutorial, _) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ElevatedButton(
                                key: tutorial.getTutorialKey('gift_button_key'),
                                onPressed: () {
                                  _updateEpisodeWatchedStatus();
                                  Navigator.pushReplacement(
                                    context,
                                    PageTransition(
                                      child: GiftScreen(),
                                      type: PageTransitionType.fade,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.card_giftcard_rounded,
                                        color: Colors.white, size: 28),
                                    SizedBox(height: 4),
                                    Text(
                                      'Gift',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (tutorial.currentStep == 10 &&
                                  tutorial.isActive)
                                Positioned(
                                  top: -5,
                                  right: 10,
                                  child: TutorialIndicator(),
                                ),
                            ],
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
      ),
    );
  }
}
