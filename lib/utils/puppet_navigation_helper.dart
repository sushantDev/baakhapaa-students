import 'package:baakhapaa/screens/challenges/all_challenges_screen.dart';
import 'package:flutter/material.dart';
import '../navigation/root_navigator_key.dart'; // mainNavigatorKey
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/verify_otp_screen.dart';
import '../screens/story/story_screen.dart';
import '../screens/story/episode_screen.dart';
import '../screens/story/video_screen.dart';
import '../screens/story/question_screen.dart';
import '../screens/story/win_screen.dart';
import '../screens/story/loose_screen.dart';
import '../screens/story/creator_story_screen.dart';
import '../screens/shop/shop_screen.dart';
import '../screens/shop/single_product_screen.dart';
import '../screens/shop/cart_screen.dart';
import '../screens/shop/search_product_screen.dart';
import '../screens/shop/vendor_product_screen.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/gift/gift_screen.dart';
import '../screens/gift/single_gift_screen.dart';
import '../screens/user/user_screen.dart';
import '../screens/user/edit_profile_screen.dart';
import '../screens/user/user_details_screen.dart';
import '../screens/user/point_logs_screen.dart';
import '../screens/user/orders_screen.dart';
import '../screens/user/setting_screen.dart';
import '../screens/user/levels_screen.dart';
import '../screens/user/weekly_rewards_screen.dart';
import '../screens/user/points_screen.dart';
import '../screens/user/achievements_screen.dart';
import '../screens/user/address_screen.dart';
import '../screens/others/ads_screen.dart';
import '../screens/others/contact_us_screen.dart';
import '../screens/others/notification_screen.dart';
import '../screens/others/referrals_screen.dart';
import '../screens/others/intro_screen.dart';
import '../screens/shorts/shorts_screen.dart';
import '../screens/shorts/shorts_question_screen.dart';
import '../screens/shorts/shorts_loose_screen.dart';
import '../screens/shorts/shorts_win_screen.dart';
import '../screens/shorts/single_shorts_screen.dart';
import '../screens/shorts/guest_win_screen.dart';
import '../screens/discover/discover_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/messages/conversations_screen.dart';
import '../utils/debug_logger.dart';

/// Utility class to handle navigation for puppet interactions
class PuppetNavigationHelper {
  /// Map of screen names to their route names
  static final Map<String, String> _screenRouteMap = {
    // Auth screens
    'welcome_screen': WelcomeScreen.routeName,
    'login_screen': LoginScreen.routeName,
    'register_screen': RegisterScreen.routeName,
    'onboarding_screen': OnboardingScreen.routeName,
    'forgot_password_screen': ForgotPasswordScreen.routeName,
    'verify_otp_screen': VerifyOtpScreen.routeName,

    // Story screens
    'story_screen': StoryScreen.routeName,
    'episode_screen': EpisodeScreen.routeName,
    'video_screen': VideoScreen.routeName,
    'question_screen': QuestionScreen.routeName,
    'win_screen': WinScreen.routeName,
    'loose_screen': LooseScreen.routeName,
    'creator_story_screen': CreatorStoryScreen.routeName,

    // Shop screens
    'shop_screen': ShopScreen.routeName,
    'single_product_screen': SingleProductScreen.routeName,
    'cart_screen': CartScreen.routeName,
    'search_product_screen': SearchProductScreen.routeName,
    'vendor_product_screen': VendorProductScreen.routeName,

    // User screens
    'user_screen': UserScreen.routeName,
    'edit_profile_screen': EditProfileScreen.routeName,
    'user_details_screen': UserDetailsScreen.routeName,
    'point_logs_screen': PointLogsScreen.routeName,
    'orders_screen': OrdersScreen.routeName,
    'tab_view_order': OrdersScreen.routeName,
    'setting_screen': SettingScreen.routeName,
    'levels_screen': LevelsScreen.routeName,
    'weekly_rewards_screen': WeeklyRewardsScreen.routeName,
    'points_screen': PointsScreen.routeName,
    'achievements_screen': AchievementsScreen.routeName,
    'address_screen': AddressScreen.routeName,

    // Other screens
    'leaderboard_screen': LeaderboardScreen.routeName,
    'gift_screen': GiftScreen.routeName,
    'single_gift_screen': SingleGiftScreen.routeName,
    'ads_screen': AdsScreen.routeName,
    'contact_us_screen': ContactUsScreen.routeName,
    'notification_screen': NotificationScreen.routeName,
    'referrals_screen': ReferralsScreen.routeName,
    'intro_screen': IntroScreen.routeName,

    // Shorts screens
    'shorts_screen': ShortsScreen.routeName,
    'shorts_question_screen': ShortsQuestionScreen.routeName,
    'shorts_loose_screen': ShortsLooseScreen.routeName,
    'shorts_win_screen': ShortsWinScreen.routeName,
    'single_shorts_screen': SingleShortsScreen.routeName,
    'guest_win_screen': GuestWinnerScreen.routeName,

    // Challenges screens
    'all_challenges_screen': AllChallengesScreen.routeName,

    // Additional screens
    'discover_screen': DiscoverScreen.routeName,
    'messages_screen': MessagesScreen.routeName,
    'conversations_screen': ConversationsScreen.routeName,

    // Backend aliases and alternative names
    'cart': CartScreen.routeName,
    'order_history': OrdersScreen.routeName,
    'my_orders': OrdersScreen.routeName,
  };

  /// Navigate to a screen based on the screen name from puppet interaction
  static Future<void> navigateToScreen(
    BuildContext context,
    String screenName, {
    Object? arguments,
    bool replace = false,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    try {
      // Add context debugging
      DebugLogger.puppet(
          '🧭 Context Widget Type: ${context.widget.runtimeType}');
      DebugLogger.puppet(
          '🧭 Context has Navigator: ${Navigator.maybeOf(context) != null}');
      DebugLogger.puppet('🧭 Context is mounted: ${context.mounted}');

      DebugLogger.puppet('🧭 Navigating to screen: $screenName');

      final routeName = _screenRouteMap[screenName];

      if (routeName == null) {
        DebugLogger.error('🧭 Unknown screen name: $screenName');
        // _showNavigationError(context, 'Unknown screen: $screenName');
        return;
      }

      DebugLogger.puppet('🧭 Using route: $routeName');

      // Special handling for screens that require arguments
      if (_requiresArguments(screenName) && arguments == null) {
        DebugLogger.warning(
            '🧭 Screen $screenName requires arguments but none provided');

        // Try to navigate to a safe fallback
        final fallback = _getFallbackForScreen(screenName);
        if (fallback != null) {
          DebugLogger.puppet('🧭 Using fallback screen: $fallback');
          await navigateToScreen(context, fallback, replace: replace);
          return;
        } else {
          _showNavigationError(
              context, 'Screen $screenName requires additional parameters');
          return;
        }
      }

      // Get NavigatorState using our helper method that handles overlay contexts
      final navigatorState = _getNavigatorState(context, navigatorKey);
      if (navigatorState == null) {
        DebugLogger.error(
            '🧭 No Navigator available from context or global key');

        // Try one more time with a small delay for overlay widgets
        DebugLogger.puppet('🧭 Retrying navigation after delay...');
        await Future.delayed(Duration(milliseconds: 100));

        final retryNavigatorState = _getNavigatorState(context, navigatorKey);
        if (retryNavigatorState == null) {
          _showNavigationError(context, 'Navigation system not available');
          return;
        } else {
          DebugLogger.puppet('🧭 ✅ Navigator found on retry');
          await _navigateWithRetry(
            retryNavigatorState,
            routeName,
            arguments: arguments,
            replace: replace,
          );
          return;
        }
      }

      // Use the retry navigation method
      await _navigateWithRetry(
        navigatorState,
        routeName,
        arguments: arguments,
        replace: replace,
      );

      DebugLogger.success('🧭 Successfully navigated to $screenName');
    } catch (e) {
      DebugLogger.error('🧭 Navigation error: $e');
      _showNavigationError(context, 'Failed to navigate to $screenName');
    }
  }

  /// Check if a screen requires arguments
  static bool _requiresArguments(String screenName) {
    const screensRequiringArguments = {
      'single_product_screen',
      'single_gift_screen',
      'video_screen',
      'episode_screen',
      'single_shorts_screen',
    };
    return screensRequiringArguments.contains(screenName);
  }

  /// Get a fallback screen for screens that require arguments
  static String? _getFallbackForScreen(String screenName) {
    const fallbackMap = {
      'single_product_screen': 'shop_screen',
      'single_gift_screen': 'gift_screen',
      'video_screen': 'story_screen',
      'episode_screen': 'story_screen',
      'single_shorts_screen': 'shorts_screen',
    };
    return fallbackMap[screenName];
  }

  /// Validate if action type matches the expected screen (following deep link pattern)
  static bool _isValidActionType(String screenName, String? actionType) {
    const actionTypeToScreenMap = {
      'Product': 'single_product_screen',
      'Gift': 'single_gift_screen',
      'Episode': 'video_screen',
      'Shorts': 'single_shorts_screen',
    };

    if (actionType == null) return true; // Allow navigation without action type

    return actionTypeToScreenMap[actionType] == screenName;
  }

  /// Navigate to a screen with validation of action type and parameters
  static Future<void> navigateToScreenWithAction(
    BuildContext context,
    String screenName, {
    String? actionType,
    int? actionId,
    Object? fallbackArguments,
    bool replace = false,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    try {
      DebugLogger.puppet(
          '🧭 Navigating to screen: $screenName with actionType: $actionType, actionId: $actionId');

      // Validate action type matches screen
      if (!_isValidActionType(screenName, actionType)) {
        DebugLogger.warning(
            '🧭 Action type "$actionType" does not match screen "$screenName"');
        // Still proceed but log the mismatch
      }

      // Use actionId as primary argument if available
      Object? arguments = actionId ?? fallbackArguments;

      await navigateToScreen(
        context,
        screenName,
        arguments: arguments,
        replace: replace,
        navigatorKey: navigatorKey,
      );
    } catch (e) {
      DebugLogger.error('🧭 Navigation with action error: $e');
      _showNavigationError(context, 'Failed to navigate to $screenName');
    }
  }

  /// Check if a screen name is valid
  static bool isValidScreen(String screenName) {
    return _screenRouteMap.containsKey(screenName);
  }

  /// Get the route name for a screen name
  static String? getRouteName(String screenName) {
    return _screenRouteMap[screenName];
  }

  /// Get all available screen names
  static List<String> getAllScreenNames() {
    return _screenRouteMap.keys.toList();
  }

  /// Show error message for navigation failures (using SnackBar instead of dialog)
  static void _showNavigationError(BuildContext context, String message) {
    DebugLogger.error('🧭 Navigation error: $message');

    // Use SnackBar instead of dialog for better UX
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Navigate back to previous screen
  static void goBack(
    BuildContext context, [
    GlobalKey<NavigatorState>? navigatorKey,
  ]) {
    final navigatorState = _getNavigatorState(context, navigatorKey);
    if (navigatorState != null && navigatorState.canPop()) {
      navigatorState.pop();
    }
  }

  /// Navigate to home screen (typically story_screen or user_screen)
  static Future<void> goToHome(
    BuildContext context, [
    GlobalKey<NavigatorState>? navigatorKey,
  ]) async {
    await navigateToScreen(
      context,
      'story_screen',
      replace: true,
      navigatorKey: navigatorKey,
    );
  }

  /// Get NavigatorState from context or fallback to global key
  /// This handles cases where context doesn't have Navigator access (like AssistiveTouch overlay)
  static NavigatorState? _getNavigatorState(
    BuildContext context, [
    GlobalKey<NavigatorState>? providedNavigatorKey,
  ]) {
    try {
      // First try to get Navigator from context
      final navigator = Navigator.maybeOf(context);
      if (navigator != null) {
        DebugLogger.puppet('🧭 Using Navigator from context');
        return navigator;
      }
    } catch (e) {
      DebugLogger.puppet('🧭 Context Navigator not available: $e');
    }

    // Try provided navigator key first
    if (providedNavigatorKey != null) {
      try {
        DebugLogger.puppet('🧭 Attempting to use provided Navigator key...');
        final providedState = providedNavigatorKey.currentState;
        if (providedState != null) {
          DebugLogger.puppet('🧭 ✅ Using provided Navigator key successfully');
          return providedState;
        } else {
          DebugLogger.puppet(
              '🧭 ❌ Provided Navigator key currentState is null');
        }
      } catch (e) {
        DebugLogger.puppet('🧭 ❌ Provided Navigator not available: $e');
      }
    }

    // Fallback to global navigator key
    try {
      DebugLogger.puppet('🧭 Attempting to use global Navigator key...');
      DebugLogger.puppet(
          '🧭 mainNavigatorKey.currentState is null: ${mainNavigatorKey.currentState == null}');

      // Import and use mainNavigatorKey from main.dart
      final globalState = mainNavigatorKey.currentState;
      if (globalState != null) {
        DebugLogger.puppet('🧭 ✅ Using global Navigator key successfully');
        return globalState;
      } else {
        DebugLogger.puppet('🧭 ❌ Global Navigator key currentState is null');
      }
    } catch (e) {
      DebugLogger.puppet('🧭 ❌ Global Navigator not available: $e');
    }

    DebugLogger.error('🧭 ❌ No Navigator available from context or global key');
    return null;
  }

  /// Navigate with retry logic for overlay contexts
  static Future<bool> _navigateWithRetry(
    NavigatorState navigator,
    String routeName, {
    Object? arguments,
    bool replace = false,
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        DebugLogger.puppet('🧭 Navigation attempt $attempt/$maxRetries');

        if (replace) {
          await navigator.pushReplacementNamed(routeName, arguments: arguments);
        } else {
          await navigator.pushNamed(routeName, arguments: arguments);
        }

        DebugLogger.puppet('🧭 ✅ Navigation successful on attempt $attempt');
        return true;
      } catch (e) {
        DebugLogger.puppet('🧭 ❌ Navigation attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          // Wait a bit before retrying
          await Future.delayed(Duration(milliseconds: 100 * attempt));
        } else {
          DebugLogger.error('🧭 ❌ All navigation attempts failed: $e');
          rethrow;
        }
      }
    }
    return false;
  }
}
