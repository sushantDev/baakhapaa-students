import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/puppet_interaction_provider.dart';
import '../providers/auth.dart';
import '../utils/debug_logger.dart';

class ScreenNameMapping {
  static const Map<String, String> _routeToScreenName = {
    // Authentication screens
    '/login': 'login_screen',
    '/login-screen': 'login_screen',
    '/register': 'register_screen',
    '/register-screen': 'register_screen',
    '/forgot_password': 'forgot_password_screen',
    '/forgot-password-screen': 'forgot_password_screen',
    '/verify_otp': 'verify_otp_screen',
    '/verify-otp-screen': 'verify_otp_screen',
    '/onboarding': 'onboarding_screen',
    '/onboarding-screen': 'onboarding_screen',
    '/welcome': 'onboarding_screen',
    '/welcome-screen': 'onboarding_screen',

    // Main navigation screens
    '/': 'story_screen',
    '/story-screen': 'story_screen',
    '/home': 'story_screen',
    '/shorts': 'shorts_screen',
    '/shorts-screen': 'shorts_screen',
    '/profile': 'user_screen',
    '/user-screen': 'user_screen',
    '/user-profile-screen': 'user_profile_screen',
    '/discover': 'discover_screen',
    '/discover-screen': 'discover_screen',

    // Shop and commerce screens
    '/shop': 'shop_screen',
    '/shop-screen': 'shop_screen',
    '/cart': 'cart_screen',
    '/cart-screen': 'cart_screen',
    '/single_product': 'single_product_screen',
    '/single-product-screen': 'single_product_screen',
    '/search_product': 'search_product_screen',
    '/search-product-screen': 'search_product_screen',
    '/vendor_product': 'vendor_product_screen',
    '/vendor-product-screen': 'vendor_product_screen',
    '/tab_view_product': 'tab_view_product',
    '/tab-view-product': 'tab_view_product',
    '/tab_view_order': 'tab_view_order',
    '/tab-view-order': 'tab_view_order',
    '/premium_packages': 'premium_packages_screen',
    '/premium-package-screen': 'premium_packages_screen',

    // Story and video screens
    '/creators': 'creators_screen',
    '/creators-screen': 'creators_screen',
    '/creator_story': 'creator_story_screen',
    '/creator-story-screen': 'creator_story_screen',
    '/episode': 'episode_screen',
    '/episode-screen': 'episode_screen',
    '/video': 'video_screen',
    '/video-screen': 'video_screen',
    '/question': 'question_screen',
    '/question-screen': 'question_screen',
    '/win': 'win_screen',
    '/win-screen': 'win_screen',
    '/loose': 'loose_screen',
    '/loose-screen': 'loose_screen',

    // Shorts screens
    '/single_shorts': 'single_shorts_screen',
    '/single-shorts-screen': 'single_shorts_screen',
    '/create_shorts': 'create_shorts_screen',
    '/create-shorts-screen': 'create_shorts_screen',
    '/drafts': 'drafts_screen',
    '/drafts-screen': 'drafts_screen',
    '/shorts_challenge': 'shorts_challenge_screen',
    '/shorts-challenge-screen': 'shorts_challenge_screen',
    '/shorts_question': 'shorts_question_screen',
    '/shorts-question-screen': 'shorts_question_screen',
    '/shorts_win': 'shorts_win_screen',
    '/shorts-win-screen': 'shorts_win_screen',
    '/shorts_loose': 'shorts_loose_screen',
    '/shorts-loose-screen': 'shorts_loose_screen',
    '/guest_winner': 'guest_winner_screen',
    '/guest-win-screen': 'guest_winner_screen',
    '/preview_shorts': 'preview_shorts_screen',
    '/preview-shorts-screen': 'preview_shorts_screen',
    '/create_shorts_question': 'create_shorts_question_screen',
    '/create-shorts-question-screen': 'create_shorts_question_screen',
    '/create_shorts_question_form': 'create_shorts_question_form_screen',

    // User management screens
    '/edit_profile': 'edit_profile_screen',
    '/edit-profile-screen': 'edit_profile_screen',
    '/user_details': 'user_details_screen',
    '/user-details-screen': 'user_details_screen',
    '/setting': 'setting_screen',
    '/setting-screen': 'setting_screen',
    '/point_logs': 'point_logs_screen',
    '/point-logs-screen': 'point_logs_screen',
    '/orders': 'orders_screen',
    '/orders-screen': 'orders_screen',
    '/referrals': 'referrals_screen',
    '/referrals-screen': 'referrals_screen',
    '/achievements': 'achievements_screen',
    '/achievements-screen': 'achievements_screen',
    '/address': 'address_screen',
    '/address-screen': 'address_screen',
    '/weekly_rewards': 'weekly_rewards_screen',
    '/weekly-rewards-screen': 'weekly_rewards_screen',
    '/points': 'points_screen',
    '/points-screen': 'points_screen',
    '/levels': 'levels_screen',
    '/levels-screen': 'levels_screen',
    '/language': 'language_selector_screen',
    '/language-screen': 'language_selector_screen',

    // Social and messaging screens
    '/conversations': 'conversations_screen',
    '/conversations-screen': 'conversations_screen',
    '/messages': 'messages_screen',
    '/messages-screen': 'messages_screen',
    '/chatbot': 'chatbot_screen',
    '/chat-bot-screen': 'chatbot_screen',

    // Challenges and games
    '/all-challenges-screen': 'all_challenges_screen',
    '/leaderboard': 'leaderboard_screen',
    '/leaderboard-screen': 'leaderboard_screen',

    // Gift and rewards
    '/gift': 'gift_screen',
    '/gift-screen': 'gift_screen',
    '/single_gift': 'single_gift_screen',
    '/single-gift-screen': 'single_gift_screen',
    '/bkp_fortune_wheel': 'bkp_fortune_wheel',

    // Additional database-specific screens
    '/verify_number': 'verify_number_screen',
    '/verify-number-screen': 'verify_number_screen',
    '/password_reset': 'password_reset_screen',
    '/password-reset-screen': 'password_reset_screen',
    '/email_verification': 'email_verification_screen',
    '/email-verification-screen': 'email_verification_screen',
    '/account_verification': 'account_verification_screen',
    '/account-verification-screen': 'account_verification_screen',
    '/phone_verification': 'phone_verification_screen',
    '/phone-verification-screen': 'phone_verification_screen',
    '/terms_of_service': 'terms_of_service_screen',
    '/terms-of-service-screen': 'terms_of_service_screen',
    '/privacy_policy': 'privacy_policy_screen',
    '/privacy-policy-screen': 'privacy_policy_screen',
    '/about': 'about_screen',
    '/about-screen': 'about_screen',
    '/help': 'help_screen',
    '/help-screen': 'help_screen',
    '/faq': 'faq_screen',
    '/faq-screen': 'faq_screen',
    '/tutorial': 'tutorial_screen',
    '/tutorial-screen': 'tutorial_screen',
    '/splash': 'splash_screen',
    '/splash-screen': 'splash_screen',
    '/loading': 'loading_screen',
    '/loading-screen': 'loading_screen',
    '/error': 'error_screen',
    '/error-screen': 'error_screen',
    '/maintenance': 'maintenance_screen',
    '/maintenance-screen': 'maintenance_screen',
    '/update_required': 'update_required_screen',
    '/update-required-screen': 'update_required_screen',
    '/network_error': 'network_error_screen',
    '/network-error-screen': 'network_error_screen',
    '/server_error': 'server_error_screen',
    '/server-error-screen': 'server_error_screen',
    '/no_internet': 'no_internet_screen',
    '/no-internet-screen': 'no_internet_screen',
    '/offline': 'offline_screen',
    '/offline-screen': 'offline_screen',
    '/coming_soon': 'coming_soon_screen',
    '/coming-soon-screen': 'coming_soon_screen',
    '/under_development': 'under_development_screen',
    '/under-development-screen': 'under_development_screen',

    // Guest-specific screens
    '/shorts_screen_guest': 'shorts_screen_guest',
    '/story_screen_guest': 'story_screen_guest',
    '/discover_screen_guest': 'discover_screen_guest',
    '/user_screen_guest': 'user_screen_guest',

    // Other screens
    '/notification': 'notification_screen',
    '/notification-screen': 'notification_screen',
    '/contact_us': 'contact_us_screen',
    '/contact-us-screen': 'contact_us_screen',
    '/ads': 'ads_screen',
    '/ads-screen': 'ads_screen',
    '/intro': 'intro_screen',
    '/intro-screen': 'intro_screen',
    '/creator_request': 'creator_request_screen',
    '/creator-request-screen': 'creator_request_screen',
    '/mlbb_registration': 'mlbb_registration_screen',
    '/mlbb-registration-screen': 'mlbb_registration_screen',
    '/challenge_request': 'challenge_request_screen',
    '/challenge-request-screen': 'challenge_request_screen',
  };

  static String getScreenName(String routeName) {
    // Remove any query parameters or fragments
    final cleanRoute = routeName.split('?').first.split('#').first;
    return _routeToScreenName[cleanRoute] ?? cleanRoute.replaceAll('/', '');
  }

  // Special method to get screen name based on authentication status
  static String getScreenNameWithAuth(String routeName, bool isAuthenticated) {
    // Remove any query parameters or fragments
    final cleanRoute = routeName.split('?').first.split('#').first;
    String screenName =
        _routeToScreenName[cleanRoute] ?? cleanRoute.replaceAll('/', '');

    DebugLogger.puppet(
        '🎭 Screen Mapping: Route "$cleanRoute" -> Screen "$screenName" (Auth: $isAuthenticated));');

    // For shorts screen, differentiate between guest and authenticated users
    if (screenName == 'shorts_screen' && !isAuthenticated) {
      DebugLogger.puppet('Screen Mapping: Converting to guest shorts screen');
      return 'shorts_screen_guest';
    }

    return screenName;
  }

  static String? getRouteFromScreenName(String screenName) {
    for (final entry in _routeToScreenName.entries) {
      if (entry.value == screenName) {
        return entry.key;
      }
    }
    return null;
  }

  static List<String> getAllScreenNames() {
    return _routeToScreenName.values.toSet().toList();
  }

  static List<String> getAllRoutes() {
    return _routeToScreenName.keys.toList();
  }
}

// Mixin to automatically handle puppet interactions for screens
mixin PuppetInteractionMixin<T extends StatefulWidget> on State<T> {
  String? _currentScreenName;
  PuppetInteractionProvider? _puppetProvider;

  @override
  void deactivate() {
    // Reset screen name so re-activation triggers puppet loading again
    _currentScreenName = null;
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      // Store provider reference early to avoid ancestor lookup issues
      try {
        _puppetProvider = context.read<PuppetInteractionProvider>();
      } catch (e) {
        DebugLogger.puppet('🎭 Mixin: Could not access puppet provider: $e');
        _puppetProvider = null;
      }
      _updateScreenName();
    }
  }

  void _updateScreenName() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    DebugLogger.puppet('Mixin: Route object - ${route?.runtimeType}');
    DebugLogger.puppet('Mixin: Route name - ${route?.settings.name}');
    DebugLogger.puppet('Mixin: Widget type - ${widget.runtimeType}');

    if (route != null) {
      String? routeName = route.settings.name;

      if (routeName != null && routeName.isNotEmpty) {
        DebugLogger.puppet('Mixin: Route detected - $routeName');

        // Try to get auth status
        bool isAuthenticated = false;
        try {
          final auth = context.read<Auth>();
          isAuthenticated = auth.isAuth;
          DebugLogger.puppet('Mixin: Auth status - $isAuthenticated');
        } catch (e) {
          // Auth provider might not be available, default to false
          isAuthenticated = false;
          DebugLogger.puppet(
              'Mixin: Auth provider not available, defaulting to guest');
        }

        final screenName =
            ScreenNameMapping.getScreenNameWithAuth(routeName, isAuthenticated);

        DebugLogger.puppet('Mixin: Mapped screen name - $screenName');

        // Special handling: If we're in ShortsScreen but route is "/",
        // override to shorts_screen to prevent story_screen from loading
        String finalScreenName = screenName;
        if (widget.runtimeType.toString() == 'ShortsScreen' &&
            routeName == '/') {
          finalScreenName =
              isAuthenticated ? 'shorts_screen' : 'shorts_screen_guest';
          DebugLogger.puppet(
              '🎭 Mixin: Override for ShortsScreen - using "$finalScreenName" instead of story_screen');
        }

        if (finalScreenName != _currentScreenName) {
          DebugLogger.puppet(
              '🎭 Mixin: Screen changed from "$_currentScreenName" to "$finalScreenName" in ${widget.runtimeType}');
          _currentScreenName = finalScreenName;
          _loadPuppetSuggestions(finalScreenName);
        } else {
          DebugLogger.puppet(
              '🎭 Mixin: Screen unchanged - "$finalScreenName" in ${widget.runtimeType}');
        }
      } else {
        DebugLogger.puppet(
            '🎭 Mixin: Route has no name or is empty in ${widget.runtimeType}');

        // Try to infer screen name from widget type when route name is null
        String? inferredScreenName = _inferScreenNameFromWidget();
        if (inferredScreenName != null) {
          DebugLogger.puppet(
              '🎭 Mixin: Inferred screen name from widget type - $inferredScreenName');

          if (inferredScreenName != _currentScreenName) {
            DebugLogger.puppet(
                '🎭 Mixin: Screen changed from "$_currentScreenName" to "$inferredScreenName" in ${widget.runtimeType}');
            _currentScreenName = inferredScreenName;
            _loadPuppetSuggestions(inferredScreenName);
          } else {
            DebugLogger.puppet(
                '🎭 Mixin: Screen unchanged - "$inferredScreenName" in ${widget.runtimeType}');
          }
        } else {
          DebugLogger.puppet(
              '🎭 Mixin: Could not infer screen name from widget type ${widget.runtimeType}');
        }
      }
    } else {
      DebugLogger.puppet('Mixin: No route detected in ${widget.runtimeType}');
    }
  }

  // Method to infer screen name from widget type when route name is null
  String? _inferScreenNameFromWidget() {
    final widgetType = widget.runtimeType.toString();

    // Map widget types to screen names
    switch (widgetType) {
      case 'ShopScreen':
        return 'shop_screen';
      case 'TabViewProduct':
        return 'shop_screen'; // TabViewProduct contains the shop screen
      case 'ShortsScreen':
        // Check auth status for shorts screen
        bool isAuthenticated = false;
        try {
          final auth = context.read<Auth>();
          isAuthenticated = auth.isAuth;
        } catch (e) {
          isAuthenticated = false;
        }
        return isAuthenticated ? 'shorts_screen' : 'shorts_screen_guest';
      case 'StoryScreen':
        return 'story_screen';
      case 'UserScreen':
        return 'user_screen';
      case 'DiscoverScreen':
        return 'discover_screen';
      case 'CartScreen':
        return 'cart_screen';
      case 'SingleProductScreen':
        return 'single_product_screen';
      case 'SearchProductScreen':
        return 'search_product_screen';
      case 'VendorProductScreen':
        return 'vendor_product_screen';
      case 'CreatorsScreen':
        return 'creators_screen';
      case 'CreatorStoryScreen':
        return 'creator_story_screen';
      case 'EpisodeScreen':
        return 'episode_screen';
      case 'VideoScreen':
        return 'video_screen';
      case 'QuestionScreen':
        return 'question_screen';
      case 'WinScreen':
        return 'win_screen';
      case 'LooseScreen':
        return 'loose_screen';
      case 'SingleShortsScreen':
        return 'single_shorts_screen';
      case 'CreateShortsScreen':
        return 'create_shorts_screen';
      case 'DraftsScreen':
        return 'drafts_screen';
      case 'ShortsQuestionScreen':
        return 'shorts_question_screen';
      case 'GuestWinnerScreen':
        return 'guest_winner_screen';
      case 'PreviewShortsScreen':
        return 'preview_shorts_screen';
      case 'EditProfileScreen':
        return 'edit_profile_screen';
      case 'UserDetailsScreen':
        return 'user_details_screen';
      case 'SettingScreen':
        return 'setting_screen';
      case 'PointLogsScreen':
        return 'point_logs_screen';
      case 'OrdersScreen':
        return 'orders_screen';
      case 'ReferralsScreen':
        return 'referrals_screen';
      case 'AchievementsScreen':
        return 'achievements_screen';
      case 'AddressScreen':
        return 'address_screen';
      case 'WeeklyRewardsScreen':
        return 'weekly_rewards_screen';
      case 'PointsScreen':
        return 'points_screen';
      case 'LevelsScreen':
        return 'levels_screen';
      case 'LanguageScreen':
        return 'language_selector_screen';
      case 'ConversationsScreen':
        return 'conversations_screen';
      case 'MessagesScreen':
        return 'messages_screen';
      case 'ChatbotScreen':
        return 'chatbot_screen';
      case 'AllChallengesScreen':
        return 'all_challenges_screen';
      case 'LeaderboardScreen':
        return 'leaderboard_screen';
      case 'GiftScreen':
        return 'gift_screen';
      case 'SingleGiftScreen':
        return 'single_gift_screen';
      case 'NotificationScreen':
        return 'notification_screen';
      case 'ContactUsScreen':
        return 'contact_us_screen';
      case 'AdsScreen':
        return 'ads_screen';
      case 'IntroScreen':
        return 'intro_screen';
      case 'CreatorRequestScreen':
        return 'creator_request_screen';
      case 'MLBBRegistrationScreen':
        return 'mlbb_registration_screen';
      case 'ChallengeRequestScreen':
        return 'challenge_request_screen';
      default:
        DebugLogger.puppet('Mixin: Unknown widget type: $widgetType');
        return null;
    }
  }

  void _loadPuppetSuggestions(String screenName) {
    DebugLogger.puppet(
        'Mixin: Loading puppet suggestions for screen "$screenName"');

    // Wrap in post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        context
            .read<PuppetInteractionProvider>()
            .loadScreenSuggestions(screenName, context);
        DebugLogger.puppet(
            'Mixin: Successfully triggered loadScreenSuggestions');
      } catch (e) {
        DebugLogger.puppet('Mixin: Error loading puppet suggestions: $e');
      }
    });
  }

  // Method to set screen context for puppet filtering
  void setPuppetContext({String? actionType, String? actionId}) {
    DebugLogger.info(
        '🎭 🎭 MIXIN setPuppetContext called - actionType: $actionType, actionId: $actionId');
    DebugLogger.info('🎭 🎭 MIXIN mounted: $mounted');

    if (!mounted) return;

    try {
      if (_puppetProvider != null) {
        DebugLogger.info('🎭 🎭 MIXIN calling provider.setContext...');
        _puppetProvider!.setContext(
          actionType: actionType,
          actionId: actionId,
        );
        DebugLogger.puppet(
            'Mixin: Set puppet context - actionType: $actionType, actionId: $actionId');
      } else {
        DebugLogger.info('🎭 🎭 MIXIN _puppetProvider is null!');
      }
    } catch (e) {
      DebugLogger.info('🎭 🎭 MIXIN Error setting puppet context: $e');
      DebugLogger.puppet('Mixin: Error setting puppet context: $e');
    }
  }

  // Method to load puppet suggestions with context
  void loadPuppetSuggestionsWithContext(String screenName,
      {String? actionType, String? actionId}) {
    DebugLogger.puppet(
        'Mixin: Loading puppet suggestions for screen "$screenName" with context - actionType: $actionType, actionId: $actionId');

    // Wrap in post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final provider = context.read<PuppetInteractionProvider>();

        // Set context first
        provider.setContext(actionType: actionType, actionId: actionId);

        // Then load suggestions
        provider.loadScreenSuggestions(screenName, context);

        DebugLogger.puppet(
            'Mixin: Successfully triggered loadScreenSuggestions with context');
      } catch (e) {
        DebugLogger.puppet(
            'Mixin: Error loading puppet suggestions with context: $e');
      }
    });
  }

  // Convenience methods for common screen types
  void setPuppetProductContext(int productId) {
    setPuppetContext(actionType: 'Product', actionId: productId.toString());
  }

  void setPuppetGiftContext(int giftId) {
    setPuppetContext(actionType: 'Gift', actionId: giftId.toString());
  }

  void setPuppetEpisodeContext(int episodeId) {
    setPuppetContext(actionType: 'Episode', actionId: episodeId.toString());
  }

  void setPuppetShortsContext(int shortsId) {
    setPuppetContext(actionType: 'Shorts', actionId: shortsId.toString());
  }

  @override
  void dispose() {
    // Use stored provider reference to avoid widget ancestor lookup during disposal
    try {
      if (_puppetProvider != null && _currentScreenName != null) {
        _puppetProvider!.clearCurrentScreen();
        DebugLogger.puppet(
            '🎭 Mixin: Safely cleared puppet interactions on dispose using stored provider');
      } else {
        DebugLogger.puppet(
            '🎭 Mixin: No stored provider or screen name, skipping clear on dispose');
      }
    } catch (e) {
      DebugLogger.puppet(
          '🎭 Mixin: Could not clear puppet interactions safely on dispose: $e');
    }

    // Clear references
    _puppetProvider = null;
    _currentScreenName = null;

    super.dispose();
  }

  // Optional: Call this method when screen content changes significantly
  void refreshPuppetSuggestions() {
    if (mounted && _currentScreenName != null) {
      try {
        // Use stored provider when available
        if (_puppetProvider != null) {
          _puppetProvider!.refreshSuggestions();
          DebugLogger.puppet(
              '🎭 Mixin: Refreshed suggestions using stored provider');
        } else {
          // Fallback to context lookup
          final provider = context.read<PuppetInteractionProvider>();
          provider.refreshSuggestions();
          DebugLogger.puppet(
              '🎭 Mixin: Refreshed suggestions using context lookup');
        }
      } catch (e) {
        DebugLogger.puppet('🎭 Mixin: Error refreshing puppet suggestions: $e');
      }
    }
  }

  // Optional: Call this when leaving the screen
  void clearPuppetInteractions() {
    // Use stored provider reference when available
    try {
      if (_puppetProvider != null) {
        _puppetProvider!.clearCurrentScreen(context: mounted ? context : null);
        DebugLogger.puppet(
            '🎭 Mixin: Successfully cleared puppet interactions using stored provider');
      } else if (mounted && context.mounted) {
        // Fallback to context lookup if provider not stored
        final provider = context.read<PuppetInteractionProvider>();
        provider.clearCurrentScreen(context: context);
        DebugLogger.puppet(
            '🎭 Mixin: Successfully cleared puppet interactions using context lookup');
      } else {
        DebugLogger.puppet(
            '🎭 Mixin: No provider available and context not mounted, skipping clear');
      }
    } catch (e) {
      DebugLogger.puppet(
          '🎭 Mixin: Could not clear puppet interactions safely: $e');
    }
  }
}

// Helper class for manual screen name management
class PuppetScreenTracker {
  static void trackScreen(BuildContext context, String screenName) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PuppetInteractionProvider>();
      provider.loadScreenSuggestions(screenName, context);
    });
  }

  /// Track screen with specific action context (for Product, Gift, Episode, Shorts screens)
  static void trackScreenWithContext(
    BuildContext context,
    String screenName, {
    String? actionType,
    int? actionId,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PuppetInteractionProvider>();
      provider.loadScreenSuggestions(
        screenName,
        context,
        contextActionType: actionType,
        contextActionId: actionId,
      );
    });
  }

  /// Convenience method for Product screens
  static void trackProductScreen(BuildContext context, int productId) {
    trackScreenWithContext(
      context,
      'single_product_screen',
      actionType: 'Product',
      actionId: productId,
    );
  }

  /// Convenience method for Gift screens
  static void trackGiftScreen(BuildContext context, int giftId) {
    trackScreenWithContext(
      context,
      'single_gift_screen',
      actionType: 'Gift',
      actionId: giftId,
    );
  }

  /// Convenience method for Episode/Video screens
  static void trackEpisodeScreen(BuildContext context, int episodeId) {
    trackScreenWithContext(
      context,
      'video_screen',
      actionType: 'Episode',
      actionId: episodeId,
    );
  }

  /// Convenience method for Shorts screens
  static void trackShortsScreen(BuildContext context, int shortsId) {
    trackScreenWithContext(
      context,
      'single_shorts_screen',
      actionType: 'Shorts',
      actionId: shortsId,
    );
  }

  static void trackScreenByRoute(BuildContext context, String routeName) {
    // Try to get auth status
    bool isAuthenticated = false;
    try {
      final auth = context.read<Auth>();
      isAuthenticated = auth.isAuth;
    } catch (e) {
      // Auth provider might not be available, default to false
      isAuthenticated = false;
    }

    final screenName =
        ScreenNameMapping.getScreenNameWithAuth(routeName, isAuthenticated);
    trackScreen(context, screenName);
  }

  static void clearScreen(BuildContext context) {
    final provider = context.read<PuppetInteractionProvider>();
    provider.clearCurrentScreen();
  }
}

// Navigator observer to automatically track route changes
class PuppetNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleRouteChange(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _handleRouteChange(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _handleRouteChange(newRoute);
    }
  }

  void _handleRouteChange(Route<dynamic> route) {
    if (route.settings.name != null && route is PageRoute) {
      final context = route.navigator?.context;
      if (context != null) {
        // Try to get auth status
        bool isAuthenticated = false;
        try {
          final auth = context.read<Auth>();
          isAuthenticated = auth.isAuth;
        } catch (e) {
          // Auth provider might not be available, default to false
          isAuthenticated = false;
        }

        final screenName = ScreenNameMapping.getScreenNameWithAuth(
            route.settings.name!, isAuthenticated);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            final provider = context.read<PuppetInteractionProvider>();
            provider.loadScreenSuggestions(screenName, context);
          } catch (e) {
            // Provider might not be available in context
            DebugLogger.puppet('Could not load puppet suggestions: $e');
          }
        });
      }
    }
  }
}
