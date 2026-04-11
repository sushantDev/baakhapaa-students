import 'package:baakhapaa/providers/video_state_provider.dart';
import 'package:baakhapaa/screens/story/story_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import './shorts_screen.dart';
import './shorts_question_screen.dart';

import '../../utils/debug_logger.dart';
import '../../services/ad_service.dart';
import '../../services/analytics_service.dart';

class ShortsLooseScreen extends StatefulWidget {
  static const routeName = '/shorts-loose-screen';

  const ShortsLooseScreen({Key? key}) : super(key: key);

  @override
  State<ShortsLooseScreen> createState() => _ShortsLooseScreenState();
}

class _ShortsLooseScreenState extends State<ShortsLooseScreen> {
  GlobalKey keyNavigation = GlobalKey();
  late int _shortsId;
  late String _title;
  int _lives = 3;
  int _coins = 0;
  int _coinsUsers = 0;
  int _userId = 0;

  @override
  void initState() {
    super.initState();

    // CRITICAL: Force stop all videos immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final videoStateProvider =
            Provider.of<VideoStateProvider>(context, listen: false);

        // Complete shutdown of video system
        videoStateProvider.forceStopAllVideos();
        videoStateProvider.enterResultScreen();
        videoStateProvider.setScreen('lose');

        // Additional safety - force multiple stops
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            videoStateProvider.forceStopAllVideos();
          }
        });

        Future.delayed(Duration(milliseconds: 200), () {
          if (mounted) {
            videoStateProvider.forceStopAllVideos();
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    DebugLogger.info('💔 ShortsLooseScreen: didChangeDependencies called');
    super.didChangeDependencies();

    // Mark that we're in a result screen
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    DebugLogger.info('💔 ShortsLooseScreen: Entering result screen mode...');
    videoStateProvider.enterResultScreen();

    // Get arguments passed from question screen
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      _shortsId = arguments['shortsId'] ?? 0;
      _title = arguments['title'] ?? '';
      _lives = arguments['lives'] ?? 3;
      _coins = arguments['coins'] ?? 0;
      _coinsUsers = arguments['coins_users'] ?? 0;
      _userId = arguments['user_id'] ?? 0;
      DebugLogger.info(
          '📋 ShortsLooseScreen: Got arguments - shortsId: $_shortsId, title: $_title');
    } else {
      DebugLogger.error(
          'ShortsLooseScreen: No arguments provided, using fallback');
      // Fallback to video state provider
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      _shortsId = videoStateProvider.getQuizSourceShortsId();
      _title = '';
      DebugLogger.info(
          '📋 ShortsLooseScreen: Fallback data - shortsId: $_shortsId');
    }

    // Track quiz failed event
    AnalyticsService.logQuizCompleted(quizType: 'shorts', won: false);
  }

  @override
  void dispose() {
    DebugLogger.info('🗑️ ShortsLooseScreen: dispose(); called');

    // Exit result screen state when disposing
    try {
      DebugLogger.info('💔 ShortsLooseScreen: Exiting result screen state...');
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);
      videoStateProvider.exitResultScreen();
      DebugLogger.success(
          'ShortsLooseScreen: Successfully exited result screen state');
    } catch (e) {
      DebugLogger.error(
          'ShortsLooseScreen: Error exiting result screen state: $e');
    }

    DebugLogger.success('ShortsLooseScreen: Dispose completed');
    super.dispose();
  }

  void _navigateToHome() {
    DebugLogger.info('🏠 ShortsLooseScreen: _navigateToHome called');
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);

    // Complete shutdown
    DebugLogger.info(
        '🚨 ShortsLooseScreen: Performing complete video shutdown');
    videoStateProvider.forceStopAllVideos();
    videoStateProvider.resetState();

    // Navigate to home (StoryScreen)
    DebugLogger.info('🚀 ShortsLooseScreen: Navigating to StoryScreen');
    Navigator.pushAndRemoveUntil(
      context,
      PageTransition(
        child: StoryScreen(),
        type: PageTransitionType.fade,
      ),
      (route) => false, // Remove all previous routes
    );
  }

  void _tryAgain() {
    DebugLogger.info('🔄 ShortsLooseScreen: _tryAgain called');
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);

    DebugLogger.info(
        '🎬 ShortsLooseScreen: Cleaning video state for try again - shortsId: $_shortsId');
    // Clean exit from result screen and enter quiz mode
    videoStateProvider.exitResultScreen();
    videoStateProvider.enterQuiz();
    videoStateProvider.saveQuizSourceShorts(_shortsId);

    // Navigate directly back to the quiz screen to replay the same short
    DebugLogger.info(
        '🚀 ShortsLooseScreen: Navigating directly to ShortsQuestionScreen for retry');
    Navigator.of(context).pushReplacementNamed(
      ShortsQuestionScreen.routeName,
      arguments: {
        'shortsId': _shortsId,
        'lives': _lives,
        'title': _title,
        'coins': _coins,
        'coins_users': _coinsUsers,
        'user_id': _userId,
      },
    );
  }

// Update the _navigateToShorts method:
  void _navigateToShorts() {
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);

    // Clean exit from result screen
    videoStateProvider.exitResultScreen();
    videoStateProvider.clearQuizSource();
    videoStateProvider.setScreen('');

    // Navigate to shorts screen
    Navigator.pushAndRemoveUntil(
      context,
      PageTransition(
        child: ShortsScreen(),
        type: PageTransitionType.fade,
      ),
      (route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation to ensure clean state
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 20), // "Almost there" icon
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B35), Color(0xFFFF8C00)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8C00)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.trending_up_rounded,
                                color: Colors.white, size: 40),
                          ),
                          SizedBox(height: 16),

                          Text(
                            'ALMOST THERE!',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          if (_title.isNotEmpty)
                            Text(
                              _title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                          // Puppet expression GIF
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl:
                                  'https://bkp-v1.blr1.cdn.digitaloceanspaces.com/puppet/puppet_expression_lose_screen.gif',
                              height: 200,
                              fit: BoxFit.contain,
                              // CachedNetworkImage uses errorWidget instead of errorBuilder
                              errorWidget: (context, url, error) =>
                                  const SizedBox.shrink(),
                            ),
                          ),

                          SizedBox(height: 12),

                          // Growth mindset section
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.06),
                                  Colors.white.withValues(alpha: 0.03),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '💡',
                                  style: TextStyle(fontSize: 28),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Every attempt builds knowledge',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '"Success is not final, failure is not fatal — it is the courage to continue that counts."',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white38,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 16),

                          // Encouragement tip
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lightbulb_outline_rounded,
                                  color: Colors.amber.withValues(alpha: 0.6),
                                  size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Tip: Re-watch the short before trying again',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white30,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Banner ad (non-premium users only)
                  if (!AdService.isUserPremium(context)) const BaakhaBannerAd(),
                  SizedBox(height: 8),
                  // Action buttons
                  Row(
                    children: [
                      // Home button
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 56,
                          margin: EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF2C3E50),
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
                      // Try Again button (primary)
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 56,
                          margin: EdgeInsets.symmetric(horizontal: 6),
                          child: ElevatedButton(
                            onPressed: _tryAgain,
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
                                    Color(0xFFFFA500),
                                    Color(0xFFFF8C00),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFFFA500)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.refresh_rounded,
                                        color: Colors.white, size: 28),
                                    SizedBox(width: 8),
                                    Text(
                                      'Try Again',
                                      style: TextStyle(
                                        fontSize: 16,
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
                      ),
                      // Shorts button
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 56,
                          margin: EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF6A4C93),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ElevatedButton(
                            onPressed: _navigateToShorts,
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
                                Icon(Icons.play_circle_fill_rounded,
                                    color: Colors.white, size: 28),
                                SizedBox(height: 4),
                                Text(
                                  'Shorts',
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
