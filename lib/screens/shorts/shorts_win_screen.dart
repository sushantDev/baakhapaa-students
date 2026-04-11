import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/providers/video_state_provider.dart';
import 'package:baakhapaa/screens/shop/tab_view_product.dart';
import 'package:baakhapaa/widgets/tutorial_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../story/story_screen.dart';
import './shorts_screen.dart';
import '../../providers/shorts.dart';
import '../../providers/auth.dart';

import '../../utils/debug_logger.dart';
import '../../services/ad_service.dart';
import '../../services/analytics_service.dart';

class ShortsWinScreen extends StatefulWidget {
  static const routeName = '/shorts-win-screen';

  const ShortsWinScreen({Key? key}) : super(key: key);

  @override
  State<ShortsWinScreen> createState() => _ShortsWinScreenState();
}

class _ShortsWinScreenState extends State<ShortsWinScreen> {
  var _isInit = false;
  var _isLoading = true;
  bool _showPromoCard = false;
  late Map<String, dynamic> episode = {};
  late List<dynamic> season = [];
  GlobalKey keyNavigation = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Ensure video is paused when win screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final videoStateProvider =
            Provider.of<VideoStateProvider>(context, listen: false);
        // Make sure we're in result screen state to prevent any video playback
        videoStateProvider.enterResultScreen();
        videoStateProvider.pauseVideo();
        videoStateProvider.setScreen('win');
        // Force stop all registered videos to prevent background audio
        videoStateProvider.forceStopAllRegisteredVideos();
        videoStateProvider.forceStopAllVideos();
      }
    });
  }

  @override
  void dispose() {
    DebugLogger.info('🗑️ ShortsWinScreen: dispose(); called');

    // Exit result screen state when disposing
    try {
      DebugLogger.info('🏆 ShortsWinScreen: Exiting result screen state...');
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      videoStateProvider.exitResultScreen();
      DebugLogger.success(
          'ShortsWinScreen: Successfully exited result screen state');
    } catch (e) {
      DebugLogger.error(
          'ShortsWinScreen: Error exiting result screen state: $e');
    }

    DebugLogger.success('ShortsWinScreen: Dispose completed');
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    DebugLogger.info('🏆 ShortsWinScreen: didChangeDependencies called');
    if (!_isInit) {
      DebugLogger.info('🎯 ShortsWinScreen: Initializing win screen...');
      final arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
      int userId = Provider.of<Auth>(context, listen: false).userId;
      var shortsProvider = Provider.of<Shorts>(context, listen: false);
      int fallBackPoints =
          Provider.of<Auth>(context, listen: false).fallBackPoints;

      // Mark that we're in a result screen
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      DebugLogger.info('🏆 ShortsWinScreen: Entering result screen mode...');
      videoStateProvider.enterResultScreen();

      DebugLogger.info(
          '📊 ShortsWinScreen: Processing win data - shortsId: ${arguments['shortsId']}, coins: ${arguments['coins']}');
      shortsProvider
          .shortsWatched(
        userId,
        arguments['shortsId'],
        arguments['title'],
        arguments['coins'],
        arguments['coins_users'],
        fallBackPoints,
      )
          .then((_) {
        if (mounted) {
          DebugLogger.success(
              'ShortsWinScreen: Win data processed successfully');
          final isPremium = AdService.isUserPremium(context);
          if (!isPremium) {
            // Non-premium: show interstitial every 3rd win; alternate banner with promo
            final shouldShowAd = AdService().incrementShortsWinAndCheckAd();
            final showPromo = AdService().shouldShowWinPromoCard();
            if (shouldShowAd && AdService().isInterstitialReady) {
              AdService().showInterstitial(
                  context: context,
                  onAdDismissed: () {
                    if (mounted) setState(() => _isLoading = false);
                  });
            } else {
              setState(() {
                _showPromoCard = showPromo;
                _isLoading = false;
              });
            }
          } else {
            // Premium users: no ads or promos
            setState(() => _isLoading = false);
          }
        } else {
          DebugLogger.error(
              '❌ ShortsWinScreen: Widget no longer mounted after win data processing');
        }
      });

      final tutorialProvider =
          Provider.of<TutorialFlowProvider>(context, listen: false);
      // Show tutorial message after init
      if (tutorialProvider.currentStep == 2) {
        DebugLogger.info('🎓 ShortsWinScreen: Processing tutorial step 2');
        tutorialProvider.nextStep().then((_) {
          if (mounted) {
            tutorialProvider.showCurrentStepMessage(context);
          }
        });
      } else if (tutorialProvider.currentStep == 3) {
        DebugLogger.info('🎓 ShortsWinScreen: Processing tutorial step 3');
        if (mounted) {
          tutorialProvider.showCurrentStepMessage(context);
        }
      }
      _isInit = true;

      // Track quiz completed event for shorts
      AnalyticsService.logQuizCompleted(
        quizType: 'shorts',
        won: true,
      );
    }
    super.didChangeDependencies();
  }

  void goToHomeScreen() {
    DebugLogger.info('🏠 ShortsWinScreen: goToHomeScreen called');
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    final shortsId = videoStateProvider.quizSourceShortsId;

    DebugLogger.info(
        '🎬 ShortsWinScreen: Preparing video state for home navigation - shortsId: $shortsId');
    // Clean up video state completely
    videoStateProvider.forceStopAllRegisteredVideos();
    videoStateProvider.forceStopAllVideos();
    videoStateProvider.exitResultScreen();
    videoStateProvider.setScreen('');
    videoStateProvider.clearAllActiveVideos();

    DebugLogger.info(
        '🚀 ShortsWinScreen: Navigating to ShortsScreen with returnToShortsId');
    Navigator.pushAndRemoveUntil(
      context,
      PageTransition(
        child: ShortsScreen(),
        type: PageTransitionType.fade,
        settings: RouteSettings(
          arguments: {
            'returnToShortsId': shortsId,
            'fromWinScreen': true,
          },
        ),
      ),
      (route) => false,
    );
  }

  void _navigateToShorts() {
    DebugLogger.info('📱 ShortsWinScreen: _navigateToShorts called');
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    final shortsId = videoStateProvider.quizSourceShortsId;

    DebugLogger.info(
        '🎬 ShortsWinScreen: Cleaning video state for shorts navigation - shortsId: $shortsId');
    // Clean up video state before navigation - exit result screen state
    videoStateProvider.forceStopAllRegisteredVideos();
    videoStateProvider.forceStopAllVideos();
    videoStateProvider.exitResultScreen();
    videoStateProvider.setScreen('');

    // Clear all active videos to reset provider state completely
    videoStateProvider.clearAllActiveVideos();

    DebugLogger.info(
        '🚀 ShortsWinScreen: Performing full navigation reset to ShortsScreen');
    Navigator.pushAndRemoveUntil(
      context,
      PageTransition(
        child: ShortsScreen(),
        type: PageTransitionType.fade,
        settings: RouteSettings(
          arguments: {
            'returnToShortsId': shortsId,
            'fromWinScreen': true,
          },
        ),
      ),
      (route) => false,
    );
  }

  void _navigateToHome() {
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);

    // Clean up video state - exit result screen state
    videoStateProvider.forceStopAllRegisteredVideos();
    videoStateProvider.forceStopAllVideos();
    videoStateProvider.exitResultScreen();
    videoStateProvider.pauseVideo();
    videoStateProvider.setScreen('');
    videoStateProvider.clearQuizSource();

    // Clear all active videos to reset provider state completely
    videoStateProvider.clearAllActiveVideos();

    Navigator.pushReplacement(
      context,
      PageTransition(
        child: StoryScreen(),
        type: PageTransitionType.fade,
      ),
    );
  }

  void _navigateToShop() {
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);

    // Clean up video state - exit result screen state
    videoStateProvider.forceStopAllRegisteredVideos();
    videoStateProvider.forceStopAllVideos();
    videoStateProvider.exitResultScreen();
    videoStateProvider.pauseVideo();
    videoStateProvider.setScreen('');
    videoStateProvider.clearQuizSource();
    // Clear all active videos to reset provider state completely
    videoStateProvider.clearAllActiveVideos();

    final GlobalKey<ScaffoldState> scaffoldKeyProduct =
        GlobalKey<ScaffoldState>();

    // Use pushAndRemoveUntil to clear the entire navigation stack
    // This ensures ShortsScreen is also removed and its videos stop
    Navigator.pushAndRemoveUntil(
      context,
      PageTransition(
        child: TabViewProduct(scaffoldKey: scaffoldKeyProduct),
        type: PageTransitionType.fade,
      ),
      (route) => false, // Remove all routes
    );
  }

  /// Prompt the user to review the app if they haven't already.
  Future<void> _promptReviewIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasReviewed = prefs.getBool('has_reviewed_app') ?? false;
      if (hasReviewed) return;

      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await prefs.setBool('has_reviewed_app', true);
        DebugLogger.info('⭐ ShortsWinScreen: Review prompt shown');
      }
    } catch (e) {
      DebugLogger.error('ShortsWinScreen: Error prompting review: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;

    // Determine actual earned points: if coins_users == 0, user gets fallback points
    final int rawCoins = (arguments['coins'] ?? 0) is int
        ? (arguments['coins'] ?? 0) as int
        : int.tryParse(arguments['coins'].toString()) ?? 0;
    final int coinsUsers = (arguments['coins_users'] ?? 0) is int
        ? (arguments['coins_users'] ?? 0) as int
        : int.tryParse(arguments['coins_users'].toString()) ?? 0;
    final int fbPoints =
        Provider.of<Auth>(context, listen: false).fallBackPoints;
    final int fallBackPts = fbPoints > 0 ? fbPoints : 1;
    final bool isFallbackEarning = coinsUsers == 0;
    final int pointsEarned = isFallbackEarning ? fallBackPts : rawCoins;

    return _isLoading
        ? const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
          )
        : Scaffold(
            backgroundColor: Colors.black,
            body: Container(
              color: Colors.black,
              child: SafeArea(
                child: Column(
                  children: [
                    // Scrollable content area
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Column(
                          children: [
                            // Completion badge
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF22C55E),
                                    Color(0xFF16A34A),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF22C55E)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(Icons.check_rounded,
                                  color: Colors.white, size: 40),
                            ),
                            SizedBox(height: 16),

                            Text(
                              'QUIZ COMPLETE!',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            Text(
                              arguments['title']?.toString() ?? 'This Short',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // SizedBox(height: 24),
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
                            SizedBox(height: 12),

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
                                '"Small daily improvements over time lead to stunning results."',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white38,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            SizedBox(height: 20),

                            // Points earned
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
                                      color:
                                          Colors.amber.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/images/coins.png',
                                        width: 28,
                                        height: 28,
                                      ),
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
                                          color: Colors.amber
                                              .withValues(alpha: 0.7),
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
                          ],
                        ),
                      ),
                    ),

                    // Bottom buttons pinned at bottom, outside scroll
                    // Alternate: show premium/widget promo every 4th win, AdMob banner otherwise
                    if (!AdService.isUserPremium(context))
                      _showPromoCard
                          ? const WinScreenPromo()
                          : const BaakhaBannerAd(),
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
                                color:
                                    Colors.grey.shade800.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ElevatedButton(
                                onPressed: _navigateToHome,
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
                                    Icon(
                                      Icons.home_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
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

                          // Claim Now button (main button in center)
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 56,
                              margin: EdgeInsets.symmetric(horizontal: 6),
                              child: ElevatedButton(
                                key: keyNavigation,
                                onPressed: () {
                                  // Claim points action
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '$pointsEarned Baakhapaa points claimed!'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  // Prompt for review after claiming
                                  _promptReviewIfNeeded();
                                  _navigateToShorts();
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
                                        Colors.orange.shade500,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.amber.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/images/coins.png',
                                          width: 25,
                                          height: 25,
                                        ), // Image Coin
                                        SizedBox(width: 8),
                                        Text(
                                          'Continue\n+$pointsEarned pts',
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
                                color: Colors.purple.shade700
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Consumer<TutorialFlowProvider>(
                                builder: (context, tutorial, _) => Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ElevatedButton(
                                      key: tutorial
                                          .getTutorialKey('gift_button_key'),
                                      onPressed: _navigateToShop,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.card_giftcard_rounded,
                                            color: Colors.white,
                                            size: 28,
                                          ),
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
                                    if (tutorial.currentStep == 3 &&
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
