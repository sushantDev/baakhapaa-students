import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;

import '../../providers/auth.dart';
import '../../providers/language_provider.dart';
import 'loose_screen.dart';
import 'win_screen.dart';
// import '../../models/game_mode.dart';
import '../../providers/story.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../models/url.dart';

import '../../utils/debug_logger.dart';
import '../../services/subscription_service.dart';
import '../../services/ad_service.dart';
import '../../models/subscription.dart';

const int kQuizHintCost = 5;

class QuestionScreen extends StatefulWidget {
  static const routeName = '/question-screen';

  const QuestionScreen({Key? key}) : super(key: key);

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen>
    with TickerProviderStateMixin, PuppetInteractionMixin {
  var _navArgs;
  late Map<String, dynamic> episode = {};
  late List questions;
  Map<String, dynamic>? activeQuestion = null;
  int activeQuestionKey = 0;
  var _isInit = false;
  late Timer countdownTimer;
  late Duration myDuration = Duration(seconds: 1);
  late int lives;
  late int coins;
  late int coins_users;
  bool _timerComplete = false;
  bool _canSkipQuestion = false;
  late int _skipQuestionTimes;
  var tutorialProvider;
  UserBenefitUsage? _extraLifeBenefit;
  UserBenefitUsage? _bypassQuestionBenefit;

  // Animation controllers for hearts
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _isHeartHurt = false;

  // Coin animation controllers
  late AnimationController _coinAnimationController;
  late AnimationController _coinFlyController;
  late AnimationController _coinShowerController;
  late Animation<double> _coinBounceAnimation;
  late Animation<int> _coinCountAnimation;
  late Animation<double> _coinShowerAnimation;

  // Answer feedback animation controllers
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

  // Extra lives purchase state
  bool _isBuyingLife = false;
  String? _buyLifeError;

  // Hint system
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
    secureScreen();
    super.initState();

    // Initialize puppet provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<PuppetInteractionProvider>().initState();
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }
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
      duration: Duration(milliseconds: 1500),
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

    _loadHintAd();
  }

  @override
  Future<void> didChangeDependencies() async {
    if (!_isInit) {
      DebugLogger.info('❓ QuestionScreen: didChangeDependencies called');
      _navArgs = ModalRoute.of(context)?.settings.arguments;
      DebugLogger.info('❓ QuestionScreen: Route arguments: $_navArgs');
      if (_navArgs is Map<String, dynamic> && _navArgs['language'] != null) {
        // Use the language from the reading screen (user was reading in this language)
        _useNepali = _navArgs['language'] == 'ne';
        DebugLogger.info(
            '❓ QuestionScreen: Language from reading screen: ${_navArgs['language']}');
      } else {
        // Fall back to system language
        final languageProvider = context.read<LanguageProvider>();
        _useNepali = languageProvider.currentLocale.languageCode == 'ne';
        DebugLogger.info(
            '❓ QuestionScreen: Language from system: ${languageProvider.currentLocale.languageCode}');
      }

      final storyProvider = Provider.of<Story>(context, listen: false);
      episode = storyProvider.episode;
      if (storyProvider.isQuizCompletedFromEpisode(episode)) {
        _isInit = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
        return;
      }
      DebugLogger.success(
          '❓ QuestionScreen: Episode loaded: ${episode['title']} (ID: ${episode['id']}));');
      questions = episode['questions'] as List;
      DebugLogger.info(
          '❓ QuestionScreen: Questions count: ${questions.length}');

      // ✅ CRITICAL FIX: Always use base_lives from episode
      // This ensures lives are reset to original value on each quiz attempt
      lives = episode['base_lives'] as int;

      coins = episode['coins'];
      coins_users = episode['coins_users'];
      DebugLogger.info('❓ QuestionScreen: Lives: $lives (base), Coins: $coins');
      DebugLogger.info(
          '❓ Extra lives bought: ${episode['extra_lives_bought']}, remaining: ${episode['extra_lives_remaining']}');
      if (episode.containsKey('can_skip_questions')) {
        _canSkipQuestion = episode['can_skip_questions'] != null
            ? episode['can_skip_questions']
            : false;
      } else {
        _canSkipQuestion = false;
      }
      _skipQuestionTimes = episode['skip_questions_times'] != null
          ? episode['skip_questions_times']
          : 1;

      activeQuestion = questions[0];
      myDuration = Duration(seconds: activeQuestion!['time'] as int);
      startTimer();
      tutorialProvider =
          Provider.of<TutorialFlowProvider>(context, listen: false);
      if (tutorialProvider.currentStep == 7) {
        tutorialProvider.nextStep().then((_) {
          if (mounted) {
            tutorialProvider.showCurrentStepMessage(context);
          }
        });
      }
      _isInit = true;
      _checkQuizBenefits();
    }
    super.didChangeDependencies();
  }

  void _checkQuizBenefits() async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (!auth.isSubscribed) {
      if (mounted) return;
    }

    try {
      final subService = SubscriptionService(context: context);
      final response = await subService.getUserBenefitStatus();
      if (mounted && response.success && response.items.isNotEmpty) {
        setState(() {
          try {
            // ID 3 is Extra lives
            _extraLifeBenefit = response.items.first.benefits.firstWhere(
              (b) => b.benefitType.id == 3,
            );
          } catch (_) {}

          try {
            // ID 5 is Bypass Questions
            _bypassQuestionBenefit = response.items.first.benefits.firstWhere(
              (b) => b.benefitType.id == 5,
            );
          } catch (_) {}
        });
      }
    } catch (e) {
      DebugLogger.error('Error checking quiz benefits: $e');
    }
  }

  Future<bool> _useExtraLifeBenefit() async {
    if (_extraLifeBenefit == null) return false;

    final remaining = _extraLifeBenefit!.usage.remaining;
    final afterUsage = _extraLifeBenefit!.usage.isUnlimited
        ? remaining
        : (remaining > 0 ? remaining - 1 : 0);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Extra Life', style: TextStyle(color: Colors.white)),
        content: Text(
          'Your remaining benefit for Extra Life is $remaining. Would you like to use 1 to refill your life? Your remaining benefit will be $afterUsage.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC83E)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Refill',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    // ✅ User cancelled - return false
    if (confirm != true) return false;

    try {
      // 1. Show loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final auth = Provider.of<Auth>(context, listen: false);
      final subService =
          SubscriptionService(context: context, authToken: auth.token);

      // 2. Update usage in backend (V2 API)
      await subService.updateUserBenefitUsage(
        userBenefitUsageId: _extraLifeBenefit!.id,
        episodeId: (episode['id'] as int),
      );

      // 3. Add lives
      if (mounted) {
        setState(() {
          lives = lives + 1; // Add 1 life as requested
        });

        Navigator.of(context, rootNavigator: true).pop(); // Close loader
        _checkQuizBenefits(); // Refresh benefit status

        // ✅ Return true on success
        return true;
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader
        _showErrorDialog('Failed to use extra life benefit: $e');
      }
      return false;
    }

    return false;
  }

  Future<void> _useBypassQuestionBenefit() async {
    if (_bypassQuestionBenefit == null) return;

    final remaining = _bypassQuestionBenefit!.usage.remaining;
    final afterUsage = _bypassQuestionBenefit!.usage.isUnlimited
        ? remaining
        : (remaining > 0 ? remaining - 1 : 0);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Bypass Question',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Your remaining benefit for Bypass Question is $remaining. Would you like to use 1 to skip this question? Your remaining benefit will be $afterUsage.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC83E)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bypass',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Show loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final auth = Provider.of<Auth>(context, listen: false);
      final subService =
          SubscriptionService(context: context, authToken: auth.token);

      // 2. Update usage in backend (V2 API)
      await subService.updateUserBenefitUsage(
        userBenefitUsageId: _bypassQuestionBenefit!.id,
        episodeId: (episode['id'] as int),
      );

      // 3. ✅ CRITICAL FIX: Stop timer before skipping to next question
      stopTimer();

      // 4. Skip question (will call resetTimer internally)
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader
        nextQuestion();
        _checkQuizBenefits(); // Refresh benefit status
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader
        _showErrorDialog('Failed to use bypass question benefit: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('An error occurred'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Okay'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    DebugLogger.info('🗑️ QuestionScreen: dispose(); called');
    try {
      countdownTimer.cancel();
      DebugLogger.info('🗑️ QuestionScreen: timer cancelled');
    } catch (e) {
      DebugLogger.error('Error cancelling timer: $e');
    }

    try {
      _heartAnimationController.dispose();
      _blinkController.dispose();
      _coinAnimationController.dispose();
      _coinFlyController.dispose();
      _coinShowerController.dispose();
      _answerFeedbackController.dispose();
      _audioPlayer.dispose();
      _hintRewardedAd?.dispose();
      DebugLogger.info(
          '🗑️ QuestionScreen: animation controllers and audio player disposed');
    } catch (e) {
      DebugLogger.error('Error disposing animation controllers: $e');
    }

    // Clean up screen protector asynchronously without waiting
    _cleanupScreenProtector();

    super.dispose();
    DebugLogger.info('🗑️ QuestionScreen: super.dispose(); called');
  }

  void _cleanupScreenProtector() async {
    try {
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.preventScreenshotOff();
      DebugLogger.info('🗑️ QuestionScreen: screen protector cleaned up');
    } catch (e) {
      DebugLogger.error('Error in screen protector cleanup: $e');
    }
  }

  void nextQuestion() {
    if ((activeQuestionKey + 1) < questions.length) {
      setState(() {
        activeQuestion = questions[activeQuestionKey + 1];
        activeQuestionKey++;
        _hintUsedForCurrentQuestion = false;
        _hintedAnswerId = null;
      });
      resetTimer();
    } else {
      if (tutorialProvider.currentStep == 8) {
        tutorialProvider.nextStep().then((_) {
          if (mounted) {
            tutorialProvider.showCurrentStepMessage(context);
          }
        });
      }
      // Trigger coin animation and navigate to win screen
      _animateCoinsIncrease();
    }
  }

  void _animateHeartLoss() async {
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

  void onQuestionComplete(int value) {
    stopTimer();
    if (value == 1) {
      // Correct answer - continue to next question
      nextQuestion();
    } else {
      // Wrong answer - reduce lives
      if (lives > 1) {
        // Still have lives remaining
        _animateHeartLoss(); // Animate before reducing lives
        if (mounted) {
          setState(() {
            lives = lives - 1;
          });
        }
        nextQuestion();
      } else {
        _animateHeartLoss(); // Still animate even for last life
        if (mounted) {
          setState(() {
            lives = 0;
          });
        }

        // ✅ FIXED: Check subscription benefit FIRST
        final hasSubscriptionBenefit = _extraLifeBenefit != null &&
            (_extraLifeBenefit!.usage.isUnlimited ||
                _extraLifeBenefit!.usage.remaining > 0);

        // Then check if extra lives are available for purchase
        final canBuyExtraLife = (episode['extra_lives'] ?? 0) > 0 &&
            (episode['extra_life_cost'] ?? 0) > 0 &&
            ((episode['extra_lives_bought'] ?? 0) <
                (episode['extra_lives'] ?? 0));

        // ✅ Show dialog if EITHER benefit OR purchase is available
        if (hasSubscriptionBenefit || canBuyExtraLife) {
          // Show dialog to buy/use extra life - PAUSE game here
          Future.delayed(Duration(milliseconds: 1500), () {
            if (mounted) {
              _showBuyExtraLifeDialog();
            }
          });
          // ✅ Do NOT call nextQuestion() - wait for user decision
        } else {
          // No extra lives available - game over
          Future.delayed(Duration(milliseconds: 1500), () async {
            if (mounted) {
              DebugLogger.info(
                  '💔 QuestionScreen: All lives lost, navigating to LooseScreen');
              DebugLogger.info('💔 Episode data: ${_navArgs}');

              // ✅ Reset episode attempt for fresh retry
              try {
                final storyProvider =
                    Provider.of<Story>(context, listen: false);
                await storyProvider.resetEpisodeAttempt(episode['id']);
                DebugLogger.success('✅ Episode attempt reset for retry');
              } catch (error) {
                DebugLogger.error('❌ Failed to reset episode: $error');
                // Continue to LooseScreen even if reset fails
              }

              Navigator.of(context).pushReplacementNamed(
                LooseScreen.routeName,
                arguments: _navArgs,
              );
            }
          });
        }
      }
    }
  }

  // Show dialog to buy extra life
  void _showBuyExtraLifeDialog() {
    final authProvider = Provider.of<Auth>(context, listen: false);
    final costToUnlock = (episode['extra_life_cost'] ?? 0) as int;
    final hasEnoughCoins = authProvider.userAvailableCoins >= costToUnlock;
    final remainingPurchases = (episode['extra_lives_remaining'] ?? 0) as int;

    // Check if user has benefit
    final hasBenefit = _extraLifeBenefit != null &&
        (_extraLifeBenefit!.usage.isUnlimited ||
            _extraLifeBenefit!.usage.remaining > 0);

    // Check if purchases are available
    final canBuyExtraLife = remainingPurchases > 0 && costToUnlock > 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.favorite, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Get Extra Life',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'You\'ve run out of lives! Get an extra life to continue.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),

                  // INFO BADGES - HORIZONTAL SCROLL
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Subscription benefit badge
                        if (hasBenefit)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flash_on,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  _extraLifeBenefit!.usage.isUnlimited
                                      ? 'Benefit lives: ∞'
                                      : 'Benefit lives: ${_extraLifeBenefit!.usage.remaining}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),

                        // Remaining purchases badge
                        if (remainingPurchases > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.blue.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_bag,
                                    color: Colors.blue, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '$remainingPurchases purchase left',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Warning messages
                  if (!hasEnoughCoins) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Need ${costToUnlock - authProvider.userAvailableCoins} more coins',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_buyLifeError != null) ...[
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        _buyLifeError!,
                        style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],

                  SizedBox(height: 24),

                  // ✅ ACTION BUTTONS - VERTICAL COLUMN
                  // Priority: Free (benefit) → Buy with coins

                  // Benefit button (if available)
                  if (hasBenefit) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: !_isBuyingLife
                            ? () async {
                                // ✅ Check if benefit was successfully used
                                final success = await _useExtraLifeBenefit();

                                // ✅ Only close dialog and continue if successful
                                if (success && mounted) {
                                  Navigator.of(this.context).pop();
                                  nextQuestion();
                                }
                                // If not successful (user cancelled), dialog stays open
                              }
                            : null,
                        icon: _isBuyingLife
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.flash_on, size: 20),
                        label: Text(
                          _isBuyingLife
                              ? 'Processing...'
                              : 'Use Free Life (Benefit)',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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

                  // ✅ Buy button (only if purchases available)
                  if (canBuyExtraLife) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: hasEnoughCoins && !_isBuyingLife
                            ? () async {
                                await _buyExtraLife();
                                Navigator.of(this.context).pop();
                                if (mounted) {
                                  nextQuestion();
                                }
                              }
                            : null,
                        icon: _isBuyingLife
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.favorite, size: 20),
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isBuyingLife ? 'Processing...' : 'Buy Life for ',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (!_isBuyingLife) ...[
                              const SizedBox(width: 4),
                              Image.asset(
                                'assets/images/coins.png',
                                width: 16,
                                height: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$costToUnlock',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasEnoughCoins
                              ? Colors.red
                              : Colors.grey.shade600,
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

                  // Give up button at bottom
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        Navigator.of(this.context).pop();

                        try {
                          final storyProvider =
                              Provider.of<Story>(this.context, listen: false);
                          await storyProvider
                              .resetEpisodeAttempt(episode['id']);
                          DebugLogger.success(
                              '✅ Episode reset after giving up');
                        } catch (error) {
                          DebugLogger.error(
                              '❌ Failed to reset episode: $error');
                        }

                        if (mounted) {
                          Navigator.of(this.context).pushReplacementNamed(
                            LooseScreen.routeName,
                            arguments: _navArgs,
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Give Up',
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
            );
          },
        );
      },
    );
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
    final hasEnoughCoins = coins >= kQuizHintCost;
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
            // Coin option
            _buildHintOption(
              ctx: ctx,
              icon: Icons.monetization_on_rounded,
              iconColor: const Color(0xFFFFD700),
              title: 'Use Coins',
              subtitle: hasEnoughCoins
                  ? '$kQuizHintCost coins  •  Balance: $coins'
                  : 'Not enough coins ($coins/$kQuizHintCost)',
              enabled: hasEnoughCoins,
              gradient: const [Color(0xFFFFD700), Color(0xFFFFA000)],
              isDark: isDark,
              onTap: () {
                Navigator.of(ctx).pop();
                _executeHint(auth, freeFromAd: false);
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
    if (activeQuestion == null) return;
    final answers = activeQuestion!['answers'] as List<dynamic>;
    String? correctId;
    for (final a in answers) {
      if (a['is_correct'] == 1) {
        correctId = a['id'].toString();
        break;
      }
    }
    if (correctId == null) return;

    setState(() {
      _hintUsedForCurrentQuestion = true;
      _hintedAnswerId = correctId;
    });

    if (!freeFromAd) {
      auth.deductCoinsLocally(kQuizHintCost);
      final story = Provider.of<Story>(context, listen: false);
      http
          .post(
        Uri.parse(Url.baakhapaaApi('/coin-transaction')),
        headers: Url.baakhapaaAuthHeaders(story.authToken),
        body: json.encode({
          'status': 'spent',
          'coin': kQuizHintCost,
          'remarks': 'Quiz hint used',
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
            if (mounted) auth.addCoinsLocally(kQuizHintCost);
            DebugLogger.error(
                'Quiz hint transaction rejected: ${responseData['message']}');
          }
        } catch (e) {
          DebugLogger.error('Quiz hint response parse error: $e');
        }
      }).catchError((e) {
        if (mounted) auth.addCoinsLocally(kQuizHintCost);
        DebugLogger.error('Quiz hint transaction network error: $e');
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

  // Buy extra life
  Future<void> _buyExtraLife() async {
    final storyProvider = Provider.of<Story>(context, listen: false);

    if (_isBuyingLife) return; // Prevent multiple taps

    setState(() {
      _isBuyingLife = true;
      _buyLifeError = null;
    });

    try {
      DebugLogger.info('🛍️ Starting extra life purchase...');

      // Call the buy extra life API
      final result = await storyProvider.buyExtraLife(episode['id']);

      // ✅ CRITICAL: Use parent context (this.context) to ensure parent setState is called
      if (mounted) {
        setState(() {
          // Update episode with new life data from API response
          episode['extra_lives_bought'] = result['data']['extra_lives_bought'];
          episode['extra_lives_remaining'] =
              result['data']['extra_lives_remaining'];

          // ✅ CRITICAL FIX: Set lives to exactly 1 (not increment)
          // User gets 1 life to continue, not cumulative lives
          lives = 1;

          _isBuyingLife = false;
          DebugLogger.info(
              '✅ Extra life purchased! Lives now: $lives, Total bought: ${result['data']['extra_lives_bought']}');
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.favorite, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Extra life purchased! You have 1 life to continue.'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Play success sound
        try {
          await _audioPlayer.play(AssetSource('sounds/correct.wav'));
        } catch (e) {
          DebugLogger.info('Sound not available: $e');
        }
      }
    } catch (error) {
      DebugLogger.error('❌ Failed to buy extra life: $error');

      if (mounted) {
        setState(() {
          _isBuyingLife = false;
          _buyLifeError = error.toString();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to purchase extra life: ${error.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // Enhanced coin animation method
  void _animateCoinsIncrease() async {
    final _authProvider = Provider.of<Auth>(context, listen: false);
    final startCoins = _authProvider.userAvailableCoins;
    final episodeCoins =
        (episode['coins'] as int?) ?? 50; // Proper type casting
    final endCoins = startCoins + episodeCoins;

    if (mounted) {
      setState(() {
        _showCoinAnimation = true;
        _displayedCoins = startCoins;
      });
    }

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

    if (mounted) {
      DebugLogger.info(
          '🏆 QuestionScreen: All questions answered correctly, navigating to WinScreen');
      DebugLogger.info('🏆 Episode data: ${_navArgs}');
      Navigator.of(context).pushReplacementNamed(
        WinScreen.routeName,
        arguments: _navArgs,
      );
    } else {
      DebugLogger.warning(
          '⚠️ QuestionScreen: Widget not mounted, skipping navigation to WinScreen');
    }
  }

  void _initializeCoinPositions() {
    _coinPositions.clear();
    // Create positions for the number of coins earned
    final episodeCoins = (episode['coins'] as int?) ?? 50;
    int numCoins =
        episodeCoins < 10 ? episodeCoins : 10; // Cap at 10 for performance
    for (int i = 0; i < numCoins; i++) {
      _coinPositions.add(Offset(
        -60.0 + (i * 25.0), // Spread horizontally around coin area
        -40.0 -
            (i % 3 * 15.0), // Start above the coin display with some variation
      ));
    }
  }

  void setCountDown() {
    final reduceSecondsBy = 1;
    if (!mounted) return;

    setState(() {
      final seconds = myDuration.inSeconds - reduceSecondsBy;
      if (seconds < 0) {
        _timerComplete = true;
      } else {
        myDuration = Duration(seconds: seconds);
      }
    });

    if (_timerComplete && mounted) {
      onQuestionComplete(0);
      if (mounted) {
        setState(() {
          _timerComplete = false;
        });
      }
    }
  }

  void startTimer() {
    countdownTimer = Timer.periodic(
      Duration(seconds: 1),
      (_) => setCountDown(),
    );
  }

  void stopTimer() {
    try {
      countdownTimer.cancel();
    } catch (e) {
      DebugLogger.error('Error stopping timer: $e');
    }
    if (mounted) {
      setState(() {
        // Timer stopped
      });
    }
  }

  void resetTimer() {
    if (!mounted) return;

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

  // Widget _buildDurationSkipsDisplay() {
  //   final canBuyDurationSkip = (episode['max_duration_skips'] ?? 0) > 0 &&
  //       (episode['duration_skip_cost'] ?? 0) > 0 &&
  //       ((episode['duration_skips_bought'] ?? 0) < (episode['max_duration_skips'] ?? 0));

  //   return Container(
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.end,
  //       children: [
  //         Text(
  //           'Skip Timer',
  //           style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
  //         ),
  //         SizedBox(height: 8),
  //         Row(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             // Skip icon
  //             Icon(
  //               Icons.fast_forward,
  //               color: Colors.blue[700],
  //               size: 28,
  //             ),
  //             SizedBox(width: 8),
  //             // Display skips count
  //             Container(
  //               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //               decoration: BoxDecoration(
  //                 color: Colors.blue.withValues(alpha: 0.1),
  //                 borderRadius: BorderRadius.circular(12),
  //                 border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
  //               ),
  //               child: Text(
  //                 '${episode['duration_skips_bought'] ?? 0}/${episode['max_duration_skips'] ?? 0}',
  //                 style: TextStyle(
  //                   fontSize: 18,
  //                   fontWeight: FontWeight.bold,
  //                   color: Colors.blue[700],
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         if (canBuyDurationSkip) ...[
  //           SizedBox(height: 8),
  //           ElevatedButton.icon(
  //             onPressed: _showBuyDurationSkipDialog,
  //             icon: Icon(Icons.add_circle, size: 18),
  //             label: Text(
  //               'Buy Skip',
  //               style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
  //             ),
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.blue,
  //               foregroundColor: Colors.white,
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //             ),
  //           ),
  //         ],
  //       ],
  //     ),
  //   );
  // }

  // // Enhanced animated coin display widget with flying coins
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

  // Enhanced answer option with animations and feedback
  Widget _buildAnimatedAnswerOption(Map<String, dynamic> answer) {
    final answerId = answer['id'].toString();
    final isSelected = _selectedAnswerId == answerId;
    final isCorrectOption = answer['is_correct'] == 1;
    final isHinted = _hintedAnswerId == answerId;
    // Show correct answer when user picked wrong
    final revealCorrect =
        _showingFeedback && !_isCorrectAnswer && isCorrectOption;

    Color getBackgroundColor() {
      if (isHinted && !_showingFeedback)
        return const Color(0xFFFFD700).withValues(alpha: 0.15);
      if (revealCorrect) return Colors.green.withValues(alpha: 0.2);
      if (!isSelected) return Colors.transparent;
      return _isCorrectAnswer
          ? Colors.green.withValues(alpha: 0.2)
          : Colors.red.withValues(alpha: 0.2);
    }

    Color getBorderColor() {
      if (isHinted && !_showingFeedback) return const Color(0xFFFFD700);
      if (revealCorrect) return Colors.green;
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
          // Shake animation for wrong answers
          shakeOffset = sin(_answerShakeAnimation.value * 3.14159 * 6) * 3;
        }

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Transform.scale(
            scale: isSelected ? _answerScaleAnimation.value : 1.0,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: getBackgroundColor(),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: getBorderColor(),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: (_isCorrectAnswer ? Colors.green : Colors.red)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
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
                          child: Text(
                            _getLocalizedAnswer(answer),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w400, // Lighter font weight
                              color: isSelected
                                  ? (_isCorrectAnswer
                                      ? Colors.green[800]
                                      : Colors.red[800])
                                  : null,
                            ),
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

    String strDigits(int n) => n.toString().padLeft(2, '0');

    final hours = strDigits(myDuration.inHours.remainder(24));
    final minutes = strDigits(myDuration.inMinutes.remainder(60));
    final seconds = strDigits(myDuration.inSeconds.remainder(60));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Quiz',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          // Animated hearts
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: AnimatedBuilder(
              animation: _isHeartHurt ? _blinkAnimation : _heartScaleAnimation,
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
          SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              child: Column(
                children: <Widget>[
                  // Quiz info strip: timer | coins | language | hint
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        // Coin display
                        _showCoinAnimation
                            ? _buildAnimatedCoinDisplay()
                            : GestureDetector(
                                onTap: () => Navigator.of(context)
                                    .pushNamed('/points-screen'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: Colors.amber
                                            .withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset('assets/images/coins.png',
                                          width: 16, height: 16),
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
                              ),
                        const SizedBox(width: 8),
                        // Language toggle
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _useNepali = !_useNepali;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_useNepali
                                    ? '🇳🇵 नेपाली (Nepali) सक्रिय'
                                    : '🇬🇧 English activated'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: Colors.amber[700],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Text(
                              _useNepali ? 'ने' : 'EN',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Hint button
                        GestureDetector(
                          onTap:
                              (_hintUsedForCurrentQuestion || _showingFeedback)
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
                  const SizedBox(height: 8),
                  // Progress indicator
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        // Question counter text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Question ${activeQuestionKey + 1} of ${questions.length}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${((activeQuestionKey + 1) / questions.length * 100).round()}%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        // Progress bar (shows current question progress)
                        Container(
                          width: double.infinity,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor:
                                (activeQuestionKey + 1) / questions.length,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.amber, Colors.amberAccent],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Container(
                    padding: EdgeInsets.only(
                        top: 0, bottom: 20, right: 10, left: 10),
                    child: activeQuestion!['type'] == 'Selection'
                        ? Column(
                            children: [
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
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
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
                              SizedBox(
                                height: 20,
                              ),
                              ...(activeQuestion!['answers'] as List<dynamic>)
                                  .map((answer) =>
                                      _buildAnimatedAnswerOption(answer))
                                  .toList(),
                            ],
                          )
                        : Column(
                            children: [
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
                                      color:
                                          Colors.black.withValues(alpha: 0.08),
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
                              SizedBox(
                                height: 20,
                              ),
                              TextField(
                                decoration:
                                    InputDecoration(labelText: 'Enter Answer'),
                                onSubmitted: (String str) {
                                  final answers = activeQuestion!['answers']
                                      as List<dynamic>;
                                  final expectedAnswer =
                                      answers[0]['answer'] ?? '';
                                  final expectedAnswerNepali =
                                      answers[0]['nepali_answer'] ?? '';
                                  // Allow both English and Nepali answers
                                  final isCorrectAnswer =
                                      str == expectedAnswer ||
                                          (expectedAnswerNepali.isNotEmpty &&
                                              str == expectedAnswerNepali);
                                  if (isCorrectAnswer) {
                                    onQuestionComplete(1);
                                  } else {
                                    onQuestionComplete(0);
                                  }
                                },
                              ),
                            ],
                          ),
                  ),
                  SizedBox(height: 10),
                  _canSkipQuestion && _skipQuestionTimes > 0
                      ? TextButton(
                          onPressed: () async {
                            final _authProvider =
                                Provider.of<Auth>(context, listen: false);

                            // ✅ CRITICAL FIX: Stop timer before skipping
                            stopTimer();

                            await _authProvider
                                .coinTransaction(
                              episode['skip_question_points'] as int,
                              'debited',
                              'Bypassed question on episode "${episode['title']}"',
                            )
                                .then((_) {
                              onQuestionComplete(1);
                              setState(() {
                                _skipQuestionTimes = _skipQuestionTimes - 1;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Bypassed question successfully!')));
                            });
                          },
                          child: Text(
                              'Use ${episode['skip_question_points']} points to bypass this question'),
                        )
                      : Container(height: 0),
                  if (_bypassQuestionBenefit != null &&
                      (_bypassQuestionBenefit!.usage.availableCount > 0 ||
                          _bypassQuestionBenefit!.usage.isUnlimited))
                    ElevatedButton.icon(
                      onPressed: _useBypassQuestionBenefit,
                      icon: Icon(Icons.flash_on, size: 16),
                      label: Text('Bypass with Benefit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
          // Celebration particles overlay
          _buildCelebrationParticles(),
        ],
      ),
    );
  }

  /// Get the appropriate question text based on language toggle
  /// Returns nepali_question if available and _useNepali is true, otherwise returns question
  String _getLocalizedQuestion(Map<String, dynamic> question) {
    if (_useNepali && question['nepali_question'] != null) {
      final nepaliQuestion = question['nepali_question'].toString().trim();
      if (nepaliQuestion.isNotEmpty) {
        DebugLogger.info('🇳🇵 Using Nepali question');
        return nepaliQuestion;
      }
    }

    return question['question'].toString();
  }

  /// Get the appropriate answer text based on language toggle
  /// Returns nepali_answer if available and _useNepali is true, otherwise returns answer
  String _getLocalizedAnswer(Map<String, dynamic> answer) {
    if (_useNepali && answer['nepali_answer'] != null) {
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
