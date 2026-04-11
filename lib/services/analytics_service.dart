import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import '../utils/debug_logger.dart';

/// Centralized Firebase Analytics service for Baakhapaa.
///
/// Tracks DAU/MAU automatically via Firebase, plus custom events
/// for key user actions: reading, quizzes, streaks, ads, purchases,
/// subscriptions, and content engagement.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static bool _isInitialized = false;

  /// Check if Firebase is initialized
  static bool get isInitialized => _isInitialized;

  /// Navigator observer for automatic screen tracking in MaterialApp.
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ──────────────────────── INITIALIZATION ────────────────────────

  /// Call once after Firebase.initializeApp().
  static Future<void> initialize() async {
    try {
      // Verify Firebase is initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized yet, skipping analytics init');
        return;
      }

      await _analytics.setAnalyticsCollectionEnabled(true);
      _isInitialized = true;
      DebugLogger.info(
          '📊 AnalyticsService: Firebase Analytics initialized successfully');
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: Init failed: $e');
      _isInitialized = false;
    }
  }

  // ──────────────────────── USER IDENTITY ────────────────────────

  /// Set user ID for cross-device analytics.
  static Future<void> setUserId(String userId) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping setUserId');
        return;
      }

      await _analytics.setUserId(id: userId);
      DebugLogger.info('📊 AnalyticsService: User ID set: $userId');
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: setUserId failed: $e');
    }
  }

  /// Clear user ID on logout.
  static Future<void> clearUserId() async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping clearUserId');
        return;
      }

      await _analytics.setUserId(id: null);
      DebugLogger.info('📊 AnalyticsService: User ID cleared');
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: clearUserId failed: $e');
    }
  }

  /// Set user properties for segmentation in Firebase console.
  static Future<void> setUserProperties({
    String? subscriptionTier,
    String? role,
    String? preferredLanguage,
    String? level,
    bool? isCreator,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping setUserProperties');
        return;
      }

      if (subscriptionTier != null) {
        await _analytics.setUserProperty(
          name: 'subscription_tier',
          value: subscriptionTier,
        );
      }
      if (role != null) {
        await _analytics.setUserProperty(name: 'user_role', value: role);
      }
      if (preferredLanguage != null) {
        await _analytics.setUserProperty(
          name: 'preferred_language',
          value: preferredLanguage,
        );
      }
      if (level != null) {
        await _analytics.setUserProperty(name: 'user_level', value: level);
      }
      if (isCreator != null) {
        await _analytics.setUserProperty(
          name: 'is_creator',
          value: isCreator.toString(),
        );
      }
      DebugLogger.info('📊 AnalyticsService: User properties updated');
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: setUserProperties failed: $e');
    }
  }

  // ──────────────────────── SCREEN VIEWS ────────────────────────

  /// Log manual screen view (for cases where navigator observer doesn't fire).
  static Future<void> logScreenView(String screenName,
      {String? screenClass}) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logScreenView');
        return;
      }

      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logScreenView failed: $e');
    }
  }

  // ──────────────────────── AUTH EVENTS ────────────────────────

  /// User signed up.
  static Future<void> logSignUp({required String method}) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logSignUp');
        return;
      }

      await _analytics.logSignUp(signUpMethod: method);
      DebugLogger.info('📊 AnalyticsService: sign_up [$method]');
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logSignUp failed: $e');
    }
  }

  /// User logged in.
  static Future<void> logLogin({required String method}) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logLogin');
        return;
      }

      await _analytics.logLogin(loginMethod: method);
      DebugLogger.info('📊 AnalyticsService: login [$method]');
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logLogin failed: $e');
    }
  }

  // ──────────────────────── BOOK / READING EVENTS ────────────────────────

  /// User opened a readable episode (book chapter).
  static Future<void> logBookRead({
    required int seasonId,
    required int episodeId,
    required String title,
    String? language,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logBookRead');
        return;
      }

      await _analytics.logEvent(
        name: 'book_read',
        parameters: {
          'season_id': seasonId,
          'episode_id': episodeId,
          'title': _truncate(title),
          if (language != null) 'language': language,
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logBookRead failed: $e');
    }
  }

  /// User completed reading all pages of a chapter.
  static Future<void> logBookCompleted({
    required int seasonId,
    required int episodeId,
    required String title,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logBookCompleted');
        return;
      }

      await _analytics.logEvent(
        name: 'book_completed',
        parameters: {
          'season_id': seasonId,
          'episode_id': episodeId,
          'title': _truncate(title),
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logBookCompleted failed: $e');
    }
  }

  // ──────────────────────── QUIZ / GAME EVENTS ────────────────────────

  /// User completed a quiz (win or lose).
  static Future<void> logQuizCompleted({
    required String quizType,
    required bool won,
    int? score,
    int? totalQuestions,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logQuizCompleted');
        return;
      }

      await _analytics.logEvent(
        name: 'quiz_completed',
        parameters: {
          'quiz_type': quizType, // 'episode', 'shorts'
          'won': won.toString(),
          if (score != null) 'score': score,
          if (totalQuestions != null) 'total_questions': totalQuestions,
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logQuizCompleted failed: $e');
    }
  }

  /// User played a crossword puzzle.
  static Future<void> logCrosswordPlayed({
    required bool completed,
    int? timeTakenSeconds,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logCrosswordPlayed');
        return;
      }

      await _analytics.logEvent(
        name: 'crossword_played',
        parameters: {
          'completed': completed.toString(),
          if (timeTakenSeconds != null) 'time_taken_seconds': timeTakenSeconds,
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logCrosswordPlayed failed: $e');
    }
  }

  /// User played an image puzzle.
  static Future<void> logPuzzlePlayed({
    required String puzzleType,
    required bool completed,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logPuzzlePlayed');
        return;
      }

      await _analytics.logEvent(
        name: 'puzzle_played',
        parameters: {
          'puzzle_type': puzzleType, // 'image', 'shorts_image'
          'completed': completed.toString(),
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logPuzzlePlayed failed: $e');
    }
  }

  // ──────────────────────── STREAK EVENTS ────────────────────────

  /// User continued their reading streak.
  static Future<void> logStreakContinued({required int streakDay}) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logStreakContinued');
        return;
      }

      await _analytics.logEvent(
        name: 'streak_continued',
        parameters: {'streak_day': streakDay},
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logStreakContinued failed: $e');
    }
  }

  // ──────────────────────── SHORTS EVENTS ────────────────────────

  /// User watched a short.
  static Future<void> logShortsViewed({
    required int shortsId,
    String? topicName,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logShortsViewed');
        return;
      }

      await _analytics.logEvent(
        name: 'shorts_viewed',
        parameters: {
          'shorts_id': shortsId,
          if (topicName != null) 'topic': _truncate(topicName),
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logShortsViewed failed: $e');
    }
  }

  /// User liked a short.
  static Future<void> logShortsLiked({required int shortsId}) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logShortsLiked');
        return;
      }

      await _analytics.logEvent(
        name: 'shorts_liked',
        parameters: {'shorts_id': shortsId},
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logShortsLiked failed: $e');
    }
  }

  // ──────────────────────── AD EVENTS ────────────────────────

  /// User watched a rewarded ad.
  static Future<void> logRewardedAdWatched({String? placement}) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logRewardedAdWatched');
        return;
      }

      await _analytics.logEvent(
        name: 'rewarded_ad_watched',
        parameters: {
          if (placement != null) 'placement': placement,
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logRewardedAdWatched failed: $e');
    }
  }

  /// Interstitial ad was shown.
  static Future<void> logInterstitialShown({String? trigger}) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logInterstitialShown');
        return;
      }

      await _analytics.logEvent(
        name: 'interstitial_shown',
        parameters: {
          if (trigger != null) 'trigger': trigger,
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logInterstitialShown failed: $e');
    }
  }

  // ──────────────────── SUBSCRIPTION EVENTS ────────────────────

  /// User subscribed.
  static Future<void> logSubscriptionStarted({
    required String tier,
    required String paymentMethod,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logSubscriptionStarted');
        return;
      }

      await _analytics.logEvent(
        name: 'subscription_started',
        parameters: {
          'tier': tier,
          'payment_method': paymentMethod,
        },
      );
    } catch (e) {
      DebugLogger.error(
          '📊 AnalyticsService: logSubscriptionStarted failed: $e');
    }
  }

  // ──────────────────── PURCHASE / COIN EVENTS ────────────────────

  /// User purchased coins.
  static Future<void> logCoinPurchase({
    required int amount,
    required String paymentMethod,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logCoinPurchase');
        return;
      }

      await _analytics.logEvent(
        name: 'coin_purchase',
        parameters: {
          'amount': amount,
          'payment_method': paymentMethod,
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logCoinPurchase failed: $e');
    }
  }

  /// User placed a shop order.
  static Future<void> logShopPurchase({
    required double totalAmount,
    required String paymentMethod,
    required int itemCount,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logShopPurchase');
        return;
      }

      await _analytics.logPurchase(
        currency: 'NPR',
        value: totalAmount,
        parameters: {
          'payment_method': paymentMethod,
          'item_count': itemCount,
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logShopPurchase failed: $e');
    }
  }

  // ──────────────────── CONTENT ENGAGEMENT ────────────────────

  /// User unlocked a season.
  static Future<void> logSeasonUnlocked({
    required int seasonId,
    required String title,
    required String method,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logSeasonUnlocked');
        return;
      }

      await _analytics.logEvent(
        name: 'season_unlocked',
        parameters: {
          'season_id': seasonId,
          'title': _truncate(title),
          'method': method, // 'coins', 'premium_free', 'subscription'
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logSeasonUnlocked failed: $e');
    }
  }

  /// User donated coins to a creator.
  static Future<void> logDonation({
    required int amount,
    required String contentType,
    required int contentId,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logDonation');
        return;
      }

      await _analytics.logEvent(
        name: 'donation_sent',
        parameters: {
          'amount': amount,
          'content_type': contentType, // 'shorts', 'episode'
          'content_id': contentId,
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logDonation failed: $e');
    }
  }

  /// User shared content.
  static Future<void> logShare({
    required String contentType,
    required int contentId,
    String? method,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logShare');
        return;
      }

      await _analytics.logShare(
        contentType: contentType,
        itemId: contentId.toString(),
        method: method ?? 'unknown',
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logShare failed: $e');
    }
  }

  /// User used TTS (text-to-speech) feature.
  static Future<void> logTTSUsed({
    required int episodeId,
    String? language,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logTTSUsed');
        return;
      }

      await _analytics.logEvent(
        name: 'tts_used',
        parameters: {
          'episode_id': episodeId,
          if (language != null) 'language': language,
        },
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logTTSUsed failed: $e');
    }
  }

  // ──────────────────── CHALLENGE EVENTS ────────────────────

  /// User entered a challenge.
  static Future<void> logChallengeEntered({required int challengeId}) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logChallengeEntered');
        return;
      }

      await _analytics.logEvent(
        name: 'challenge_entered',
        parameters: {'challenge_id': challengeId},
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logChallengeEntered failed: $e');
    }
  }

  // ──────────────────── REFERRAL EVENTS ────────────────────

  /// User shared their referral code.
  static Future<void> logReferralShared() async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logReferralShared');
        return;
      }

      await _analytics.logEvent(name: 'referral_shared');
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logReferralShared failed: $e');
    }
  }

  /// User signed up via referral.
  static Future<void> logReferralSignUp({required String referralCode}) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logReferralSignUp');
        return;
      }

      await _analytics.logEvent(
        name: 'referral_sign_up',
        parameters: {'referral_code': referralCode},
      );
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logReferralSignUp failed: $e');
    }
  }

  // ──────────────────── SEARCH EVENTS ────────────────────

  /// User searched for content.
  static Future<void> logSearch({required String query}) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logSearch');
        return;
      }

      await _analytics.logSearch(searchTerm: query);
    } catch (e) {
      DebugLogger.error('📊 AnalyticsService: logSearch failed: $e');
    }
  }

  // ──────────────────── GENERIC EVENT ────────────────────

  /// Log any custom event not covered above.
  static Future<void> logCustomEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      // Skip if Firebase isn't initialized
      if (Firebase.apps.isEmpty) {
        DebugLogger.warning(
            '📊 AnalyticsService: Firebase not initialized, skipping logCustomEvent');
        return;
      }

      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      DebugLogger.error(
          '📊 AnalyticsService: logCustomEvent [$name] failed: $e');
    }
  }

  // ──────────────────── HELPERS ────────────────────

  /// Firebase Analytics limits string param values to 100 chars.
  static String _truncate(String value, [int maxLength = 100]) {
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }
}
