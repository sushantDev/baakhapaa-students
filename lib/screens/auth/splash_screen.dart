import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/shorts/shorts_screen.dart';
import '../../screens/user/user_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = '/splash';

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    // Fade in → hold → fade out
    _fadeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 35),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
    _animController.forward().whenComplete(_navigateAfterSplash);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterSplash() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();

    // Deep link present — skip onboarding, go to login/register directly
    final immediateNav = prefs.getString('immediate_navigation') ?? '';
    final pendingReferral = prefs.getString('pending_referral_code') ?? '';
    if (immediateNav.isNotEmpty || pendingReferral.isNotEmpty) {
      if (!mounted) return;
      // Mark onboarding as completed so it doesn't show after login
      await prefs.setBool('onboarding_completed', true);
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      return;
    }

    // Returning user — skip onboarding
    if (prefs.getBool('onboarding_completed') == true) {
      final auth = Provider.of<Auth>(context, listen: false);
      final loggedIn = await auth.tryAutoLogin();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        loggedIn ? UserScreen.routeName : ShortsScreen.routeName,
      );
      return;
    }

    // First launch — show onboarding (slides are built-in, no fetch needed)
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(OnboardingScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Image.asset(
            'assets/images/logo-lony.png',
            width: 260,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.play_circle_fill,
              size: 80,
              color: Color(0xFFF4B625),
            ),
          ),
        ),
      ),
    );
  }
}
