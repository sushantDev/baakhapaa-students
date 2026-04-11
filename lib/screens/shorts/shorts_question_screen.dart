import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/providers/shorts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:baakhapaa/services/ad_service.dart';
import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/providers/video_state_provider.dart';
import 'package:baakhapaa/providers/language_provider.dart';
import 'package:baakhapaa/screens/shorts/create/create_shorts_question_screen.dart';
import 'package:baakhapaa/screens/shorts/guest_win_screen.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../../providers/auth.dart';
import './shorts_loose_screen.dart';
import './shorts_win_screen.dart';
import '../../widgets/loading.dart';
import '../../utils/debug_logger.dart';

// ignore_for_file: unnecessary_null_comparison

class ShortsQuestionScreen extends StatefulWidget {
  static const routeName = '/shorts-question-screen';

  const ShortsQuestionScreen({Key? key}) : super(key: key);

  @override
  State<ShortsQuestionScreen> createState() => _ShortsQuestionScreenState();
}

class _ShortsQuestionScreenState extends State<ShortsQuestionScreen>
    with TickerProviderStateMixin {
  var shortsProvider;
  var tutorialProvider;
  late Map<String, dynamic> shorts = {};
  late int shortsId;
  late List questions;
  late String title;
  Map<String, dynamic>? activeQuestion = null;
  int activeQuestionKey = 0;
  var _isInit = false;
  late Timer countdownTimer;
  late Duration myDuration = Duration(seconds: 1);
  late int lives;
  late int coins;
  late int coins_users;
  bool _timerComplete = false;
  bool _isLoading = true;
  int _userId = 0;

  // Guest guidance variables
  bool _showGuestHint = false;
  Timer? _hintTimer;
  String? _correctAnswerId;
  bool _isUserLoggedIn() {
    final authProvider = Provider.of<Auth>(context, listen: false);
    return authProvider.isAuth;
  }

  final GlobalKey _quizKey =
      GlobalKey(debugLabel: 'quiz_answers'); // Add this key

  // Animation controllers for hearts
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _isHeartHurt = false;

  late AnimationController _coinAnimationController;
  late AnimationController _coinFlyController;
  late AnimationController _coinShowerController;
  late Animation<double> _coinBounceAnimation;
  late Animation<int> _coinCountAnimation;
  late Animation<double> _coinShowerAnimation;

  // Add answer feedback animation controllers
  late AnimationController _answerFeedbackController;
  late Animation<double> _answerScaleAnimation;
  late Animation<double> _answerShakeAnimation;
  String? _selectedAnswerId;
  bool _showingFeedback = false;
  bool _isCorrectAnswer = false;

  bool _showCoinAnimation = false;
  int _displayedCoins = 0;
  List<Offset> _coinPositions = [];

  // Audio player for sound effects
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Hint system
  static const int kShortsQuizHintCost = 5;
  bool _hintUsedForCurrentQuestion = false;
  String? _hintedAnswerId;
  RewardedAd? _hintRewardedAd;
  bool _isHintAdLoading = false;

  // Language toggle for Nepali support
  bool _useNepali = false;

  Future<void> secureScreen() async {
    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.preventScreenshotOn();
  }

  @override
  void initState() {
    super.initState();

    // Initialize language toggle based on user's system language
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final languageProvider = context.read<LanguageProvider>();
      setState(() {
        _useNepali = languageProvider.currentLocale.languageCode == 'ne';
      });
    });

    // Initialize animation controllers
    _heartAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _heartScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _heartAnimationController,
      curve: Curves.elasticOut,
    ));

    _blinkController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    _blinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_blinkController);

    // Initialize coin animation controllers
    _coinAnimationController = AnimationController(
      duration: Duration(milliseconds: 3000),
      vsync: this,
    );

    _coinFlyController = AnimationController(
      duration: Duration(milliseconds: 2500),
      vsync: this,
    );

    _coinShowerController = AnimationController(
      duration: Duration(milliseconds: 3500),
      vsync: this,
    );

    _coinBounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _coinAnimationController,
      curve: Curves.elasticOut,
    ));

    _coinShowerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _coinShowerController,
      curve: Curves.easeInOut,
    ));

    // Initialize answer feedback animation controller
    _answerFeedbackController = AnimationController(
      duration:
          Duration(milliseconds: 600), // Further reduced for quicker feedback
      vsync: this,
    );

    _answerScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _answerFeedbackController,
      curve: Curves.elasticOut,
    ));

    _answerShakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _answerFeedbackController,
      curve: Curves.easeInOut,
    ));

    secureScreen();

    // Initialize video state for quiz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final videoStateProvider =
            Provider.of<VideoStateProvider>(context, listen: false);
        // Enter quiz mode - this will stop all video playback
        videoStateProvider.enterQuiz();
        // Also force stop all videos as additional safety
        videoStateProvider.forceStopAllVideos();
      }
    });

    // Initialize tutorial provider immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        tutorialProvider =
            Provider.of<TutorialFlowProvider>(context, listen: false);
        if (tutorialProvider.currentStep == 1) {
          tutorialProvider.nextStep().then((_) {
            if (mounted) {
              tutorialProvider.showCurrentStepMessage(context);
            }
          });
        }
      }
    });

    _loadHintAd();
  }

  @override
  void didChangeDependencies() {
    DebugLogger.info('🧠 ShortsQuestionScreen: didChangeDependencies called');
    if (!_isInit) {
      DebugLogger.info('🎯 ShortsQuestionScreen: Initializing quiz screen...');
      final arguments =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

      lives = arguments['lives'];
      shortsId = arguments['shortsId'];
      title = arguments['title'];
      coins = arguments['coins'];
      coins_users = arguments['coins_users'];
      _userId = arguments['user_id'];

      DebugLogger.info(
          '📋 ShortsQuestionScreen: Quiz data - shortsId: $shortsId, lives: $lives, coins: $coins');

      // Mark that we're entering quiz mode
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      DebugLogger.info('🧠 ShortsQuestionScreen: Entering quiz mode...');
      videoStateProvider.enterQuiz();

      shortsProvider = Provider.of<Shorts>(context, listen: false);

      shortsProvider.fetchShortsQuestions(shortsId).then((_) {
        if (!mounted) {
          DebugLogger.api(
              '❌ ShortsQuestionScreen: Widget no longer mounted after questions fetch');
          return;
        }

        DebugLogger.success(
            'ShortsQuestionScreen: Questions fetched successfully');
        setState(() {
          questions = shortsProvider.questions;
          _isLoading = false;
        });
        activeQuestion = questions[0];
        myDuration = Duration(seconds: activeQuestion!['time'] as int);
        DebugLogger.info(
            '⏰ ShortsQuestionScreen: Quiz timer set to ${myDuration.inSeconds} seconds');
        _findCorrectAnswer();
        startTimer();
        // Start hint timer for guests
        if (!_isUserLoggedIn()) {
          DebugLogger.auth(
              '💡 ShortsQuestionScreen: Starting hint timer for guest user');
          _startHintTimer();
        }
      });

      _isInit = true;
    }
    super.didChangeDependencies();
  }

  void _findCorrectAnswer() {
    if (activeQuestion != null && activeQuestion!['answers'] != null) {
      final answers = activeQuestion!['answers'] as List<dynamic>;
      for (var answer in answers) {
        if (answer['is_correct'] == 1) {
          _correctAnswerId = answer['id'].toString();
          break;
        }
      }
    }
  }

  void _startHintTimer() {
    final hintDelay = Duration(seconds: 3);

    _hintTimer?.cancel();
    _hintTimer = Timer(hintDelay, () {
      if (mounted && !_isUserLoggedIn()) {
        setState(() {
          _showGuestHint = true;
        });
      }
    });
  }

  @override
  @override
  void dispose() {
    DebugLogger.info('🗑️ ShortsQuestionScreen: dispose(); called');
    countdownTimer.cancel();
    DebugLogger.info('⏰ ShortsQuestionScreen: Timer cancelled');

    _heartAnimationController.dispose();
    _blinkController.dispose();
    _coinAnimationController.dispose();
    _coinFlyController.dispose();
    _coinShowerController.dispose();
    _answerFeedbackController.dispose();
    _audioPlayer.dispose();
    _hintRewardedAd?.dispose();
    DebugLogger.info('🎬 ShortsQuestionScreen: Animation controllers disposed');

    // Clear any ongoing animations
    if (_heartAnimationController.isAnimating == true) {
      _heartAnimationController.stop();
    }
    if (_coinAnimationController.isAnimating == true) {
      _coinAnimationController.stop();
    }

    // Exit quiz state when disposing
    try {
      DebugLogger.info('🧠 ShortsQuestionScreen: Exiting quiz state...');
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      videoStateProvider.exitQuiz();
      DebugLogger.success(
          'ShortsQuestionScreen: Successfully exited quiz state');
    } catch (e) {
      DebugLogger.error('ShortsQuestionScreen: Error exiting quiz state: $e');
      // Ignore errors during dispose
    }

    // Handle screen protector cleanup without await
    DebugLogger.info(
        '🔒 ShortsQuestionScreen: Cleaning up screen protector...');
    ScreenProtector.protectDataLeakageOff();
    ScreenProtector.preventScreenshotOff();

    DebugLogger.success('ShortsQuestionScreen: Dispose completed');
    super.dispose();
  }

  void _animateHeartLoss() async {
    if (!mounted) return;

    setState(() {
      _isHeartHurt = true;
    });

    // Start blinking animation (blink 4 times)
    for (int i = 0; i < 4; i++) {
      await _blinkController.forward();
      await _blinkController.reverse();
    }

    // Wait a bit then remove the hurt heart
    await Future.delayed(Duration(milliseconds: 200));

    setState(() {
      _isHeartHurt = false;
    });

    // Show new fresh heart with pop animation
    _heartAnimationController.forward().then((_) {
      _heartAnimationController.reverse();
    });
  }

  // ─── Hint System ───

  void _loadHintAd() {
    if (_isHintAdLoading) return;
    _isHintAdLoading = true;
    RewardedAd.load(
      adUnitId: AdService.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _hintRewardedAd = ad;
          _isHintAdLoading = false;
        },
        onAdFailedToLoad: (_) {
          _hintRewardedAd = null;
          _isHintAdLoading = false;
        },
      ),
    );
  }

  void _useHint() {
    if (_hintUsedForCurrentQuestion || _showingFeedback) return;
    final auth = Provider.of<Auth>(context, listen: false);
    final coins = auth.userAvailableCoins;
    final hasEnoughCoins = coins >= kShortsQuizHintCost;
    final hasAd = _hintRewardedAd != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
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
              'Highlight the correct answer for this question',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            _buildHintOption(
              ctx: ctx,
              icon: Icons.monetization_on_rounded,
              iconColor: const Color(0xFFFFD700),
              title: 'Use Coins',
              subtitle: hasEnoughCoins
                  ? '$kShortsQuizHintCost coins  •  Balance: $coins'
                  : 'Not enough coins ($coins/$kShortsQuizHintCost)',
              enabled: hasEnoughCoins,
              gradient: const [Color(0xFFFFD700), Color(0xFFFFA000)],
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _executeHint(auth, freeFromAd: false);
              },
            ),
            const SizedBox(height: 12),
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
                _showRewardedAdForHint();
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
            color: enabled
                ? gradient[0].withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, color: enabled ? iconColor : Colors.grey, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        )),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRewardedAdForHint() {
    if (_hintRewardedAd == null) return;
    stopTimer();
    _hintRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _hintRewardedAd = null;
        _loadHintAd();
        if (mounted && !_hintUsedForCurrentQuestion) startTimer();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _hintRewardedAd = null;
        _loadHintAd();
        if (mounted) startTimer();
      },
    );
    _hintRewardedAd!.show(onUserEarnedReward: (_, reward) {
      _executeHint(Provider.of<Auth>(context, listen: false), freeFromAd: true);
      if (mounted) startTimer();
    });
  }

  void _executeHint(Auth auth, {required bool freeFromAd}) {
    if (_correctAnswerId == null) return;

    setState(() {
      _hintUsedForCurrentQuestion = true;
      _hintedAnswerId = _correctAnswerId;
    });

    if (!freeFromAd) {
      auth.deductCoinsLocally(kShortsQuizHintCost);
      final shortsProviderLocal = Provider.of<Shorts>(context, listen: false);
      http
          .post(
        Uri.parse(Url.baakhapaaApi('/coin-transaction')),
        headers: Url.baakhapaaAuthHeaders(shortsProviderLocal.authToken),
        body: json.encode({
          'status': 'spent',
          'coin': kShortsQuizHintCost,
          'remarks': 'Shorts quiz hint used',
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
            if (mounted) auth.addCoinsLocally(kShortsQuizHintCost);
            DebugLogger.error(
                'Shorts quiz hint transaction rejected: ${responseData['message']}');
          }
        } catch (e) {
          DebugLogger.error('Shorts quiz hint response parse error: $e');
        }
      }).catchError((e) {
        if (mounted) auth.addCoinsLocally(kShortsQuizHintCost);
        DebugLogger.error('Shorts quiz hint transaction network error: $e');
      });
    }
  }

  // Enhanced answer selection with visual feedback
  void _handleAnswerSelection(String answerId, int isCorrect) async {
    if (_showingFeedback) return; // Prevent multiple selections

    final bool isCorrectAnswer = isCorrect == 1;

    if (mounted) {
      setState(() {
        _selectedAnswerId = answerId;
        _showingFeedback = true;
        _isCorrectAnswer = isCorrectAnswer;
      });
    }

    // Play sound and vibration feedback
    _playFeedbackSound(isCorrectAnswer);
    _triggerVibration(isCorrectAnswer);

    // Start feedback animation
    _answerFeedbackController.forward();

    // Wait for visual feedback
    await Future.delayed(Duration(milliseconds: 1500));

    // Reset animation and proceed
    _answerFeedbackController.reset();
    if (mounted) {
      setState(() {
        _selectedAnswerId = null;
        _showingFeedback = false;
      });
    }

    // Proceed with existing logic
    onQuestionComplete(isCorrect);
  }

  // Play sound effect based on answer correctness
  Future<void> _playFeedbackSound(bool isCorrect) async {
    try {
      if (isCorrect) {
        await _audioPlayer.play(AssetSource('sounds/correct.wav'));
      } else {
        await _audioPlayer.play(AssetSource('sounds/wrong.wav'));
      }
    } catch (audioError) {
      // Custom sounds not available, but system sound already played
      DebugLogger.info(
          'Custom sound not available, using system sound only $audioError');
    }
  }

  // Trigger vibration based on answer correctness
  Future<void> _triggerVibration(bool isCorrect) async {
    try {
      // Check if device supports vibration
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        if (isCorrect) {
          // Pleasant single vibration for correct answer (150ms)
          await Vibration.vibrate(duration: 150);
        } else {
          // Strong pattern vibration for wrong answer (3 short bursts)
          await Vibration.vibrate(
            pattern: [
              0, // wait 0ms
              200, // vibrate 200ms (stronger)
              100, // pause 100ms
              200, // vibrate 200ms
              100, // pause 100ms
              200 // vibrate 200ms
            ],
          );
        }
      }
    } catch (e) {
      DebugLogger.error('Error triggering vibration: $e');
    }
  }

  // Enhanced coin animation method
  void _animateCoinsIncrease() async {
    if (!mounted) return;

    final _authProvider = Provider.of<Auth>(context, listen: false);
    final startCoins = _authProvider.userAvailableCoins;
    final endCoins = startCoins + coins;

    setState(() {
      _showCoinAnimation = true;
      _displayedCoins = startCoins;
    });

    // Initialize coin positions for flying effect
    _initializeCoinPositions();

    // Start all animations
    _coinShowerController.forward();
    _coinFlyController.forward();

    // Wait a bit then start the count animation
    await Future.delayed(Duration(milliseconds: 800));

    // Create count animation
    _coinCountAnimation = IntTween(
      begin: startCoins,
      end: endCoins,
    ).animate(CurvedAnimation(
      parent: _coinAnimationController,
      curve: Curves.easeInOut,
    ));

    // Listen to animation updates
    _coinCountAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _displayedCoins = _coinCountAnimation.value;
        });
      }
    });

    // Start bounce animation
    _coinAnimationController.forward();

    // Wait for animation to complete then navigate
    await Future.delayed(Duration(milliseconds: 4000));

    // Prepare for navigation to win screen
    if (mounted) {
      DebugLogger.info(
          '🏆 ShortsQuestionScreen: Preparing for win screen navigation...');
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      // Exit quiz and enter result screen state
      DebugLogger.info(
          '🧠 ShortsQuestionScreen: Exiting quiz and entering result screen');
      videoStateProvider.exitQuiz();
      videoStateProvider.enterResultScreen();

      if (_isUserLoggedIn()) {
        DebugLogger.info(
            '🎉 ShortsQuestionScreen: Navigating to logged-in win screen');
        Navigator.of(context).pushReplacementNamed(
          ShortsWinScreen.routeName,
          arguments: {
            'shortsId': shortsId,
            'coins': coins,
            'title': title,
            'coins_users': coins_users,
          },
        );
      } else {
        DebugLogger.info(
            '👤 ShortsQuestionScreen: Navigating to guest win screen');
        Navigator.of(context).pushReplacement(
          PageTransition(
            type: PageTransitionType.rightToLeft,
            child: GuestWinnerScreen(),
          ),
        );
      }
    }
  }

  void _initializeCoinPositions() {
    _coinPositions.clear();
    // Create positions for the number of coins earned
    int numCoins = coins < 10 ? coins : 10; // Cap at 10 for performance
    for (int i = 0; i < numCoins; i++) {
      _coinPositions.add(Offset(
        -60.0 + (i * 25.0), // Spread horizontally around coin area
        -40.0 -
            (i % 3 * 15.0), // Start above the coin display with some variation
      ));
    }
  }

  void nextQuestion() {
    if ((activeQuestionKey + 1) < questions.length) {
      // Small delay to ensure feedback is cleared
      Future.delayed(Duration(milliseconds: 100), () {
        if (!mounted) return;

        // Reset feedback state before showing new question
        _answerFeedbackController.reset();

        setState(() {
          activeQuestion = questions[activeQuestionKey + 1];
          activeQuestionKey++;
          _showGuestHint = false; // Reset
          // Reset feedback state
          _selectedAnswerId = null;
          _showingFeedback = false;
          _isCorrectAnswer = false;
          _hintUsedForCurrentQuestion = false;
          _hintedAnswerId = null;
        });

        _findCorrectAnswer(); // Find correct answer for new question
        resetTimer();

        if (!_isUserLoggedIn()) {
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _showGuestHint = true;
              });
            }
          });
        }
      });
    } else {
      _animateCoinsIncrease();
    }
  }

  void onQuestionComplete(int value) {
    stopTimer();
    if (value == 1) {
      nextQuestion();
    } else {
      if (lives > 1) {
        _animateHeartLoss();
        setState(() {
          lives = lives - 1;
        });
      } else {
        if (_coinAnimationController.isAnimating == true) {
          _coinAnimationController.stop();
        }
        _animateHeartLoss();

        Future.delayed(Duration(milliseconds: 1500), () {
          if (mounted) {
            final videoStateProvider =
                Provider.of<VideoStateProvider>(context, listen: false);

            // Emergency shutdown of video system
            DebugLogger.info(
                '🚨 ShortsQuestionScreen: Emergency video shutdown for lose navigation');
            videoStateProvider.forceStopAllVideos();
            videoStateProvider.exitQuiz();

            // Additional safety delay before navigation
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) {
                DebugLogger.info(
                    '🚀 ShortsQuestionScreen: Navigating to lose screen');
                Navigator.of(context).pushReplacementNamed(
                  ShortsLooseScreen.routeName,
                  arguments: {
                    'shortsId': shortsId,
                    'title': title,
                    'lives': lives,
                    'coins': coins,
                    'coins_users': coins_users,
                    'user_id': _userId,
                  },
                );
              }
            });
          }
        });
      }
    }
  }

  void setCountDown() {
    final reduceSecondsBy = 1;
    setState(() {
      final seconds = myDuration.inSeconds - reduceSecondsBy;
      if (seconds < 0) {
        _timerComplete = true;
      } else {
        myDuration = Duration(seconds: seconds);
      }
    });

    if (_timerComplete) {
      onQuestionComplete(0);
      setState(() {
        _timerComplete = false;
      });
    }
  }

  void startTimer() {
    countdownTimer = Timer.periodic(
      Duration(seconds: 1),
      (_) => setCountDown(),
    );
  }

  void stopTimer() {
    setState(() {
      countdownTimer.cancel();
    });
  }

  void resetTimer() {
    setState(() {
      myDuration = Duration(seconds: activeQuestion!['time'] as int);
    });
    startTimer();
  }

  // List<Icon> _myLives(int count) {
  //   return List.generate(
  //     count,
  //     (index) => Icon(
  //       Icons.favorite,
  //       color: Colors.red,
  //     ),
  //   ).toList();
  // }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  bool _shouldHighlightAnswer(Map<String, dynamic> answer) {
    if (_isUserLoggedIn()) return false;
    if (_showingFeedback) return false;
    if (!_showGuestHint) return false;
    return answer['id'].toString() == _correctAnswerId;
  }

  // Enhanced animated coin display widget with flying coins
  Widget _buildAnimatedCoinDisplay() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Flying coins shower
        if (_showCoinAnimation)
          ...List.generate(_coinPositions.length, (index) {
            return AnimatedBuilder(
              animation: _coinShowerAnimation,
              builder: (context, child) {
                final position = _coinPositions[index];

                // Create parabolic motion - up then down
                double animationValue = _coinShowerAnimation.value;
                double yOffset;
                double opacity;
                double scale;

                if (animationValue <= 0.4) {
                  // Going up phase (0 to 0.4)
                  double upPhase = animationValue / 0.4;
                  yOffset = position.dy - (upPhase * 80); // Go up 80 pixels
                  opacity = upPhase;
                  scale = 0.3 + (upPhase * 0.7);
                } else if (animationValue <= 0.8) {
                  // Falling down phase (0.4 to 0.8)
                  double fallPhase = (animationValue - 0.4) / 0.4;
                  yOffset = position.dy -
                      80 +
                      (fallPhase * 120); // Fall down 120 pixels
                  opacity = 1.0;
                  scale = 1.0;
                } else {
                  // Disappearing phase (0.8 to 1.0)
                  double fadePhase = (animationValue - 0.8) / 0.2;
                  yOffset = position.dy + 40; // Continue falling
                  opacity = 1.0 - fadePhase;
                  scale = 1.0 - (fadePhase * 0.5);
                }

                return Positioned(
                  left: position.dx,
                  top: yOffset,
                  child: Transform.scale(
                    scale: scale,
                    child: Transform.rotate(
                      angle: animationValue * 12.56, // Multiple rotations
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/coins.png',
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

        // Main coin display
        AnimatedBuilder(
          animation: _coinBounceAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _coinBounceAnimation.value,
              child: Container(
                width: 120,
                height: 45,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    width: 2,
                    color: Colors.amber,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 3,
                    ),
                    if (_showCoinAnimation)
                      BoxShadow(
                        color: Colors.yellow.withValues(alpha: 0.6),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Baakhapaa coin image
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/coins.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Coin count display
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_showCoinAnimation)
                          Text(
                            '+${coins}',
                            style: TextStyle(
                              color: Colors.green[600],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        Text(
                          '${_displayedCoins}',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: _showCoinAnimation
                                ? [
                                    Shadow(
                                      color:
                                          Colors.amber.withValues(alpha: 0.5),
                                      blurRadius: 3,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

// Updated _buildAnimatedAnswerOption method with proper guest highlighting
  Widget _buildAnimatedAnswerOption(Map<String, dynamic> answer) {
    final answerId = answer['id'].toString();
    final isSelected = _selectedAnswerId == answerId;
    final isGuestHint = _shouldHighlightAnswer(answer);
    final isCorrectOption = answer['is_correct'] == 1;
    final isHinted = _hintedAnswerId == answerId;
    final revealCorrect =
        _showingFeedback && !_isCorrectAnswer && isCorrectOption;

    Color getBackgroundColor() {
      if (isHinted && !_showingFeedback)
        return const Color(0xFFFFD700).withValues(alpha: 0.15);
      if (revealCorrect) return Colors.green.withValues(alpha: 0.2);
      if (isGuestHint && !_isUserLoggedIn()) {
        return Colors.amber.withValues(alpha: 0.3);
      }
      if (!isSelected) return Colors.transparent;
      return _isCorrectAnswer
          ? Colors.green.withValues(alpha: 0.2)
          : Colors.red.withValues(alpha: 0.2);
    }

    Color getBorderColor() {
      if (isHinted && !_showingFeedback) return const Color(0xFFFFD700);
      if (revealCorrect) return Colors.green;
      if (isGuestHint && !_isUserLoggedIn()) {
        return Colors.amber;
      }
      if (!isSelected)
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[600]!
            : Colors.grey[400]!;
      return _isCorrectAnswer ? Colors.green : Colors.red;
    }

    Widget getIcon() {
      if (revealCorrect)
        return Icon(Icons.check_circle, color: Colors.green, size: 20);
      if (isHinted && !_showingFeedback)
        return Icon(Icons.lightbulb, color: Color(0xFFFFD700), size: 20);
      if (isGuestHint && !_isUserLoggedIn()) {
        return Icon(Icons.lightbulb, color: Colors.amber, size: 20);
      }
      if (!isSelected) return Container();
      return _isCorrectAnswer
          ? Icon(Icons.check_circle, color: Colors.green, size: 20)
          : Icon(Icons.cancel, color: Colors.red, size: 20);
    }

    return AnimatedBuilder(
      animation:
          isSelected ? _answerFeedbackController : AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        double shakeOffset = 0.0;
        if (isSelected && !_isCorrectAnswer) {
          shakeOffset = sin(_answerShakeAnimation.value * 3.14159 * 6) * 3;
        }

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform.scale(
            scale: isSelected ? _answerScaleAnimation.value : 1.0,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200), // Faster transition
              curve: Curves.easeInOut,
              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: getBackgroundColor(),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: getBorderColor(),
                  width: (isSelected || isGuestHint) ? 2 : 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: (_isCorrectAnswer ? Colors.green : Colors.red)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  if (isGuestHint && !_isUserLoggedIn())
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showingFeedback
                      ? null
                      : () {
                          _handleAnswerSelection(
                            answer['id'].toString(),
                            answer['is_correct'] as int,
                          );
                        },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: Duration(milliseconds: 500),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isGuestHint && !_isUserLoggedIn()
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? (_isCorrectAnswer
                                      ? Colors.green[800]
                                      : Colors.red[800])
                                  : isGuestHint && !_isUserLoggedIn()
                                      ? Colors.amber[800]
                                      : null,
                            ),
                            child: Text(_getLocalizedAnswer(answer)),
                          ),
                        ),
                        SizedBox(width: 8),
                        AnimatedSwitcher(
                          duration: Duration(milliseconds: 300),
                          child: getIcon(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Build celebration particles for correct answers
  Widget _buildCelebrationParticles() {
    if (!_showingFeedback || !_isCorrectAnswer) return Container();

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _answerFeedbackController,
          builder: (context, child) {
            return CustomPaint(
              painter: CelebrationPainter(_answerFeedbackController.value),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _authProvider = Provider.of<Auth>(context, listen: false);
    final screenWidth = MediaQuery.of(context).size.width;

    String strDigits(int n) => n.toString().padLeft(2, '0');

    final hours =
        myDuration != null ? strDigits(myDuration.inHours.remainder(24)) : '00';
    final minutes = myDuration != null
        ? strDigits(myDuration.inMinutes.remainder(60))
        : '00';
    final seconds = myDuration != null
        ? strDigits(myDuration.inSeconds.remainder(60))
        : '00';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Handle back button press - ensure video state is restored
          DebugLogger.info(
              '🔙 ShortsQuestionScreen: Back button pressed, exiting quiz state');
          try {
            final videoStateProvider =
                Provider.of<VideoStateProvider>(context, listen: false);
            videoStateProvider.exitQuiz();
          } catch (e) {
            DebugLogger.error('ShortsQuestionScreen: Error on back press: $e');
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              try {
                final videoStateProvider =
                    Provider.of<VideoStateProvider>(context, listen: false);
                videoStateProvider.exitQuiz();
              } catch (e) {
                DebugLogger.error('ShortsQuestionScreen: Error on close: $e');
              }
              Navigator.of(context).pop();
            },
          ),
          title: const Text('Quiz',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          actions: [
            // Animated hearts
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: AnimatedBuilder(
                animation:
                    _isHeartHurt ? _blinkAnimation : _heartScaleAnimation,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: _isHeartHurt ? 1.0 : _heartScaleAnimation.value,
                      child: Opacity(
                        opacity: _isHeartHurt ? _blinkAnimation.value : 1.0,
                        child: Icon(
                          _isHeartHurt ? Icons.heart_broken : Icons.favorite,
                          color: _isHeartHurt ? Colors.red[300] : Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$lives',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[400],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            _isLoading
                ? Loading()
                : Container(
                    child: SafeArea(
                      child: Column(
                        key: _quizKey,
                        children: <Widget>[
                          // Quiz info strip: timer | coins | hint
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border(
                                bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1)),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Timer
                                Icon(Icons.access_time_filled,
                                    color: Colors.green[300], size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '$hours:$minutes:$seconds',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                // Coin display
                                _showCoinAnimation
                                    ? _buildAnimatedCoinDisplay()
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: Colors.amber
                                                  .withValues(alpha: 0.5)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.asset(
                                                'assets/images/coins.png',
                                                width: 16,
                                                height: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${_authProvider.userAvailableCoins}',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber),
                                            ),
                                          ],
                                        ),
                                      ),
                                const SizedBox(width: 8),
                                // Hint button
                                GestureDetector(
                                  onTap: (_hintUsedForCurrentQuestion ||
                                          _showingFeedback)
                                      ? null
                                      : _useHint,
                                  child: Icon(
                                    Icons.lightbulb_outline,
                                    size: 20,
                                    color: (_hintUsedForCurrentQuestion ||
                                            _showingFeedback)
                                        ? Colors.grey[600]
                                        : const Color(0xFFFFD700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Progress indicator section
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 15.0),
                            child: Column(
                              children: [
                                // Question counter text
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Question ${activeQuestionKey + 1} of ${questions.length}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${((activeQuestionKey + 1) / questions.length * 100).round()}%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                // Progress bar
                                Container(
                                  width: double.infinity,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[700]
                                        : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: (activeQuestionKey + 1) /
                                        questions.length,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.amber,
                                            Colors.amberAccent
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 30),

                          // Question and answers section - Use Expanded
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(horizontal: 15),
                              child: Column(
                                children: [
                                  // Question container
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[800]
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.08),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _getLocalizedQuestion(activeQuestion!),
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(height: 20),

                                  // Answer options
                                  if (activeQuestion!['type'] == 'Selection')
                                    ...(activeQuestion!['answers']
                                            as List<dynamic>)
                                        .map((answer) =>
                                            _buildAnimatedAnswerOption(answer))
                                        .toList(),

                                  if (activeQuestion!['type'] != 'Selection')
                                    Column(
                                      children: [
                                        SizedBox(height: 20),
                                        TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Enter Answer',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          onSubmitted: (String str) {
                                            final answers =
                                                activeQuestion!['answers']
                                                    as List<dynamic>;
                                            final expectedAnswer =
                                                answers[0]['answer'] ?? '';
                                            final expectedAnswerNepali =
                                                answers[0]['nepali_answer'] ??
                                                    '';
                                            // Allow both English and Nepali answers
                                            final isCorrectAnswer = str ==
                                                    expectedAnswer ||
                                                (expectedAnswerNepali
                                                        .isNotEmpty &&
                                                    str ==
                                                        expectedAnswerNepali);
                                            if (isCorrectAnswer) {
                                              onQuestionComplete(1);
                                            } else {
                                              onQuestionComplete(0);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  if (!_isUserLoggedIn() && _showGuestHint)
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      margin: EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.lightbulb,
                                              color: Colors.amber, size: 20),
                                          SizedBox(width: 5),
                                          Text(
                                            'Hint:Look for the highlighted answer',
                                            style: TextStyle(
                                              color: Colors.amber,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Manage questions button (if applicable)
                                  if (_isUserLoggedIn() &&
                                      _userId ==
                                          Provider.of<Auth>(context,
                                                  listen: false)
                                              .userId)
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 20),
                                      child: InkWell(
                                        onTap: () {
                                          stopTimer();
                                          Navigator.of(context).popAndPushNamed(
                                            CreateShortsQuestionScreen
                                                .routeName,
                                            arguments: {
                                              'shortsId': shortsId,
                                              'totalMcqsRequired': 0,
                                              'fromQuestionScreen': true,
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: screenWidth * 0.6,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(width: 1),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Manage Questions',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  SizedBox(height: 20), // Bottom padding
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            // Celebration particles overlay
            _buildCelebrationParticles(),
          ],
        ),
      ),
    );
  }

  /// Get the appropriate question text based on user's language preference
  /// Returns nepali_question if available and language is 'ne', otherwise returns question
  String _getLocalizedQuestion(Map<String, dynamic> question) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final isNepaliLanguage =
        languageProvider.currentLocale.languageCode == 'ne';

    if (isNepaliLanguage && question['nepali_question'] != null) {
      final nepaliQuestion = question['nepali_question'].toString().trim();
      if (nepaliQuestion.isNotEmpty) {
        DebugLogger.info('🇳🇵 Using Nepali question in Shorts');
        return nepaliQuestion;
      }
    }

    return question['question'].toString();
  }

  /// Get the appropriate answer text based on user's language preference
  /// Returns nepali_answer if available and language is 'ne', otherwise returns answer
  String _getLocalizedAnswer(Map<String, dynamic> answer) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final isNepaliLanguage =
        languageProvider.currentLocale.languageCode == 'ne';

    if (isNepaliLanguage && answer['nepali_answer'] != null) {
      final nepaliAnswer = answer['nepali_answer'].toString().trim();
      if (nepaliAnswer.isNotEmpty) {
        return nepaliAnswer;
      }
    }

    return answer['answer'].toString();
  }
}

// Custom painter for celebration particles
class CelebrationPainter extends CustomPainter {
  final double animationValue;

  CelebrationPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (animationValue == 0) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42); // Fixed seed for consistent animation

    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = (random.nextDouble() * 3 + 2) * animationValue;

      paint.color = [Colors.amber, Colors.orange, Colors.yellow][i % 3]
          .withValues(alpha: 1.0 - animationValue);

      canvas.drawCircle(
        Offset(x, y - animationValue * 100),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
