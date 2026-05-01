import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth.dart';
import '../../utils/debug_logger.dart';
import '../../widgets/skeleton_loading.dart';
import '../story/story_screen.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class RegisterWithReferralScreen extends StatefulWidget {
  static const routeName = '/register-with-referral';

  const RegisterWithReferralScreen({Key? key}) : super(key: key);

  @override
  State<RegisterWithReferralScreen> createState() =>
      _RegisterWithReferralScreenState();
}

class _RegisterWithReferralScreenState
    extends State<RegisterWithReferralScreen> {
  String? referralCode;
  bool _isLoading = true;

  @override
  void initState() {
    DebugLogger.info("📱 RegisterWithReferralScreen.initState() - Starting");
    super.initState();
    _checkReferralAndUser();
  }

  Future<void> _checkReferralAndUser() async {
    DebugLogger.info(
        "🔍 RegisterWithReferralScreen._checkReferralAndUser() - Starting validation");
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingReferral = prefs.getString('pending_referral_code');
      final authData = prefs.getString('userData');
      final referralTimestamp = prefs.getInt('pending_referral_timestamp') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final oneMinute = 60 * 1000; // 1 minute in milliseconds

      DebugLogger.info(
          "🔍 RegisterWithReferralScreen - Pending referral: $pendingReferral");
      DebugLogger.info(
          "🔍 RegisterWithReferralScreen - Auth data exists: ${authData != null && authData.isNotEmpty}");
      DebugLogger.info(
          "🔍 RegisterWithReferralScreen - Referral timestamp: $referralTimestamp");
      DebugLogger.info(
          "🔍 RegisterWithReferralScreen - Current time: $currentTime");
      DebugLogger.info(
          "🔍 RegisterWithReferralScreen - Time diff: ${currentTime - referralTimestamp}ms");
      DebugLogger.info(
          "🔍 RegisterWithReferralScreen - Is stale: ${referralTimestamp == 0 || currentTime - referralTimestamp > oneMinute}");

      // If there's no pending referral, or it's stale, this screen shouldn't be shown
      if (pendingReferral == null ||
          pendingReferral.isEmpty ||
          (referralTimestamp > 0 &&
              currentTime - referralTimestamp > oneMinute)) {
        DebugLogger.info(
            "❌ RegisterWithReferralScreen - No valid referral found, redirecting");
        DebugLogger.info(
            "No valid pending referral found, redirecting to appropriate screen");

        // Clear any stale referral data
        await prefs.remove('pending_referral_code');
        await prefs.remove('pending_referral_timestamp');
        DebugLogger.info(
            "🧹 RegisterWithReferralScreen - Cleared stale referral data");

        if (authData != null && authData.isNotEmpty) {
          // User is authenticated, go to story screen
          DebugLogger.info(
              "📱 RegisterWithReferralScreen - Redirecting authenticated user to story screen");
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(StoryScreen.routeName);
          }
        } else {
          // User is not authenticated, go to login screen
          DebugLogger.info(
              "📱 RegisterWithReferralScreen - Redirecting unauthenticated user to login screen");
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
          }
        }
        return;
      }

      DebugLogger.info(
          "✅ RegisterWithReferralScreen - Valid referral found, continuing with screen");
      setState(() {
        referralCode = pendingReferral;
        _isLoading = false;
      });

      // If user is already logged in, handle referral differently
      if (authData != null && authData.isNotEmpty) {
        DebugLogger.info(
            "👤 RegisterWithReferralScreen - User has auth data, checking authentication");
        final auth = Provider.of<Auth>(context, listen: false);

        // Ensure auth state is properly loaded
        await auth.tryAutoLogin();
        DebugLogger.info(
            "👤 RegisterWithReferralScreen - Auth.isAuth: ${auth.isAuth}");
        DebugLogger.info(
            "👤 RegisterWithReferralScreen - Auth.hasReferral: ${auth.hasReferral}");

        if (auth.isAuth) {
          if (!auth.hasReferral) {
            // User is logged in but doesn't have a referral, apply it
            DebugLogger.info(
                "🎯 RegisterWithReferralScreen - Applying referral to authenticated user");
            try {
              await auth.checkUsername(pendingReferral);
              DebugLogger.info(
                  "👤 RegisterWithReferralScreen - Username exists: ${auth.usernameExists}");
              if (auth.usernameExists) {
                DebugLogger.info(
                    "✅ RegisterWithReferralScreen - Setting referral code");
                await auth.setReferCode(pendingReferral);
                await auth.getUser(); // Refresh user data

                // Clear the pending referral
                await prefs.remove('pending_referral_code');
                await prefs.remove('pending_referral_timestamp');
                DebugLogger.info(
                    "🧹 RegisterWithReferralScreen - Cleared pending referral after applying");

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Referral code applied successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  DebugLogger.info(
                      "📱 RegisterWithReferralScreen - Navigating to story screen after successful referral");
                  Navigator.of(context)
                      .pushReplacementNamed(StoryScreen.routeName);
                }
              } else {
                // Invalid referral code, clear it and go to home
                DebugLogger.info(
                    "❌ RegisterWithReferralScreen - Invalid referral code");
                await prefs.remove('pending_referral_code');
                await prefs.remove('pending_referral_timestamp');
                DebugLogger.info(
                    "🧹 RegisterWithReferralScreen - Cleared invalid referral code");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invalid referral code'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  DebugLogger.info(
                      "📱 RegisterWithReferralScreen - Navigating to story screen after invalid referral");
                  Navigator.of(context)
                      .pushReplacementNamed(StoryScreen.routeName);
                }
              }
            } catch (e) {
              DebugLogger.error('Error applying referral: $e');
              DebugLogger.info(
                  "💥 RegisterWithReferralScreen - Error applying referral: $e");
              // Clear pending referral on error
              await prefs.remove('pending_referral_code');
              await prefs.remove('pending_referral_timestamp');
              DebugLogger.info(
                  "🧹 RegisterWithReferralScreen - Cleared pending referral after error");
              if (mounted) {
                DebugLogger.info(
                    "📱 RegisterWithReferralScreen - Navigating to story screen after error");
                Navigator.of(context)
                    .pushReplacementNamed(StoryScreen.routeName);
              }
            }
          } else {
            DebugLogger.info(
                "⚠️ RegisterWithReferralScreen - User already has a referral, clearing pending");
            // User already has referral, clear pending referral and go to home
            await prefs.remove('pending_referral_code');
            await prefs.remove('pending_referral_timestamp');
            DebugLogger.info(
                "🧹 RegisterWithReferralScreen - Cleared pending referral (user has existing)");
            if (mounted) {
              DebugLogger.info(
                  "📱 RegisterWithReferralScreen - Navigating to story screen (user has existing referral)");
              Navigator.of(context).pushReplacementNamed(StoryScreen.routeName);
            }
          }
        } else {
          DebugLogger.info(
              "⚠️ RegisterWithReferralScreen - User has auth data but not authenticated");
          // Auth data exists but user is not authenticated, clear auth data and continue with referral flow
          await prefs.remove('userData');
          DebugLogger.info(
              "Cleared invalid auth data, continuing with referral flow");
          DebugLogger.info(
              "🧹 RegisterWithReferralScreen - Cleared invalid auth data, continuing with referral flow");
        }
      }
    } catch (e) {
      DebugLogger.error('Error checking referral: $e');
      // Clear any pending data on error and redirect appropriately
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_referral_code');
      await prefs.remove('pending_referral_timestamp');

      // Check if user should go to login or story screen
      final authData = prefs.getString('userData');
      if (mounted) {
        if (authData != null && authData.isNotEmpty) {
          Navigator.of(context).pushReplacementNamed(StoryScreen.routeName);
        } else {
          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: ListSkeleton(itemCount: 4)),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade100,
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo or icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.people,
                    size: 60,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 32),

                // Welcome message
                Text(
                  '🎉 You\'ve been invited!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 16),

                if (referralCode != null)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Referral Code:',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          referralCode!,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 24),

                Text(
                  'Join Skill Sikka and get min 25 bonus points when you complete registration!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 40),

                // Register button
                Container(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      DebugLogger.info(
                          "🔘 RegisterWithReferralScreen - Create Account button pressed");
                      DebugLogger.info(
                          "🔘 RegisterWithReferralScreen - Navigating to RegisterScreen with referral: $referralCode");
                      Navigator.of(context).pushNamed(
                        RegisterScreen.routeName,
                        arguments: referralCode,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    icon: Icon(Icons.person_add, size: 24),
                    label: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Login button
                Container(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      DebugLogger.info(
                          "🔘 RegisterWithReferralScreen - Already have account button pressed");
                      // Clear pending referral first
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('pending_referral_code');
                      await prefs.remove('pending_referral_timestamp');
                      DebugLogger.info(
                          "🧹 RegisterWithReferralScreen - Cleared pending referral before login");

                      DebugLogger.info(
                          "📱 RegisterWithReferralScreen - Navigating to LoginScreen");
                      Navigator.of(context)
                          .pushReplacementNamed(LoginScreen.routeName);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                      side: BorderSide(color: Colors.blue.shade600, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(Icons.login, size: 24),
                    label: Text(
                      'Already have an account?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Skip option
                TextButton(
                  onPressed: () async {
                    DebugLogger.info(
                        "🔘 RegisterWithReferralScreen - Skip for now button pressed");
                    // Clear pending referral and go to proper authentication flow
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('pending_referral_code');
                    await prefs.remove('pending_referral_timestamp');
                    DebugLogger.info(
                        "🧹 RegisterWithReferralScreen - Cleared pending referral (skip)");

                    // Check if user is authenticated
                    final auth = Provider.of<Auth>(context, listen: false);
                    DebugLogger.info(
                        "👤 RegisterWithReferralScreen - Checking auth state for skip: ${auth.isAuth}");
                    if (auth.isAuth) {
                      DebugLogger.info(
                          "📱 RegisterWithReferralScreen - User authenticated, navigating to StoryScreen");
                      Navigator.of(context)
                          .pushReplacementNamed(StoryScreen.routeName);
                    } else {
                      DebugLogger.info(
                          "📱 RegisterWithReferralScreen - User not authenticated, navigating to LoginScreen");
                      // Not authenticated, go to login screen
                      Navigator.of(context)
                          .pushReplacementNamed(LoginScreen.routeName);
                    }
                  },
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
