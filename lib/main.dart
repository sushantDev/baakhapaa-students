import 'dart:async';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/providers/affiliate.dart';
import 'package:baakhapaa/providers/chatbot_provider.dart';
import 'package:baakhapaa/providers/comment.dart';
import 'package:baakhapaa/providers/connectivity_service.dart';
import 'package:baakhapaa/providers/levels.dart';
import 'package:baakhapaa/providers/rewards_provider.dart';
import 'package:baakhapaa/services/pusher_service.dart';
import 'package:baakhapaa/providers/social_auth_provider.dart';
import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/providers/vendor.dart';
import 'package:baakhapaa/screens/affiliate/affiliate_dashboard_screen.dart';
import 'package:baakhapaa/screens/analytics/analytics_screen.dart';
import 'package:baakhapaa/screens/challenges/challenge_detail_screen.dart';
import 'package:baakhapaa/screens/shop/create/create_product_screen.dart';
import 'package:baakhapaa/screens/shop/create/vendor_product_type_screen.dart';
import 'package:baakhapaa/screens/subscription/subscription_screen.dart';
import 'package:baakhapaa/screens/shorts/guest_win_screen.dart';
import 'package:baakhapaa/screens/messages/chat_bot_screen.dart';
import 'package:baakhapaa/screens/level_map/level_map_screen.dart';
import 'package:baakhapaa/screens/user/levels_screen.dart';
import 'package:baakhapaa/screens/user/weekly_rewards_screen.dart';
import 'package:baakhapaa/screens/user/points_screen.dart';
import 'package:baakhapaa/screens/user/wallet_auth_screen.dart';
import 'package:baakhapaa/services/level_manager.dart';
import 'package:baakhapaa/utils/debug_logger.dart' as debug;
// AssistiveTouch replaced by PuppetDashboard + GlobalEventListener
import 'package:baakhapaa/widgets/puppet_speech_bubble.dart';
import 'package:baakhapaa/widgets/connectivity_aware_widget.dart';
import 'package:baakhapaa/widgets/footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:khalti_checkout_flutter/khalti_checkout_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:baakhapaa/providers/currency_provider.dart';
import 'package:baakhapaa/providers/delivery_provider.dart';
import 'package:baakhapaa/providers/language_provider.dart';
import 'package:baakhapaa/providers/collaboration_provider.dart';
import 'package:baakhapaa/screens/collaboration/collaborations_screen.dart';
import 'package:baakhapaa/screens/collaboration/collaboration_detail_screen.dart';
import 'package:baakhapaa/screens/collaboration/create_collaboration_screen.dart';
import 'package:baakhapaa/screens/my_courses/my_courses_screen.dart';
import 'package:baakhapaa/screens/others/language_screen.dart';
import 'package:baakhapaa/services/clarity_service.dart';
import 'package:baakhapaa/services/sentry_service.dart';
import './firebase_options.dart';
import './providers/auth.dart';
import './providers/story.dart';
import './providers/shop.dart';
import './providers/cart.dart';
import './providers/favorites.dart';
import './providers/orders.dart';
import './providers/leaderboard.dart';
import './providers/announcement.dart';
import './providers/shorts.dart';
import './providers/challenge.dart';
import './providers/story_creation.dart';
import './screens/shop/tab_view_product.dart';
import './screens/auth/welcome_screen.dart';
import './screens/auth/login_screen.dart';
import './screens/story/story_screen.dart';
import './screens/story/search_screen.dart';
import './screens/auth/register_screen.dart';
import './screens/auth/register_with_referral_screen.dart';
import './screens/gift/gift_screen.dart';
import './screens/leaderboard/leaderboard_screen.dart';
import './screens/shop/shop_screen.dart';
import './screens/story/episode_screen.dart';
import './screens/story/readable_episode_screen.dart';
import './screens/story/reading_streak_screen.dart';
import './screens/widget/widget_setup_screen.dart';
import './screens/story/book_requests_screen.dart';
import './screens/onboarding/interest_selection_screen.dart';
import './services/home_widget_service.dart';
import './screens/story/video_screen.dart';
import './screens/story/question_screen.dart';
import './screens/story/loose_screen.dart';
import './screens/story/win_screen.dart';
import './screens/story/crossword_screen.dart';
import './screens/story/image_puzzle_screen.dart';
import './screens/shorts/shorts_image_puzzle_screen.dart';
import './screens/shop/single_product_screen.dart';
import './screens/shop/cart_screen.dart';
import './screens/shop/shipping_address_screen.dart';
import './screens/shop/order_tracking_screen.dart';
import './screens/gift/single_gift_screen.dart';
import './screens/others/notification_screen.dart';
import './screens/shop/search_product_screen.dart';
import './screens/auth/forgot_password_screen.dart';
import './screens/auth/verify_otp_screen.dart';
import './screens/others/contact_us_screen.dart';
import './screens/story/creator_story_screen.dart';
import './screens/user/edit_profile_screen.dart';
import './screens/user/orders_screen.dart';
import './screens/user/setting_screen.dart';
import './screens/user/blocked_creators_screen.dart';
import './screens/user/profile_privacy_screen.dart';
import './screens/user/point_logs_screen.dart';
import './screens/others/referrals_screen.dart';
import './screens/others/ads_screen.dart';
import './screens/shorts/shorts_screen.dart';
import './screens/shorts/challenges_screen.dart';
import './screens/shorts/shorts_loose_screen.dart';
import './screens/shorts/shorts_question_screen.dart';
import './screens/shorts/shorts_win_screen.dart';
import './screens/others/intro_screen.dart';
import './screens/shorts/single_shorts_screen.dart';
import './theme/theme_constants.dart';
import './theme/AppStateNotifier.dart';
import './screens/shop/vendor_product_screen.dart';
import './screens/shop/for_you_products_screen.dart';
import './screens/others/creator_request_screen.dart';
import './screens/others/mlbb_registration_screen.dart';
import './screens/story/creators_screen.dart';
import './screens/others/bkp_fortune_wheel.dart';
import './screens/user/tab_view_log.dart';
import './screens/user/achievements_screen.dart';
import './screens/user/player_profile_screen.dart';
import './screens/user/user_details_screen.dart';
import './screens/user/user_screen.dart';
import './screens/user/social_media_screen.dart';
// import './screens/auth/onboarding_screen.dart';
import './screens/auth/splash_screen.dart';
// import './providers/onboarding_provider.dart';
import './screens/messages/conversations_screen.dart';
import './screens/messages/messages_screen.dart';
import './screens/others/challenge_request_screen.dart';
import './screens/user/address_screen.dart';
import './screens/challenges/all_challenges_screen.dart';
import './screens/discover/discover_screen.dart';
import './screens/shorts/create/create_shorts_screen.dart';
import './screens/shorts/create/drafts_screen.dart';
import './screens/shorts/create/preview_shorts_screen.dart';
import './screens/shorts/create/create_shorts_question_form_screen.dart';
import './screens/shorts/create/create_shorts_question_screen.dart';
import './screens/create/story/create_story_type_screen.dart';
import './screens/create/shared/ai_content_generator_screen.dart';
import './screens/create/story/create_season_screen.dart';
import './screens/create/story/create_episode_screen.dart';
import './screens/create/story/view_episodes_screen.dart';
import './screens/create/story/manage_episode_questions_screen.dart';
import './screens/create/story/create_question_screen.dart';
import './providers/assistive_touch_provider.dart';
import './providers/video_state_provider.dart';
import './providers/puppet_interaction_provider.dart';
import './models/url.dart';
import './config/app_credentials.dart';
import '../utils/debug_logger.dart';
import './deep_link_handler.dart';
import 'package:baakhapaa/navigation/root_navigator_key.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class _FooterRouteObserver extends NavigatorObserver {
  final ValueNotifier<String?> currentRouteName = ValueNotifier(null);
  final List<String?> _routeStack = [];

  void _updateCurrentRoute(String? routeName) {
    currentRouteName.value = routeName;
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _routeStack.add(route.settings.name);
    _updateCurrentRoute(route.settings.name);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (_routeStack.isNotEmpty) {
      _routeStack.removeLast();
    }
    _routeStack.add(newRoute?.settings.name);
    _updateCurrentRoute(newRoute?.settings.name);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    if (_routeStack.isNotEmpty) {
      _routeStack.removeLast();
    }
    if (previousRoute != null) {
      _updateCurrentRoute(previousRoute.settings.name);
    } else {
      _updateCurrentRoute(_routeStack.isNotEmpty ? _routeStack.last : null);
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    _routeStack.remove(route.settings.name);
    _updateCurrentRoute(_routeStack.isNotEmpty ? _routeStack.last : null);
  }
}

// Add the globalAuth variable - this will be used to track the Auth instance globally
final Auth globalAuth = Auth();

// Global stream controller for reward notifications
final StreamController<Map<String, dynamic>> rewardNotificationStream =
    StreamController<Map<String, dynamic>>.broadcast();

// Trigger auto-login during initialization to prevent UI builder calls
bool _autoLoginTriggered = false;

void _triggerAutoLoginOnce() {
  if (!_autoLoginTriggered) {
    _autoLoginTriggered = true;
    Future.microtask(() => globalAuth.tryAutoLogin());
    DebugLogger.info("🔑 Auto-login triggered during initialization");
  }
}

Future<void> _initializeFirebaseSafely() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    // Startup can race between app and background init paths; ignore duplicate.
    if (e.code != 'duplicate-app') {
      rethrow;
    }
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initializeFirebaseSafely();

  debugPrint("Handling a background message: ${message.messageId}");
}

void _initializeLocalNotifications() {
  const initializationSettingsAndroid = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );
  final initializationSettingsIOS = DarwinInitializationSettings();

  final initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void _showLocalNotification(RemoteMessage message) {
  const androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'channel_id',
    'Channel Name',
    importance: Importance.max,
    priority: Priority.high,
  );

  const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  final notificationDetails = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  flutterLocalNotificationsPlugin.show(
    message.hashCode, // Unique notification ID per message
    message.notification?.title,
    message.notification?.body,
    notificationDetails,
  );
}

void _handleRewardNotification(Map<String, dynamic> data) {
  debug.DebugLogger.info(
    '🎁 REWARD NOTIFICATION: Handling reward notification',
  );
  debug.DebugLogger.info('🎁 REWARD DATA: $data');

  try {
    // SECURITY: Validate notification belongs to current user
    final notificationUserId = data['user_id']?.toString();
    final currentUserId = globalAuth.userId.toString();

    if (notificationUserId != null) {
      if (notificationUserId != currentUserId) {
        debug.DebugLogger.info(
          '🚫 REJECTED: Notification for user $notificationUserId (current: $currentUserId) - FCM token mismatch',
        );
        debug.DebugLogger.info(
          '⚠️  This indicates the FCM token on backend is associated with wrong user. Token will be refreshed.',
        );
        return; // Ignore notifications for other users
      }
      debug.DebugLogger.info(
        '✅ VALIDATED: Notification for current user $currentUserId',
      );
    }

    // Broadcast the reward data through the stream
    // This will show the overlay in the assistive touch widget
    debug.DebugLogger.info('🎁 Broadcasting to stream...');
    rewardNotificationStream.add(data);
    debug.DebugLogger.info(
      '🎁 Stream broadcast complete. Listener count: ${rewardNotificationStream.hasListener}',
    );

    // Note: We don't show a local notification here because this handler is called
    // when the app is in the foreground (from FirebaseMessaging.onMessage).
    // The overlay shown through the stream is sufficient for active users.
    // Local notifications are handled by background message handlers.
  } catch (e) {
    debug.DebugLogger.error('Error handling reward notification: $e');
    SentryService.captureException(e, tag: 'reward_notification_error');
  }
}

void main() async {
  // Initialize Sentry and run the app
  await SentryService.initSentry(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize SharedPreferences first
    final prefs = await SharedPreferences.getInstance();
    final appStateNotifier = AppStateNotifier(prefs);

    // Trigger auto-login once during app initialization
    _triggerAutoLoginOnce();

    // Initialize TutorialFlowProvider
    final tutorialFlowProvider = TutorialFlowProvider();
    final languageProvider = LanguageProvider();
    final currencyProvider = CurrencyProvider();
    // Initialize AssistiveTouchProvider with proper error handling
    final assistiveTouchProvider = AssistiveTouchProvider();
    try {
      await assistiveTouchProvider.initState();
    } catch (e) {
      debug.DebugLogger.puppet(
        'Failed to initialize AssistiveTouchProvider: $e',
      );
      // Also capture this error in Sentry
      await SentryService.captureException(
        e,
        tag: 'initialization_error',
        extra: {'component': 'AssistiveTouchProvider'},
      );
      // Continue even if assistive touch fails to initialize
    }

    // Initialize other services
    try {
      unawaited(
        MobileAds.instance.initialize().then((_) {
          // Preload interstitial ad once MobileAds is ready
          AdService().preloadInterstitial();
          // Fetch backend-controlled ad feature flags
          AdService.fetchAdSettings();
        }).catchError((e) {
          debug.DebugLogger.error('AdMob initialization failed: $e');
        }),
      );
    } catch (e) {
      debug.DebugLogger.error('MobileAds init error: $e');
    }
    await _initializeFirebaseSafely();

    // Initialize Stripe SDK
    try {
      Stripe.publishableKey = AppCredentials.stripePublishableKey;
      // Do NOT set merchantIdentifier — it triggers an Apple Pay async let
      // check inside PaymentSheetLoader.load() which crashes on iOS 17+/macOS 26+
      // via a Swift Concurrency fatal error (_swift_task_dealloc_specific).
      await Stripe.instance.applySettings();
      debug.DebugLogger.info('Stripe SDK initialized');
    } catch (e) {
      debug.DebugLogger.error('Stripe init error: $e');
    }

    // Initialize home screen widget
    try {
      await HomeWidgetService.initialize();
    } catch (e) {
      debug.DebugLogger.error('Failed to initialize HomeWidgetService: $e');
      await SentryService.captureException(
        e,
        tag: 'initialization_error',
        extra: {'component': 'HomeWidgetService'},
      );
      // Continue even if home widget fails to initialize
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    try {
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // For iOS, get APNS token first
        if (Platform.isIOS) {
          debug.DebugLogger.auth('Getting APNS token...');
          String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          debug.DebugLogger.auth('APNS Token: $apnsToken');
        }

        // Get FCM token
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          debug.DebugLogger.auth('FCM Token: $token');
          await prefs.setString('fcmToken', token);
        }
      } else {
        debug.DebugLogger.info('Notification permissions not granted');
      }
    } catch (e, stackTrace) {
      debug.DebugLogger.auth('FCM Token Setup Error: $e');
      debug.DebugLogger.info('Stack Trace: $stackTrace');
      // Capture FCM setup errors in Sentry
      await SentryService.captureException(
        e,
        stackTrace: stackTrace,
        tag: 'fcm_setup_error',
      );
    }

    _initializeLocalNotifications();

    debug.DebugLogger.auth(
      'User granted permission: ${settings.authorizationStatus}',
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debug.DebugLogger.info('Got a message whilst in the foreground!');
      debug.DebugLogger.info('Message data: ${message.data}');

      if (message.notification != null) {
        debug.DebugLogger.info(
          'Message also contained a notification: ${message.notification}',
        );

        // SECURITY: Validate user_id if present in notification data
        final notificationUserId = message.data['user_id']?.toString();
        final currentUserId = globalAuth.userId.toString();

        if (notificationUserId != null && notificationUserId != currentUserId) {
          debug.DebugLogger.info(
            '🚫 FCM: Ignoring notification for user $notificationUserId (current: $currentUserId)',
          );
          return; // Don't process notifications for other users
        }

        // Check if it's a low-priority notification - show as system notification only
        final priority = message.data['priority'];
        if (priority == 'low') {
          debug.DebugLogger.info(
            '🔔 FCM: Low-priority notification - showing as system notification',
          );
          _showLocalNotification(message);

          // Update chat count if it's a chat message
          if (message.data.containsKey('msg_type') &&
              message.data.containsKey('conversation_id')) {
            try {
              Auth auth = globalAuth;
              auth.updateUnreadCount();
            } catch (e) {
              debug.DebugLogger.error('Error updating unread count: $e');
              SentryService.captureException(e, tag: 'messaging_error');
            }
          }
          return; // Don't show overlay for low-priority events
        }

        // Only increment notification count for non-low-priority notifications,
        // since low-priority events (likes, comments, etc.) are sent via FCM only
        try {
          globalAuth.incrementNotificationCount();
          debug.DebugLogger.info(
            '🔔 FCM: Incremented notification count to: ${globalAuth.unreadNotificationCount}',
          );
        } catch (e) {
          debug.DebugLogger.error('Error incrementing notification count: $e');
        }

        // Check if it's a reward/gift notification (high-priority)
        if (message.data.containsKey('type') &&
            (message.data['type'] == 'reward_earned' ||
                message.data['type'] == 'level_upgraded' ||
                message.data['type'] == 'gift_available')) {
          // Handle reward/gift notification
          _handleRewardNotification(message.data);
          // Also show a local notification so it appears in the system tray
          _showLocalNotification(message);
        } else {
          // Show regular notification
          _showLocalNotification(message);
        }

        // Check if it's a chat message by looking at the message data
        if (message.data.containsKey('msg_type') &&
            message.data.containsKey('conversation_id')) {
          try {
            Auth auth = globalAuth;
            auth.updateUnreadCount();
          } catch (e) {
            debug.DebugLogger.error('Error updating unread count: $e');
            // Capture messaging errors in Sentry
            SentryService.captureException(e, tag: 'messaging_error');
          }
        }
      }
    });

    // Handle app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Navigate to specific screen based on message data
      if (message.data['conversation_id'] != null) {
        debug.DebugLogger.info(message.data['conversation_id']);
      }

      final type = message.data['type']?.toString();

      // Handle shorts engagement notification taps
      if (type == 'shorts_liked' ||
          type == 'shorts_commented' ||
          type == 'shorts_donation_received') {
        final rawId = message.data['shorts_id'];
        final shortsId =
            rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
        if (shortsId > 0) {
          mainNavigatorKey.currentState?.pushNamed(
            SingleShortsScreen.routeName,
            arguments: shortsId,
          );
        }
        return;
      }

      // Handle season engagement notification taps
      if (type == 'season_commented' || type == 'season_donation_received') {
        mainNavigatorKey.currentState?.pushNamed(StoryScreen.routeName);
        return;
      }

      // Handle gift notification taps
      if (type == 'gift_available') {
        mainNavigatorKey.currentState?.pushNamed(GiftScreen.routeName);
        return;
      }

      // Handle challenge won taps
      if (type == 'challenge_won') {
        mainNavigatorKey.currentState?.pushNamed(ChallengesScreen.routeName);
        return;
      }

      // Handle collaboration notification taps
      final screen = message.data['screen'];
      if (screen == 'collaborations_received' ||
          screen == 'collaborations_sent') {
        final collabId = message.data['collaboration_id'];
        if (collabId != null) {
          // Navigate to collaboration detail
          mainNavigatorKey.currentState?.pushNamed(
            CollaborationDetailScreen.routeName,
            arguments: int.tryParse(collabId.toString()) ?? 0,
          );
        } else {
          // Navigate to collaborations list
          mainNavigatorKey.currentState?.pushNamed(
            CollaborationsScreen.routeName,
          );
        }
      } else if (screen == 'create_content') {
        // Collaboration is ready — navigate to collaborations screen
        mainNavigatorKey.currentState?.pushNamed(
          CollaborationsScreen.routeName,
        );
      }
    });

    final AppLinks _appLinks = AppLinks();

    // Check for the initial deep link if the app was opened via a deep link
    try {
      Uri? initialLink = await _appLinks.getInitialLink();
      if (initialLink != null && initialLink.toString().isNotEmpty) {
        DebugLogger.info(
          "🔗 MAIN: Received initial link: ${initialLink.toString()}",
        );
        DebugLogger.info(
          "Initial Deep Link detected: ${initialLink.toString()}",
        );

        // For universal links (https://student.baakhapaa.com), handle immediately to prevent browser fallback
        if (initialLink.scheme == 'https' &&
            initialLink.host == Url.deepLinkHost) {
          DebugLogger.info(
            "🌐 MAIN: Universal link detected, processing immediately",
          );

          // Handle referral links - store for later processing after login
          if (initialLink.path == '/register' &&
              initialLink.queryParameters.containsKey('referral')) {
            String referralCode = initialLink.queryParameters['referral']!;
            DebugLogger.info(
              "🎯 MAIN: Immediate referral processing: $referralCode",
            );

            // Store referral with fresh timestamp and mark for immediate navigation
            await prefs.setString('pending_referral_code', referralCode);
            await prefs.setInt(
              'pending_referral_timestamp',
              DateTime.now().millisecondsSinceEpoch,
            );
            await prefs.setString('immediate_navigation', 'register_referral');
            DebugLogger.info(
              "✅ MAIN: Referral stored for immediate navigation",
            );

            debug.DebugLogger.success(
              "Universal link referral handled immediately: $referralCode",
            );
          }
          // All other deep links are handled directly by DeepLinkHandler.init()
          // Do NOT store them to SharedPreferences to avoid persistence issues
        }
        // Custom scheme links (baakhapaa://, baakhapaa_wallet://) are also handled by DeepLinkHandler
      }
    } on Exception catch (e) {
      debug.DebugLogger.error('Failed to get initial link: $e');
      SentryService.captureException(e, tag: 'deep_link_error');
    }

    // Note: The DeepLinkHandler.init() sets up its own stream listener.
    // Do NOT add another listener here to avoid duplicate processing.

    // Initialize Clarity configuration
    final clarityConfig = ClarityConfig(
      projectId: "tbjfd8om2b",
      logLevel: LogLevel
          .None, // Use LogLevel.Verbose for debugging during development
    );

    // Initialize Firebase Analytics for DAU/MAU tracking
    await AnalyticsService.initialize();

    // Test integrations
    ClarityService.testClarityInitialization();
    SentryService.testSentryIntegration();

    runApp(
      // Use MultiProvider to provide both AppStateNotifier and TutorialFlowProvider at the top level
      MultiProvider(
        providers: [
          // Use the global auth instance
          ChangeNotifierProvider<Auth>.value(value: globalAuth),
          ChangeNotifierProvider.value(value: appStateNotifier),
          ChangeNotifierProvider.value(value: tutorialFlowProvider),
          ChangeNotifierProvider.value(value: languageProvider),
          ChangeNotifierProvider.value(value: currencyProvider),
        ],
        child: ClarityWidget(app: MyApp(), clarityConfig: clarityConfig),
      ),
    );
  });
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<Khalti> _khaltiInstance;
  late final _FooterRouteObserver _footerRouteObserver;

  // Use the global mainNavigatorKey from main.dart (imported by DeepLinkHandler)
  @override
  void initState() {
    super.initState();
    _footerRouteObserver = _FooterRouteObserver();

    // Initialize Khalti with the new SDK approach - using a default placeholder PIDX
    // This will be updated when making actual payments
    final payConfig = KhaltiPayConfig(
      publicKey: AppCredentials.isProduction
          ? AppCredentials.khaltiPublicKey
          : AppCredentials.khaltiTestPublicKey,
      // Use an empty string instead of null for the initial configuration
      pidx: '',
      environment: Environment.prod,
    );

    _khaltiInstance = Khalti.init(
      enableDebugging: true,
      payConfig: payConfig,
      onPaymentResult: (paymentResult, khalti) {
        log('Payment Result: ${paymentResult.toString()}');
        // Make the payment result available through a custom method
        _handlePaymentResult(paymentResult);
      },
      onMessage: (
        khalti, {
        description,
        statusCode,
        event,
        needsPaymentConfirmation,
      }) async {
        log(
          'Khalti Message - Description: $description, Status Code: $statusCode, Event: $event, NeedsPaymentConfirmation: $needsPaymentConfirmation',
        );

        // Verify payment if needed
        if (needsPaymentConfirmation == true) {
          try {
            await khalti.verify();
          } catch (e) {
            log('Payment verification failed: $e');
          }
        }
      },
      onReturn: () => log('Successfully redirected to return_url.'),
    );

    // Process any pending deep links after the app is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkHandler().init();
      DeepLinkHandler.processInitialLink();
    });
  }

  @override
  void dispose() {
    _footerRouteObserver.currentRouteName.dispose();
    super.dispose();
  }

  // New method to use the _khaltiInstance field
  Future<Khalti> getKhaltiInstance() async {
    return _khaltiInstance;
  }

  // New method to handle payment results
  void _handlePaymentResult(PaymentResult result) {
    // This method uses the _khaltiInstance field indirectly
    // by handling results from the Khalti payment process
    log('Handling payment result: ${result.payload?.status}');
    // You can add custom application-wide payment handling logic here
  }

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKeyProduct =
        GlobalKey<ScaffoldState>();
    final GlobalKey<ScaffoldState> scaffoldKeyOrder =
        GlobalKey<ScaffoldState>();
    return MultiProvider(
      providers: [
        // Remove the duplicate Auth provider since we're now using globalAuth
        // ChangeNotifierProvider(
        //  create: (ctx) => Auth(),
        // ),
        ChangeNotifierProvider(create: (ctx) => AssistiveTouchProvider()),
        ChangeNotifierProvider(create: (ctx) => RewardsProvider()),
        ChangeNotifierProvider(create: (ctx) => VideoStateProvider()),
        ChangeNotifierProvider(create: (ctx) => PuppetInteractionProvider()),
        // ChangeNotifierProvider(
        //   create: (ctx) => OnboardingProvider(),
        // ),
        // ignore: missing_required_param
        ChangeNotifierProxyProvider<Auth, Story>(
          update: (ctx, auth, previousStory) => Story(
            auth.token,
            previousStory == null ? [] : previousStory.seasons,
            // Preserve critical state from previous provider instance
            selectedSeason: previousStory?.selectedSeason,
            episode: previousStory?.episode,
            featuredSeasons: previousStory?.featuredSeasons,
            suggestedSeasons: previousStory?.suggestedSeasons,
            difficultSeasons: previousStory?.difficultSeasons,
            myListItems: previousStory?.myListItems,
            continueWatchingItems: previousStory?.continueWatchingItems,
            premiumCreatorSeasons: previousStory?.premiumCreatorSeasons,
            creatorSeasons: previousStory?.creatorSeasons,
            readableSeasons: previousStory?.readableSeasons,
            readingStreak: previousStory?.readingStreak,
          ),
          create: (BuildContext context) => Story('', []),
        ),
        // ignore: missing_required_param
        ChangeNotifierProxyProvider<Auth, Shop>(
          update: (ctx, auth, previousShop) =>
              Shop(auth.token, previousShop == null ? {} : previousShop.shop),
          create: (BuildContext context) => Shop('', {}),
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final cart = Cart();
            cart.loadCartFromStorage(); // Load cart from storage on initialization
            return cart;
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final favorites = Favorites();
            favorites
                .loadFavoritesFromStorage(); // Load favorites from storage on initialization
            return favorites;
          },
        ),
        // ignore: missing_required_param
        ChangeNotifierProxyProvider<Auth, Orders>(
          update: (ctx, auth, previousOrders) => Orders(
            auth.token,
            previousOrders == null ? [] : previousOrders.orders,
            auth.username!,
          ),
          create: (BuildContext context) => Orders('', [], ''),
        ),
        // ignore: missing_required_param
        ChangeNotifierProxyProvider<Auth, Leaderboard>(
          update: (ctx, auth, previousLeaderboard) => Leaderboard(
            auth.token,
            previousLeaderboard == null ? [] : previousLeaderboard.leaderboard,
          ),
          create: (BuildContext context) => Leaderboard('', []),
        ),
        // ignore: missing_required_param
        ChangeNotifierProxyProvider<Auth, Announcement>(
          update: (ctx, auth, previousNotification) => Announcement(
            auth.token,
            previousNotification == null
                ? []
                : previousNotification.notification,
            onNotificationRead: () => auth.decrementNotificationCount(),
            onAllNotificationsRead: () => auth.clearNotificationCount(),
          ),
          create: (BuildContext context) => Announcement('', []),
        ),
        // ignore: missing_required_param
        ChangeNotifierProxyProvider<Auth, Shorts>(
          update: (ctx, auth, previousShorts) =>
              Shorts.fromPrevious(auth.token, previousShorts),
          create: (BuildContext context) => Shorts('', []),
        ),
        // ignore: missing_required_param
        ChangeNotifierProxyProvider<Auth, Challenge>(
          update: (ctx, auth, previousChallenges) => Challenge(
            auth.token,
            previousChallenges == null ? [] : previousChallenges.challenges,
          ),
          create: (BuildContext context) => Challenge('', []),
        ),
        // Story Creation Provider
        ChangeNotifierProxyProvider<Auth, StoryCreation>(
          update: (ctx, auth, previousStoryCreation) =>
              StoryCreation(auth.token),
          create: (BuildContext context) => StoryCreation(''),
        ),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProxyProvider<Auth, Comments>(
          create: (ctx) => Comments('', []),
          update: (ctx, auth, previousComments) =>
              Comments(auth.token, previousComments?.comments ?? []),
        ),
        ChangeNotifierProvider(create: (_) => ChatbotProvider()),
        ChangeNotifierProvider(
          create: (_) => SocialAuthProvider()..initialize(),
        ),
        ChangeNotifierProxyProvider<Auth, Levels>(
          update: (ctx, auth, previousLevels) {
            // Preserve state from previous instance if it exists and token hasn't changed
            final Levels levels;
            if (previousLevels != null &&
                previousLevels.authToken == auth.token) {
              // Token hasn't changed, reuse the previous instance
              levels = previousLevels;
            } else if (previousLevels != null) {
              // Token changed, but preserve state from previous instance
              levels = Levels.fromPrevious(previousLevels, auth.token);
            } else {
              // First time creation
              levels = Levels(auth.token);
            }

            // Initialize the level manager when both providers are ready
            if (auth.isAuth) {
              LevelManager.instance.initialize(auth, levels);
            }

            return levels;
          },
          create: (BuildContext context) => Levels(''),
        ),
        ChangeNotifierProxyProvider<Auth, Vendor>(
          create: (_) => Vendor(''),
          update: (ctx, auth, previousVendor) => Vendor(auth.token),
        ),
        ChangeNotifierProxyProvider<Auth, CollaborationProvider>(
          update: (ctx, auth, previous) =>
              CollaborationProvider.fromPrevious(auth.token, previous),
          create: (BuildContext context) => CollaborationProvider(''),
        ),
        ChangeNotifierProxyProvider<Auth, AffiliateProvider>(
          create: (_) => AffiliateProvider(null),
          update: (ctx, auth, previous) {
            final provider = previous ?? AffiliateProvider(auth.token);
            provider.authToken = auth.token;
            provider.updateFromAuth(auth);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<Auth, DeliveryProvider>(
          create: (_) => DeliveryProvider(''),
          update: (ctx, auth, previous) => DeliveryProvider(auth.token),
        ),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: mainNavigatorKey,
            navigatorObservers: [
              SentryNavigatorObserver(),
              AnalyticsService.observer,
              _footerRouteObserver,
            ],
            title: AppLocalizations.of(context)?.appTitle ?? 'Baakhapaa',
            locale: languageProvider.currentLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale?.languageCode) {
                  return supportedLocale;
                }
              }
              return const Locale('en');
            },
            theme: theme_constants.lightTheme,
            themeMode: ThemeMode.dark,
            darkTheme: theme_constants.darkTheme,
            builder: (context, child) {
              return ValueListenableBuilder<String?>(
                valueListenable: _footerRouteObserver.currentRouteName,
                builder: (builderContext, observedRouteName, _) {
                  final routeName = observedRouteName ??
                      ModalRoute.of(builderContext)?.settings.name;
                  final shouldShowFooter = Footer.shouldShowOnRoute(
                    builderContext,
                    child,
                    routeName,
                  );
                  final footerIndex = Footer.indexForRoute(child, routeName);
                  final fullBleedFooter =
                      Footer.isFullBleedRoute(routeName, child);

                  return Scaffold(
                    extendBody: true,
                    body: ConnectivityAwareWidget(
                      child: Stack(
                        children: [
                          child ?? const SizedBox.shrink(),
                          // Global event listener for Pusher/FCM (replaces floating AssistiveTouch)
                          _GlobalEventListener(mainNavKey: mainNavigatorKey),
                          // Quest guidance hint — below header, pointing to puppet
                          const QuestHintBubble(),
                          // Bottom-of-screen puppet speech bubble
                          const PuppetSpeechOverlay(),
                          if (shouldShowFooter && fullBleedFooter)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Footer(
                                footerIndex,
                                navigator: mainNavigatorKey.currentState,
                                fullBleed: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                    bottomNavigationBar: shouldShowFooter && !fullBleedFooter
                        ? Footer(
                            footerIndex,
                            navigator: mainNavigatorKey.currentState,
                          )
                        : null,
                  );
                },
              );
            },
            home: SplashScreen(),
            onGenerateRoute: (RouteSettings settings) {
              switch (settings.name) {
                case '/search-screen':
                  final String? initialQuery = settings.arguments as String?;
                  return MaterialPageRoute(
                    builder: (context) =>
                        SearchScreen(initialQuery: initialQuery),
                  );
                default:
                  return null;
              }
            },
            routes: {
              WelcomeScreen.routeName: (ctx) => WelcomeScreen(),
              AdsScreen.routeName: (ctx) => AdsScreen(),
              LoginScreen.routeName: (ctx) => LoginScreen(),
              RegisterScreen.routeName: (ctx) => RegisterScreen(),
              RegisterWithReferralScreen.routeName: (ctx) =>
                  RegisterWithReferralScreen(),
              StoryScreen.routeName: (ctx) => StoryScreen(),
              ShopScreen.routeName: (ctx) => ShopScreen(),
              LeaderboardScreen.routeName: (ctx) => LeaderboardScreen(),
              GiftScreen.routeName: (ctx) => GiftScreen(),
              UserScreen.routeName: (ctx) => UserScreen(),
              EpisodeScreen.routeName: (ctx) => EpisodeScreen(),
              ReadableEpisodeScreen.routeName: (ctx) => ReadableEpisodeScreen(),
              ReadingStreakScreen.routeName: (ctx) => ReadingStreakScreen(),
              WidgetSetupScreen.routeName: (ctx) => WidgetSetupScreen(),
              BookRequestsScreen.routeName: (ctx) => BookRequestsScreen(),
              VideoScreen.routeName: (ctx) => VideoScreen(),
              QuestionScreen.routeName: (ctx) => QuestionScreen(),
              SettingScreen.routeName: (ctx) => SettingScreen(),
              BlockedCreatorsScreen.routeName: (ctx) => BlockedCreatorsScreen(),
              ProfilePrivacyScreen.routeName: (ctx) => ProfilePrivacyScreen(),
              WinScreen.routeName: (ctx) => WinScreen(),
              LooseScreen.routeName: (ctx) => LooseScreen(),
              CrosswordScreen.routeName: (ctx) => CrosswordScreen(),
              ImagePuzzleScreen.routeName: (ctx) => ImagePuzzleScreen(),
              ShortsImagePuzzleScreen.routeName: (ctx) =>
                  ShortsImagePuzzleScreen(),
              SingleProductScreen.routeName: (ctx) => SingleProductScreen(),
              CartScreen.routeName: (ctx) => CartScreen(),
              SingleGiftScreen.routeName: (ctx) => SingleGiftScreen(),
              EditProfileScreen.routeName: (ctx) => EditProfileScreen(),
              UserDetailsScreen.routeName: (ctx) => UserDetailsScreen(),
              PointLogsScreen.routeName: (ctx) => PointLogsScreen(),
              OrdersScreen.routeName: (ctx) => OrdersScreen(),
              // OnboardingScreen.routeName: (ctx) => OnboardingScreen(),
              ContactUsScreen.routeName: (ctx) => ContactUsScreen(),
              NotificationScreen.routeName: (ctx) => NotificationScreen(),
              SearchProductScreen.routeName: (ctx) => SearchProductScreen(),
              ForgotPasswordScreen.routeName: (ctx) => ForgotPasswordScreen(),
              VerifyOtpScreen.routeName: (ctx) => VerifyOtpScreen(),
              CreatorStoryScreen.routeName: (ctx) => CreatorStoryScreen(),
              ReferralsScreen.routeName: (ctx) => ReferralsScreen(),
              ShortsScreen.routeName: (ctx) => ShortsScreen(),
              ChallengesScreen.routeName: (ctx) => ChallengesScreen(),
              ShortsQuestionScreen.routeName: (ctx) => ShortsQuestionScreen(),
              ShortsLooseScreen.routeName: (ctx) => ShortsLooseScreen(),
              ShortsWinScreen.routeName: (ctx) => ShortsWinScreen(),
              GuestWinnerScreen.routeName: (ctx) => GuestWinnerScreen(),
              IntroScreen.routeName: (ctx) => IntroScreen(),
              SingleShortsScreen.routeName: (ctx) => SingleShortsScreen(),
              VendorProductScreen.routeName: (ctx) => VendorProductScreen(),
              ForYouProductsScreen.routeName: (ctx) => ForYouProductsScreen(),
              CreatorRequestScreen.routeName: (ctx) => CreatorRequestScreen(),
              AnalyticsScreen.routeName: (ctx) => AnalyticsScreen(),
              LevelMapScreen.routeName: (ctx) => LevelMapScreen(),
              MlbbRegistrationScreen.routeName: (ctx) =>
                  MlbbRegistrationScreen(),
              ChallengeRequestScreen.routeName: (ctx) =>
                  ChallengeRequestScreen(),
              SubscriptionScreen.routeName: (ctx) => SubscriptionScreen(),
              CreatorsScreen.routeName: (ctx) => CreatorsScreen(),
              BkpFortuneWheel.routeName: (ctx) => BkpFortuneWheel(),
              AchievementsScreen.routeName: (ctx) => AchievementsScreen(),
              PlayerProfileScreen.routeName: (ctx) => PlayerProfileScreen(),
              AddressScreen.routeName: (ctx) => AddressScreen(),
              TabViewProduct.routeName: (ctx) =>
                  TabViewProduct(scaffoldKey: scaffoldKeyProduct),
              TabViewOrder.routeName: (ctx) =>
                  TabViewProduct(scaffoldKey: scaffoldKeyOrder),
              ConversationsScreen.routeName: (ctx) => ConversationsScreen(),
              MessagesScreen.routeName: (ctx) => MessagesScreen(),
              ChallengeDetailScreen.routeName: (ctx) => ChallengeDetailScreen(),
              AllChallengesScreen.routeName: (ctx) => AllChallengesScreen(),
              DiscoverScreen.routeName: (ctx) => DiscoverScreen(),
              CreateShortsScreen.routeName: (ctx) => CreateShortsScreen(),
              DraftsScreen.routeName: (ctx) => DraftsScreen(),
              PreviewShortsScreen.routeName: (ctx) => PreviewShortsScreen(),
              CreateStoryTypeScreen.routeName: (ctx) => CreateStoryTypeScreen(),
              AiContentGeneratorScreen.routeName: (ctx) =>
                  const AiContentGeneratorScreen(),
              CreateSeasonScreen.routeName: (ctx) => CreateSeasonScreen(),
              CreateEpisodeScreen.routeName: (ctx) => CreateEpisodeScreen(),
              ViewEpisodesScreen.routeName: (ctx) => ViewEpisodesScreen(),
              ManageEpisodeQuestionsScreen.routeName: (ctx) =>
                  ManageEpisodeQuestionsScreen(),
              CreateQuestionScreen.routeName: (ctx) => CreateQuestionScreen(),
              CreateShortsQuestionScreen.routeName: (ctx) =>
                  CreateShortsQuestionScreen(),
              CreateShortsQuestionFormScreen.routeName: (ctx) =>
                  CreateShortsQuestionFormScreen(),
              WeeklyRewardsScreen.routeName: (ctx) => WeeklyRewardsScreen(),
              PointsScreen.routeName: (ctx) => PointsScreen(),
              WalletAuthScreen.routeName: (ctx) => WalletAuthScreen(),
              ChatbotScreen.routeName: (ctx) => ChatbotScreen(),
              LevelsScreen.routeName: (ctx) => LevelsScreen(),
              SocialMediaScreen.routeName: (ctx) => SocialMediaScreen(),
              LanguageSelectorScreen.routeName: (ctx) =>
                  LanguageSelectorScreen(),
              CreateProductScreen.routeName: (ctx) => CreateProductScreen(),
              VendorProductTypeScreen.routeName: (_) =>
                  const VendorProductTypeScreen(),
              AffiliateDashboardScreen.routeName: (ctx) =>
                  const AffiliateDashboardScreen(),
              CollaborationsScreen.routeName: (ctx) => CollaborationsScreen(),
              CollaborationDetailScreen.routeName: (ctx) =>
                  CollaborationDetailScreen(),
              CreateCollaborationScreen.routeName: (ctx) =>
                  CreateCollaborationScreen(),
              InterestSelectionScreen.routeName: (ctx) =>
                  InterestSelectionScreen(),
              ShippingAddressScreen.routeName: (ctx) =>
                  const ShippingAddressScreen(),
              OrderTrackingScreen.routeName: (ctx) =>
                  const OrderTrackingScreen(),
              MyCourses.routeName: (ctx) => const MyCourses(),
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _GlobalEventListener — handles Pusher/FCM events, shows in-app notifications
// Replaces the floating AssistiveTouch overlay for event handling.
// ═══════════════════════════════════════════════════════════════════════════

class _GlobalEventListener extends StatefulWidget {
  final GlobalKey<NavigatorState> mainNavKey;

  const _GlobalEventListener({required this.mainNavKey});

  @override
  State<_GlobalEventListener> createState() => _GlobalEventListenerState();
}

class _GlobalEventListenerState extends State<_GlobalEventListener> {
  StreamSubscription? _pusherSub;
  StreamSubscription? _fcmSub;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _init());
    }
  }

  void _init() {
    // Listen to Pusher realtime events
    try {
      final pusher = Provider.of<PusherService>(context, listen: false);
      _pusherSub = pusher.eventStream.listen(_handlePusherEvent);
    } catch (_) {}

    // Listen to FCM notification events
    _fcmSub = rewardNotificationStream.stream.listen(_handleFcmEvent);

    // First-launch onboarding: show quest hint pointing to header puppet
    _showFirstLaunchQuestIntroIfNeeded();
  }

  /// Shows a golden speech bubble below the header on first launch, teaching
  /// the user that the puppet icon leads to their quests.
  void _showFirstLaunchQuestIntroIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool('puppet_quest_intro_shown') ?? false;
      if (alreadyShown) return;

      final auth = Provider.of<Auth>(context, listen: false);
      if (!auth.isAuth) return;

      // Delay so the app has fully rendered before showing the hint
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      final provider = Provider.of<AssistiveTouchProvider>(
        context,
        listen: false,
      );
      provider.showQuestGuidance(
        '👆 Tap the puppet here to see your quests and level up!',
        seconds: 10,
      );

      await prefs.setBool('puppet_quest_intro_shown', true);
    } catch (_) {}
  }

  void _handlePusherEvent(PusherEventData event) {
    if (!mounted) return;
    if (event.priority == 'low') return;

    // Forward to rewards provider for dashboard data
    try {
      final rewards = Provider.of<RewardsProvider>(context, listen: false);
      rewards.handlePusherEvent(event);
    } catch (_) {}

    // Increment notification bell count for high-priority events
    try {
      globalAuth.incrementNotificationCount();
    } catch (_) {}

    // Show in-app notification
    _showInAppNotification(
      title: _getEventTitle(event.type),
      message: _getEventDescription(event),
      icon: _getEventIcon(event.type),
    );

    // Also show local system notification for high-priority events
    _showLocalPusherNotification(
      title: _getEventTitle(event.type),
      body: _getEventDescription(event),
      id: event.hashCode,
    );
  }

  void _handleFcmEvent(Map<String, dynamic> notification) {
    if (!mounted) return;
    final title = notification['title'] ?? 'Notification';
    final body = notification['body'] ?? '';
    _showInAppNotification(
      title: title,
      message: body,
      icon: Icons.notifications,
    );
  }

  void _showInAppNotification({
    required String title,
    required String message,
    required IconData icon,
  }) {
    if (!mounted) return;
    final overlay = widget.mainNavKey.currentState?.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _InAppNotificationBanner(
        title: title,
        message: message,
        icon: icon,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      try {
        entry.remove();
      } catch (_) {}
    });
  }

  void _showLocalPusherNotification({
    required String title,
    required String body,
    required int id,
  }) {
    const androidDetails = AndroidNotificationDetails(
      'pusher_events',
      'Real-time Events',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    flutterLocalNotificationsPlugin.show(id, title, body, details);
  }

  String _getEventTitle(String? type) {
    switch (type) {
      case 'reward_earned':
        return 'Points Earned!';
      case 'level_upgraded':
        return 'Level Up!';
      case 'gift_available':
        return 'New Gift Available';
      case 'progress_updated':
        return 'Progress Updated';
      default:
        return 'Update';
    }
  }

  String _getEventDescription(PusherEventData event) {
    final data = event.data;
    switch (event.type) {
      case 'reward_earned':
        final amount = data['amount'] ?? data['coins'] ?? '';
        final source = data['source'] ?? '';
        return '+$amount points from $source';
      case 'level_upgraded':
        final newLevel = data['new_level_name'] ?? data['new_level'] ?? '';
        return 'You reached $newLevel!';
      case 'gift_available':
        return data['message'] ?? 'A gift is waiting for you';
      default:
        return data['message'] ?? '';
    }
  }

  IconData _getEventIcon(String? type) {
    switch (type) {
      case 'reward_earned':
        return Icons.monetization_on;
      case 'level_upgraded':
        return Icons.upgrade;
      case 'gift_available':
        return Icons.card_giftcard;
      default:
        return Icons.notifications;
    }
  }

  @override
  void dispose() {
    _pusherSub?.cancel();
    _fcmSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ═══════════════════════════════════════════════════════════════════════════
// _InAppNotificationBanner — Material-style notification at top of screen
// ═══════════════════════════════════════════════════════════════════════════

class _InAppNotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onDismiss;

  const _InAppNotificationBanner({
    required this.title,
    required this.message,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<_InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    // Start dismiss animation after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _ctrl.reverse().whenComplete(widget.onDismiss);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < -100) {
              _ctrl.reverse().whenComplete(widget.onDismiss);
            }
          },
          child: Container(
            margin: EdgeInsets.only(top: topPad + 8, left: 16, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF4B625).withOpacity(0.3),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4B625).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.icon,
                    color: const Color(0xFFF4B625),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.message.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _ctrl.reverse().whenComplete(widget.onDismiss),
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.5),
                    size: 18,
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
