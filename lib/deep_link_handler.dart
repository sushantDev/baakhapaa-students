import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:baakhapaa/utils/wallet_launcher.dart';
import 'package:baakhapaa/main.dart' show mainNavigatorKey, globalAuth;

import '../screens/story/story_screen.dart';
import '../screens/story/episode_screen.dart';
import '../screens/gift/single_gift_screen.dart';
import '../screens/shop/single_product_screen.dart';
import '../screens/story/video_screen.dart';
import '../screens/story/readable_episode_screen.dart';
import '../screens/shorts/single_shorts_screen.dart';
import '../screens/shorts/shorts_screen.dart';
import '../screens/auth/login_screen.dart';
import '../providers/story.dart';
import 'models/url.dart';
import 'package:provider/provider.dart';
import 'utils/debug_logger.dart';

class DeepLinkHandler with ChangeNotifier {
  late AppLinks appLinks;
  StreamSubscription<Uri>? linkSubscription;

  // Singleton instance
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  // Static flag to prevent multiple initializations globally
  static bool _globalInitialized = false;
  static bool _globalInitializing = false;

  // Flag to prevent concurrent processing
  static bool _isProcessing = false;

  // Keep track of recently processed links to avoid reprocessing (short cooldown to prevent loops)
  static Set<String> _recentlyProcessedLinks = {};
  static const int _linkCooldownSeconds = 5; // Short cooldown to prevent loops

  /// Process an initial deep link immediately on cold start.
  /// This should be called from main.dart after the app is ready.
  static Future<void> processInitialLink() async {
    DebugLogger.info("🔗 DeepLinkHandler.processInitialLink() - Starting");

    // Prevent concurrent processing
    if (_isProcessing) {
      DebugLogger.info(
          "⚠️ DeepLinkHandler.processInitialLink() - Already processing, skipping");
      return;
    }
    _isProcessing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? deeplink = prefs.getString('deepLink');

      if (deeplink != null && deeplink.isNotEmpty) {
        DebugLogger.info(
            "🔗 DeepLinkHandler.processInitialLink() - Found stored link: $deeplink");

        // Add to processed links to prevent duplicate processing
        if (_recentlyProcessedLinks.contains(deeplink)) {
          DebugLogger.info(
              "⚠️ DeepLinkHandler.processInitialLink() - Already processed, skipping");
          return;
        }
        _recentlyProcessedLinks.add(deeplink);

        // Clear the stored link BEFORE processing to prevent re-triggering
        await prefs.remove('deepLink');
        await prefs.remove('immediate_universal_link');

        // Wait for navigator to be ready
        await Future.delayed(Duration(milliseconds: 500));

        // Navigate using global navigator key
        handleDeepLink(Uri.parse(deeplink));

        // Remove from processed set after extended delay
        Future.delayed(Duration(seconds: _linkCooldownSeconds), () {
          _recentlyProcessedLinks.remove(deeplink);
        });
      } else {
        DebugLogger.info(
            "🔵 DeepLinkHandler.processInitialLink() - No stored link found");
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Decode a deep link ID - handles both base64 encoded and plain IDs
  static dynamic _decodeDeepLinkId(String id) {
    try {
      // First try to decode as base64 JSON (legacy format)
      final decoded = utf8.decode(base64Url.decode(id));
      // Check if it's JSON
      if (decoded.startsWith('{') || decoded.startsWith('[')) {
        return json.decode(decoded);
      }
      // If it's just a number string, return as int
      final numericValue = int.tryParse(decoded);
      if (numericValue != null) {
        DebugLogger.info(
            "🔗 _decodeDeepLinkId() - Base64 decoded to number: $numericValue");
        return numericValue;
      }
      return decoded;
    } catch (e) {
      // If base64 decoding fails, try parsing as plain number
      final numericValue = int.tryParse(id);
      if (numericValue != null) {
        DebugLogger.info(
            "🔗 _decodeDeepLinkId() - Plain number ID: $numericValue");
        return numericValue;
      }
      // Return as string if all else fails
      DebugLogger.info("🔗 _decodeDeepLinkId() - Using as string: $id");
      return id;
    }
  }

  void init() async {
    // Prevent multiple simultaneous initializations globally
    if (_globalInitialized || _globalInitializing) {
      DebugLogger.info(
          "🔵 DeepLinkHandler.init() - Already initialized globally, skipping");
      return;
    }

    _globalInitializing = true;
    DebugLogger.info("🔵 DeepLinkHandler.init() - Starting initialization");
    appLinks = AppLinks();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? deeplink = await prefs.getString('deepLink');
    DebugLogger.info(
        "🔵 DeepLinkHandler.init() - Got deeplink from prefs: $deeplink");

    // Check for pending referral codes and clear them if they're stale or user is already authenticated
    final String? pendingReferral = prefs.getString('pending_referral_code');
    final String? authData = prefs.getString('userData');
    DebugLogger.info(
        "🔵 DeepLinkHandler.init() - Pending referral: $pendingReferral");
    DebugLogger.info(
        "🔵 DeepLinkHandler.init() - Auth data exists: ${authData != null && authData.isNotEmpty}");

    if (pendingReferral != null) {
      DebugLogger.info(
          "🟡 DeepLinkHandler.init() - Found pending referral, checking conditions");
      if (authData != null && authData.isNotEmpty) {
        // User is logged in but has pending referral, clear it
        DebugLogger.info(
            "🟠 DeepLinkHandler.init() - User authenticated with pending referral, clearing");
        DebugLogger.info("Clearing pending referral for authenticated user");
        await prefs.remove('pending_referral_code');
        await prefs.remove('pending_referral_timestamp');
        DebugLogger.info(
            "✅ DeepLinkHandler.init() - Cleared pending referral for authenticated user");
      } else {
        // Check if the referral code has been sitting for too long (more than 1 min)
        final referralTimestamp =
            prefs.getInt('pending_referral_timestamp') ?? 0;
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        final oneMinute = 60 * 1000; // 1 min in milliseconds

        DebugLogger.info(
            "🟡 DeepLinkHandler.init() - Referral timestamp: $referralTimestamp");
        DebugLogger.info(
            "🟡 DeepLinkHandler.init() - Current time: $currentTime");
        DebugLogger.info(
            "🟡 DeepLinkHandler.init() - Time diff: ${currentTime - referralTimestamp}ms");

        if (referralTimestamp == 0 ||
            currentTime - referralTimestamp > oneMinute) {
          DebugLogger.info(
              "🟠 DeepLinkHandler.init() - Referral is stale or invalid, clearing");
          DebugLogger.info("Clearing stale or invalid pending referral code");
          await prefs.remove('pending_referral_code');
          await prefs.remove('pending_referral_timestamp');
          DebugLogger.info("✅ DeepLinkHandler.init() - Cleared stale referral");
        } else {
          DebugLogger.info(
              "🟢 DeepLinkHandler.init() - Referral is still valid, keeping it");
        }
      }
    } else {
      DebugLogger.info("🔵 DeepLinkHandler.init() - No pending referral found");
    }

    // Process initial links
    DebugLogger.info("🔵 DeepLinkHandler.init() - Setting up link listeners");
    linkSubscription = appLinks.uriLinkStream.listen((link) {
      // Check if this link was recently processed to prevent loops
      final linkStr = link.toString();
      DebugLogger.info("🔗 DeepLinkHandler - Received link: $linkStr");
      if (_recentlyProcessedLinks.contains(linkStr)) {
        DebugLogger.info(
            "⚠️ DeepLinkHandler - Skipping already processed link: $linkStr");
        DebugLogger.info("Skipping already processed link: $linkStr");
        return;
      }

      // Add to processed links
      _recentlyProcessedLinks.add(linkStr);
      DebugLogger.info(
          "✅ DeepLinkHandler - Added to processed links: $linkStr");

      // Schedule removal from the set after extended cooldown
      Future.delayed(Duration(seconds: _linkCooldownSeconds), () {
        _recentlyProcessedLinks.remove(linkStr);
        DebugLogger.info(
            "🧹 DeepLinkHandler - Removed from processed links: $linkStr");
      });

      _navigateToLink(link);
    }, onError: (err) {
      DebugLogger.info("❌ DeepLinkHandler - Link stream error: $err");
      DebugLogger.error('Error of applink: $err');
    });

    if (deeplink != null && deeplink.isNotEmpty) {
      DebugLogger.info(
          "🔗 DeepLinkHandler.init() - Processing stored deeplink: $deeplink");
      if (!_recentlyProcessedLinks.contains(deeplink)) {
        _recentlyProcessedLinks.add(deeplink);
        // Clear from SharedPreferences BEFORE processing to prevent re-triggering
        prefs.remove('deepLink');
        DebugLogger.info("🧹 DeepLinkHandler.init() - Cleared stored deeplink");

        _navigateToLink(Uri.parse(deeplink));

        // Remove after extended cooldown
        Future.delayed(Duration(seconds: _linkCooldownSeconds), () {
          _recentlyProcessedLinks.remove(deeplink);
        });
      } else {
        DebugLogger.info(
            "⚠️ DeepLinkHandler.init() - Stored deeplink already processed");
      }
    } else {
      DebugLogger.info("🔵 DeepLinkHandler.init() - No stored deeplink found");
    }

    // Clear shared prefs on init just to be safe
    prefs.remove('deepLink');

    // Mark as initialized
    _globalInitialized = true;
    _globalInitializing = false;

    DebugLogger.info("✅ DeepLinkHandler.init() - Initialization complete");
  }

  static void handleDeepLink(Uri uri) async {
    DebugLogger.info("🔗 handleDeepLink() - Processing URI: ${uri.toString()}");
    DebugLogger.info(
        "🔗 handleDeepLink() - Scheme: ${uri.scheme}, Host: ${uri.host}, Path: ${uri.path}");
    try {
      // PROFESSIONAL DEEP LINK HANDLING
      // Step 1: Handle wallet apps - support both old and new schemes
      if (uri.scheme == 'baakhapaawallet' || uri.scheme == 'baakhapaa_wallet') {
        DebugLogger.info(
            "💳 handleDeepLink() - Wallet app deep link detected (${uri.scheme})");
        DebugLogger.info("Handling wallet deep link: ${uri.toString()}");
        WalletLauncher.launchWalletApp();
        return;
      }

      // Step 2: Handle Universal Links (https://student.baakhapaa.com) with immediate processing
      if ((uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host == Url.deepLinkHost) {
        DebugLogger.info(
            "🌐 handleDeepLink() - Universal link detected: ${uri.toString()}");
        DebugLogger.info("Processing universal link: ${uri.toString()}");

        // Handle universal link referral patterns
        if ((uri.path == '/register' || uri.path == '/signup') &&
            uri.queryParameters.containsKey('referral')) {
          String referralCode = uri.queryParameters['referral']!;
          DebugLogger.info(
              "🎯 handleDeepLink() - Universal link referral detected: $referralCode");
          await _handleReferralLink(referralCode);
          return;
        }

        // Handle referral path in universal links (https://student.baakhapaa.com/referral/code)
        if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first == 'referral' &&
            uri.pathSegments.length > 1) {
          String referralCode = uri.pathSegments[1];
          DebugLogger.info(
              "🎯 handleDeepLink() - Universal link referral path detected: $referralCode");
          await _handleReferralLink(referralCode);
          return;
        }

        // For other universal link paths, continue with normal processing
        DebugLogger.info(
            "🌐 handleDeepLink() - Processing universal link path: ${uri.path}");
      }

      // Step 3: Handle Custom Schemes (baakhapaa://) with enhanced support
      if (uri.scheme == 'baakhapaa') {
        DebugLogger.info(
            "📱 handleDeepLink() - Custom scheme baakhapaa:// detected: ${uri.toString()}");
        DebugLogger.info("Processing baakhapaa:// scheme: ${uri.toString()}");

        // Handle custom scheme referrals
        if (uri.host == 'referral' && uri.pathSegments.isNotEmpty) {
          String referralCode = uri.pathSegments.first;
          DebugLogger.info(
              "🎯 handleDeepLink() - Custom scheme referral detected: $referralCode");
          await _handleReferralLink(referralCode);
          return;
        }
      }

      // Check for referral links first - support both 'ref' and 'referral' parameters
      if (uri.queryParameters.containsKey('ref') ||
          uri.queryParameters.containsKey('referral')) {
        String referralCode =
            uri.queryParameters['ref'] ?? uri.queryParameters['referral']!;
        DebugLogger.info(
            "🎯 handleDeepLink() - Referral query param detected: $referralCode");
        DebugLogger.info("Handling referral link with code: $referralCode");
        await _handleReferralLink(referralCode);
        return;
      }

      // Check for register host pattern (e.g., baakhapaa://register?referral=code)
      if (uri.host == 'register' &&
          uri.queryParameters.containsKey('referral')) {
        String referralCode = uri.queryParameters['referral']!;
        DebugLogger.info(
            "🎯 handleDeepLink() - Register host with referral detected: $referralCode");
        DebugLogger.info(
            "Handling register host referral link with code: $referralCode");
        await _handleReferralLink(referralCode);
        return;
      }

      // Check if there are any path segments before trying to access them
      List<String> pathSegments = uri.pathSegments;
      DebugLogger.info("🔗 handleDeepLink() - Path segments: $pathSegments");
      if (pathSegments.isEmpty) {
        DebugLogger.info(
            "🏠 handleDeepLink() - No path segments, checking authentication");
        DebugLogger.info("No path segments in URI, returning to home");

        // Check authentication before deciding where to go
        if (globalAuth.isAuth) {
          DebugLogger.info(
              "🏠 handleDeepLink() - User authenticated, going to StoryScreen");
          mainNavigatorKey.currentState?.pushNamed(StoryScreen.routeName);
        } else {
          DebugLogger.info(
              "🏠 handleDeepLink() - User not authenticated, going to ShortsScreen");
          mainNavigatorKey.currentState?.pushNamed(ShortsScreen.routeName);
        }
        return;
      }

      String targetSegment = pathSegments.first;
      String targetSegmentlast = pathSegments.last;
      DebugLogger.info(
          "🔗 handleDeepLink() - Target segment: $targetSegment, Last segment: $targetSegmentlast");

      // Handle referral path (e.g., /referral/username)
      if (targetSegment == 'referral' && pathSegments.length > 1) {
        String referralCode = pathSegments[1];
        DebugLogger.info(
            "🎯 handleDeepLink() - Referral path detected: $referralCode");
        DebugLogger.info("Handling referral path with code: $referralCode");
        await _handleReferralLink(referralCode);
        return;
      }

      // Check if user needs to login for protected content (not for referral links)
      // Protected content: shorts, episode, product, gift, season
      final protectedSegments = [
        'shorts',
        'episode',
        'product',
        'gift',
        'season'
      ];
      if (protectedSegments.contains(targetSegment) && !globalAuth.isAuth) {
        DebugLogger.info(
            "🔒 handleDeepLink() - Guest user accessing protected content, redirecting to login");
        mainNavigatorKey.currentState?.pushNamed(LoginScreen.routeName);
        return;
      }

      // Decode the ID
      dynamic decodedId = _decodeDeepLinkId(targetSegmentlast);
      DebugLogger.info(
          "🔗 handleDeepLink() - Target: $targetSegment, DecodedId: $decodedId");

      if (targetSegment == 'gift') {
        DebugLogger.info(
            "🎁 handleDeepLink() - Navigating to gift: $decodedId");
        mainNavigatorKey.currentState?.pushNamed(
          SingleGiftScreen.routeName,
          arguments: decodedId,
        );
      } else if (targetSegment == 'product') {
        DebugLogger.info(
            "🛍️ handleDeepLink() - Navigating to product: $decodedId");
        mainNavigatorKey.currentState?.pushNamed(
          SingleProductScreen.routeName,
          arguments: decodedId,
        );
      } else if (targetSegment == 'episode') {
        DebugLogger.info(
            "📺 handleDeepLink() - Navigating to episode: $decodedId");
        // Check content_type to route readable episodes correctly
        final context = mainNavigatorKey.currentContext;
        if (context != null) {
          try {
            final storyProvider = Provider.of<Story>(context, listen: false);
            final season = storyProvider.selectedSeason;
            final isReadable =
                (season['content_type'] ?? 'video') == 'readable';
            mainNavigatorKey.currentState?.pushNamed(
              isReadable
                  ? ReadableEpisodeScreen.routeName
                  : VideoScreen.routeName,
              arguments: decodedId,
            );
          } catch (e) {
            mainNavigatorKey.currentState?.pushNamed(
              VideoScreen.routeName,
              arguments: decodedId,
            );
          }
        }
      } else if (targetSegment == 'season') {
        DebugLogger.info(
            "🎭 handleDeepLink() - Navigating to season: $decodedId");
        // Fetch season details and set in provider before navigating
        final context = mainNavigatorKey.currentContext;
        if (context != null) {
          try {
            final storyProvider = Provider.of<Story>(context, listen: false);
            final seasonDetails = await storyProvider.fetchSeasonDetails(
                decodedId is int
                    ? decodedId
                    : int.tryParse(decodedId.toString()) ?? 0);
            if (seasonDetails != null) {
              await storyProvider.setSelectedSeason(seasonDetails);
              mainNavigatorKey.currentState?.pushNamed(EpisodeScreen.routeName);
            } else {
              DebugLogger.error(
                  "Failed to fetch season details for ID: $decodedId");
              _navigateToHome("Season not found");
            }
          } catch (e) {
            DebugLogger.error("Error fetching season for deep link: $e");
            _navigateToHome("Season error");
          }
        } else {
          DebugLogger.error("No context available for season navigation");
          _navigateToHome("Context error");
        }
      } else if (targetSegment == 'shorts') {
        DebugLogger.info(
            "🎬 handleDeepLink() - Navigating to shorts: $decodedId");
        mainNavigatorKey.currentState?.pushNamed(
          SingleShortsScreen.routeName,
          arguments: decodedId,
        );
      } else {
        DebugLogger.info(
            "🏠 handleDeepLink() - Unknown segment, going to home");
        _navigateToHome("Unknown segment");
      }
    } catch (e) {
      DebugLogger.info("❌ handleDeepLink() - General error: $e");
      DebugLogger.error("Error in handleDeepLink: $e");
      _navigateToHome("General error");
    }
  }

  static Future<void> _handleReferralLink(String referralCode) async {
    DebugLogger.info(
        "🎯 _handleReferralLink() - Processing referral: $referralCode");
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if user is already logged in by checking auth state
      final authData = prefs.getString('userData');
      DebugLogger.info(
          "🎯 _handleReferralLink() - Auth data exists: ${authData != null && authData.isNotEmpty}");

      if (authData == null || authData.isEmpty) {
        // User not logged in, store referral code with timestamp and navigate to registration with referral
        DebugLogger.info(
            "🎯 _handleReferralLink() - User not logged in, storing referral");
        await prefs.setString('pending_referral_code', referralCode);
        await prefs.setInt('pending_referral_timestamp',
            DateTime.now().millisecondsSinceEpoch);
        DebugLogger.info(
            "✅ _handleReferralLink() - Stored referral code: $referralCode");
        DebugLogger.info("Stored referral code for new user: $referralCode");

        DebugLogger.info(
            "🎯 _handleReferralLink() - Navigating to register-with-referral screen");
        mainNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/register-with-referral',
          (route) => false,
          arguments: referralCode,
        );
      } else {
        // User is logged in, clear any pending referral and navigate to home
        DebugLogger.info(
            "🎯 _handleReferralLink() - User already logged in, clearing referral");
        await prefs.remove('pending_referral_code');
        await prefs.remove('pending_referral_timestamp');
        DebugLogger.info(
            "User already logged in, clearing referral and going to home");

        DebugLogger.info(
            "🎯 _handleReferralLink() - Navigating to story screen");
        mainNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          StoryScreen.routeName,
          (route) => false,
        );

        // Show a snackbar about the referral link
        final context = mainNavigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'You are already logged in. Check your referrals section if you want to refer others.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      DebugLogger.info("❌ _handleReferralLink() - Error: $e");
      DebugLogger.error("Error handling referral link: $e");
      // Clear any pending referral on error
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_referral_code');
      await prefs.remove('pending_referral_timestamp');
      _navigateToHome("Referral link error");
    }
  }

  void _navigateToLink(Uri uri) {
    DebugLogger.info(
        "🔗 _navigateToLink() - Processing URI: ${uri.toString()}");
    try {
      DebugLogger.info("Navigating to deep link: ${uri.toString()}");
      handleDeepLink(uri);
    } catch (e) {
      DebugLogger.info("❌ _navigateToLink() - Error: $e");
      DebugLogger.error("Error in _navigateToLink: $e");
      _navigateToHome("Navigate to link error");
    }
  }

  void dispose() {
    linkSubscription?.cancel();
    _recentlyProcessedLinks.clear();
    WalletLauncher.resetLaunchFlag();

    // Reset global flags to allow reinitialization if needed
    _globalInitialized = false;
    _globalInitializing = false;

    super.dispose();
  }

  // Method to clear any pending links
  static void clearProcessedLinks() {
    _recentlyProcessedLinks.clear();
    WalletLauncher.resetLaunchFlag();
  }

  // Method to clear pending referral codes
  static Future<void> clearPendingReferrals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_referral_code');
      await prefs.remove('pending_referral_timestamp');
      DebugLogger.info("Cleared pending referral codes");
    } catch (e) {
      DebugLogger.error("Error clearing pending referrals: $e");
    }
  }

  // Helper method to navigate to appropriate home screen based on authentication
  static void _navigateToHome(String reason) {
    DebugLogger.info("🏠 DeepLinkHandler._navigateToHome() - Reason: $reason");
    if (globalAuth.isAuth) {
      DebugLogger.info(
          "🏠 DeepLinkHandler._navigateToHome() - User authenticated, going to StoryScreen");
      mainNavigatorKey.currentState?.pushNamed(StoryScreen.routeName);
    } else {
      DebugLogger.info(
          "🏠 DeepLinkHandler._navigateToHome() - User not authenticated, going to ShortsScreen");
      mainNavigatorKey.currentState?.pushNamed(ShortsScreen.routeName);
    }
  }
}
