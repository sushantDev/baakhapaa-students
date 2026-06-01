import 'dart:io';
import 'dart:math';
import 'package:baakhapaa/screens/leaderboard/leaderboard_screen.dart';
import 'package:baakhapaa/screens/level_map/level_map_screen.dart';
import 'package:baakhapaa/screens/gift/single_gift_screen.dart';
import 'package:baakhapaa/screens/user/points_screen.dart';
import 'package:flutter/material.dart';
import 'package:baakhapaa/providers/rewards_provider.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/levels.dart';
import 'package:baakhapaa/providers/assistive_touch_provider.dart';
import 'package:baakhapaa/services/pusher_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:baakhapaa/models/url.dart';
import 'package:provider/provider.dart';
import 'package:baakhapaa/services/subscription_service.dart';
import 'package:baakhapaa/models/subscription.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/my_upgrader_messages.dart';
import '../skeleton_loading.dart';
import '../../../utils/debug_logger.dart';

class RedesignedRewardsOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final List<PusherEventData> pusherEvents;
  final List<Map<String, dynamic>> notificationEvents;
  final GlobalKey<NavigatorState> navigatorKey;
  final bool isForcedUpdate;

  const RedesignedRewardsOverlay({
    Key? key,
    required this.onClose,
    required this.navigatorKey,
    this.pusherEvents = const [],
    this.notificationEvents = const [],
    this.isForcedUpdate = false,
  }) : super(key: key);

  @override
  State<RedesignedRewardsOverlay> createState() =>
      _RedesignedRewardsOverlayState();
}

class _RedesignedRewardsOverlayState extends State<RedesignedRewardsOverlay>
    with TickerProviderStateMixin {
  late PageController _eventPageController;
  int _currentEventPage = 0;
  late PageController _taskPageController;
  int _currentTaskPage = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _notificationAnimationController;

  // Rewarded Ad variables
  RewardedAd? _rewardedAd;
  int _numRewardedLoadAttempts = 0;
  int maxFailedLoadAttempts = 3;
  final adUnitId = Platform.isAndroid
      ? 'ca-app-pub-8105529278923041/8001756243'
      : 'ca-app-pub-8105529278923041/5550852727';
  int _adsCallCount = 0;
  late DateTime _lastCalledDate = DateTime.now();
  int _maxAdsCallLimit = 100;

  // Email verification sending state
  bool _isSendingEmail = false;

  // Shared upgrader instance and cached result
  Upgrader? _sharedUpgrader;
  bool? _cachedUpdateAvailable;

  // For You gifts data
  List<dynamic> _forYouGifts = [];
  bool _isLoadingGifts = false;

  // Track if we hid assistive touch (so we know to show it again)
  bool _hasHiddenAssistiveTouch = false;

  // Store provider reference to use in dispose safely
  AssistiveTouchProvider? _assistiveTouchProvider;

  // Track if we're transitioning to a modal (don't restore assistive touch in dispose)
  bool _isTransitioningToModal = false;

  // Benefit variables
  UserBenefitUsage? _upgradeLevelBenefit;
  bool _isUpgrading = false;

  // Check if update is available (with caching)
  Future<bool> _checkUpdateAvailable(Upgrader upgrader) async {
    try {
      // Return cached result if available and upgrader is initialized
      if (_cachedUpdateAvailable != null) {
        return _cachedUpdateAvailable!;
      }

      // Always initialize to ensure we have fresh data
      await upgrader.initialize();

      final appStoreVersion = upgrader.currentAppStoreVersion;
      final installedVersion = upgrader.currentInstalledVersion;

      if (appStoreVersion != null && installedVersion != null) {
        DebugLogger.info(
            '🔍 UPDATE CHECK: Installed: $installedVersion, Store: $appStoreVersion');

        // Simple version comparison
        final hasUpdate = upgrader.shouldDisplayUpgrade();

        // Cache the result
        _cachedUpdateAvailable = hasUpdate;

        return hasUpdate;
      }
      return false;
    } catch (e) {
      DebugLogger.info('❌ Error checking update: $e');
      return false;
    }
  }

  // Show update required message when user tries to dismiss forced update
  void _showUpdateRequiredMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Please update the app to continue using Baakhapaa',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save provider reference to use safely in dispose
    _assistiveTouchProvider =
        Provider.of<AssistiveTouchProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();

    DebugLogger.info(
        '🚀 OVERLAY INIT: Pusher events count: ${widget.pusherEvents.length}');
    DebugLogger.info(
        '🚀 OVERLAY INIT: Notification events count: ${widget.notificationEvents.length}');
    DebugLogger.info(
        '🚀 OVERLAY INIT: Pusher events data: ${widget.pusherEvents}');
    DebugLogger.info(
        '🚀 OVERLAY INIT: Notification events data: ${widget.notificationEvents}');

    // Filter out low-priority events from both lists
    final highPriorityPusherEvents =
        widget.pusherEvents.where((event) => event.priority != 'low').toList();
    final highPriorityNotificationEvents = widget.notificationEvents
        .where((event) => event['priority'] != 'low')
        .toList();

    final totalEvents =
        highPriorityPusherEvents.length + highPriorityNotificationEvents.length;

    DebugLogger.info(
        '🚀 OVERLAY INIT: Total HIGH-priority events: $totalEvents');
    DebugLogger.info(
        '🚀 OVERLAY INIT: Filtered ${widget.pusherEvents.length - highPriorityPusherEvents.length} low-priority Pusher events');
    DebugLogger.info(
        '🚀 OVERLAY INIT: Filtered ${widget.notificationEvents.length - highPriorityNotificationEvents.length} low-priority notification events');

    // Auto-close ONLY if:
    // 1. There are NO high-priority events (totalEvents == 0), AND
    // 2. There WERE some events to begin with (at least one low-priority event)
    // This means: only auto-close if ALL events were filtered out as low-priority
    // Don't auto-close if user manually opened overlay with no events (to view dashboard)
    final hadEventsToFilter =
        widget.pusherEvents.isNotEmpty || widget.notificationEvents.isNotEmpty;
    final shouldAutoClose =
        totalEvents == 0 && hadEventsToFilter && !widget.isForcedUpdate;

    if (shouldAutoClose) {
      DebugLogger.info(
          '⚠️ OVERLAY INIT: All events were low-priority, auto-closing overlay');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onClose();
      });
      // Still initialize controllers to prevent errors
      _eventPageController = PageController();
      _taskPageController = PageController();
      _animationController = AnimationController(
        duration: Duration(milliseconds: 400),
        vsync: this,
      );
      _scaleAnimation = CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      );
      _notificationAnimationController = AnimationController(
        duration: Duration(milliseconds: 2500),
        vsync: this,
      );
      // DON'T hide assistive touch since we're closing immediately
      return;
    }

    // Hide assistive touch IMMEDIATELY when overlay will display
    // Don't wait for postFrameCallback - hide it synchronously
    if (_assistiveTouchProvider != null) {
      try {
        _assistiveTouchProvider!.setRewardsOverlayActive(true);
        _hasHiddenAssistiveTouch = true;
        DebugLogger.info('✅ Assistive touch hidden - overlay is displaying');
      } catch (e) {
        DebugLogger.info('⚠️ Failed to hide assistive touch: $e');
      }
    }

    _eventPageController = PageController(
      viewportFraction: totalEvents > 1 ? 0.9 : 1.0,
    );

    _taskPageController = PageController();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();

    // Notification celebration animation
    _notificationAnimationController = AnimationController(
      duration: Duration(milliseconds: 2500),
      vsync: this,
    );

    // Start notification animation if there are HIGH-priority events
    if (totalEvents > 0) {
      DebugLogger.info('🎬 Starting notification animation');
      _notificationAnimationController.repeat();
    } else {
      DebugLogger.info(
          '⚠️ No high-priority events - notification animation not started');
    }

    // Load ads and ads call count
    _createRewardedAd();
    _loadAdsCallCount();

    // Refresh rewards overlay data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Clear upgrader cache for testing
      await Upgrader.clearSavedSettings();
      DebugLogger.info('🔄 UPGRADER: Cache cleared');

      if (!mounted) return;
      final rewardsProvider =
          Provider.of<RewardsProvider>(context, listen: false);
      final levelsProvider = Provider.of<Levels>(context, listen: false);
      final authProvider = Provider.of<Auth>(context, listen: false);

      // Fetch daily rewards status first to get fresh data
      try {
        await authProvider.fetchDailyRewardsStatus();
      } catch (e) {
        DebugLogger.info('❌ Error fetching daily rewards status: $e');
      }

      // Fetch for you gifts
      _fetchForYouGifts(authProvider);

      // Fetch dashboard
      await rewardsProvider.fetchDashboard(levelsProvider);

      // Check if user has completed all tasks (100% progress)
      if (rewardsProvider.progressPercentage >= 100 ||
          levelsProvider.remainingActions.isEmpty) {
        // Call check level up API
        try {
          final result = await levelsProvider.checkLevelUp();
          DebugLogger.info('🎉 Level up check result: $result');

          // If leveled up, refresh the dashboard to show new level
          if (result['leveled_up'] == true) {
            await rewardsProvider.fetchDashboard(levelsProvider);

            // Refresh daily rewards status to sync coins display
            if (mounted) {
              try {
                await authProvider.fetchDailyRewardsStatus();
              } catch (_) {}
            }
          }
        } catch (e) {
          DebugLogger.info('❌ Error checking level up: $e');
        }
      }

      // Check for level upgrade benefit
      await _checkLevelUpgradeBenefit();
    });
  }

  @override
  void dispose() {
    // Show assistive touch again when overlay closes (only if we hid it)
    // BUT don't restore if we're transitioning to a modal dialog
    if (_hasHiddenAssistiveTouch &&
        _assistiveTouchProvider != null &&
        !_isTransitioningToModal) {
      try {
        _assistiveTouchProvider!.setRewardsOverlayActive(false);
        DebugLogger.info('✅ Assistive touch shown again - overlay disposed');
      } catch (e) {
        DebugLogger.info('⚠️ Failed to show assistive touch: $e');
      }
    } else if (_isTransitioningToModal) {
      DebugLogger.info(
          '⏭️ Skipping assistive touch restoration - transitioning to modal');
    }

    _eventPageController.dispose();
    _taskPageController.dispose();
    _animationController.dispose();
    _notificationAnimationController.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _dismissCurrentEvent() {
    // Filter out low-priority events
    final highPriorityPusherEvents =
        widget.pusherEvents.where((event) => event.priority != 'low').toList();
    final highPriorityNotificationEvents = widget.notificationEvents
        .where((event) => event['priority'] != 'low')
        .toList();

    final totalEvents =
        highPriorityPusherEvents.length + highPriorityNotificationEvents.length;

    if (totalEvents == 0) {
      widget.onClose();
      return;
    }

    if (_currentEventPage < totalEvents - 1) {
      _eventPageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onClose();
    }
  }

  Future<void> _checkLevelUpgradeBenefit() async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (!auth.isSubscribed) {
      return;
    }

    try {
      final subService = SubscriptionService(context: context);
      final response = await subService.getUserBenefitStatus();
      if (mounted && response.success && response.items.isNotEmpty) {
        setState(() {
          try {
            // ID 1 is Upgrade level
            _upgradeLevelBenefit = response.items.first.benefits.firstWhere(
              (b) => b.benefitType.id == 1,
            );
          } catch (_) {
            _upgradeLevelBenefit = null;
          }
        });
      }
    } catch (e) {
      DebugLogger.info('❌ Error checking level upgrade benefit: $e');
    }
  }

  Future<void> _useUpgradeLevelBenefit() async {
    if (_upgradeLevelBenefit == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title:
            const Text('Upgrade Level', style: TextStyle(color: Colors.white)),
        content: Text(
          'Do you want to use your "${_upgradeLevelBenefit!.benefitType.name}" benefit to skip all requirements and reach the next level?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC83E)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Upgrade Now',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpgrading = true);

    try {
      // 1. Show loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFC83E))),
      );

      final levelsProvider = Provider.of<Levels>(context, listen: false);

      // 2. Perform upgrade via provider
      final nextLevelId = levelsProvider.nextLevel?['id'];
      await levelsProvider.upgradeLevelWithBenefit(
        userBenefitUsageId: _upgradeLevelBenefit!.id,
        nextLevelId:
            nextLevelId != null ? int.tryParse(nextLevelId.toString()) : null,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader

        // 3. Refresh benefit status
        await _checkLevelUpgradeBenefit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Level upgraded successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to upgrade level: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewardsProvider = Provider.of<RewardsProvider>(context);
    final authProvider = Provider.of<Auth>(context);
    final screenHeight = MediaQuery.of(context).size.height;

    // Filter out low-priority events
    final highPriorityPusherEvents =
        widget.pusherEvents.where((event) => event.priority != 'low').toList();
    final highPriorityNotificationEvents = widget.notificationEvents
        .where((event) => event['priority'] != 'low')
        .toList();

    final totalEvents =
        highPriorityPusherEvents.length + highPriorityNotificationEvents.length;
    final hasEvents = totalEvents > 0;

    // Create or reuse shared upgrader widget
    _sharedUpgrader ??= Upgrader(
      durationUntilAlertAgain: Duration(hours: 1),
      countryCode: 'NP',
      languageCode: 'en',
      messages: MyUpgraderMessages(),
      // minAppVersion removed - automatically detects updates from App Store
    );
    final upgraderWidget = _sharedUpgrader!;

    return WillPopScope(
      onWillPop: () async {
        // Prevent back button from closing when forced update
        if (widget.isForcedUpdate) {
          DebugLogger.info('⚠️ Cannot close overlay - forced update required');
          _showUpdateRequiredMessage(context);
          return false;
        }
        return true;
      },
      child: GestureDetector(
        onTap: widget.isForcedUpdate
            ? () => _showUpdateRequiredMessage(context)
            : widget
                .onClose, // Show message instead of closing when forced update
        child: Container(
          decoration: hasEvents
              ? BoxDecoration(
                  color: Colors.black,
                  image: DecorationImage(
                    image: AssetImage("assets/images/win.gif"),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5),
                      BlendMode.darken,
                    ),
                  ),
                )
              : null,
          color: hasEvents ? null : Colors.black.withOpacity(0.7),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping the card
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * (hasEvents ? 0.85 : 0.72),
                    maxWidth: 380,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header with user image and progress
                                _buildHeader(
                                    context, rewardsProvider, authProvider),

                                SizedBox(height: 16),

                                // Check email verification status and update availability
                                FutureBuilder<bool>(
                                  future: _checkUpdateAvailable(upgraderWidget),
                                  builder: (context, updateSnapshot) {
                                    final hasUpdate =
                                        updateSnapshot.data == true;

                                    if (authProvider
                                                .user['email_verified_at'] !=
                                            null &&
                                        !hasUpdate) {
                                      // Task Section - Only for verified users WITHOUT pending updates
                                      return Column(
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16),
                                            child: _buildTaskSection(
                                                context, rewardsProvider),
                                          ),
                                          SizedBox(height: 16),
                                        ],
                                      );
                                    }
                                    return SizedBox.shrink();
                                  },
                                ),

                                // Notification Section with carousel
                                if (hasEvents)
                                  _buildNotificationSection(context)
                                else
                                  // Static future rewards preview or email verification
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: _buildFutureRewardsPreview(context,
                                        rewardsProvider, upgraderWidget),
                                  ),

                                SizedBox(height: 16),

                                // Quick Access Actions - Only for verified users WITHOUT pending updates
                                FutureBuilder<bool>(
                                  future: _checkUpdateAvailable(upgraderWidget),
                                  builder: (context, updateSnapshot) {
                                    final hasUpdate =
                                        updateSnapshot.data == true;

                                    if (authProvider
                                                .user['email_verified_at'] !=
                                            null &&
                                        !hasUpdate) {
                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child:
                                            _buildQuickAccessActions(context),
                                      );
                                    }
                                    return SizedBox.shrink();
                                  },
                                ),

                                SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ), // Close WillPopScope child (Container)
    ); // Close WillPopScope
  }

  // Build Update Available Section (enhanced design)
  Widget _buildUpdateAvailableSection(BuildContext context, Upgrader upgrader) {
    final accentColor = widget.isForcedUpdate ? Colors.red : Colors.green;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isForcedUpdate
              ? [
                  Colors.red.withOpacity(0.25),
                  Colors.red.withOpacity(0.15),
                  Colors.red.withOpacity(0.08),
                ]
              : [
                  Colors.green.withOpacity(0.20),
                  Colors.green.withOpacity(0.12),
                  Colors.green.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.6),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: accentColor.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated icon with glow effect
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accentColor.withOpacity(0.4),
                  accentColor.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.2),
                border: Border.all(
                  color: accentColor.withOpacity(0.8),
                  width: 2.5,
                ),
              ),
              child: Icon(
                widget.isForcedUpdate
                    ? Icons.warning_rounded
                    : Icons.system_update_rounded,
                color: accentColor.shade300,
                size: 40,
              ),
            ),
          ),

          // Title with emphasis
          if (widget.isForcedUpdate)
            Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.4),
                    Colors.red.withOpacity(0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.red.withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'UPDATE REQUIRED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          // Version badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.new_releases, color: accentColor.shade200, size: 16),
                SizedBox(width: 6),
                Text(
                  'v${upgrader.currentAppStoreVersion}',
                  style: TextStyle(
                    color: accentColor.shade100,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Description
          Text(
            widget.isForcedUpdate
                ? 'This update contains critical fixes and improvements. Please update now to continue using Baakhapaa.'
                : 'Get the latest features, improvements, and bug fixes. Update now for the best experience!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          SizedBox(height: 24),

          // Update Now Button - Enhanced design
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isForcedUpdate
                    ? [Colors.red.shade600, Colors.red.shade800]
                    : [Colors.green.shade500, Colors.green.shade700],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  String? appStoreUrl;
                  if (Platform.isIOS) {
                    appStoreUrl =
                        'https://apps.apple.com/np/app/baakhapaa/id1621440391';
                  } else {
                    appStoreUrl =
                        'https://play.google.com/store/apps/details?id=com.baakhapaa.com';
                  }

                  final uri = Uri.parse(appStoreUrl);
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Could not open app store'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    DebugLogger.info('❌ Error launching app store: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error opening app store'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Update Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Additional info for forced update
          if (widget.isForcedUpdate) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white.withOpacity(0.7),
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'App will resume after update',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RewardsProvider rewardsProvider,
      Auth authProvider) {
    // Get puppet image URL from auth provider
    String puppetImageUrl = "${Url.mediaUrl}/assets/puppetdev.png";
    try {
      if (authProvider.puppetImage != null &&
          authProvider.puppetImage!.isNotEmpty) {
        puppetImageUrl = authProvider.puppetImage!;
      }
    } catch (e) {
      // Use default image
    }

    // Check if user email is verified
    final isEmailVerified = authProvider.user['email_verified_at'] != null;

    return GestureDetector(
      onTap: () {
        // Block unverified users from Level Map Screen
        if (!isEmailVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.lock, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        '🔒 Please verify your email to access User Journey'),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        // Block navigation if forced update is required
        if (widget.isForcedUpdate) {
          _showUpdateRequiredMessage(context);
          return;
        }

        final navigator = widget.navigatorKey.currentState;
        if (navigator == null) return;

        // Close overlay first
        widget.onClose();

        // Use popUntil to remove any existing LevelMapScreen from stack
        // Then push a fresh one - this prevents stacking duplicates
        Future.delayed(const Duration(milliseconds: 100), () {
          // Pop any existing LevelMapScreen from the stack
          navigator.popUntil((route) {
            // Check if this route is a LevelMapScreen
            final isLevelMap = route.settings.name == '/level-map' ||
                route.settings.name == LevelMapScreen.routeName ||
                route.toString().contains('LevelMapScreen');
            // Return true to STOP popping (keep this route and below)
            // Return false to CONTINUE popping (remove this route)
            return !isLevelMap;
          });

          // Now push the LevelMapScreen
          navigator.push(
            MaterialPageRoute(
              builder: (context) => LevelMapScreen(),
              settings: RouteSettings(name: LevelMapScreen.routeName),
            ),
          );
        });
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF252525),
              Color(0xFF1F1F1F),
              Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // Puppet Image (80x80)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.6),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: puppetImageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.person,
                          color: Colors.amber,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),

                // Level Name and Progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Level name with clear label
                      Row(
                        children: [
                          Icon(
                            Icons.military_tech,
                            color: Colors.amber.shade400,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rewardsProvider.levelName,
                              style: TextStyle(
                                color: Colors.amber.shade300,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Progress bar with percentage inside
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            children: [
                              // Progress fill
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor:
                                    (rewardsProvider.progressPercentage / 100)
                                        .clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade400,
                                        Colors.amber.shade500,
                                        Colors.amber.shade600,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Percentage text centered inside
                              Center(
                                child: Text(
                                  '${rewardsProvider.progressPercentage.toInt()}% Complete',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.8),
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 10),

                      // Next level information - more prominent
                      if (rewardsProvider.nextLevelName.isNotEmpty)
                        Row(
                          children: [
                            Text(
                              'Next Level:',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                rewardsProvider.nextLevelName,
                                style: TextStyle(
                                  color: Colors.purple.shade300,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.purple.shade300,
                              size: 12,
                            ),
                          ],
                        ),
                      if (_upgradeLevelBenefit != null &&
                          (_upgradeLevelBenefit!.canUse ||
                              _upgradeLevelBenefit!.usage.isUnlimited)) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _isUpgrading ? null : _useUpgradeLevelBenefit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt,
                                    color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  _isUpgrading ? 'Upgrading...' : 'Upgrade Now',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // User rank and points
                      SizedBox(height: 8),
                      Row(
                        children: [
                          // Rank
                          GestureDetector(
                            onTap: () {
                              // Block navigation if forced update is required
                              if (widget.isForcedUpdate) {
                                _showUpdateRequiredMessage(context);
                                return;
                              }

                              final navigator =
                                  widget.navigatorKey.currentState;
                              if (navigator == null) return;

                              // Close overlay first
                              widget.onClose();

                              // Use popUntil to remove any existing LeaderboardScreen from stack
                              // Then push a fresh one - this prevents stacking duplicates
                              Future.delayed(const Duration(milliseconds: 100),
                                  () {
                                // Pop any existing LeaderboardScreen from the stack
                                navigator.popUntil((route) {
                                  // Check if this route is a LeaderboardScreen
                                  final isLeaderboard =
                                      route.settings.name == '/leaderboard' ||
                                          route.settings.name ==
                                              LeaderboardScreen.routeName ||
                                          route
                                              .toString()
                                              .contains('LeaderboardScreen');
                                  // Return true to STOP popping (keep this route and below)
                                  // Return false to CONTINUE popping (remove this route)
                                  // We want to keep non-leaderboard routes, remove leaderboard ones
                                  return !isLeaderboard;
                                });

                                // Now push the LeaderboardScreen
                                navigator.push(
                                  MaterialPageRoute(
                                    builder: (context) => LeaderboardScreen(),
                                    settings: RouteSettings(
                                        name: LeaderboardScreen.routeName),
                                  ),
                                );
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.purple.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    color: Colors.purple.shade300,
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Rank #${authProvider.userRank}',
                                    style: TextStyle(
                                      color: Colors.purple.shade200,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          // Available coins
                          GestureDetector(
                            onTap: () {
                              // Block navigation if forced update is required
                              if (widget.isForcedUpdate) {
                                _showUpdateRequiredMessage(context);
                                return;
                              }

                              final navigator =
                                  widget.navigatorKey.currentState;
                              if (navigator == null) return;

                              // Close overlay first
                              widget.onClose();

                              // Use popUntil to remove any existing PointsScreen from stack
                              // Then push a fresh one - this prevents stacking duplicates
                              Future.delayed(const Duration(milliseconds: 100),
                                  () {
                                // Pop any existing PointsScreen from the stack
                                navigator.popUntil((route) {
                                  // Check if this route is a PointsScreen
                                  final isPointsScreen = route.settings.name ==
                                          '/wallet-auth' ||
                                      route.settings.name ==
                                          PointsScreen.routeName ||
                                      route.toString().contains('PointsScreen');
                                  // Return true to STOP popping (keep this route and below)
                                  // Return false to CONTINUE popping (remove this route)
                                  return !isPointsScreen;
                                });

                                // Now push the PointsScreen
                                navigator.push(
                                  MaterialPageRoute(
                                    builder: (context) => PointsScreen(),
                                    settings: RouteSettings(
                                        name: PointsScreen.routeName),
                                  ),
                                );
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/coins.png',
                                    width: 12,
                                    height: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '${authProvider.userAvailableCoins}',
                                    style: TextStyle(
                                      color: Colors.amber.shade200,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Close button - elegant minimal design
            Positioned(
              top: -4,
              right: -4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Block closing if forced update is required
                    if (widget.isForcedUpdate) {
                      _showUpdateRequiredMessage(context);
                      return;
                    }
                    widget.onClose();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.9),
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Task Section - Slidable for multiple tasks
  Widget _buildTaskSection(
      BuildContext context, RewardsProvider rewardsProvider) {
    final levelsProvider = Provider.of<Levels>(context);
    final remainingActions = levelsProvider.remainingActions;
    final hasTask = remainingActions.isNotEmpty;

    if (!hasTask) {
      // Completion state
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            DebugLogger.info('🔍 Task section tapped - Level Complete');
            _showTaskDetailsModal(context, rewardsProvider);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.withOpacity(0.15),
                  Colors.green.withOpacity(0.08),
                  Colors.green.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      color: Colors.green.shade300, size: 24),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎉 Level Complete!',
                        style: TextStyle(
                          color: Colors.green.shade100,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'All quests completed successfully',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Active tasks - slidable view
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quest Label
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.stars_rounded,
                color: Colors.amber.shade400,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'CURRENT QUEST',
                style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 90,
          child: PageView.builder(
            controller: _taskPageController,
            onPageChanged: (index) {
              setState(() => _currentTaskPage = index);
            },
            itemCount: remainingActions.length,
            itemBuilder: (context, index) {
              final taskData = remainingActions[index];
              final actionData = taskData['action'];
              final description = actionData?['title'] ?? 'Task';

              // Parse current progress
              final currentProgressValue = taskData['current_progress'];
              int currentProgress = 0;
              if (currentProgressValue is int) {
                currentProgress = currentProgressValue;
              } else if (currentProgressValue is String) {
                currentProgress = int.tryParse(currentProgressValue) ?? 0;
              }

              final requiredValue =
                  int.tryParse(taskData['required_value']?.toString() ?? '0') ??
                      0;
              final progressPercentage = requiredValue > 0
                  ? (currentProgress / requiredValue * 100).clamp(0, 100)
                  : 0;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    DebugLogger.info(
                        '🔍 Task section tapped - Task: $description');
                    _showTaskDetailsModal(context, rewardsProvider,
                        taskIndex: index);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.withOpacity(0.12),
                          Colors.amber.withOpacity(0.06),
                          Colors.amber.withOpacity(0.03),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.35),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                description,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        // Progress bar
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 0.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progressPercentage / 100,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progressPercentage >= 100
                                          ? Colors.green.shade400
                                          : Colors.amber.shade400,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber.shade400,
                                    Colors.amber.shade500,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$currentProgress/$requiredValue',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (remainingActions.length > 1) ...[
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              remainingActions.length,
              (index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 3),
                width: _currentTaskPage == index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color:
                      _currentTaskPage == index ? Colors.amber : Colors.white30,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Show full task details in a modal
  void _showTaskDetailsModal(
      BuildContext context, RewardsProvider rewardsProvider,
      {int? taskIndex}) {
    DebugLogger.info(
        '🎯 Opening task details modal for task index: $taskIndex');

    // Get task data BEFORE closing overlay to avoid deactivated widget issues
    final levelsProvider = Provider.of<Levels>(context, listen: false);
    final remainingActions = levelsProvider.remainingActions;

    // Capture navigator key before closing overlay
    final navKey = widget.navigatorKey;

    // Set flag to prevent assistive touch restoration during transition
    setState(() {
      _isTransitioningToModal = true;
    });

    // Hide assistive touch to prevent interaction while modal is open
    AssistiveTouchProvider? assistiveTouchProvider;
    try {
      assistiveTouchProvider =
          Provider.of<AssistiveTouchProvider>(context, listen: false);
      assistiveTouchProvider.setRewardsOverlayActive(true);
      DebugLogger.info('✅ Assistive touch hidden for modal');
    } catch (e) {
      DebugLogger.info('⚠️ Could not access assistive touch provider: $e');
    }

    // Close the main rewards overlay first
    widget.onClose();

    // Show the task details modal after a brief delay
    Future.delayed(const Duration(milliseconds: 150), () {
      final navContext = navKey.currentContext;
      if (navContext == null) {
        DebugLogger.info('⚠️ Navigator context is null, cannot show dialog');
        // Restore assistive touch if dialog can't be shown
        assistiveTouchProvider?.setRewardsOverlayActive(false);
        return;
      }

      DebugLogger.info('✅ Navigator context available, showing dialog');

      showDialog(
        context: navContext,
        barrierColor: Colors.black.withOpacity(0.7),
        barrierDismissible: true,
        useRootNavigator: true,
        builder: (BuildContext dialogContext) {
          DebugLogger.info('🎯 Building task modal dialog');

          String? taskDescription;
          String? taskHint;
          int currentProgress = 0;
          int requiredValue = 0;

          final hasTask = remainingActions.isNotEmpty;

          if (hasTask &&
              taskIndex != null &&
              taskIndex < remainingActions.length) {
            final taskData = remainingActions[taskIndex];
            final actionData = taskData['action'];
            taskDescription = actionData?['description'];
            taskHint = taskData['hint'];

            final currentProgressValue = taskData['current_progress'];
            if (currentProgressValue is int) {
              currentProgress = currentProgressValue;
            } else if (currentProgressValue is String) {
              currentProgress = int.tryParse(currentProgressValue) ?? 0;
            }

            requiredValue =
                int.tryParse(taskData['required_value']?.toString() ?? '0') ??
                    0;
          } else if (hasTask) {
            // Fallback to first task if index not provided
            taskDescription = rewardsProvider.actionDescription;
            taskHint = rewardsProvider.levelHint;
            currentProgress = rewardsProvider.currentProgress;
            requiredValue = rewardsProvider.requiredValue;
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                color: Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasTask
                      ? Colors.amber.withOpacity(0.35)
                      : Colors.green.withOpacity(0.35),
                  width: 2,
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (hasTask ? Colors.amber : Colors.green)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            hasTask ? Icons.flag_outlined : Icons.check_circle,
                            color:
                                hasTask ? Colors.amber : Colors.green.shade300,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasTask ? 'Current Quest' : 'Level Complete!',
                            style: TextStyle(
                              color: hasTask
                                  ? Colors.amber.shade100
                                  : Colors.green.shade100,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white60),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            // Restore assistive touch when dialog closes
                            assistiveTouchProvider
                                ?.setRewardsOverlayActive(false);
                            DebugLogger.info(
                                '✅ Assistive touch restored after modal close');
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    if (hasTask) ...[
                      // Task description
                      Text(
                        taskDescription ?? 'Complete this task',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Progress details
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.withOpacity(0.08),
                              Colors.black.withOpacity(0.25),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress',
                                  style: TextStyle(
                                    color: Colors.amber.shade200,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$currentProgress/$requiredValue',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            // Enhanced progress bar
                            Stack(
                              children: [
                                Container(
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: Colors.grey.shade700,
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: requiredValue > 0
                                          ? (currentProgress / requiredValue)
                                              .clamp(0.0, 1.0)
                                          : 0.0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.amber.shade300,
                                              Colors.amber.shade500,
                                              Colors.amber.shade700,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.amber.withOpacity(0.5),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Shine effect
                                Container(
                                  height: 14,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(7),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(0.3),
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, 0.5],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            // Progress percentage and remaining
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${requiredValue > 0 ? ((currentProgress / requiredValue) * 100).toInt() : 0}% complete',
                                  style: TextStyle(
                                    color: Colors.amber.shade300,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (requiredValue > currentProgress)
                                  Text(
                                    '${requiredValue - currentProgress} more',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Hint if available
                      if (taskHint != null && taskHint.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_rounded,
                                color: Colors.amber.shade300,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hint',
                                      style: TextStyle(
                                        color: Colors.amber.shade200,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      taskHint,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      // Completion message
                      Text(
                        'Congratulations! You\'ve completed all tasks for ${rewardsProvider.levelName}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      if (rewardsProvider.nextLevelName.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.rocket_launch,
                                  color: Colors.amber.shade300, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Ready to advance to ${rewardsProvider.nextLevelName}!',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ).then((_) {
        // Restore assistive touch when dialog is dismissed by barrier tap or close button
        assistiveTouchProvider?.setRewardsOverlayActive(false);
        DebugLogger.info('✅ Assistive touch restored after modal dismiss');
      }).catchError((error) {
        // Restore assistive touch even if there's an error
        assistiveTouchProvider?.setRewardsOverlayActive(false);
        DebugLogger.info(
            '⚠️ Error in modal, but assistive touch restored: $error');
      });
    });
  }

  // Notification Section
  Widget _buildNotificationSection(BuildContext context) {
    DebugLogger.info('🔔 Building notification section');
    DebugLogger.info('🔔 Pusher events: ${widget.pusherEvents.length}');
    DebugLogger.info(
        '🔔 Notification events: ${widget.notificationEvents.length}');

    // Filter out low-priority events
    final highPriorityPusherEvents =
        widget.pusherEvents.where((event) => event.priority != 'low').toList();
    final highPriorityNotificationEvents = widget.notificationEvents
        .where((event) => event['priority'] != 'low')
        .toList();

    DebugLogger.info(
        '🔔 High-priority Pusher events: ${highPriorityPusherEvents.length}');
    DebugLogger.info(
        '🔔 High-priority Notification events: ${highPriorityNotificationEvents.length}');

    final totalEvents =
        highPriorityPusherEvents.length + highPriorityNotificationEvents.length;

    // Determine if current event is a level up
    bool isLevelUp = false;
    if (_currentEventPage < highPriorityPusherEvents.length) {
      isLevelUp =
          highPriorityPusherEvents[_currentEventPage].type == 'level_upgraded';
    } else {
      final notifIndex = _currentEventPage - highPriorityPusherEvents.length;
      if (notifIndex < highPriorityNotificationEvents.length) {
        isLevelUp = highPriorityNotificationEvents[notifIndex]['type'] ==
            'level_upgraded';
      }
    }

    return Column(
      children: [
        // Dynamic celebration based on event type
        Container(
          height: 45,
          clipBehavior: Clip.none,
          child: isLevelUp
              ? _buildLevelUpCelebration()
              : _buildSparklesAnimation(),
        ),
        // Event cards
        Container(
          height: 220,
          child: PageView.builder(
            controller: _eventPageController,
            onPageChanged: (index) {
              setState(() => _currentEventPage = index);
            },
            itemCount: totalEvents,
            itemBuilder: (context, index) {
              DebugLogger.info('📄 Building page $index of $totalEvents');

              if (index < highPriorityPusherEvents.length) {
                DebugLogger.info(
                    '📄 Building PUSHER event card at index $index');
                final event = highPriorityPusherEvents[index];
                return _buildSimpleEventCard(
                  type: event.type,
                  title: _getEventTitle(event.type),
                  description: _getEventDescription(event),
                );
              } else {
                final notifIndex = index - highPriorityPusherEvents.length;
                DebugLogger.info(
                    '📄 Building NOTIFICATION event card at notifIndex $notifIndex');
                final notification = highPriorityNotificationEvents[notifIndex];
                return _buildSimpleEventCard(
                  type: notification['type'],
                  title: _getEventTitle(notification['type']),
                  description: _getNotificationDescription(notification),
                );
              }
            },
          ),
        ),
        SizedBox(height: 12),
        // Page indicators
        if (totalEvents > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalEvents,
              (index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 3),
                width: _currentEventPage == index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentEventPage == index
                      ? Colors.amber
                      : Colors.white30,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Simple, guaranteed-to-render event card
  Widget _buildSimpleEventCard({
    required String? type,
    required String title,
    required String description,
  }) {
    DebugLogger.info('🎨 Building SIMPLE event card: $title - $description');

    final isReward = type == 'reward_earned';
    final accentColor = isReward ? Colors.amber : Colors.purple;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon/Emoji
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.2),
            ),
            child: Center(
              child: isReward
                  ? Image.asset(
                      'assets/images/coins.png',
                      width: 28,
                      height: 28,
                      errorBuilder: (context, error, stackTrace) {
                        DebugLogger.info(
                            '⚠️ Failed to load coins.png in simple card, using icon fallback');
                        return Icon(Icons.monetization_on,
                            color: accentColor, size: 24);
                      },
                    )
                  : Icon(Icons.celebration, color: accentColor, size: 24),
            ),
          ),
          SizedBox(height: 8),
          // Title
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 5),
          // Description
          Text(
            description,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 10),
          // Button
          GestureDetector(
            onTap: _dismissCurrentEvent,
            child: Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isReward ? Colors.amber.shade700 : Colors.purple.shade700,
                    accentColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Awesome!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Animated sparkles for regular rewards
  Widget _buildSparklesAnimation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildRotatingSparkle(0, '✨'),
        SizedBox(width: 8),
        _buildRotatingSparkle(1, '🎉'),
        SizedBox(width: 8),
        _buildRotatingSparkle(2, '✨'),
      ],
    );
  }

  Widget _buildRotatingSparkle(int index, String emoji) {
    return AnimatedBuilder(
      animation: _notificationAnimationController,
      builder: (context, child) {
        final progress = _notificationAnimationController.value;

        // Gentle bobbing motion - each sparkle bobs at different phases
        final bobPhase = (progress + (index * 0.33)) % 1.0;
        final verticalBob = -6.0 * sin(bobPhase * 6.28319); // Smooth sine wave

        // Horizontal sway - creates floating effect
        final sway = 3.0 * sin((progress + (index * 0.2)) * 3.14159);

        // Pulsing scale - gentle breathing effect
        final scalePulse =
            1.0 + 0.15 * sin((progress + (index * 0.25)) * 6.28319);

        // Gentle rotation - slower for center emoji
        final rotationSpeed = emoji == '🎉' ? 0.5 : 1.0;
        final rotation =
            progress * rotationSpeed * 3.14159; // Half speed rotation

        // Twinkling opacity
        final twinkle = 0.7 + 0.3 * ((progress * 3 + index * 0.5) % 1.0);

        return Transform.translate(
          offset: Offset(sway, verticalBob),
          child: Transform.scale(
            scale: scalePulse,
            child: Opacity(
              opacity: twinkle,
              child: Transform.rotate(
                angle: rotation,
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Walking/celebration animation for level up - Professional emotional design
  Widget _buildLevelUpCelebration() {
    return AnimatedBuilder(
      animation: _notificationAnimationController,
      builder: (context, child) {
        final progress = _notificationAnimationController.value;

        // Smooth left-to-right walking motion (0.0 to 1.0 progress)
        final walkProgress = progress % 1.0;
        final horizontalPosition = Tween<double>(begin: -70.0, end: 70.0)
            .animate(
              CurvedAnimation(
                parent: AlwaysStoppedAnimation(walkProgress),
                curve: Curves.easeInOut,
              ),
            )
            .value;

        // Natural walking bob (subtle up and down)
        final bobCycle = (walkProgress * 6) % 1.0; // 6 steps per cycle
        final verticalBob =
            -8 * (1 - (2 * bobCycle - 1).abs()); // Smooth sine-like bob

        // Confetti falling from top with natural physics
        final confettiFallProgress = (progress * 2) % 1.0;
        final confettiY = Tween<double>(begin: -10.0, end: 35.0)
            .animate(
              CurvedAnimation(
                parent: AlwaysStoppedAnimation(confettiFallProgress),
                curve: Curves.easeIn, // Gravity effect
              ),
            )
            .value;

        // Gentle sway for confetti
        final confettiSwayLeft = 8.0 * sin(confettiFallProgress * 3.14159);
        final confettiSwayRight = -8.0 * sin(confettiFallProgress * 3.14159);

        // Star twinkling (scale pulse)
        final starTwinkle1 = 0.7 + 0.3 * ((progress * 3) % 1.0);
        final starTwinkle2 = 0.7 + 0.3 * ((progress * 3 + 0.5) % 1.0);

        // Party emoji gentle pulse
        final partyPulse = 1.0 +
            0.15 *
                ((progress * 4) % 1.0 > 0.5
                    ? 1.0 - (progress * 4) % 1.0
                    : (progress * 4) % 1.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Falling confetti - left side
            Positioned(
              left: 20 + confettiSwayLeft,
              top: confettiY,
              child: Transform.rotate(
                angle:
                    confettiFallProgress * 0.5, // Gentle rotation while falling
                child: Opacity(
                  opacity: 1.0 -
                      (confettiFallProgress * 0.3), // Slight fade at bottom
                  child: Text('🎊', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
            // Falling confetti - right side
            Positioned(
              right: 20 + confettiSwayRight,
              top: confettiY,
              child: Transform.rotate(
                angle: -confettiFallProgress * 0.5,
                child: Opacity(
                  opacity: 1.0 - (confettiFallProgress * 0.3),
                  child: Text('🎊', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
            // Twinkling stars - left
            Positioned(
              left: 35,
              top: 8,
              child: Transform.scale(
                scale: starTwinkle1,
                child: Opacity(
                  opacity: starTwinkle1,
                  child: Text('⭐', style: TextStyle(fontSize: 15)),
                ),
              ),
            ),
            // Twinkling stars - right
            Positioned(
              right: 35,
              top: 8,
              child: Transform.scale(
                scale: starTwinkle2,
                child: Opacity(
                  opacity: starTwinkle2,
                  child: Text('⭐', style: TextStyle(fontSize: 15)),
                ),
              ),
            ),
            // Walking figure with celebration - moves left to right naturally
            Center(
              child: Transform.translate(
                offset: Offset(horizontalPosition, verticalBob),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Walking person (slightly bigger during step)
                    Transform.scale(
                      scale: 1.0 + 0.05 * (1 - (2 * bobCycle - 1).abs()),
                      child: Text('🚶‍♂️‍➡️', style: TextStyle(fontSize: 26)),
                    ),
                    SizedBox(width: 6),
                    // Party emoji with gentle pulse
                    Transform.scale(
                      scale: partyPulse,
                      child: Text('🎉', style: TextStyle(fontSize: 22)),
                    ),
                  ],
                ),
              ),
            ),
            // Additional celebratory sparkles at center
            Center(
              child: Opacity(
                opacity: 0.4 + 0.3 * ((progress * 5) % 1.0),
                child: Text('✨', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Future Rewards Preview (Shows update, email verification, or future rewards)
  Widget _buildFutureRewardsPreview(BuildContext context,
      RewardsProvider rewardsProvider, Upgrader upgraderWidget) {
    final authProvider = Provider.of<Auth>(context);
    final isEmailVerified = authProvider.user['email_verified_at'] != null;

    // Use the shared upgrader passed from build()
    // Check if update is available first (highest priority)
    return FutureBuilder<bool>(
      future: _checkUpdateAvailable(upgraderWidget),
      builder: (context, updateSnapshot) {
        if (updateSnapshot.data == true) {
          // Show update section (replaces future rewards)
          return _buildUpdateAvailableSection(context, upgraderWidget);
        }

        // If no update, show email verification or future rewards
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isEmailVerified
                    ? Colors.purple.withOpacity(0.08)
                    : Colors.red.withOpacity(0.15),
                isEmailVerified
                    ? Colors.purple.withOpacity(0.03)
                    : Colors.red.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEmailVerified
                  ? Colors.purple.withOpacity(0.25)
                  : Colors.red.withOpacity(0.6),
              width: isEmailVerified ? 1.5 : 2.5,
            ),
            boxShadow: isEmailVerified
                ? []
                : [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isEmailVerified ? Icons.redeem : Icons.error_outline,
                    color: isEmailVerified
                        ? Colors.purple.shade300
                        : Colors.red.shade300,
                    size: isEmailVerified ? 20 : 24,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEmailVerified
                          ? 'Future Rewards'
                          : '⚠️ Email Verification Required',
                      style: TextStyle(
                        color: isEmailVerified
                            ? Colors.purple.shade200
                            : Colors.red.shade200,
                        fontSize: isEmailVerified ? 14 : 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // Show email verification or future rewards based on status
              if (!isEmailVerified)
                _buildEmailVerificationContent(context, authProvider)
              else
                _buildFutureRewardsContent(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmailVerificationContent(
      BuildContext context, Auth authProvider) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Animated attention icon
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.2),
              border: Border.all(
                color: Colors.red.withOpacity(0.6),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.email_outlined,
              color: Colors.red.shade300,
              size: 48,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '🚨 Email Not Verified',
            style: TextStyle(
              color: Colors.red.shade300,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'Verify your email to unlock all features and continue earning experience.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 18),
          // Verify Email Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSendingEmail
                  ? null
                  : () async {
                      DebugLogger.info('📧 Email verification button pressed');

                      setState(() {
                        _isSendingEmail = true;
                      });

                      try {
                        DebugLogger.info('📧 Calling verifyUserEmail()...');
                        await authProvider.verifyUserEmail();
                        DebugLogger.info(
                            '📧 ✅ Email verification API call completed successfully');

                        if (mounted) {
                          setState(() {
                            _isSendingEmail = false;
                          });

                          // Capture navigator key before closing overlay
                          final navKey = widget.navigatorKey;

                          // Close the main overlay first
                          widget.onClose();

                          // Show success dialog after a brief delay to ensure overlay is closed
                          await Future.delayed(Duration(milliseconds: 200));

                          final navContext = navKey.currentContext;
                          if (navContext == null) {
                            DebugLogger.info(
                                '⚠️ Navigator context is null after email verification');
                            return;
                          }

                          DebugLogger.info(
                              '✅ Showing email verification success dialog');

                          // Show success dialog with Done button
                          showDialog(
                            context: navContext,
                            barrierDismissible: false,
                            builder: (dialogContext) => WillPopScope(
                              onWillPop: () async => false,
                              child: AlertDialog(
                                backgroundColor: Color(0xFF1E1E1E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                title: Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.green, size: 28),
                                    SizedBox(width: 12),
                                    Text(
                                      'Email Sent!',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Verification email has been sent successfully!',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Please check your inbox and verify your email to unlock all features.',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 13),
                                    ),
                                    SizedBox(height: 8),
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.yellow.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.yellow.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: Colors.yellow.shade700,
                                            size: 16,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Check spam/junk folder',
                                              style: TextStyle(
                                                color: Colors.yellow.shade200,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        // Close the success dialog
                                        Navigator.of(dialogContext).pop();

                                        // Show loading indicator while fetching user data
                                        final loadingNavContext =
                                            navKey.currentContext;
                                        if (loadingNavContext == null) return;

                                        showDialog(
                                          context: loadingNavContext,
                                          barrierDismissible: false,
                                          builder: (loadingCtx) => WillPopScope(
                                            onWillPop: () async => false,
                                            child: AlertDialog(
                                              backgroundColor:
                                                  Color(0xFF1E1E1E),
                                              content: Row(
                                                children: [
                                                  CircularProgressIndicator(
                                                      color: Colors.amber),
                                                  SizedBox(width: 20),
                                                  Expanded(
                                                    child: Text(
                                                        'Checking verification status...'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );

                                        try {
                                          // Fetch updated user data
                                          DebugLogger.info(
                                              '📧 Fetching user data to check verification...');
                                          await authProvider.getUser();

                                          // Check if email is now verified
                                          final isNowVerified = authProvider
                                                  .user['email_verified_at'] !=
                                              null;
                                          DebugLogger.info(
                                              '📧 Email verified: $isNowVerified');

                                          // Fetch rewards dashboard to show tasks
                                          final rewardsProvider =
                                              Provider.of<RewardsProvider>(
                                                  widget.navigatorKey
                                                      .currentContext!,
                                                  listen: false);
                                          final levelsProvider =
                                              Provider.of<Levels>(
                                                  widget.navigatorKey
                                                      .currentContext!,
                                                  listen: false);
                                          await rewardsProvider
                                              .fetchDashboard(levelsProvider);

                                          DebugLogger.info(
                                              '📧 User data and tasks fetched successfully');

                                          // Check if widget is still mounted before using context
                                          if (!mounted) return;

                                          // Close loading dialog
                                          if (widget.navigatorKey
                                                  .currentContext !=
                                              null) {
                                            Navigator.of(widget.navigatorKey
                                                    .currentContext!)
                                                .pop();
                                          }

                                          // Refresh the overlay UI
                                          if (mounted) {
                                            setState(() {});
                                          }

                                          // Show appropriate message based on verification status
                                          if (widget.navigatorKey
                                                  .currentContext !=
                                              null) {
                                            if (isNowVerified) {
                                              ScaffoldMessenger.of(widget
                                                      .navigatorKey
                                                      .currentContext!)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      Icon(Icons.verified,
                                                          color: Colors.white,
                                                          size: 20),
                                                      SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                            '🎉 Email verified! All features unlocked!'),
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor: Colors.green,
                                                  duration:
                                                      Duration(seconds: 3),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(widget
                                                      .navigatorKey
                                                      .currentContext!)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      Icon(
                                                          Icons.hourglass_empty,
                                                          color: Colors.white,
                                                          size: 20),
                                                      SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                            '⏳ Email not yet verified. Please check your inbox and click the verification link.'),
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                  duration:
                                                      Duration(seconds: 4),
                                                ),
                                              );
                                            }
                                          }
                                        } catch (error) {
                                          DebugLogger.info(
                                              '📧 Error fetching user data: $error');

                                          // Check if widget is still mounted before using context
                                          if (!mounted) return;

                                          // Close loading dialog
                                          if (widget.navigatorKey
                                                  .currentContext !=
                                              null) {
                                            Navigator.of(widget.navigatorKey
                                                    .currentContext!)
                                                .pop();
                                          }

                                          if (widget.navigatorKey
                                                  .currentContext !=
                                              null) {
                                            ScaffoldMessenger.of(widget
                                                    .navigatorKey
                                                    .currentContext!)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Failed to check verification status'),
                                                backgroundColor: Colors.orange,
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding:
                                            EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: Text(
                                        'Done',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      } catch (error) {
                        DebugLogger.info(
                            '📧 ❌ Error in verifyUserEmail: $error');
                        DebugLogger.info('📧 Error type: ${error.runtimeType}');
                        DebugLogger.info(
                            '📧 Error details: ${error.toString()}');

                        if (mounted) {
                          setState(() {
                            _isSendingEmail = false;
                          });

                          // Show error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Error: ${error.toString()}'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
              icon: _isSendingEmail
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.mark_email_read, size: 20),
              label: Text(
                _isSendingEmail ? 'Sending...' : 'Send Verification Email',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isSendingEmail ? Colors.red.shade700 : Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
              ),
            ),
          ),
          SizedBox(height: 14),
          // Spam folder warning
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.yellow.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.yellow.shade700,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Check your spam/junk folder if you don\'t see the email',
                    style: TextStyle(
                      color: Colors.yellow.shade200,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchForYouGifts(Auth auth) async {
    if (!mounted) return;

    setState(() {
      _isLoadingGifts = true;
    });

    try {
      final response = await auth.getGiftsForYou();
      if (mounted) {
        setState(() {
          _forYouGifts = response['data'] ?? [];
          _isLoadingGifts = false;
        });
      }
    } catch (e) {
      DebugLogger.info('❌ Error fetching for you gifts: $e');
      if (mounted) {
        setState(() {
          _isLoadingGifts = false;
        });
      }
    }
  }

  Widget _buildFutureRewardsContent() {
    if (_isLoadingGifts) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ShimmerLoading(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: const [
                SkeletonBox(width: 80, height: 80, borderRadius: 10),
                SizedBox(width: 12),
              ],
            ),
          ),
        ),
      );
    }

    if (_forYouGifts.isEmpty) {
      return Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.card_giftcard,
                  color: Colors.purple.shade200, size: 40),
              SizedBox(height: 8),
              Text(
                'No gifts available right now',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _forYouGifts.length,
        itemBuilder: (context, index) {
          final gift = _forYouGifts[index];
          return _buildGiftCard(gift);
        },
      ),
    );
  }

  Widget _buildGiftCard(Map<String, dynamic> gift) {
    final images = gift['images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty ? '${images[0]['full']}' : '';
    final title = gift['title'] ?? 'Gift';
    final coin = gift['coin'] ?? 0;
    final tag = gift['tag'];
    final giftId = gift['id'];

    return GestureDetector(
      onTap: () {
        if (giftId != null) {
          // Close overlay and navigate to single gift screen
          widget.onClose();
          Future.delayed(const Duration(milliseconds: 100), () {
            widget.navigatorKey.currentState?.pushNamed(
              SingleGiftScreen.routeName,
              arguments: giftId,
            );
          });
        }
      },
      child: Container(
        width: 95,
        height: 104, // Fixed height to prevent overflow
        margin: EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.purple.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 95,
                          height: 55,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 95,
                            height: 55,
                            color: Colors.black26,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.purple.shade200,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            DebugLogger.info(
                                '❌ Image load error for $url: $error');
                            return Container(
                              width: 95,
                              height: 55,
                              color: Colors.black26,
                              child: Icon(
                                Icons.card_giftcard,
                                color: Colors.purple.shade200,
                                size: 24,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 95,
                          height: 55,
                          color: Colors.black26,
                          child: Icon(
                            Icons.card_giftcard,
                            color: Colors.purple.shade200,
                            size: 24,
                          ),
                        ),
                ),
                // Tag badge
                if (tag != null)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Title and coin
            Padding(
              padding: EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/coins.png',
                        width: 10,
                        height: 10,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '$coin',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quick Access Actions (3 buttons in 1 row)
  Widget _buildQuickAccessActions(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final rewardsData = auth.dailyRewardsData;
    final canClaimToday = rewardsData['can_claim_today'] ?? false;
    final currentDay = rewardsData['current_day'] ?? 1;
    final rewardsList = rewardsData['rewards'] ?? [];
    final currentReward = rewardsList.length >= currentDay && currentDay > 0
        ? rewardsList[currentDay - 1]
        : null;
    final points =
        currentReward != null ? currentReward['points'] : 10 * currentDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Free Rewards',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            // 1. Daily Rewards Claim
            Expanded(
              child: _buildQuickAccessButton(
                icon: Icons.card_giftcard,
                label: canClaimToday ? 'Claim $points pts' : 'Claimed',
                color: canClaimToday ? Colors.green : Colors.grey,
                badge: canClaimToday ? '!' : null,
                isEnabled: canClaimToday,
                onTap: () {
                  if (canClaimToday) {
                    _claimDailyReward();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Already claimed today. Come back tomorrow!'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
            SizedBox(width: 10),
            // 2. Leaderboard (NEW - More engaging than New Stories)
            // Expanded(
            //   child: _buildQuickAccessButton(
            //     icon: Icons.leaderboard,
            //     label: 'Leader\nboard',
            //     color: Colors.purple,
            //     onTap: () {
            //       widget.onClose();
            //       Future.delayed(const Duration(milliseconds: 100), () {
            //         widget.navigatorKey.currentState?.push(
            //           MaterialPageRoute(
            //             builder: (context) => LeaderboardScreen(),
            //           ),
            //         );
            //       });
            //     },
            //   ),
            // ),
            // SizedBox(width: 10),
            // 3. Watch Ads to earn points (with daily limit)
            Expanded(
              child: _buildQuickAccessButton(
                icon: Icons.videocam,
                label: 'Earn Points',
                color: _adsCallCount >= _maxAdsCallLimit
                    ? Colors.grey
                    : Colors.amber,
                badge: _adsCallCount >= _maxAdsCallLimit
                    ? null
                    : '${_maxAdsCallLimit - _adsCallCount}',
                isEnabled: _adsCallCount < _maxAdsCallLimit,
                onTap: () {
                  if (_adsCallCount >= _maxAdsCallLimit) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Daily ad limit reached. Come back tomorrow!'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    _playRewardedAd(context);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessButton({
    required IconData icon,
    required String label,
    required Color color,
    String? badge,
    bool isEnabled = true,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      elevation: isEnabled ? 4 : 0,
      shadowColor: color.withOpacity(0.5),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withOpacity(0.4),
        highlightColor: color.withOpacity(0.2),
        child: Container(
          height: 50,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isEnabled
                  ? [
                      color.withOpacity(0.25),
                      Color(0xFF2D2D2D),
                      Color(0xFF1A1A1A),
                    ]
                  : [
                      Color(0xFF1A1A1A),
                      Color(0xFF121212),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled
                  ? color.withOpacity(0.7)
                  : Colors.white.withOpacity(0.1),
              width: 2,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: -1,
                      offset: Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? color.withOpacity(0.35)
                          : Colors.grey.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: isEnabled
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      icon,
                      color: isEnabled ? Colors.white : Colors.grey.shade600,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isEnabled ? Colors.white : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              // Badge indicator
              if (badge != null)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.shade600,
                          Colors.red.shade800,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.7),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Center(
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Load rewarded ad
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
    if (mounted) {
      setState(() {
        _adsCallCount = prefs.getInt('functionCallCount') ?? 0;
        int lastCalledTimestamp = prefs.getInt('lastCalledDate') ?? 0;
        _lastCalledDate =
            DateTime.fromMillisecondsSinceEpoch(lastCalledTimestamp);
      });
    }
  }

  Future<void> _incrementAdsCallCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _adsCallCount++;
        prefs.setInt('functionCallCount', _adsCallCount);
        prefs.setInt('lastCalledDate', DateTime.now().millisecondsSinceEpoch);
      });
    }
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Play rewarded ad directly
  void _playRewardedAd(BuildContext context) {
    if (_rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ad is still loading, please try again in a moment'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!isSameDay(_lastCalledDate, DateTime.now())) {
      _adsCallCount = 0;
    }

    if (_adsCallCount >= _maxAdsCallLimit) {
      _showAdsLimitDialog();
      return;
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

    _rewardedAd?.setImmersiveMode(true);
    _rewardedAd?.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
        var auth = Provider.of<Auth>(context, listen: false);
        final user = auth.user;
        final adsWatchedPoints =
            int.tryParse(user['ads_watched_points']?.toString() ?? '') ?? 5;

        await auth
            .coinTransaction(
          adsWatchedPoints,
          'credited',
          'Rewards granted from watching ads.',
        )
            .then((_) async {
          await auth.getUser();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 You earned $adsWatchedPoints points!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          // Refresh rewards overlay data
          final rewardsProvider =
              Provider.of<RewardsProvider>(context, listen: false);
          final levelsProvider = Provider.of<Levels>(context, listen: false);
          await rewardsProvider.fetchDashboard(levelsProvider);
        });
        _incrementAdsCallCount();
        _rewardedAd = null;
      },
    );
  }

  void _showAdsLimitDialog() {
    if (!mounted) return;
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;

    showDialog(
      context: navContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Daily Limit Reached',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You have reached your daily ad watching limit of $_maxAdsCallLimit ads. Please try again tomorrow!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _claimDailyReward() async {
    DebugLogger.info('🎁 CLAIM: Starting daily reward claim');
    if (!mounted) {
      DebugLogger.info('⚠️ CLAIM: Widget not mounted, aborting');
      return;
    }

    final auth = Provider.of<Auth>(context, listen: false);
    final rewardsData = auth.dailyRewardsData;

    DebugLogger.info(
        '🎁 CLAIM: Can claim today: ${rewardsData['can_claim_today']}');

    if (rewardsData['can_claim_today'] == false) {
      DebugLogger.info('⚠️ CLAIM: Already claimed today');
      _showAlreadyClaimedDialog();
      return;
    }

    _showClaimingDialog();
    DebugLogger.info('🎁 CLAIM: Claiming dialog shown');

    bool dialogClosed = false;

    try {
      DebugLogger.info('🎁 CLAIM: Calling API...');
      // Actually claim the reward with timeout
      final result = await auth.claimDailyReward().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          DebugLogger.info('❌ CLAIM: API timeout');
          throw Exception(
              'Request timeout. Please check your connection and try again.');
        },
      );

      DebugLogger.info('✅ CLAIM: API success: $result');

      // ALWAYS close claiming dialog first, regardless of mounted state
      // Dialog uses navigatorKey context, not widget context
      await _closeClaimingDialog();
      dialogClosed = true;
      DebugLogger.info('✅ CLAIM: Dialog closed after success');

      // Update user's coin balance immediately from API response
      // IMPORTANT: Do this BEFORE checking mounted state
      // This ensures UI reflects the new balance right away
      // Auth provider updates work even if widget is unmounted
      bool balanceUpdated = false;
      try {
        final updatedBalances = result['updated_balances'];
        if (updatedBalances != null) {
          final availableCoins = updatedBalances['available_coins'];
          final earnedCoins = updatedBalances['earned_coins'];
          final totalUsedCoins = updatedBalances['total_used_coins'];

          if (availableCoins != null) {
            DebugLogger.info(
                '💰 CLAIM: Updating balance immediately - Available: $availableCoins, Earned: $earnedCoins');

            // Update auth provider's user data with new balances
            auth.updateUserBalances(
              availableCoins: availableCoins,
              earnedCoins: earnedCoins,
              totalUsedCoins: totalUsedCoins,
            );
            balanceUpdated = true;
            DebugLogger.info('✅ CLAIM: Balance updated in auth state');
          }
        } else {
          DebugLogger.info(
              '⚠️ CLAIM: No updated_balances in response, fetching user data...');
        }
      } catch (e) {
        DebugLogger.info('⚠️ CLAIM: Error updating balance from response: $e');
      }

      // If balance wasn't updated from response, fetch full user data
      // This ensures balance is updated everywhere in the app
      if (!balanceUpdated) {
        try {
          DebugLogger.info('🔄 CLAIM: Fetching user data to update balance...');
          await auth.getUser();
          DebugLogger.info('✅ CLAIM: User data fetched, balance updated');
        } catch (e) {
          DebugLogger.info('⚠️ CLAIM: Error fetching user data: $e');
        }
      }

      // Refresh daily rewards status to get latest claim state
      // This works even if widget is unmounted
      try {
        DebugLogger.info('🔄 CLAIM: Refreshing daily rewards status...');
        await auth.fetchDailyRewardsStatus();
        DebugLogger.info('✅ CLAIM: Daily rewards status refreshed');
      } catch (e) {
        DebugLogger.info('⚠️ CLAIM: Error refreshing daily rewards status: $e');
      }

      // Check if widget is still mounted before continuing with UI updates
      if (!mounted) {
        DebugLogger.info(
            '⚠️ CLAIM: Widget unmounted after API call - skipping UI updates (balance already updated)');
        return;
      }

      // Small delay to ensure dialog is fully closed
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      // Show success message
      final message = result['message'] ?? 'Daily reward claimed successfully!';
      final reward = result['reward'];
      final points = reward?['points'] ?? 0;

      DebugLogger.info(
          '🎉 CLAIM: Showing success message: $message (+$points points)');

      try {
        final navContext = widget.navigatorKey.currentContext;
        if (navContext != null && mounted) {
          ScaffoldMessenger.of(navContext).showSnackBar(
            SnackBar(
              content: Text('🎉 $message (+$points points)'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        DebugLogger.info('⚠️ Error showing success snackbar: $e');
      }

      // Refresh data
      DebugLogger.info('🔄 CLAIM: Refreshing data...');
      await auth.fetchDailyRewardsStatus();

      // Check if still mounted before accessing context
      if (!mounted) return;

      final rewardsProvider =
          Provider.of<RewardsProvider>(context, listen: false);
      final levelsProvider = Provider.of<Levels>(context, listen: false);
      await rewardsProvider.fetchDashboard(levelsProvider);
      DebugLogger.info('✅ CLAIM: Data refreshed');
    } catch (e) {
      DebugLogger.info('❌ CLAIM: Error occurred: $e');

      // ALWAYS close claiming dialog if not already closed
      // Don't check mounted state - dialog persists on navigator
      if (!dialogClosed) {
        await _closeClaimingDialog();
        dialogClosed = true;
        DebugLogger.info('✅ CLAIM: Dialog closed after error');
      }

      // Check if widget is still mounted before showing error
      if (!mounted) {
        DebugLogger.info(
            '⚠️ CLAIM: Widget unmounted - cannot show error dialog');
        return;
      }

      // Small delay before showing error dialog
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      DebugLogger.info('⚠️ CLAIM: Showing error dialog');
      _showErrorDialog(e.toString());
    } finally {
      // Final safety net - ensure dialog is closed no matter what
      // This runs even if widget is unmounted
      if (!dialogClosed) {
        DebugLogger.info('🔧 CLAIM: Finally block - ensuring dialog is closed');
        await _closeClaimingDialog();
      }
    }
  }

  // Helper method to close claiming dialog safely
  // IMPORTANT: This should work even if widget is unmounted
  // because dialog uses navigatorKey.currentContext, not widget context
  Future<void> _closeClaimingDialog() async {
    try {
      // Use navigator key context - this persists even if widget unmounts
      final navContext = widget.navigatorKey.currentContext;
      if (navContext != null) {
        // Check if there's a dialog to pop
        if (Navigator.canPop(navContext)) {
          Navigator.of(navContext).pop();
          DebugLogger.info('✅ Claiming dialog closed');
        } else {
          DebugLogger.info('⚠️ No dialog to pop');
        }
      } else {
        DebugLogger.info('⚠️ Cannot close dialog - navigator context is null');
      }
    } catch (e) {
      DebugLogger.info('⚠️ Error closing claiming dialog: $e');
      // Try alternative method - pop using root navigator
      try {
        final navContext = widget.navigatorKey.currentContext;
        if (navContext != null) {
          Navigator.of(navContext, rootNavigator: true).pop();
          DebugLogger.info('✅ Claiming dialog closed via root navigator');
        }
      } catch (rootError) {
        DebugLogger.info('⚠️ Root navigator pop also failed: $rootError');
      }
    }
  }

  void _showAlreadyClaimedDialog() {
    if (!mounted) return;
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;

    try {
      showDialog(
        context: navContext,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(ctx).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title:
              Text('Already Claimed', style: TextStyle(color: Colors.orange)),
          content: Text(
              'You have already claimed your reward today. Come back tomorrow for more points!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      DebugLogger.info('⚠️ Error showing already claimed dialog: $e');
    }
  }

  void _showClaimingDialog() {
    if (!mounted) return;
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;

    try {
      showDialog(
        context: navContext,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(ctx).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Claiming reward...")
            ],
          ),
        ),
      );
    } catch (e) {
      DebugLogger.info('⚠️ Error showing claiming dialog: $e');
    }
  }

  void _showErrorDialog(String error) {
    if (!mounted) return;
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;

    // Parse error message to show user-friendly text
    String userMessage = error;
    if (error.contains('already claimed') ||
        error.contains('Already claimed')) {
      userMessage =
          'You have already claimed your reward today. Come back tomorrow!';
    } else if (error.contains('timeout') || error.contains('Timeout')) {
      userMessage =
          'Request timed out. Please check your internet connection and try again.';
    } else if (error.contains('network') || error.contains('Network')) {
      userMessage =
          'Network error. Please check your connection and try again.';
    } else {
      userMessage = 'Failed to claim reward: $error';
    }

    DebugLogger.info('⚠️ Showing error dialog: $userMessage');

    try {
      showDialog(
        context: navContext,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(ctx).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Oops!', style: TextStyle(color: Colors.red)),
          content: Text(userMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK', style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      );
    } catch (e) {
      DebugLogger.info('⚠️ Error showing error dialog: $e');
    }
  }

  String _getEventTitle(String? type) {
    switch (type) {
      case 'reward_earned':
        return 'Reward Earned!';
      case 'level_upgraded':
        return 'Level Up!';
      case 'gift_available':
        return 'Gift Available!';
      case 'progress_updated':
        return 'Progress Updated!';
      default:
        return 'Notification';
    }
  }

  String _getEventDescription(PusherEventData event) {
    switch (event.type) {
      case 'reward_earned':
        final source = _formatSourceName(event.source);
        final amount = event.amount ?? 0;
        return 'You earned $amount points${source.isNotEmpty ? ' from $source' : ''}!';
      case 'level_upgraded':
        final levelName = event.newLevel;
        if (levelName != null && levelName.toString().isNotEmpty) {
          return 'Congratulations! You reached $levelName!';
        }
        return 'Congratulations on your level up!';
      case 'gift_available':
        final giftType = event.giftType;
        if (giftType != null && giftType.isNotEmpty) {
          return 'A new $giftType is waiting for you!';
        }
        return 'A new gift is waiting for you!';
      case 'progress_updated':
        return 'Keep going! Your progress is being tracked.';
      default:
        return 'Check your updates!';
    }
  }

  String _formatSourceName(String? source) {
    if (source == null || source.isEmpty) return '';

    // Convert snake_case to Title Case and make it user-friendly
    final formatted = source
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');

    return formatted;
  }

  String _getNotificationDescription(Map<String, dynamic> notification) {
    final type = notification['type'];

    DebugLogger.info('🔍 Building notification description for type: $type');
    DebugLogger.info('🔍 Notification data: $notification');

    switch (type) {
      case 'reward_earned':
        final source = _formatSourceName(notification['source']?.toString());
        final amount = notification['amount']?.toString() ?? '0';
        final description =
            'You earned $amount points${source.isNotEmpty ? ' from $source' : ''}!';
        DebugLogger.info('🔍 Reward description: $description');
        return description;

      case 'level_upgraded':
        final levelName =
            notification['level_name'] ?? notification['new_level'];
        if (levelName != null && levelName.toString().isNotEmpty) {
          return 'Congratulations! You reached $levelName!';
        }
        return 'Congratulations on your level up!';

      case 'gift_available':
        final giftType = notification['gift_type'];
        if (giftType != null && giftType.toString().isNotEmpty) {
          return 'A new $giftType is waiting for you!';
        }
        return 'A new gift is waiting for you!';

      case 'progress_updated':
        final progress = notification['progress'];
        if (progress != null) {
          return 'You\'re now at $progress% completion!';
        }
        return 'Your progress has been updated!';

      default:
        // Fallback to message field or generic message
        final message = notification['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }

        // Try to build a generic message from available data
        final amount = notification['amount'];
        if (amount != null) {
          final source = _formatSourceName(notification['source']?.toString());
          return 'You earned $amount points${source.isNotEmpty ? ' from $source' : ''}!';
        }

        return 'You have a new update!';
    }
  }
}
