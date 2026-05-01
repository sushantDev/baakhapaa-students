import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:baakhapaa/helpers/helpers.dart';

import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;

import '../../models/url.dart';
import '../../providers/auth.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../../utils/debug_logger.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: <String>[
    'email',
  ],
);

class LoginScreen extends StatefulWidget {
  static const routeName = '/login-screen';

  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  var _isLoading = false;
  bool _obscureText = true;
  String? _errorMessage;
  var _isInit = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Timer(Duration(seconds: 1), () async {
          _joinUsItsFree();
          _loadErrorMessage();
        });
      });
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _joinUsItsFree() async {
    // Initialize any needed preferences here if required
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Authentication Error'),
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

  Widget _buildAuthLoadingView(bool isDarkMode) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo/avatar area
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber.shade400,
                    Colors.amber.shade600,
                    Colors.orange.shade600,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Setting up your profile...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Just a moment while we get things ready',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void goToRegisterScreen() {
    Navigator.push(
        context,
        PageTransition(
          child: RegisterScreen(),
          type: PageTransitionType.rightToLeft,
        ));
  }

  void goToForgotPasswordScreen() {
    Navigator.push(
        context,
        PageTransition(
          child: ForgotPasswordScreen(),
          type: PageTransitionType.rightToLeft,
        ));
  }

  bool isEmailValid(String email) {
    return RegExp(
            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email);
  }

  // Helper function to derive a name from email address
  String deriveNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return '';

    // Extract the part before @ symbol
    final username = email.split('@').first;

    // Remove common patterns and numbers
    String cleanName = username
        .replaceAll(RegExp(r'[0-9]+'), '') // Remove numbers
        .replaceAll(RegExp(r'[._-]'),
            ' ') // Replace dots, underscores, hyphens with spaces
        .trim();

    // Handle common patterns like "firstname.lastname" or "first_last"
    if (cleanName.contains(' ')) {
      // Get only the first word (first name)
      final words = cleanName.split(' ').where((word) => word.isNotEmpty);
      if (words.isNotEmpty) {
        final firstName = words.first;
        return firstName[0].toUpperCase() +
            firstName.substring(1).toLowerCase();
      }
    } else {
      // For single words like "sushantsapkota", just take the first 7-8 characters
      // This will give us "Sushant" from "sushantsapkota"
      if (cleanName.length > 7) {
        cleanName = cleanName.substring(0, 7); // Take first 7 characters
      }

      // Capitalize first letter and make rest lowercase
      if (cleanName.isNotEmpty) {
        return cleanName[0].toUpperCase() +
            cleanName.substring(1).toLowerCase();
      }
    }

    return cleanName.isNotEmpty
        ? cleanName[0].toUpperCase() + cleanName.substring(1).toLowerCase()
        : '';
  }

  // Helper function to derive name from suggestions intelligently
  String deriveNameFromSuggestions(List<String> suggestions) {
    if (suggestions.isEmpty) return '';

    // Find the longest common prefix or most meaningful suggestion
    String bestSuggestion = suggestions.first;

    // Look for suggestions that might contain actual name parts
    for (String suggestion in suggestions) {
      // Remove numbers and special characters to get base name
      String cleanSuggestion = suggestion
          .replaceAll(RegExp(r'[0-9_]+$'), '')
          .replaceAll(RegExp(r'[._-]'), ' ')
          .trim();

      if (cleanSuggestion.length > 2 && cleanSuggestion.contains(' ')) {
        // If it contains spaces, it might be a name
        return cleanSuggestion.split(' ').map((word) {
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join(' ');
      } else if (cleanSuggestion.length > bestSuggestion.length) {
        bestSuggestion = cleanSuggestion;
      }
    }

    // Capitalize the best suggestion
    if (bestSuggestion.isNotEmpty) {
      return bestSuggestion[0].toUpperCase() +
          bestSuggestion.substring(1).toLowerCase();
    }

    return '';
  }

  Future<void> login() async {
    DebugLogger.auth('Login button pressed'); // Debug print

    if (!_formKey.currentState!.validate()) {
      DebugLogger.error('Form validation failed'); // Debug print
      return;
    }

    // Clear any previous error messages
    setState(() {
      _errorMessage = null;
    });

    DebugLogger.auth('Starting login process...'); // Debug print
    startOrStopLoading();

    final email = emailController.text.trim();
    final password = passwordController.text;

    try {
      var _authProvider = Provider.of<Auth>(context, listen: false);
      DebugLogger.auth('Calling auth provider login...'); // Debug print
      await _authProvider.login(email, password);
      DebugLogger.auth('Login successful!'); // Debug print

      // Immediately fetch updated user data after login
      // This ensures proper auth state and loading management
      await _authProvider.getUser();

      // Clear any pending referral codes since user is now logged in
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_referral_code');

      // Store onboarding selections + award 40 onboarding coins (idempotent)
      // ONBOARDING COMMENTED OUT
      // final auth = Provider.of<Auth>(context, listen: false);
      // await auth.storeOnboardingSelections();
      // if (prefs.getBool('claim_onboarding_reward') == true) {
      //   await auth.claimOnboardingReward();
      //   await prefs.remove('claim_onboarding_reward');
      // }

      // Navigate to UserScreen after successful login
      Navigator.of(context).pushNamedAndRemoveUntil(
        UserScreen.routeName,
        (route) => false, // This removes all previous routes
      );
    } catch (error) {
      DebugLogger.auth('Login error: $error'); // Debug print

      String errorMessage =
          'Authentication failed. Please double check your login credentials and try again.';

      // Handle specific error messages if your API returns them
      if (error.toString().contains('Invalid credentials')) {
        errorMessage = 'Invalid email or password. Please try again.';
      } else if (error.toString().contains('Network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }

      setState(() {
        _errorMessage = errorMessage;
      });

      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) {
        DebugLogger.info('Stopping loading state...'); // Debug print
        startOrStopLoading();
      }
    }
  }

  Future<void> _loadErrorMessage() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final errorMessage = prefs.getString('login_error');
    if (errorMessage != null && mounted) {
      setState(() {
        _errorMessage = errorMessage;
      });
      await prefs.remove('login_error');
    }
  }

  Future<void> signinGoogle() async {
    try {
      startOrStopLoading();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        startOrStopLoading();
        return;
      }

      final authProvider = Provider.of<Auth>(context, listen: false);
      final responseData = await authProvider.loginGoogle(
        googleUser.displayName ?? '',
        googleUser.email,
        googleUser.photoUrl ?? '',
        null,
      );

      // Handle different status cases from the response
      final status =
          (responseData['data'] as Map<String, dynamic>)['status'] as String;

      switch (status) {
        case 'existing':
          // Existing user - direct login
          // await Provider.of<Auth>(context, listen: false).loginGoogle(
          //   googleUser.displayName ?? '',
          //   googleUser.email,
          //   googleUser.photoUrl ?? '',
          //   null,
          // );
          break;

        case 'new':
          // New user - show username selection
          final suggestions =
              List<String>.from(responseData['data']['suggestions'] ?? []);
          final selectedUsername = await _showUsernameSelectionDialog(
            context,
            suggestions,
            googleUser.displayName ?? '',
          );

          if (selectedUsername != null) {
            await Provider.of<Auth>(context, listen: false).loginGoogle(
              googleUser.displayName ?? '',
              googleUser.email,
              googleUser.photoUrl ?? '',
              selectedUsername,
            );
          } else {
            // User cancelled username selection
            return;
          }
          break;

        case 'registered':
          // await Provider.of<Auth>(context, listen: false).loginGoogle(
          //   googleUser.displayName ?? '',
          //   googleUser.email,
          //   googleUser.photoUrl ?? '',
          //   null,
          // );
          break;

        default:
          throw Exception('Unknown status: $status');
      }

      // Clear any pending referral codes since user is now logged in
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_referral_code');

      // Store onboarding selections + award 40 onboarding coins (idempotent)
      // ONBOARDING COMMENTED OUT
      // await authProvider.storeOnboardingSelections();
      // if (prefs.getBool('claim_onboarding_reward') == true) {
      //   await authProvider.claimOnboardingReward();
      //   await prefs.remove('claim_onboarding_reward');
      // }

      // Navigate to UserScreen after successful authentication
      Navigator.of(context).pushNamedAndRemoveUntil(
        UserScreen.routeName,
        (route) => false,
      );
    } on PlatformException catch (e) {
      DebugLogger.error('Google Sign In platform error: $e');

      final message = e.message ?? '';
      final isAndroidConfigIssue =
          e.code == 'sign_in_failed' && message.contains('10');

      if (isAndroidConfigIssue) {
        _showErrorDialog(
          'Google Sign-In is not configured for this app build. '
          'Please verify package name and SHA fingerprints in Firebase Console.',
        );
      } else {
        _showErrorDialog('Google Sign In failed: ${e.toString()}');
      }
    } catch (e) {
      DebugLogger.error('Google Sign In error: $e');
      _showErrorDialog('Google Sign In failed: ${e.toString()}');
    } finally {
      startOrStopLoading();
    }
  }

  Future<String?> _showUsernameSelectionDialog(
    BuildContext context,
    List<String> suggestions,
    String defaultName,
  ) async {
    // Check if the default name is available
    String initialUsername = defaultName;
    bool initialAvailability = true;
    bool isChecking = true;

    // Check the default name availability first
    try {
      final authProvider = Provider.of<Auth>(context, listen: false);
      await authProvider.checkUsername(defaultName);
      initialAvailability = !authProvider.usernameExists;

      // If default name is not available, use first suggestion
      if (!initialAvailability && suggestions.isNotEmpty) {
        initialUsername = suggestions.first;
        // Check the first suggestion's availability too
        await authProvider.checkUsername(initialUsername);
        initialAvailability = !authProvider.usernameExists;
        DebugLogger.info(
            'Default name "$defaultName" taken, using suggestion: "$initialUsername"');
      }
    } catch (e) {
      DebugLogger.error('Error checking initial username: $e');
      initialAvailability = false;
      if (suggestions.isNotEmpty) {
        initialUsername = suggestions.first;
      }
    }

    final TextEditingController usernameController =
        TextEditingController(text: initialUsername);
    bool isAvailable = initialAvailability;
    isChecking = false;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Choose Username'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      errorText: !isAvailable ? 'Username already taken' : null,
                      suffixIcon: isChecking
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : usernameController.text.length > 2
                              ? Icon(
                                  isAvailable
                                      ? Icons.check_circle_outline
                                      : Icons.cancel_outlined,
                                  color:
                                      isAvailable ? Colors.green : Colors.red,
                                  size: 20,
                                )
                              : null,
                    ),
                    onChanged: (value) async {
                      if (value.length > 2) {
                        setState(() => isChecking = true);

                        // Use Auth provider to check username
                        try {
                          final authProvider =
                              Provider.of<Auth>(context, listen: false);
                          await authProvider.checkUsername(value);

                          // Update availability based on provider's usernameExists value
                          setState(() {
                            isAvailable = !authProvider.usernameExists;
                            isChecking = false;
                          });
                        } catch (e) {
                          setState(() {
                            isAvailable = false;
                            isChecking = false;
                          });
                          DebugLogger.error('Error checking username: $e');
                        }
                      } else {
                        setState(() {
                          isAvailable = true;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  if (suggestions.isNotEmpty) ...[
                    Text('Suggested usernames:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions.map((suggestion) {
                        return ActionChip(
                          label: Text(suggestion),
                          onPressed: () async {
                            // When suggestion is selected, check its availability
                            setState(() {
                              isChecking = true;
                              usernameController.text = suggestion;
                            });

                            try {
                              final authProvider =
                                  Provider.of<Auth>(context, listen: false);
                              await authProvider.checkUsername(suggestion);

                              setState(() {
                                isAvailable = !authProvider.usernameExists;
                                isChecking = false;
                              });
                            } catch (e) {
                              setState(() {
                                isAvailable = false;
                                isChecking = false;
                              });
                              DebugLogger.error(
                                  'Error checking username suggestion: $e');
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text('Continue'),
                  onPressed: isAvailable && !isChecking
                      ? () => Navigator.of(context).pop(usernameController.text)
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> signinApple() async {
    try {
      if (!await TheAppleSignIn.isAvailable()) {
        throw ('This Device is not eligible for Apple Sign in');
      }

      startOrStopLoading();

      final AuthorizationResult result = await TheAppleSignIn.performRequests([
        AppleIdRequest(requestedScopes: [Scope.email, Scope.fullName])
      ]);

      switch (result.status) {
        case AuthorizationStatus.authorized:
          final identityToken = Utf8Decoder()
              .convert(result.credential!.identityToken as List<int>);

          // Extract user information from Apple sign-in result with better fallback logic
          String? name;
          final givenName = result.credential?.fullName?.givenName;
          final familyName = result.credential?.fullName?.familyName;

          if (givenName != null && familyName != null) {
            name = '$givenName $familyName';
          } else if (givenName != null) {
            name = givenName;
          } else if (familyName != null) {
            name = familyName;
          }

          final String? email = result.credential?.email;

          // Debug logging to see what we get from Apple
          DebugLogger.info('Apple Sign-In - Name: $name, Email: $email');
          DebugLogger.info('Apple Sign-In - Given Name: $givenName');
          DebugLogger.info('Apple Sign-In - Family Name: $familyName');

          // Note: Apple only provides user info on first authorization
          // Subsequent sign-ins will have null values for privacy
          // The backend should decode the identity token to get user information
          // or store the name from the first login for future use

          // Pre-derive name from available sources before making API calls
          String derivedName = '';
          String emailToUse = email ?? ''; // Apple client-side email

          // 1. Use Apple's client-side name if available (first login only)
          if (name != null && name.isNotEmpty) {
            derivedName = name;
            DebugLogger.info('Using Apple client name: $derivedName');
          }

          // 2. If no name from Apple, try to derive from email
          if (derivedName.isEmpty && emailToUse.isNotEmpty) {
            derivedName = deriveNameFromEmail(emailToUse);
            DebugLogger.info(
                'Derived name from Apple email ($emailToUse): $derivedName');
          }

          final authProvider = Provider.of<Auth>(context, listen: false);

          // Step 1: Make initial API call to get email from backend token decoding
          Map<String, dynamic> responseData = await authProvider.loginApple(
            identityToken,
            derivedName, // Pass any client-side derived name
            email,
            null,
          );

          // Step 2: If we still don't have a name, derive it from backend email response
          // and make another API call with the derived name for better suggestions
          if (derivedName.isEmpty) {
            final data = responseData['data'] as Map<String, dynamic>?;
            final backendEmail = data?['email'] as String?;

            if (backendEmail != null && backendEmail.isNotEmpty) {
              derivedName = deriveNameFromEmail(backendEmail);
              DebugLogger.info(
                  'Derived name from backend email ($backendEmail): $derivedName');
              emailToUse = backendEmail; // Update email to use

              // Make a second API call with the derived name for better suggestions
              if (derivedName.isNotEmpty) {
                DebugLogger.info(
                    'Making second API call with derived name: $derivedName');
                responseData = await authProvider.loginApple(
                  identityToken,
                  derivedName,
                  backendEmail,
                  null,
                );
              }
            }
          }

          DebugLogger.info('Final derived name: "$derivedName"');

          // Debug logging to see API response
          DebugLogger.info('Apple API Response: ${responseData.toString()}');
          DebugLogger.info('API Response Data: ${responseData['data']}');
          DebugLogger.info(
              'API Response Name: ${responseData['data']?['name']}');
          DebugLogger.info(
              'API Response Suggestions: ${responseData['data']?['suggestions']}');

          // Handle different status cases from the response
          final data = responseData['data'] as Map<String, dynamic>?;
          if (data == null) {
            throw Exception('Invalid response data from Apple login API');
          }

          final status = data['status'] as String?;
          if (status == null) {
            throw Exception('Missing status in Apple login response');
          }

          DebugLogger.info('Apple login status: $status');

          switch (status) {
            case 'existing':
              // Existing user - direct login
              break;

            case 'new':
              // New user - show username selection
              final suggestions = List<String>.from(data['suggestions'] ?? []);

              // Multi-layered approach to get the user's name
              String defaultNameForDialog = '';

              // 1. Primary: Get from API response (backend decoded the token)
              defaultNameForDialog = data['name'] as String? ?? '';
              DebugLogger.info('Name from API: $defaultNameForDialog');

              // 2. Secondary: Use the pre-derived name from Apple or email
              if (defaultNameForDialog.isEmpty && derivedName.isNotEmpty) {
                defaultNameForDialog = derivedName;
                DebugLogger.info(
                    'Using pre-derived name: $defaultNameForDialog');
              }

              // 3. Tertiary: Update email source if needed
              // If Apple client-side email was empty, use API response email
              if (emailToUse.isEmpty) {
                emailToUse = data['email'] as String? ?? '';
              }

              // 4. Quaternary: Try to derive from API email if still no name
              if (defaultNameForDialog.isEmpty && emailToUse.isNotEmpty) {
                defaultNameForDialog = deriveNameFromEmail(emailToUse);
                DebugLogger.info(
                    'Name derived from API email ($emailToUse): $defaultNameForDialog');
              }

              // 5. Quinary: Derive from username suggestions
              if (defaultNameForDialog.isEmpty && suggestions.isNotEmpty) {
                defaultNameForDialog = deriveNameFromSuggestions(suggestions);
                DebugLogger.info(
                    'Name derived from suggestions: $defaultNameForDialog');
              }

              // 6. Final fallback: Use a generic name
              if (defaultNameForDialog.isEmpty) {
                defaultNameForDialog = 'User';
                DebugLogger.info('Using fallback name: User');
              }

              DebugLogger.info(
                  'Final name for dialog: "$defaultNameForDialog"');

              final selectedUsername = await _showUsernameSelectionDialog(
                context,
                suggestions,
                defaultNameForDialog,
              );

              if (selectedUsername != null) {
                // Use the final derived name for the second API call
                final String nameToUse = defaultNameForDialog.isNotEmpty
                    ? defaultNameForDialog
                    : derivedName;
                DebugLogger.info('Using name for final API call: $nameToUse');

                await Provider.of<Auth>(context, listen: false).loginApple(
                  identityToken,
                  nameToUse, // Pass the final derived name here
                  emailToUse.isNotEmpty
                      ? emailToUse
                      : email, // Use the email we found
                  selectedUsername,
                );
              } else {
                // User cancelled username selection
                return;
              }
              break;

            case 'registered':
              // User already registered - direct login
              break;

            default:
              throw Exception('Unknown status: $status');
          }

          // Clear any pending referral codes since user is now logged in
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pending_referral_code');

          // Store onboarding selections + award 40 onboarding coins (idempotent)
          // ignore: unused_local_variable
          final authSvc = Provider.of<Auth>(context, listen: false);
          // ONBOARDING COMMENTED OUT
          // await authSvc.storeOnboardingSelections();
          // if (prefs.getBool('claim_onboarding_reward') == true) {
          //   await authSvc.claimOnboardingReward();
          //   await prefs.remove('claim_onboarding_reward');
          // }

          // Navigate to UserScreen after successful authentication
          Navigator.of(context).pushNamedAndRemoveUntil(
            UserScreen.routeName,
            (route) => false,
          );
          break;

        case AuthorizationStatus.error:
          _showErrorDialog('Apple sign in failed');
          break;
        case AuthorizationStatus.cancelled:
          _showErrorDialog('Apple sign in cancelled');
          break;
      }
    } catch (e) {
      DebugLogger.error('Apple Sign In error: $e');
      _showErrorDialog('Apple Sign In failed: ${e.toString()}');
    } finally {
      startOrStopLoading();
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
            ? _buildAuthLoadingView(isDarkMode)
            : SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(height: 30),

                        // Logo Section - Matching story_screen colors
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Column(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
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
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'assets/images/sikka2.jpeg',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Skill Sikka',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Knowledge, Action & Rewards',
                                  style: TextStyle(
                                    fontSize: 13,
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

                        // Welcome Text - Modern with better spacing
                        // Text(
                        //   'Welcome Back!',
                        //   style: TextStyle(
                        //     fontSize: 28,
                        //     fontWeight: FontWeight.bold,
                        //     fontFamily: 'Montserrat',
                        //     color:
                        //         isDarkMode ? Colors.white : Colors.grey.shade800,
                        //   ),
                        // ),
                        // SizedBox(height: 8),
                        // Padding(
                        //   padding: EdgeInsets.symmetric(horizontal: 10),
                        //   child: Text(
                        //     'Sign in to continue your amazing journey of entertainment and learning',
                        //     style: TextStyle(
                        //       fontSize: 14,
                        //       fontFamily: 'Montserrat',
                        //       color: Colors.grey.shade600,
                        //       height: 1.3,
                        //     ),
                        //     textAlign: TextAlign.center,
                        //     maxLines: 2,
                        //     overflow: TextOverflow.ellipsis,
                        //   ),
                        // ),

                        // SizedBox(height: 40),

                        // Login Form - Ultra Modern Design with Enhanced Premium Look
                        Container(
                          padding: EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey.shade900.withValues(alpha: 0.75)
                                : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.15),
                                blurRadius: 32,
                                offset: Offset(0, 16),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Email Field - Ultra Modern
                              Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
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
                                    hintText: context.l10n.email,
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
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.email_outlined,
                                        color: Colors.amber.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 18),
                                  ),
                                ),
                              ),

                              SizedBox(height: 20),

                              // Password Field - Ultra Modern
                              Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: TextFormField(
                                  controller: passwordController,
                                  obscureText: _obscureText,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
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
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.lock_outline,
                                        color: Colors.amber.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureText
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey.shade500,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureText = !_obscureText;
                                        });
                                      },
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 18),
                                  ),
                                ),
                              ),

                              SizedBox(height: 32),

                              // Login Button - Enhanced Premium Design with Loading State
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: _isLoading
                                      ? null
                                      : LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.amber.shade400,
                                            Colors.amber.shade600,
                                            Colors.orange.shade600,
                                          ],
                                        ),
                                  color:
                                      _isLoading ? Colors.grey.shade300 : null,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: _isLoading
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: Colors.amber
                                                .withValues(alpha: 0.4),
                                            blurRadius: 16,
                                            offset: Offset(0, 8),
                                          ),
                                        ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isLoading ? null : login,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: _isLoading
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            Colors.white),
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Text(
                                                  '${context.l10n.signInTitle}...',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Montserrat',
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              '${context.l10n.signInTitle}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Montserrat',
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: 20),

                              // Error Message Display
                              if (_errorMessage != null)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12),
                                  margin: EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red.shade600,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 13,
                                            fontFamily: 'Montserrat',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Forgot Password - Elegant
                              TextButton(
                                onPressed: goToForgotPasswordScreen,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                child: Text(
                                  '${context.l10n.forgotPasswordLink} ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Montserrat',
                                    color: Colors.amber.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 32),

                        // Social Login Section - Modern & Platform Specific
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.black.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.amber.withValues(alpha: 0.3)
                                  : Colors.grey.shade300.withValues(alpha: 0.8),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${context.l10n.or} ${context.l10n.continueButton} ${context.l10n.withString}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontFamily: 'Montserrat',
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 16),
                              // Platform specific login buttons
                              if (Platform.isAndroid)
                                // Google Login for Android
                                Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: signinGoogle,
                                      borderRadius: BorderRadius.circular(14),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.red.shade400,
                                                  Colors.red.shade600
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.g_mobiledata,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            '${context.l10n.continueButton} ${context.l10n.withString}Google',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (Platform.isIOS)
                                // Apple Login for iOS
                                Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: signinApple,
                                      borderRadius: BorderRadius.circular(14),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.apple,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            '${context.l10n.continueButton} ${context.l10n.withString} Apple',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        SizedBox(height: 30),

                        // Register Link - Matching story_screen colors
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
                                "${context.l10n.dontHaveAccount} ",
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
                                onTap: goToRegisterScreen,
                                child: Text(
                                  context.l10n.signUpTitle,
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

                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
