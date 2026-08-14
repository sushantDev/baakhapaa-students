import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/skeleton_loading.dart';
import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/screens/user/tab_view_log.dart';
import 'package:baakhapaa/screens/user/weekly_rewards_screen.dart';
import 'package:baakhapaa/screens/user/achievements_screen.dart';
// import 'package:baakhapaa/widgets/subscriptionBanner.dart';
import 'package:baakhapaa/screens/story/story_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:page_transition/page_transition.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';

class PointsScreen extends StatefulWidget {
  static const routeName = '/points-screen';

  const PointsScreen({Key? key}) : super(key: key);

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen>
    with PuppetInteractionMixin, WidgetsBindingObserver {
  var _isLoading = true;
  var _isAuthChecked = false; // Track if auth check is complete
  late Map<String, dynamic> _user = {};
  late Map<String, dynamic> _userInformation = {};
  List<dynamic> _chartCoinLogs = []; // Add chart data
  bool _isLoadingChart = false; // Add chart loading state
  late RewardedAd? _rewardedAd;
  int _numRewardedLoadAttempts = 0;
  int maxFailedLoadAttempts = 3;
  final adUnitId = Platform.isAndroid
      ? 'ca-app-pub-8105529278923041/8001756243'
      : 'ca-app-pub-8105529278923041/5550852727';
  int _adsCallCount = 0;
  late DateTime _lastCalledDate = DateTime.now();
  Timer _timer = Timer(Duration.zero, () {});
  int _maxAdsCallLimit = 100;

  // Auto-lock functionality
  bool _isAutoLockEnabled = true;
  int _autoLockDuration = 5; // minutes
  Timer? _autoLockTimer;
  late DateTime _lastUserInteraction = DateTime.now();

  // Store provider references for safe disposal
  Auth? _authProvider;
  PuppetInteractionProvider? _puppetProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize puppet provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<PuppetInteractionProvider>().initState();
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }

      // Check wallet access after first frame
      _checkWalletAccess();
    });

    // Load auto-lock settings
    _loadAutoLockSettings();

    _createRewardedAd();
    _loadAdsCallCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider references for safe disposal
    try {
      _authProvider = Provider.of<Auth>(context, listen: false);
    } catch (e) {
      DebugLogger.auth('Auth provider not available: $e');
    }
    try {
      _puppetProvider =
          Provider.of<PuppetInteractionProvider>(context, listen: false);
    } catch (e) {
      DebugLogger.puppet('Puppet provider not available: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isAuthChecked) {
      _resetAutoLockTimer();
    }
  }

  Future<void> _loadAutoLockSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoLockEnabled = prefs.getBool('wallet_auto_lock_enabled') ?? true;
      _autoLockDuration = prefs.getInt('wallet_auto_lock_duration') ?? 5;
    });

    // Start auto-lock timer if auth is checked
    if (_isAuthChecked) {
      _startAutoLockTimer();
    }
  }

  void _startAutoLockTimer() {
    // Cancel existing timer if any
    _autoLockTimer?.cancel();

    if (!_isAutoLockEnabled) {
      return;
    }

    _lastUserInteraction = DateTime.now();

    // Start a periodic timer to check for inactivity
    _autoLockTimer = Timer.periodic(
      const Duration(seconds: 30), // Check every 30 seconds
      (_) {
        _checkAndLockIfInactive();
      },
    );
  }

  void _resetAutoLockTimer() {
    if (!_isAutoLockEnabled) {
      return;
    }

    _lastUserInteraction = DateTime.now();
  }

  void _checkAndLockIfInactive() {
    if (!_isAuthChecked || !_isAutoLockEnabled) {
      return;
    }

    final now = DateTime.now();
    final elapsedMinutes = now.difference(_lastUserInteraction).inMinutes;

    if (elapsedMinutes >= _autoLockDuration) {
      // Lock the wallet
      _lockWallet();
    }
  }

  Future<void> _lockWallet() async {
    // Cancel the auto-lock timer
    _autoLockTimer?.cancel();

    // Clear wallet session
    var auth = Provider.of<Auth>(context, listen: false);
    await auth.clearWalletSession();

    if (mounted) {
      // Navigate to story screen immediately
      Navigator.of(context).pushNamedAndRemoveUntil(
        StoryScreen.routeName,
        (route) => false, // Remove all routes
      );

      // Show lock message after navigation starts
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Wallet locked due to inactivity. Returning to stories.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rewardedAd?.dispose();
    _timer.cancel();

    // Cancel auto-lock timer
    _autoLockTimer?.cancel();

    // Clear puppet interactions using stored provider (safe during disposal)
    try {
      if (_puppetProvider != null) {
        _puppetProvider!.clearCurrentScreen();
      }
    } catch (e) {
      DebugLogger.puppet('Error clearing puppet interactions: $e');
    }

    // Clear wallet session using stored provider (safe during disposal)
    try {
      if (_authProvider != null) {
        _authProvider!.clearWalletSession();
      }
    } catch (e) {
      DebugLogger.auth('Error clearing wallet session: $e');
    }

    super.dispose();
  }

  Future<void> _checkWalletAccess() async {
    // Prevent multiple simultaneous auth checks
    if (_isAuthChecked) return;

    setState(() {
      _isAuthChecked = true;
    });
    _initData();
  }

  Future<void> _initData() async {
    var auth = Provider.of<Auth>(context, listen: false);
    await auth.getUser();
    try {
      await auth.fetchDailyRewardsStatus();
    } catch (error) {
      DebugLogger.api('Error fetching rewards status: $error');
    }

    // Fetch chart data
    await _fetchChartData();

    setState(() {
      _user = auth.user;
      _userInformation = auth.userInformation ?? {};
      _isLoading = false;
    });
  }

  Future<void> _fetchChartData() async {
    setState(() {
      _isLoadingChart = true;
    });

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final response = await auth.getCoinLogs(page: 1);
      setState(() {
        _chartCoinLogs = response['data'] ?? [];
        _isLoadingChart = false;
      });
    } catch (error) {
      DebugLogger.api('Error fetching chart data: $error');
      setState(() {
        _chartCoinLogs = [];
        _isLoadingChart = false;
      });
    }
  }

  void _createRewardedAd() {
    RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _rewardedAd = ad;
            _numRewardedLoadAttempts = 0;
          },
          onAdFailedToLoad: (LoadAdError error) {
            _rewardedAd = null;
            _numRewardedLoadAttempts += 1;
            if (_numRewardedLoadAttempts < maxFailedLoadAttempts) {
              _createRewardedAd();
            }
          },
        ));
  }

  Future<void> _loadAdsCallCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _adsCallCount = prefs.getInt('functionCallCount') ?? 0;
      int lastCalledTimestamp = prefs.getInt('lastCalledDate') ?? 0;
      _lastCalledDate =
          DateTime.fromMillisecondsSinceEpoch(lastCalledTimestamp);
    });
  }

  Future<void> _incrementAdsCallCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _adsCallCount++;
      prefs.setInt('functionCallCount', _adsCallCount);
      prefs.setInt('lastCalledDate', DateTime.now().millisecondsSinceEpoch);
    });
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _showRewardedAd() {
    if (_rewardedAd == null) return;

    if (!isSameDay(_lastCalledDate, DateTime.now())) {
      _adsCallCount = 0;
    }

    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {},
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _createRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _createRewardedAd();
      },
    );

    if (_adsCallCount < _maxAdsCallLimit) {
      _rewardedAd?.setImmersiveMode(true);
      _rewardedAd?.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
          var auth = Provider.of<Auth>(context, listen: false);
          final rewardPoints =
              int.tryParse(_user['ads_watched_points']?.toString() ?? '') ?? 5;
          await auth
              .coinTransaction(rewardPoints, 'credited',
                  'Rewards granted from watching ads.')
              .then((_) {
            showScaffoldMessenger(context,
                '${context.l10n.appTitle} ${context.l10n.points} transferred successfully!');
            _initData();
          });
          _incrementAdsCallCount();
          _rewardedAd = null;
        },
      );
    } else {
      _showAdsLimitDialog();
    }
  }

  void _showAdsLimitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            "Ads Limit Reached",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                "You've reached the daily limit for watching ads. Please come back tomorrow!",
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _claimDailyReward() async {
    final auth = Provider.of<Auth>(context, listen: false);
    final rewardsData = auth.dailyRewardsData;

    if (rewardsData['can_claim_today'] == false) {
      _showAlreadyClaimedDialog();
      return;
    }

    _showClaimingDialog();

    try {
      final result = await auth.claimDailyReward();

      // Check if widget is still mounted before using context
      if (!mounted) return;

      Navigator.of(context).pop();

      final reward = result['reward'];
      if (reward != null) {
        _showSuccessDialog(reward);
      } else {
        _showGenericSuccessDialog(result['message']);
      }

      await _initData();
    } catch (e) {
      // Check if widget is still mounted before using context
      if (!mounted) return;

      Navigator.of(context).pop();
      _showErrorDialog(e.toString());
    }
  }

  void _showAlreadyClaimedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Already Claimed', style: TextStyle(color: Colors.orange)),
        content: Text(
            'You have already claimed your reward today. Come back tomorrow for more points!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed(WeeklyRewardsScreen.routeName);
            },
            child: Text(context.l10n.weeklyReward),
          ),
        ],
      ),
    );
  }

  void _showClaimingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(width: 20),
            Text("Claiming reward...")
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> reward) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title:
            Text('🎉 Reward Claimed!', style: TextStyle(color: Colors.green)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard, size: 48, color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'You received ${reward['points']} points of ${reward['name']}!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Come back tomorrow for more rewards.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  void _showGenericSuccessDialog(String? message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Success!', style: TextStyle(color: Colors.green)),
        content: Text(message ?? 'Daily reward claimed successfully!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Error', style: TextStyle(color: Colors.red)),
        content: Text('Failed to claim reward: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _showWithdrawalDialog() {
    final auth = Provider.of<Auth>(context, listen: false);
    final hasBadge = auth.hasPointsToNrsConversionBadgeId;

    if (!hasBadge) {
      _showBadgeRequiredDialog();
      return;
    }

    _showWithdrawalFormDialog(auth);
  }

  void _showBadgeRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.red, width: 2),
          ),
          title: const Text(
            'Badge Required',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'You need to earn the Points Conversion Badge before you can withdraw coins.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Complete achievements to unlock this badge.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  PageTransition(
                    child: AchievementsScreen(),
                    type: PageTransitionType.fade,
                  ),
                );
              },
              child: const Text('View Badge'),
            ),
          ],
        );
      },
    );
  }

  void _showWithdrawalFormDialog(Auth auth) {
    final formKey = GlobalKey<FormState>();
    String paymentMethod = 'Bank Transfer';
    String paymentDetails = '';
    double amount = 0.0;
    int pointsToConvert = 0;
    final conversionRate = auth.nrsPerBaakhapaaPoints;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.amber, width: 2),
          ),
          title: const Text(
            'Request Withdrawal',
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (_, setState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Conversion Rate: ${conversionRate.toStringAsFixed(2)} NPR per point',
                        style: TextStyle(color: Colors.amber),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: '${context.l10n.pointLog} to Convert',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          pointsToConvert = int.tryParse(value) ?? 0;
                          amount = pointsToConvert * conversionRate;
                          setState(() {});
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter points to convert';
                          }
                          final points = int.tryParse(value);
                          if (points == null || points <= 0) {
                            return 'Please enter a valid number';
                          }
                          if (points >
                              (_userInformation['available_coins'] ?? 0)) {
                            return 'Insufficient points';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Amount to receive: NPR ${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        // initialValue: paymentMethod,
                        decoration: InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: [
                          'Bank Transfer',
                          'Mobile Banking',
                          'eSewa',
                          'Khalti'
                        ]
                            .map((method) => DropdownMenuItem(
                                  value: method,
                                  child: Text(method),
                                ))
                            .toList(),
                        onChanged: (value) {
                          paymentMethod = value!;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Payment Details',
                          hintText: 'Enter account details or phone number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (value) {
                          paymentDetails = value;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter payment details';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop();
                  await _processWithdrawal(
                    auth: auth,
                    amount: amount,
                    pointsToConvert: pointsToConvert,
                    paymentMethod: paymentMethod,
                    paymentDetails: paymentDetails,
                  );
                }
              },
              child: const Text('Submit Request'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processWithdrawal({
    required Auth auth,
    required double amount,
    required int pointsToConvert,
    required String paymentMethod,
    required String paymentDetails,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.amber),
              SizedBox(height: 16),
              Text('Processing your withdrawal request...'),
            ],
          ),
        );
      },
    );

    try {
      await auth.requestWithdrawal(
        amount,
        pointsToConvert,
        paymentMethod,
        paymentDetails,
      );

      Navigator.of(context).pop();
      _showWithdrawalSuccessDialog();
      await _initData();
    } catch (error) {
      Navigator.of(context).pop();
      _showWithdrawalErrorDialog(error.toString());
    }
  }

  void _showWithdrawalSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.green, width: 2),
          ),
          title: const Text(
            'Success',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 48, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Your withdrawal request has been submitted successfully.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'It will be processed within 24-48 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showWithdrawalErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.red, width: 2),
          ),
          title: const Text(
            'Error',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Text('Failed to process your withdrawal request: $error'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required String imagePath,
    required String text,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 98,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    imagePath,
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 6),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildActionButton(
            imagePath: 'assets/images/transp.png',
            text: context.l10n.transactionHistory,
            onTap: () {
              Navigator.push(
                context,
                PageTransition(
                  child: TabViewOrder(
                    scaffoldKey: GlobalKey<ScaffoldState>(),
                  ),
                  type: PageTransitionType.fade,
                ),
              );
            },
          ),
          SizedBox(width: 12),
          _buildActionButton(
            imagePath: 'assets/images/giftp.png',
            text: context.l10n.weeklyReward,
            onTap: () {
              Navigator.of(context).pushNamed(WeeklyRewardsScreen.routeName);
            },
          ),
          SizedBox(width: 12),
          _buildActionButton(
            imagePath: 'assets/images/cupp.png',
            text: context.l10n.badgesAchievement,
            onTap: () {
              Navigator.of(context).pushNamed(AchievementsScreen.routeName);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPointsChart() {
    // Process coin logs to create chart data
    final chartData = _processChartData(_chartCoinLogs);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.pointsOverview,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.refresh, size: 20),
                    onPressed: () async {
                      await _refreshData();
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          child: TabViewOrder(
                            scaffoldKey: GlobalKey<ScaffoldState>(),
                          ),
                          type: PageTransitionType.fade,
                        ),
                      );
                    },
                    child: Text(context.l10n.viewDetails),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          // Summary cards with animations
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context.l10n.credited,
                  chartData['totalCredited'].toString(),
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  context.l10n.debited,
                  chartData['totalDebited'].toString(),
                  Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Chart with loading state
          Container(
            height: 240, // Increased height for better visibility
            child: _isLoadingChart
                ? const ShimmerLoading(
                    child: SkeletonBox(
                        width: double.infinity, height: 200, borderRadius: 12),
                  )
                : chartData['spots'].isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No transaction data available',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start earning points to see your progress',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : AnimatedContainer(
                        duration: Duration(milliseconds: 800),
                        curve: Curves.easeInOut,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: chartData['maxValue'] / 4,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: chartData['dates'].length > 4
                                      ? 40
                                      : 30, // More space for rotated text
                                  interval: chartData['dates'].length <= 4
                                      ? 1
                                      : chartData['dates'].length <= 7
                                          ? 1
                                          : 2, // Show all or every other
                                  getTitlesWidget: (value, meta) {
                                    return _buildBottomTitleWidget(
                                        value, chartData['dates']);
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  interval: chartData['maxValue'] / 4,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            minX: 0,
                            maxX: (chartData['dates'].length - 1).toDouble(),
                            minY: 0,
                            maxY: chartData['maxValue'],
                            lineBarsData: [
                              LineChartBarData(
                                spots: chartData['creditedSpots'],
                                isCurved: true,
                                color: Colors.green,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter:
                                      (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: 4,
                                      color: Colors.green,
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.green.withValues(alpha: 0.1),
                                ),
                              ),
                              LineChartBarData(
                                spots: chartData['debitedSpots'],
                                isCurved: true,
                                color: Colors.red,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter:
                                      (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: 4,
                                      color: Colors.red,
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.red.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(context.l10n.credited, Colors.green),
              SizedBox(width: 20),
              _buildLegendItem(context.l10n.debited, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomTitleWidget(double value, List<String> dates) {
    final index = value.toInt();
    if (index >= 0 && index < dates.length) {
      return Padding(
        padding: EdgeInsets.only(top: 8),
        child: RotatedBox(
          quarterTurns:
              dates.length > 4 ? 1 : 0, // Rotate text if too many dates
          child: Text(
            dates[index],
            style: TextStyle(
              color: Colors.grey,
              fontSize: dates.length > 4 ? 9 : 10,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }

  Map<String, dynamic> _processChartData(List<dynamic> coinLogs) {
    if (coinLogs.isEmpty) {
      return {
        'spots': <FlSpot>[],
        'creditedSpots': <FlSpot>[],
        'debitedSpots': <FlSpot>[],
        'dates': <String>[],
        'totalCredited': 0,
        'totalDebited': 0,
        'maxValue': 100.0,
      };
    }

    // Group transactions by date
    Map<String, Map<String, int>> dailyData = {};
    int totalCredited = 0;
    int totalDebited = 0;

    for (var log in coinLogs) {
      final date = DateTime.parse(log['created_at']);
      final dateKey = DateFormat('M/d').format(date); // Shorter format
      final coins = int.tryParse(log['coin'].toString()) ?? 0;
      final status = log['status']?.toString() ?? '';

      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = {'credited': 0, 'debited': 0};
      }

      if (status == 'credited') {
        dailyData[dateKey]!['credited'] =
            dailyData[dateKey]!['credited']! + coins;
        totalCredited += coins;
      } else if (status == 'debited') {
        dailyData[dateKey]!['debited'] =
            dailyData[dateKey]!['debited']! + coins;
        totalDebited += coins;
      }
    }

    // Sort dates and create spots
    final sortedEntries = dailyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Take last 7 days maximum for better visualization
    final recentEntries = sortedEntries.length > 7
        ? sortedEntries.sublist(sortedEntries.length - 7)
        : sortedEntries;

    List<FlSpot> creditedSpots = [];
    List<FlSpot> debitedSpots = [];
    List<String> dates = [];
    double maxValue = 0;

    for (int i = 0; i < recentEntries.length; i++) {
      final entry = recentEntries[i];
      final credited = entry.value['credited']!.toDouble();
      final debited = entry.value['debited']!.toDouble();

      creditedSpots.add(FlSpot(i.toDouble(), credited));
      debitedSpots.add(FlSpot(i.toDouble(), debited));
      dates.add(entry.key);

      maxValue = math.max(maxValue, math.max(credited, debited));
    }

    // Ensure maxValue is not zero
    if (maxValue == 0) maxValue = 100;

    return {
      'spots': creditedSpots + debitedSpots,
      'creditedSpots': creditedSpots,
      'debitedSpots': debitedSpots,
      'dates': dates,
      'totalCredited': totalCredited,
      'totalDebited': totalDebited,
      'maxValue': maxValue + (maxValue * 0.1), // Add 10% padding
    };
  }

  // ignore: unused_element
  Widget _buildDailyRewards() {
    final auth = Provider.of<Auth>(context);
    final rewardsData = auth.dailyRewardsData;
    final currentDay = rewardsData['current_day'] ?? 1;
    final canClaimToday = rewardsData['can_claim_today'] ?? false;
    final rewardsList = rewardsData['rewards'] ?? [];
    final currentReward = rewardsList.length >= currentDay && currentDay > 0
        ? rewardsList[currentDay - 1]
        : null;
    final points =
        currentReward != null ? currentReward['points'] : 10 * currentDay;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: _claimDailyReward,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.dailyRewards,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${context.l10n.day} $currentDay: $points ${context.l10n.points}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  canClaimToday ? 'Claim Now' : context.l10n.claimed,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color:
                        canClaimToday ? Colors.yellow.shade600 : Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCreatorMonetization() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFA726),
                Color(0xFFFB8C00),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monetization Plan for Creators',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Earn rewards for your content',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              // Coming Soon Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'COMING SOON',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Feature List
              _buildFeatureItem(
                Icons.video_library,
                'Earn from video views & engagement',
              ),
              SizedBox(height: 8),
              _buildFeatureItem(
                Icons.trending_up,
                'Get rewarded for trending content',
              ),
              SizedBox(height: 8),
              _buildFeatureItem(
                Icons.card_giftcard,
                'Exclusive creator bonuses & perks',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.9),
          size: 18,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWatchAds() {
    int adsAttemptsLeft = _maxAdsCallLimit - _adsCallCount;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: _showRewardedAd,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.watchAds,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${context.l10n.earn} ${_user['ads_watched_points'] ?? 0} ${context.l10n.points}',
                        style: TextStyle(
                          color: Colors.yellow.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '$adsAttemptsLeft ${context.l10n.attempts} ${context.l10n.left}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      await auth.getUser();
      await auth.fetchDailyRewardsStatus();

      // Also refresh chart data
      await _fetchChartData();

      setState(() {
        _user = auth.user;
        _userInformation = auth.userInformation ?? {};
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data refreshed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh data. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show loading while authentication check is in progress
    if (!_isAuthChecked) {
      return Scaffold(
        appBar: header(context: context, titleText: 'Wallet'),
        body: const WalletScreenSkeleton(),
      );
    }

    return Scaffold(
      appBar: header(context: context, titleText: 'Wallet'),
      body: GestureDetector(
        onTap: _resetAutoLockTimer,
        onPanDown: (_) => _resetAutoLockTimer(),
        child: _isLoading
            ? const WalletScreenSkeleton()
            : RefreshIndicator(
                onRefresh: () async {
                  _resetAutoLockTimer();
                  await _refreshData();
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    _resetAutoLockTimer();
                    return false;
                  },
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // SubscriptionBanner(
                        //   bannerType: 'png',
                        // ),
                        // _buildPointsHeader(),
                        // _buildCreatorMonetization(),
                        // MonetizationWidget(
                        //   onTap: _showWithdrawalDialog,
                        //   title: 'Available Points',
                        //   subtitle:
                        //       'Convert to Cash\nPoints Expires at: ${_userInformation['coin_expires_at'] != null ? DateFormat.yMMMd('en_US').format(DateTime.parse(_userInformation['coin_expires_at'].toString())) : 'Never'}',
                        //   availableCoins:
                        //       _userInformation['available_coins'] ?? 0,
                        //   nrsPerPoint: Provider.of<Auth>(context, listen: false)
                        //       .nrsPerBaakhapaaPoints,
                        //   color: Colors.amber,
                        //   showTotalValue: true,
                        //   currency: 'NPR',
                        // ),
                        _buildActionButtons(),
                        _buildPointsChart(),
                        // _buildDailyRewards(),
                        _buildWatchAds(),
                        // Wallet Security Settings
                        // WalletSecuritySettings(
                        //   onSettingsChanged: () {
                        //     // Reload auto-lock settings when changed
                        //     _loadAutoLockSettings();
                        //   },
                        // ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
