import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/auth.dart';
import '../screens/subscription/subscription_screen.dart';
import '../services/home_widget_service.dart';
import '../utils/debug_logger.dart';
import '../services/analytics_service.dart';
import '../models/url.dart';

/// Centralized ad management service for Baakhapaa.
///
/// Handles banner, interstitial, and native ads with preloading,
/// frequency caps, and consistent styling across the app.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // --- Ad Unit IDs ---
  // Each ad format requires its own ad unit in AdMob.
  // Create separate ad units for: Banner, Interstitial, Native, Rewarded.

  static String get bannerAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-8105529278923041/8331889619' // Google live banner id
      : 'ca-app-pub-8105529278923041/9641101853'; // Google live banner id for iOS

  static String get interstitialAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-8105529278923041/2201595539' // Google live interstitial id
      : 'ca-app-pub-8105529278923041/6827236253'; // Google live interstitial for iOS

  static String get rewardedAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-8105529278923041/8001756243'
      : 'ca-app-pub-8105529278923041/5550852727';

  static String get nativeAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-8105529278923041/5549309026' // Google live native id
      : 'ca-app-pub-8105529278923041/5565620895'; // Google live native id for iOS

  // Preloaded interstitial ad
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  int _interstitialLoadRetries = 0;
  static const int _maxInterstitialRetries = 3;

  // ── Global interstitial frequency controls ─────────────────────────
  // Daily cap: max interstitials shown per calendar day
  static const int _maxInterstitialsPerDay = 8;
  int _interstitialsShownToday = 0;
  DateTime _interstitialDayTracker = DateTime.now();

  // Cooldown: minimum seconds between two interstitials
  static const int _interstitialCooldownSeconds = 90;
  DateTime? _lastInterstitialShownAt;

  // Shorts win counter for showing interstitial every 3 wins
  int _shortsWinCount = 0;

  // Shorts view counter — show interstitial after every N shorts viewed
  int _shortsViewCount = 0;
  static const int _shortsAdInterval = 20; // Show interstitial every 20 shorts

  // Challenge shorts view counter — show interstitial every 7 challenge shorts
  int _challengeViewCount = 0;
  static const int _challengeAdInterval = 20;

  // Win screen banner counter — show promo card every 4th win screen (after 3 AdMob banners)
  int _winBannerCount = 0;
  static const int _winPromoInterval = 4;

  // Counter to show subscription promo instead of AdMob ad occasionally
  int _bannerShowCount = 0;
  static const int _promoFrequency = 4; // Show promo every 4th banner slot

  // Backend-controlled ad feature flags (fetched from /api/ad-config)
  // Defaults to false (ads disabled) until the backend responds.
  static bool _shortsScrollAdsEnabled = false;
  static bool _quizCompletionAdsEnabled = false;
  static bool _bannerAdsEnabled = false;

  /// Whether banner ads across screens are enabled by the backend.
  static bool get bannerAdsEnabled => _bannerAdsEnabled;

  /// Whether ads after completing episode/book quizzes are enabled.
  bool get quizCompletionAdsEnabled => _quizCompletionAdsEnabled;

  /// Fetch ad feature flags from the backend public ad-config endpoint.
  /// Call once at app startup. Silently ignores errors (defaults stay false).
  static Future<void> fetchAdSettings() async {
    try {
      final response = await http
          .get(
            Uri.parse('${Url.rootUrl}/ad-config'),
            headers: Url.baakhapaaHeaders,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null) {
          _shortsScrollAdsEnabled =
              (data['shorts_scroll_ads_enabled']?.toString() == '1');
          _quizCompletionAdsEnabled =
              (data['quiz_completion_ads_enabled']?.toString() == '1');
          _bannerAdsEnabled = (data['banner_ads_enabled']?.toString() == '1') ||
              (data['forced_ads']?.toString() == '1');
          DebugLogger.info(
              '✅ AdService: shorts_scroll_ads=$_shortsScrollAdsEnabled, quiz_completion_ads=$_quizCompletionAdsEnabled, banner_ads=$_bannerAdsEnabled');
        }
      }
    } catch (e) {
      DebugLogger.error('⚠️ AdService: Failed to fetch ad settings: $e');
    }
  }

  // Win promo type rotation: alternate between subscription and widget suggestion
  int _promoTypeCounter = 0;

  /// Get the next promo type to show on win screens.
  /// Alternates between 'subscription' and 'widget'.
  String getNextWinPromoType() {
    _promoTypeCounter++;
    return _promoTypeCounter % 2 == 0 ? 'widget' : 'subscription';
  }

  /// Check if the current user has an active premium subscription.
  /// Premium users should not see any ads.
  static bool isUserPremium(BuildContext context) {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      return auth.isSubscribed;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if global interstitial limits allow showing an ad right now.
  bool _canShowInterstitial() {
    final now = DateTime.now();

    // Reset daily counter if it's a new day
    if (now.day != _interstitialDayTracker.day ||
        now.month != _interstitialDayTracker.month ||
        now.year != _interstitialDayTracker.year) {
      _interstitialsShownToday = 0;
      _interstitialDayTracker = now;
    }

    // Check daily cap
    if (_interstitialsShownToday >= _maxInterstitialsPerDay) {
      DebugLogger.info(
          '⏳ AdService: Daily interstitial cap reached ($_maxInterstitialsPerDay)');
      return false;
    }

    // Check cooldown
    if (_lastInterstitialShownAt != null) {
      final elapsed = now.difference(_lastInterstitialShownAt!).inSeconds;
      if (elapsed < _interstitialCooldownSeconds) {
        DebugLogger.info(
            '⏳ AdService: Interstitial cooldown active (${_interstitialCooldownSeconds - elapsed}s remaining)');
        return false;
      }
    }

    return true;
  }

  /// Record that an interstitial was shown (updates daily count + cooldown).
  void _recordInterstitialShown() {
    _interstitialsShownToday++;
    _lastInterstitialShownAt = DateTime.now();
  }

  /// Increment shorts win counter and return true if an interstitial should show.
  bool incrementShortsWinAndCheckAd() {
    _shortsWinCount++;
    if (_shortsWinCount >= 3) {
      _shortsWinCount = 0;
      return _canShowInterstitial();
    }
    return false;
  }

  /// Increment shorts view counter and return true if an interstitial should show.
  /// Call this each time a user scrolls to a new short.
  bool incrementShortsViewAndCheckAd() {
    if (!_shortsScrollAdsEnabled) return false;
    _shortsViewCount++;
    if (_shortsViewCount >= _shortsAdInterval) {
      _shortsViewCount = 0;
      return _canShowInterstitial();
    }
    return false;
  }

  /// Increment challenge view counter and return true if an interstitial should show.
  /// Call this each time a user scrolls to a new challenge short.
  bool incrementChallengeViewAndCheckAd() {
    if (!_shortsScrollAdsEnabled) return false;
    _challengeViewCount++;
    if (_challengeViewCount >= _challengeAdInterval) {
      _challengeViewCount = 0;
      return _canShowInterstitial();
    }
    return false;
  }

  /// Returns true every 4th call (after 3 AdMob banner impressions) to show
  /// the premium promo card in the win screen banner slot instead of an AdMob ad.
  bool shouldShowWinPromoCard() {
    _winBannerCount++;
    if (_winBannerCount >= _winPromoInterval) {
      _winBannerCount = 0;
      return true;
    }
    return false;
  }

  /// Preload an interstitial ad so it's ready when needed.
  void preloadInterstitial() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialLoadRetries = 0;
          DebugLogger.info('✅ AdService: Interstitial ad preloaded');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          DebugLogger.error(
              '❌ AdService: Interstitial failed to load: ${error.message} (code: ${error.code})');
          // Retry with exponential backoff for transient errors (code 3 = NO_FILL)
          if (_interstitialLoadRetries < _maxInterstitialRetries) {
            _interstitialLoadRetries++;
            final delaySeconds = 30 * _interstitialLoadRetries;
            Future.delayed(Duration(seconds: delaySeconds), () {
              preloadInterstitial();
            });
          }
        },
      ),
    );
  }

  /// Show the preloaded interstitial ad.
  /// [onAdDismissed] is called after the user closes the ad.
  /// Skips showing for premium subscribers or if global limits are exceeded.
  void showInterstitial({VoidCallback? onAdDismissed, BuildContext? context}) {
    // Skip ads for premium users
    if (context != null && isUserPremium(context)) {
      onAdDismissed?.call();
      return;
    }

    // Check global daily cap and cooldown
    if (!_canShowInterstitial()) {
      onAdDismissed?.call();
      return;
    }

    if (_interstitialAd == null) {
      DebugLogger.info('⚠️ AdService: No interstitial ready, skipping');
      onAdDismissed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        preloadInterstitial(); // Preload next one
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        preloadInterstitial();
        onAdDismissed?.call();
        DebugLogger.error(
            '❌ AdService: Interstitial show failed: ${error.message}');
      },
    );

    _recordInterstitialShown();
    _interstitialAd!.show();
    AnalyticsService.logInterstitialShown(trigger: 'interstitial');
  }

  /// Whether an interstitial ad is ready to show.
  bool get isInterstitialReady => _interstitialAd != null;

  /// Check if the next banner slot should show a subscription promo instead.
  /// Returns true every [_promoFrequency]th call for non-subscribed users.
  bool shouldShowSubscriptionPromo(BuildContext context) {
    _bannerShowCount++;
    if (_bannerShowCount % _promoFrequency != 0) return false;
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final user = auth.user;
      // Don't show promo if already subscribed
      if (user['subscription_expired'] != true) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Dispose all ads (call on app exit).
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}

/// A small, app-styled banner ad widget that fits the Baakhapaa design.
///
/// Uses adaptive banner size to match screen width.
/// Occasionally shows a subscription promo instead of an AdMob ad.
class BaakhaBannerAd extends StatefulWidget {
  const BaakhaBannerAd({Key? key}) : super(key: key);

  @override
  State<BaakhaBannerAd> createState() => _BaakhaBannerAdState();
}

class _BaakhaBannerAdState extends State<BaakhaBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _showPromo = false;

  @override
  void initState() {
    super.initState();
    // Check if we should show subscription promo instead
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Don't show any ads for premium users
      if (AdService.isUserPremium(context)) return;

      // Don't show banner ads unless enabled by backend
      if (!AdService.bannerAdsEnabled) return;

      if (AdService().shouldShowSubscriptionPromo(context)) {
        setState(() => _showPromo = true);
      } else {
        _loadBannerAd();
      }
    });
  }

  void _loadBannerAd() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (adSize == null || !mounted) return;

    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          DebugLogger.error(
              '❌ BaakhaBannerAd: Failed to load: ${error.message}');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show subscription promo instead of ad
    if (_showPromo) {
      return const SubscriptionPromoCard();
    }

    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.grey.shade100,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}

/// A subscription promo card shown in place of some ad slots.
class SubscriptionPromoCard extends StatelessWidget {
  const SubscriptionPromoCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).pushNamed(SubscriptionScreen.routeName),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.workspace_premium,
                  color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Remove Ads with Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ad-free experience + bonus coins & exclusive content',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade600, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget suggestion promo card that prompts users to add the home screen widget.
class WidgetSuggestionCard extends StatelessWidget {
  const WidgetSuggestionCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HomeWidgetService.requestPinWidget(),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2E1A), Color(0xFF16403E)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.greenAccent.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.widgets_rounded,
                  color: Colors.greenAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add Streak Widget',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Track your daily streak right from your home screen',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.teal.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A win-screen promo widget that shows either subscription or widget promo based on rotation.
class WinScreenPromo extends StatelessWidget {
  const WinScreenPromo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final promoType = AdService().getNextWinPromoType();
    if (promoType == 'widget' && Platform.isAndroid) {
      return const WidgetSuggestionCard();
    }
    return const SubscriptionPromoCard();
  }
}
