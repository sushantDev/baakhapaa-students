import 'package:baakhapaa/helpers/helpers.dart';

import '../../widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/url.dart';
import '../../providers/auth.dart';
import '../../providers/story.dart';
import '../../providers/challenge.dart';
import '../../utils/debug_logger.dart';
import './login_screen.dart';
import '../story/story_screen.dart';

class RegisterScreen extends StatefulWidget {
  static const routeName = '/register-screen';

  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isChecked = false;
  bool _showPassword = false;
  String? _referralCode;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if referral code was passed as route argument
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String) {
      _referralCode = args;
    }

    // Fallback: load from SharedPreferences (set by deep link handler)
    if (_referralCode == null || _referralCode!.isEmpty) {
      SharedPreferences.getInstance().then((prefs) {
        final pending = prefs.getString('pending_referral_code');
        if (pending != null && pending.isNotEmpty && mounted) {
          setState(() => _referralCode = pending);
        }
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Registration Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Okay', style: TextStyle(color: Colors.amber.shade600)),
          ),
        ],
      ),
    );
  }

  void startOrStopLoading() {
    setState(() {
      _isLoading = !_isLoading;
    });
  }

  void goToLoginScreen() {
    Navigator.push(
        context,
        PageTransition(
          child: LoginScreen(),
          type: PageTransitionType.leftToRight,
        ));
  }

  bool isEmailValid(String email) {
    // ignore: deprecated_member_use
    return RegExp(
            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);
  }

  Future<void> register() async {
    if (_formKey.currentState!.validate()) {
      if (!_isChecked) {
        _showErrorDialog('Please accept Terms & Conditions to continue.');
        return;
      }

      startOrStopLoading();
      final name = nameController.text;
      final email = emailController.text;
      final password = passwordController.text;

      try {
        var _authProvider = Provider.of<Auth>(context, listen: false);
        await _authProvider.register(name, email, password);

        // Immediately fetch updated user data after registration
        await _authProvider.getUser();

        // If there's a referral code, apply it after successful registration
        if (_referralCode != null && _referralCode!.isNotEmpty) {
          try {
            await _authProvider.checkUsername(_referralCode!);
            if (_authProvider.usernameExists) {
              await _authProvider.changeFirstLoginStatus();
              await _authProvider.setReferCode(_referralCode!);

              // Refresh user data to reflect referral
              await _authProvider.getUser();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Registration successful! Referral code applied. You received 25 bonus points!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          } catch (referralError) {
            // Don't fail registration if referral fails, just show a warning
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Registration successful, but referral code could not be applied.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }

        // Only navigate to StoryScreen if registration is successful
        // Clear any pending referral codes since user is now registered and logged in
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_referral_code');

        // Store onboarding selections + award 40 onboarding coins (idempotent)
        final authProvider = Provider.of<Auth>(context, listen: false);
        await authProvider.storeOnboardingSelections();
        if (prefs.getBool('claim_onboarding_reward') == true) {
          await authProvider.claimOnboardingReward();
          await prefs.remove('claim_onboarding_reward');
        }

        // Pre-fetch story data before navigation to prevent loading state
        if (mounted) {
          try {
            final storyProvider = Provider.of<Story>(context, listen: false);
            final challengeProvider =
                Provider.of<Challenge>(context, listen: false);

            // Fetch initial data in parallel to reduce wait time
            await Future.wait([
              storyProvider.fetchFeaturedSeasons().catchError((e) {
                DebugLogger.error('Pre-fetch featured seasons failed: $e');
                return Future.value();
              }),
              storyProvider.fetchSuggestedSeasons().catchError((e) {
                DebugLogger.error('Pre-fetch suggested seasons failed: $e');
                return Future.value();
              }),
              challengeProvider.fetchChallenges().catchError((e) {
                DebugLogger.error('Pre-fetch challenges failed: $e');
                return Future.value();
              }),
            ]);

            DebugLogger.info('✅ Story data pre-fetched successfully');
          } catch (e) {
            DebugLogger.error('Pre-fetch error: $e');
            // Continue with navigation even if pre-fetch fails
          }
        }

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          PageTransition(
            child: StoryScreen(),
            type: PageTransitionType.rightToLeft,
          ),
          (route) => false,
        );
      } catch (error) {
        // Log the actual error for debugging
        DebugLogger.info('❌ REGISTRATION ERROR: $error');
        DebugLogger.info('❌ ERROR TYPE: ${error.runtimeType}');

        // Handle specific error cases
        String errorMessage = 'Registration failed. Please try again later.';

        // Check for duplicate username error (most common)
        if (error.toString().contains('Duplicate entry') &&
            error.toString().contains('users_username_unique')) {
          errorMessage =
              'This name is already taken. Your name is used to create your unique username.\n\nPlease enter a different name or add numbers/initials to make it unique (e.g., "Sushant Sapkota 2" or "S Sapkota").';
        } else if (error.toString().contains('email has already been taken') ||
            (error.toString().contains('Duplicate entry') &&
                error.toString().contains('email'))) {
          errorMessage =
              'This email is already registered. Please use a different email address.';
        } else if (error.toString().contains('username field is required')) {
          errorMessage =
              'Name is required. Please enter your full name to create your username.';
        } else if (error.toString().contains('role field is required')) {
          errorMessage =
              'Registration failed due to missing information. Please try again.';
        } else if (error is Map && error.containsKey('errors')) {
          // Handle validation errors from API
          Map<String, dynamic> errors = error['errors'];
          List<String> errorMessages = [];

          errors.forEach((field, messages) {
            if (messages is List) {
              errorMessages.addAll(messages.cast<String>());
            }
          });

          if (errorMessages.isNotEmpty) {
            errorMessage = errorMessages.join('\n');
          }
        } else if (error is Map && error.containsKey('message')) {
          // Handle API error message
          errorMessage = error['message'].toString();
        }

        _showErrorDialog(errorMessage);
      } finally {
        if (mounted) {
          startOrStopLoading();
        }
      }
    }
  }

  void openTermsAndConditions() async {
    const url = 'https://sites.google.com/view/baakhapaa-privacy-policy/home';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    }
  }

  void openPrivacyPolicy() async {
    const url = 'https://sites.google.com/view/baakhapaa-privacy-policy/home';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
          image: DecorationImage(
            opacity: 0.5,
            image:
                CachedNetworkImageProvider("${Url.mediaUrl}/assets/sketch.png"),
            fit: BoxFit.fill,
          ),
        ),
        child: _isLoading
            ? Loading()
            : SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(height: 30),

                        // Logo Section - Professional
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 25),
                          child: Column(
                            children: [
                              Container(
                                width: 85,
                                height: 85,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey.shade800
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDarkMode
                                          ? Colors.black.withValues(alpha: 0.3)
                                          : Colors.grey.withValues(alpha: 0.2),
                                      blurRadius: 16,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.asset(
                                    'assets/images/logo-lony.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              SizedBox(height: 18),
                              Text(
                                'BAAKHAPAA',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              SizedBox(height: 6),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  'Join the Amazing Community!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Montserrat',
                                    color: Colors.amber.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 10),

                        // Welcome Text - Modern with better spacing and visibility
                        Text(
                          '${context.l10n.createAccountButton}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                            color: isDarkMode
                                ? Colors.white
                                : Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.black.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            context.l10n.startJourney,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Montserrat',
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.grey.shade800,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        SizedBox(height: 35),

                        // Registration Form - Matching story_screen colors
                        Container(
                          padding: EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey.shade900.withValues(alpha: 0.75)
                                : Colors.white.withValues(alpha: 0.98),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.15),
                                blurRadius: 28,
                                offset: Offset(0, 14),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 14,
                                offset: Offset(0, 7),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 7,
                                offset: Offset(0, 3),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Name Field - Matching story_screen colors
                              Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: TextFormField(
                                  controller: nameController,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your full name';
                                    }
                                    return null;
                                  },
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 15,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'User Name',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Montserrat',
                                      color: Colors.grey.shade500,
                                      fontSize: 15,
                                    ),
                                    prefixIcon: Container(
                                      margin: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Icon(
                                        Icons.person_outline,
                                        color: Colors.amber.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 16),
                                  ),
                                ),
                              ),

                              // Helper text for username
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, top: 4),
                                child: Text(
                                  'This will be your unique username',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 11,
                                    color: Colors.amber.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),

                              SizedBox(height: 18),

                              // Email Field - Matching story_screen colors
                              Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!isEmailValid(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 15,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '${context.l10n.email}',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Montserrat',
                                      color: Colors.grey.shade500,
                                      fontSize: 15,
                                    ),
                                    prefixIcon: Container(
                                      margin: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Icon(
                                        Icons.email_outlined,
                                        color: Colors.amber.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 16),
                                  ),
                                ),
                              ),

                              SizedBox(height: 18),

                              // Password Field - Matching story_screen colors
                              Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: TextFormField(
                                  controller: passwordController,
                                  obscureText:
                                      !_showPassword, // Fixed: Use !_showPassword instead of _showPassword
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 15,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context.l10n.password,
                                    hintStyle: TextStyle(
                                      fontFamily: 'Montserrat',
                                      color: Colors.grey.shade500,
                                      fontSize: 15,
                                    ),
                                    prefixIcon: Container(
                                      margin: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Icon(
                                        Icons.lock_outline,
                                        color: Colors.amber.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showPassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.grey.shade500,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showPassword = !_showPassword;
                                        });
                                      },
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 16),
                                  ),
                                ),
                              ),

                              SizedBox(height: 20),

                              // Terms & Conditions Checkbox - Modern
                              Row(
                                children: [
                                  Transform.scale(
                                    scale: 1.1,
                                    child: Checkbox(
                                      value: _isChecked,
                                      onChanged: (value) {
                                        setState(() {
                                          _isChecked = value!;
                                        });
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      activeColor: isDarkMode
                                          ? Colors.amber
                                          : Color(0xff24b7c1),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Wrap(
                                      children: [
                                        Text(
                                          '${context.l10n.iAgreeToThe} ',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontFamily: 'Montserrat',
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: openTermsAndConditions,
                                          child: Text(
                                            'Terms & Conditions',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'Montserrat',
                                              color: isDarkMode
                                                  ? Colors.amber
                                                  : Color(0xff24b7c1),
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          ' ${context.l10n.and} ',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontFamily: 'Montserrat',
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: openPrivacyPolicy,
                                          child: Text(
                                            'Privacy Policy',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'Montserrat',
                                              color: isDarkMode
                                                  ? Colors.amber
                                                  : Color(0xff24b7c1),
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 28),

                              // Register Button - Matching story_screen colors
                              Container(
                                width: double.infinity,
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.amber.shade400,
                                      Colors.amber.shade600,
                                      Colors.orange.shade600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.amber.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: Text(
                                    '${context.l10n.createAccountButton}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Montserrat',
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 25),

                        // Login Link - Matching story_screen colors
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.black.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${context.l10n.alreadyHaveAccount}",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontFamily: 'Montserrat',
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: goToLoginScreen,
                                child: Text(
                                  '${context.l10n.signInTitle}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontFamily: 'Montserrat',
                                    color: Colors.amber.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 35),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
