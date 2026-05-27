import 'package:baakhapaa/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../story/story_screen.dart';
// import './shorts_screen.dart';
import '../auth/login_screen.dart'; // Assuming you have a login screen
import '../../providers/video_state_provider.dart';
import '../../utils/debug_logger.dart';

class GuestWinnerScreen extends StatefulWidget {
  static const routeName = '/guest-winner-screen';

  const GuestWinnerScreen({Key? key}) : super(key: key);

  @override
  State<GuestWinnerScreen> createState() => _GuestWinnerScreenState();
}

class _GuestWinnerScreenState extends State<GuestWinnerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();

    // Stop background music when win screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final videoStateProvider =
            Provider.of<VideoStateProvider>(context, listen: false);
        DebugLogger.info(
            '🎵 GuestWinnerScreen: Stopping background music on win screen');
        videoStateProvider.forceStopAllRegisteredVideos();
        videoStateProvider.forceStopAllVideos();
        videoStateProvider.exitResultScreen();
        videoStateProvider.setScreen('win');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _collectReward() {
    // Navigate to login screen
    SharedPreferences.getInstance().then((sharedPreferences) {
      sharedPreferences.setBool('isWatched', true);
      Navigator.pushReplacement(
        context,
        PageTransition(
          child: LoginScreen(),
          type: PageTransitionType.bottomToTop,
        ),
      );
    });
  }

  // void _goToHome() {
  //   Navigator.pushReplacement(
  //     context,
  //     PageTransition(
  //       child: LoginScreen(),
  //       type: PageTransitionType.fade,
  //     ),
  //   );
  // }

  // void _goToShorts() {
  //   Navigator.pushReplacementNamed(context, ShortsScreen.routeName);
  // }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/win.gif"),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Header Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'C O N G R A T U L A T I O N !',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'You Won This Episode !!!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Trophy and Reward Section
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      children: [
                        Container(
                          width: screenWidth < 600
                              ? (0.4 * screenHeight)
                              : (0.3 * screenHeight),
                          height: screenWidth < 600 ? 250 : 300,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage("assets/images/Trophy.png"),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),

                        // Reward Points Display
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.amber, width: 2),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stars,
                                    color: Colors.amber,
                                    size: 30,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    '10 Sikka',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Earned!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Collect Reward Button
                        Container(
                          width: double.infinity,
                          height: 55,
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            onPressed: _collectReward,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.card_giftcard, size: 24),
                                SizedBox(width: 10),
                                Text(
                                  '${context.l10n.claim} ${context.l10n.reward}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 15),

                        Text(
                          'Sign in to collect your Sikka!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 30),

                        // Navigation Buttons
                      ],
                    ),
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
