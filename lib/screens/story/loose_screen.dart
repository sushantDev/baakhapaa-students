import 'package:baakhapaa/screens/story/story_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import '../gift/gift_screen.dart';
import './episode_screen.dart';
import './video_screen.dart';
import './readable_episode_screen.dart';
import '../../providers/story.dart';
import '../../utils/debug_logger.dart';
import '../../services/ad_service.dart';
import '../../services/analytics_service.dart';

class LooseScreen extends StatelessWidget {
  static const routeName = '/loose-screen';

  const LooseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final story = Provider.of<Story>(context, listen: false);
    final episodeTitle = story.episode['title']?.toString() ?? 'This Chapter';

    // Track quiz failed event
    AnalyticsService.logQuizCompleted(quizType: 'episode', won: false);

    return Scaffold(
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
                        SizedBox(height: 20),

                        // "Almost there" icon
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
                                '"The master has failed more times than the beginner has tried."',
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
                              'Tip: Re-watch the video before answering',
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
                          onPressed: () {
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
                    // Try Again button (primary)
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 56,
                        margin: EdgeInsets.symmetric(horizontal: 6),
                        child: ElevatedButton(
                          onPressed: () => _tryAgain(context),
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
                                  color:
                                      Color(0xFFFFA500).withValues(alpha: 0.4),
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
                    // Gift button
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
                          onPressed: () {
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void goToEpisode(BuildContext context) {
    var _navArgs;
    _navArgs = ModalRoute.of(context)!.settings.arguments;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (_navArgs != 'deep_link') {
      Navigator.pushReplacementNamed(context, EpisodeScreen.routeName);
    } else {
      Navigator.of(context)
        ..pop()
        ..pop();
    }
  }

  void _tryAgain(BuildContext context) {
    DebugLogger.info('🔄 LooseScreen: Try Again button pressed');
    var _navArgs = ModalRoute.of(context)!.settings.arguments;
    DebugLogger.info('🔄 LooseScreen: Route arguments: $_navArgs');

    try {
      var story = Provider.of<Story>(context, listen: false);
      var currentEpisode = story.episode;

      if (currentEpisode.isNotEmpty) {
        DebugLogger.info('🔄 LooseScreen: Navigating back with same episode');
        DebugLogger.info(
            '🔄 LooseScreen: Episode data: ${currentEpisode['title']} (ID: ${currentEpisode['id']})');
        final season = story.selectedSeason;
        final isReadable = (season['content_type'] ?? 'video') == 'readable';
        Navigator.pushReplacementNamed(
          context,
          isReadable ? ReadableEpisodeScreen.routeName : VideoScreen.routeName,
          arguments: currentEpisode,
        );
      } else {
        DebugLogger.info(
            '🔄 LooseScreen: No current episode found, navigating to episodes list');
        goToEpisode(context);
      }
    } catch (e) {
      DebugLogger.error('🔄 LooseScreen: Error getting episode data: $e');
      goToEpisode(context);
    }
  }
}
