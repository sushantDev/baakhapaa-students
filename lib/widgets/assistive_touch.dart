import 'dart:async';

import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/providers/video_state_provider.dart';
import 'package:baakhapaa/screens/auth/login_screen.dart';
import 'package:baakhapaa/screens/leaderboard/leaderboard_screen.dart';
import 'package:baakhapaa/screens/messages/chat_bot_screen.dart';
import 'package:baakhapaa/screens/messages/conversations_screen.dart';
import 'package:baakhapaa/screens/others/notification_screen.dart';
import 'package:baakhapaa/screens/story/story_screen.dart';
import 'package:baakhapaa/screens/user/achievements_screen.dart';
import 'package:baakhapaa/screens/user/setting_screen.dart';
import 'package:baakhapaa/screens/user/tab_view_log.dart';
import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:upgrader/upgrader.dart';
import 'package:baakhapaa/providers/assistive_touch_provider.dart';
import 'package:baakhapaa/providers/puppet_interaction_provider.dart';
import 'package:baakhapaa/providers/rewards_provider.dart';
import 'package:baakhapaa/providers/levels.dart';
import 'package:baakhapaa/services/pusher_service.dart';
import 'package:baakhapaa/widgets/rewards/redesigned_rewards_overlay.dart';
import 'package:baakhapaa/widgets/rewards/level_up_celebration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/debug_logger.dart';
import '../main.dart' show rewardNotificationStream, globalAuth;

class AssistiveTouch extends StatefulWidget {
  final GlobalKey<NavigatorState> mainNavKey;

  const AssistiveTouch({
    Key? key,
    required this.mainNavKey,
  }) : super(key: key);

  @override
  _AssistiveTouchState createState() => _AssistiveTouchState();
}

class _AssistiveTouchState extends State<AssistiveTouch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late SharedPreferences _prefs;
  double _left = 0.0; // This will be updated in _loadPosition
  double _top = 100.0;
  double _touchOpacity = 1.0;
  bool _isDragging = false;
  bool _isMenuOpen = false;
  bool _isMoreMenuOpen = false;
  bool _showRewardsOverlay = false;
  bool _showLevelCelebration = false;
  bool _isForcedUpdate = false;
  bool _isCheckingUpdate = false;
  List<Map<String, dynamic>> _notificationEvents = [];
  List<PusherEventData> _pusherEvents = [];

  // Deduplication: Track recent event IDs to prevent duplicates
  final Set<String> _recentEventIds = {};

  Timer? _visibilityTimer;
  int currentMessageIndex = 0;
  Timer? messageTimer;
  StreamSubscription? _rewardStreamSubscription;
  StreamSubscription? _pusherStreamSubscription;

  @override
  void initState() {
    super.initState();
    DebugLogger.puppet('AssistiveTouch: Initializing AssistiveTouch widget');
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Delay initialization to avoid memory issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DebugLogger.puppet('AssistiveTouch: Starting post-frame initialization');
      _loadPosition();
      _startInitialVisibilityTimer();
      _initializeProvider();
      _checkForUpdates(); // Check for app updates
    });
  }

  /// Check if app update is available and force show overlay
  Future<void> _checkForUpdates() async {
    if (!mounted || _isCheckingUpdate) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      // Import upgrader package at the top of this file if not already
      final upgrader = Upgrader(
        durationUntilAlertAgain: Duration(hours: 24),
        countryCode: 'NP',
        languageCode: 'en',
      );

      await upgrader.initialize();

      // Wait a bit for initialization to complete
      await Future.delayed(Duration(milliseconds: 500));

      final appStoreVersion = upgrader.currentAppStoreVersion;
      final installedVersion = upgrader.currentInstalledVersion;

      if (appStoreVersion != null && installedVersion != null) {
        DebugLogger.info(
            '🔍 ASSISTIVE UPDATE CHECK: Installed: $installedVersion, Store: $appStoreVersion');

        // Simple check - if shouldDisplayUpgrade returns true, force the update
        final hasUpdate = upgrader.shouldDisplayUpgrade();

        if (hasUpdate) {
          DebugLogger.info('⚠️ FORCED UPDATE REQUIRED!');
          DebugLogger.info('📱 App Store Version: $appStoreVersion');
          DebugLogger.info('📱 Installed Version: $installedVersion');

          if (mounted) {
            setState(() {
              _isForcedUpdate = true;
              _showRewardsOverlay = true; // Auto-open overlay
              _touchOpacity = 1.0;
            });
          }
        } else {
          DebugLogger.info('✅ App is up to date');
        }
      }
    } catch (e) {
      DebugLogger.info('❌ Error checking for updates in assistive touch: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  Future<void> _initializeProvider() async {
    if (!mounted) return;
    final provider =
        Provider.of<AssistiveTouchProvider>(context, listen: false);
    await provider.initState();

    // Initialize rewards provider
    try {
      final rewardsProvider =
          Provider.of<RewardsProvider>(context, listen: false);
      final authProvider = Provider.of<Auth>(context, listen: false);
      Provider.of<Levels>(context, listen: false);

      // await rewardsProvider.fetchDashboard(levelsProvider: levelsProvider);

      DebugLogger.info(
          '🎁 ASSISTIVE: Setting up reward notification listener...');

      // Initialize Pusher for real-time events
      try {
        DebugLogger.info(
            '🔌 ASSISTIVE: Setting up Pusher for user ${authProvider.userId}');
        await PusherService.setupAndConnect(
          authProvider.userId,
          authToken: authProvider.token,
        );

        // Listen to Pusher events
        _setupPusherEventListener(rewardsProvider);
        DebugLogger.info('✅ ASSISTIVE: Pusher setup complete');
      } catch (e) {
        DebugLogger.info('❌ ASSISTIVE: Pusher setup error: $e');
        // Continue without Pusher, FCM will still work
      }

      // Listen to reward notifications from FCM (backup delivery)
      _rewardStreamSubscription =
          rewardNotificationStream.stream.listen((data) {
        DebugLogger.info(
            '🎁 ASSISTIVE: ✅ Received reward notification in assistive touch!');
        DebugLogger.info('🎁 ASSISTIVE: Data received: $data');

        if (!mounted) {
          DebugLogger.info('🎁 ASSISTIVE: Widget not mounted, skipping');
          return;
        }

        // Generate event ID for deduplication
        final eventType = data['type'] ?? 'unknown';
        final eventId = _generateEventId(eventType, data);

        // Skip if this is a duplicate event
        if (_isRecentEvent(eventId)) {
          return;
        }

        // Check if this is a low-priority notification
        final priority = data['priority'];
        if (priority == 'low') {
          DebugLogger.info(
              '🔕 ASSISTIVE: Low-priority FCM notification - skipping overlay');

          // Increment notification count for low-priority notifications
          try {
            globalAuth.incrementNotificationCount();
            DebugLogger.info(
                '✅ ASSISTIVE: Incremented notification count for low-priority FCM event');
          } catch (e) {
            DebugLogger.error(
                '❌ ASSISTIVE: Error incrementing notification count: $e');
          }

          return; // Don't show overlay, let system notification handle it
        }

        // Update rewards provider with the notification data
        rewardsProvider.handleRewardNotification(data);

        // Add to notification events queue only if overlay not already open
        // This prevents duplicates when both Pusher and FCM fire
        setState(() {
          if (!_showRewardsOverlay) {
            // Clear old events when opening fresh
            _notificationEvents.clear();
            _pusherEvents.clear();
          }
          _notificationEvents.add(data);
          _showRewardsOverlay = true;
          _touchOpacity = 1.0;
        });

        DebugLogger.info('🎁 ASSISTIVE: Rewards overlay shown!');
      });
    } catch (e) {
      DebugLogger.error('Error initializing provider: $e');
    }

    // Start message sequence
    if (mounted) {
      _startMessageSequence();
    }
  }

  void _setupPusherEventListener(RewardsProvider rewardsProvider) {
    final pusherService = PusherService();

    _pusherStreamSubscription = pusherService.eventStream.listen(
      (event) {
        DebugLogger.info('🎁 ASSISTIVE: Received Pusher event: ${event.type}');

        if (!mounted) {
          DebugLogger.info(
              '🎁 ASSISTIVE: Widget not mounted, skipping Pusher event');
          return;
        }

        // Generate event ID for deduplication
        final eventId = _generateEventId(event.type, event.data);

        // Skip if this is a duplicate event
        if (_isRecentEvent(eventId)) {
          return;
        }

        // Check if this is a low-priority notification
        if (event.priority == 'low') {
          DebugLogger.info(
              '🔕 ASSISTIVE: Low-priority Pusher event - showing local notification');
          _showLowPriorityNotification(event);

          // Increment notification count using globalAuth
          try {
            globalAuth.incrementNotificationCount();
            DebugLogger.info(
                '✅ ASSISTIVE: Incremented notification count for low-priority Pusher event');
          } catch (e) {
            DebugLogger.info(
                '❌ ASSISTIVE: Error incrementing notification count: $e');
          }

          return; // Don't show overlay for engagement notifications
        }

        // Update rewards provider with Pusher event
        rewardsProvider.handleRewardNotification(event.data);

        // Add to Pusher events queue only if overlay not already open
        // This prevents duplicates when both Pusher and FCM fire
        setState(() {
          if (!_showRewardsOverlay) {
            // Clear old events when opening fresh
            _notificationEvents.clear();
            _pusherEvents.clear();
          }
          _pusherEvents.add(event);
          _showRewardsOverlay = true;
          _touchOpacity = 1.0;
        });

        DebugLogger.info('✅ ASSISTIVE: Pusher event overlay shown!');
      },
      onError: (error) {
        DebugLogger.info('❌ ASSISTIVE: Pusher stream error: $error');
      },
    );
  }

  final List<MenuItemData> _menuItems = [
    MenuItemData(Icons.home, 'Home'),
    MenuItemData(Icons.notifications, 'Notification'),
    MenuItemData(Icons.person, 'My Profile'),
    MenuItemData(Icons.message, 'Messages'),
    MenuItemData(Icons.receipt_long, 'Logs'),
    MenuItemData(Icons.support_agent, 'AI Support'),
    MenuItemData(Icons.leaderboard, 'Leaderboard'),
    MenuItemData(Icons.more_horiz, 'More'),
    MenuItemData(Icons.arrow_back, 'Go Back'),
  ];

  final List<MenuItemData> _moreMenuItems = [
    MenuItemData(Icons.settings, 'Settings'),
    MenuItemData(Icons.emoji_events, 'Achievements'),
    MenuItemData(Icons.arrow_back, 'Go Back'),
  ];

  void _handleMenuItemTap(int index) {
    // Check if user is authenticated before allowing navigation
    bool isAuthenticated = false;
    try {
      final authProvider = Provider.of<Auth>(context, listen: false);
      isAuthenticated = authProvider.isAuth;
    } catch (e) {
      isAuthenticated = false;
    }

    // If not authenticated, show login prompt instead of navigating
    if (!isAuthenticated) {
      // Allow "Go Back" functionality for guest users since it's basic navigation
      if (index == 8) {
        // Go Back option
        _handleGoBack();
        return;
      }
      _showLoginPrompt();
      return;
    }

    if (index == 7) {
      // More option
      _showMoreMenu();
      return;
    }
    switch (index) {
      case 0: // Home
        _handleHome();
        break;
      case 1: //Notification Center
        _handleNotificationCenter();
        break;
      case 2: // My Profile
        _handleControlCenter();
        break;
      case 3: // Messages
        _handleMessageCenter();
        break;
      case 4: // Settings
        _handleTransactionsCenter();
        break;
      case 5: // Search
        // _handleSupportCenter();
        _handleAiAssistant();
        break;
      case 6: // Leaderboard
        _handleLeaderboardCenter();
        break;
      case 7: // More
        _toggleMenu();
        break;
      default: // Go Back
        _handleGoBack();
        break;
    }
  }

  void _handleMoreMenuItemTap(int index) {
    // Check if user is authenticated before allowing navigation
    bool isAuthenticated = false;
    try {
      final authProvider = Provider.of<Auth>(context, listen: false);
      isAuthenticated = authProvider.isAuth;
    } catch (e) {
      isAuthenticated = false;
    }

    // If not authenticated, show login prompt instead of navigating
    if (!isAuthenticated && index != 2) {
      // Allow "Go Back" for guest users
      _showLoginPrompt();
      return;
    }

    switch (index) {
      case 0: // Settings
        _handleSettings();
        break;
      case 1: // Achievements
        _handleAchievements();
        break;
      default: // Go Back
        // Just close the more menu and return to main menu
        setState(() {
          _isMoreMenuOpen = false;
        });
        break;
    }
  }

  void _handleSettings() {
    _toggleMoreMenu();
    _toggleMenu();
    widget.mainNavKey.currentState!.pushNamed(SettingScreen.routeName);
  }

  void _handleAchievements() {
    _toggleMoreMenu();
    _toggleMenu();
    widget.mainNavKey.currentState!.pushNamed(AchievementsScreen.routeName);
  }

  void _showMoreMenu() {
    setState(() {
      _isMoreMenuOpen = true;
    });
  }

  void _toggleMoreMenu() {
    setState(() {
      _isMoreMenuOpen = false;
    });
  }

  void _showLoginPrompt() {
    _toggleMenu(); // Close the menu first

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.blue),
              SizedBox(width: 8),
              Text('Login Required'),
            ],
          ),
          content: Text(
            'Please log in to access this feature and enjoy the full Baakhapaa experience!',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to login screen
                widget.mainNavKey.currentState!
                    .pushNamed(LoginScreen.routeName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Login'),
            ),
          ],
        );
      },
    );
  }

  void _startInitialVisibilityTimer() {
    _visibilityTimer?.cancel();
    _visibilityTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isDragging && !_isMenuOpen) {
        _snapToEdge(context); // Auto-hide to mostly off-screen position
      }
    });
  }

  void _handleGoBack() {
    _toggleMenu();
    try {
      if (widget.mainNavKey.currentState != null &&
          widget.mainNavKey.currentState!.canPop()) {
        widget.mainNavKey.currentState!.pop();
      }
    } catch (e) {
      DebugLogger.error('Navigation error: $e');
    }
  }

  /// Generate a unique ID for an event to prevent duplicates
  String _generateEventId(String type, Map<String, dynamic> data) {
    // Create unique ID from type + timestamp + key data
    final timestamp = data['timestamp'] ?? DateTime.now().toIso8601String();
    final userId = data['user_id'] ?? data['new_level_id'] ?? '';
    return '$type-$userId-$timestamp';
  }

  /// Check if event was recently processed (within last 5 seconds)
  bool _isRecentEvent(String eventId) {
    if (_recentEventIds.contains(eventId)) {
      DebugLogger.info('⚠️ DEDUP: Skipping duplicate event: $eventId');
      return true;
    }

    // Add to recent events and schedule cleanup
    _recentEventIds.add(eventId);

    // Clean up after 5 seconds
    Future.delayed(Duration(seconds: 5), () {
      _recentEventIds.remove(eventId);
    });

    return false;
  }

  /// Check if assistive touch is in hidden position (completely off-screen)
  bool _isInHiddenPosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    return _left >= screenWidth - 5 || _left <= -50;
  }

  Future<void> _loadPosition() async {
    if (!mounted) return;

    _prefs = await SharedPreferences.getInstance();
    final screenSize = MediaQuery.of(context).size;

    if (!mounted) return;

    // Load saved position, or default to visible position on right side
    final savedX = _prefs.getDouble('assistive_touch_x');
    final savedY = _prefs.getDouble('assistive_touch_y');

    setState(() {
      // If no saved position, start visible on right side (not hidden)
      _left = savedX ?? (screenSize.width - 65);
      _top = savedY ?? (screenSize.height - 200);

      // Ensure it's within screen bounds with 120px safe zones from top and bottom
      _left = _left.clamp(-55.0, screenSize.width);
      _top = _top.clamp(120.0, screenSize.height - 120.0);
    });
  }

  void _savePosition() {
    _prefs.setDouble('assistive_touch_x', _left);
    _prefs.setDouble('assistive_touch_y', _top);
  }

  void _snapToEdge(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final centerX = _left + 28; // Center of larger touch area

    setState(() {
      if (centerX < screenWidth / 2) {
        // Completely hide on left side
        _left = -55;
      } else {
        // Completely hide on right side
        _left = screenWidth;
      }
      _savePosition();
    });

    // After snapping, start a timer to reduce opacity if not interacting
    _visibilityTimer?.cancel();
    _visibilityTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_isDragging && !_isMenuOpen) {
        setState(() {
          _touchOpacity = 0.8;
        });
      }
    });
  }

  void _toggleMenu() async {
    // If forced update is active, prevent closing the overlay
    if (_isForcedUpdate && _showRewardsOverlay) {
      DebugLogger.info('⚠️ Cannot close overlay - forced update required');
      return;
    }

    // Check if user is authenticated - don't show rewards for guests
    bool isAuthenticated = false;
    try {
      final authProvider = Provider.of<Auth>(context, listen: false);
      isAuthenticated = authProvider.isAuth;
    } catch (e) {
      isAuthenticated = false;
    }

    if (!isAuthenticated) {
      // Don't open rewards overlay for guest users
      return;
    }

    // Fetch fresh data when opening the overlay
    if (!_showRewardsOverlay) {
      try {
        final rewardsProvider =
            Provider.of<RewardsProvider>(context, listen: false);
        final levelsProvider = Provider.of<Levels>(context, listen: false);

        // Fetch latest level progress from API
        await rewardsProvider.fetchDashboard(levelsProvider);

        DebugLogger.info('🎁 Refreshed rewards data from API');
      } catch (e) {
        DebugLogger.error('Error refreshing rewards data: $e');
      }
    }

    // Prevent closing overlay if forced update is required
    if (_isForcedUpdate && _showRewardsOverlay) {
      DebugLogger.info(
          '⚠️ Cannot close rewards overlay - forced update required');
      return;
    }

    setState(() {
      // Show rewards overlay instead of menu
      _showRewardsOverlay = !_showRewardsOverlay;

      if (_showRewardsOverlay) {
        _touchOpacity = 1.0;
      } else {
        // Start timer to auto-hide to edge after overlay closes
        _visibilityTimer?.cancel();
        _visibilityTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && !_isDragging && !_showRewardsOverlay) {
            _snapToEdge(context);
          }
        });
      }
    });
  }

  void _handleNavigation(Function() navigationAction) {
    // Block navigation if forced update is required
    if (_isForcedUpdate) {
      DebugLogger.info('⚠️ Navigation blocked - forced update required');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Please update the app to continue'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: Duration(seconds: 3),
        ),
      );
      // Force open rewards overlay if not already open
      if (!_showRewardsOverlay) {
        setState(() {
          _showRewardsOverlay = true;
          _touchOpacity = 1.0;
        });
      }
      return;
    }

    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);

    _toggleMenu();

    // Set navigation flag and pause video if in shorts screen
    if (videoStateProvider.currentScreen == 'shorts') {
      videoStateProvider.setNavigatingWithAssistiveTouch(true);
      Future.microtask(() {
        videoStateProvider.pauseVideo();
      });
    }

    navigationAction();
  }

  void _handleHome() {
    _handleNavigation(() {
      widget.mainNavKey.currentState!
          .pushReplacementNamed(StoryScreen.routeName);
    });
  }

  void _handleNotificationCenter() {
    _handleNavigation(() {
      widget.mainNavKey.currentState!.pushNamed(NotificationScreen.routeName);
    });
  }

  void _handleControlCenter() {
    _handleNavigation(() {
      widget.mainNavKey.currentState!.pushNamed(UserScreen.routeName);
    });
  }

  void _handleMessageCenter() {
    _handleNavigation(() {
      // Clear unread count (only if auth provider is available)
      try {
        Provider.of<Auth>(context, listen: false).clearUnreadMessageCount();
      } catch (e) {
        // Auth provider might not be available for guest users
        DebugLogger.auth('Auth provider not available for guest user');
      }
      widget.mainNavKey.currentState!.pushNamed(ConversationsScreen.routeName);
    });
  }

  void _handleTransactionsCenter() {
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
    _handleNavigation(() {
      widget.mainNavKey.currentState!.push(
        PageTransition(
          child: TabViewOrder(scaffoldKey: _scaffoldKey),
          type: PageTransitionType.fade,
        ),
      );
    });
  }

  // void _handleSupportCenter() {
  //   final _authProvider = Provider.of<Auth>(context, listen: false);
  //   List<int> userIds = [
  //     _authProvider.userId,
  //     37,
  //   ];

  //   _handleNavigation(() {
  //     _authProvider.startConversations(userIds).then((_) {
  //       widget.mainNavKey.currentState!.pushNamed(
  //         MessagesScreen.routeName,
  //         arguments: {
  //           'conversation_id': _authProvider.selectedConversationId,
  //           'user_name': 'Baakhapaa Support',
  //         },
  //       );
  //     });
  //   });
  // }

  void _handleAiAssistant() {
    _handleNavigation(() {
      widget.mainNavKey.currentState!.pushNamed(ChatbotScreen.routeName);
    });
  }

  void _handleLeaderboardCenter() {
    _handleNavigation(() {
      widget.mainNavKey.currentState!.pushNamed(LeaderboardScreen.routeName);
    });
  }

  void _updatePosition(DragUpdateDetails details) {
    final screenSize = MediaQuery.of(context).size;
    final maxX = screenSize.width + 10; // Allow it to go completely off-screen
    final maxY = screenSize.height - 120.0; // 120px safe zone from bottom

    setState(() {
      _left = (_left + details.delta.dx).clamp(-60.0, maxX);
      _top = (_top + details.delta.dy)
          .clamp(120.0, maxY); // 120px safe zone from top
      _touchOpacity = 1.0; // Full opacity while dragging
    });
  }

  void _startMessageSequence() async {
    final provider =
        Provider.of<AssistiveTouchProvider>(context, listen: false);
    if (provider.messages.isEmpty) return;

    currentMessageIndex = 0;
    setState(() {
      _touchOpacity = 1.0;
    });

    await provider.toggleMessage(true);

    messageTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) return;

      if (currentMessageIndex < provider.messages.length - 1) {
        setState(() {
          currentMessageIndex++;
          _touchOpacity = 1.0;
        });
      } else {
        timer.cancel();
        await provider.toggleMessage(false);
        setState(() {
          currentMessageIndex = 0;
        });

        _visibilityTimer?.cancel();
        _visibilityTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && !_isDragging && !_isMenuOpen && !_showRewardsOverlay) {
            _snapToEdge(context); // Auto-hide to mostly off-screen
          }
        });
      }
    });
  }

  Widget _buildMessageBubble(List<String> messages, bool show) {
    if (!show || messages.isEmpty) return SizedBox.shrink();

    // Ensure currentMessageIndex is within bounds
    currentMessageIndex = currentMessageIndex.clamp(0, messages.length - 1);

    double bubbleLeft;
    double screenWidth = MediaQuery.of(context).size.width;

    // Calculate position to ensure bubble is always beside the assistive touch
    if (_left < screenWidth / 2) {
      bubbleLeft = _left + 70;
    } else {
      bubbleLeft = _left - 220 - 10;
    }

    // Ensure bubble stays within screen bounds
    if (bubbleLeft < 0) bubbleLeft = 0;
    if (bubbleLeft + 220 > screenWidth) bubbleLeft = screenWidth - 220;

    final assistiveProvider =
        Provider.of<AssistiveTouchProvider>(context, listen: false);
    final isPuppetMessage = assistiveProvider.currentPuppet != null;

    return Positioned(
      left: bubbleLeft,
      top: _top - 10,
      child: AnimatedOpacity(
        opacity: show ? 1.0 : 0.0,
        duration: Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () {
            // Execute the same action as the button when tapping the message bubble
            if (isPuppetMessage && assistiveProvider.currentPuppet != null) {
              final puppet = assistiveProvider.currentPuppet!;

              // Execute puppet interaction like the button does
              if (puppet.goToPage != null && puppet.goToPage!.isNotEmpty) {
                // Complete the puppet interaction which executes actions
                try {
                  final puppetProvider = Provider.of<PuppetInteractionProvider>(
                      context,
                      listen: false);
                  puppetProvider.completePuppetInteraction(
                    context: context,
                    navigatorKey: widget.mainNavKey,
                  );
                } catch (e) {
                  DebugLogger.info(
                      '🎭 ERROR calling completePuppetInteraction: $e');
                }
              } else {
                // Just dismiss if no navigation target
                try {
                  final puppetProvider = Provider.of<PuppetInteractionProvider>(
                      context,
                      listen: false);
                  puppetProvider.dismissCurrentPuppet(
                      isDismissed: true, context: context);
                } catch (e) {
                  DebugLogger.info('🎭 ERROR calling dismissCurrentPuppet: $e');
                }
              }
            }
          },
          child: Container(
            constraints: BoxConstraints(maxWidth: 220, minHeight: 40),
            child: Stack(
              children: [
                CustomPaint(
                  painter: CloudPainter(isLeftSide: _left >= screenWidth / 2),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Add puppet indicator for puppet messages
                        if (isPuppetMessage)
                          Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.smart_toy,
                                    size: 12, color: Colors.amber),
                                SizedBox(width: 4),
                                Text(
                                  'Puppet Assistant',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Message content
                        AnimatedSwitcher(
                          duration: Duration(milliseconds: 500),
                          child: Text(
                            messages[currentMessageIndex],
                            key: ValueKey<int>(currentMessageIndex),
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),

                        // Show level progress if available
                        if (isPuppetMessage &&
                            assistiveProvider.currentPuppet?.levelProgress !=
                                null)
                          _buildLevelProgressIndicator(
                              assistiveProvider.currentPuppet!.levelProgress!),

                        // Add tap hint for puppet messages
                        if (isPuppetMessage)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Tap to see options',
                              style: TextStyle(
                                color: Colors.amber.withValues(alpha: 0.7),
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 4,
                  child: _buildSkipButton(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    final assistiveProvider =
        Provider.of<AssistiveTouchProvider>(context, listen: false);
    final isPuppetMessage = assistiveProvider.currentPuppet != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show "Less" button for puppet messages after multiple shows
        if (isPuppetMessage && assistiveProvider.puppetDismissCount >= 2)
          GestureDetector(
            onTap: () {
              _showPuppetOptionsDialog(context);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.5), width: 1),
              ),
              child: Icon(
                Icons.settings,
                color: Colors.orange,
                size: 14,
              ),
            ),
          ),

        // Skip/Next button
        GestureDetector(
          onTap: () {
            DebugLogger.info('🎭 ASSISTIVE TOUCH BUTTON TAPPED');
            DebugLogger.info('🎭 isPuppetMessage: $isPuppetMessage');

            if (isPuppetMessage) {
              // Check if puppet has goToPage for navigation OR actionType/actionId for actions
              final puppet = assistiveProvider.currentPuppet;
              DebugLogger.info('🎭 Current puppet: $puppet');
              DebugLogger.info('🎭 Puppet goToPage: ${puppet?.goToPage}');
              DebugLogger.info('🎭 Puppet actionType: ${puppet?.actionType}');
              DebugLogger.info('🎭 Puppet actionId: ${puppet?.actionId}');

              // Check if this puppet has any actionable content (navigation OR action)
              final hasNavigation =
                  puppet?.goToPage != null && puppet!.goToPage!.isNotEmpty;
              final hasAction =
                  puppet?.actionType != null && puppet?.actionId != null;

              if (hasNavigation || hasAction) {
                DebugLogger.info(
                    '🎭 ACTION PATH - Puppet has ${hasNavigation ? "navigation" : ""}${hasNavigation && hasAction ? " and " : ""}${hasAction ? "action" : ""}');

                // Complete the puppet interaction (this executes actions AND handles navigation)
                DebugLogger.info('🎭 Calling completePuppetInteraction...');
                try {
                  final puppetProvider = Provider.of<PuppetInteractionProvider>(
                      context,
                      listen: false);
                  puppetProvider.completePuppetInteraction(
                    context: context,
                    navigatorKey: widget.mainNavKey,
                  );
                  DebugLogger.info(
                      '🎭 completePuppetInteraction called successfully');
                } catch (e) {
                  DebugLogger.info(
                      '🎭 ERROR calling completePuppetInteraction: $e');
                }

                // Clear the puppet message since action is complete
                assistiveProvider.clearPuppetMessage();
              } else {
                DebugLogger.info(
                    '🎭 DISMISSAL PATH - No goToPage, just dismissing');

                // Complete the puppet interaction for dismissal
                DebugLogger.info('🎭 Calling dismissCurrentPuppet...');
                try {
                  final puppetProvider = Provider.of<PuppetInteractionProvider>(
                      context,
                      listen: false);
                  puppetProvider.dismissCurrentPuppet(
                      isDismissed: true, context: context);
                  DebugLogger.info(
                      '🎭 dismissCurrentPuppet called successfully');
                } catch (e) {
                  DebugLogger.info('🎭 ERROR calling dismissCurrentPuppet: $e');
                }

                // Handle puppet message dismissal (no navigation)
                assistiveProvider.clearPuppetMessage();
              }
            } else {
              // Handle tutorial message dismissal
              final tutorialProvider =
                  Provider.of<TutorialFlowProvider>(context, listen: false);
              setState(() {
                assistiveProvider.clearTutorialMessage();
              });
              tutorialProvider.completeTutorial();
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isPuppetMessage &&
                      ((assistiveProvider.currentPuppet?.goToPage != null &&
                              assistiveProvider
                                  .currentPuppet!.goToPage!.isNotEmpty) ||
                          (assistiveProvider.currentPuppet?.actionType !=
                                  null &&
                              assistiveProvider.currentPuppet?.actionId !=
                                  null))
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isPuppetMessage &&
                          ((assistiveProvider.currentPuppet?.goToPage != null &&
                                  assistiveProvider
                                      .currentPuppet!.goToPage!.isNotEmpty) ||
                              (assistiveProvider.currentPuppet?.actionType !=
                                      null &&
                                  assistiveProvider.currentPuppet?.actionId !=
                                      null))
                      ? Colors.green.withValues(alpha: 0.5)
                      : Colors.amber.withValues(alpha: 0.5),
                  width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPuppetMessage &&
                          ((assistiveProvider.currentPuppet?.goToPage != null &&
                                  assistiveProvider
                                      .currentPuppet!.goToPage!.isNotEmpty) ||
                              (assistiveProvider.currentPuppet?.actionType !=
                                      null &&
                                  assistiveProvider.currentPuppet?.actionId !=
                                      null))
                      ? 'Next'
                      : isPuppetMessage
                          ? 'Got it'
                          : 'Skip',
                  style: TextStyle(
                    color: isPuppetMessage &&
                            ((assistiveProvider.currentPuppet?.goToPage !=
                                        null &&
                                    assistiveProvider
                                        .currentPuppet!.goToPage!.isNotEmpty) ||
                                (assistiveProvider.currentPuppet?.actionType !=
                                        null &&
                                    assistiveProvider.currentPuppet?.actionId !=
                                        null))
                        ? Colors.green
                        : Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isPuppetMessage &&
                    ((assistiveProvider.currentPuppet?.goToPage != null &&
                            assistiveProvider
                                .currentPuppet!.goToPage!.isNotEmpty) ||
                        (assistiveProvider.currentPuppet?.actionType != null &&
                            assistiveProvider.currentPuppet?.actionId !=
                                null))) ...[
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.green,
                    size: 12,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPuppetOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Puppet Assistant Options'),
          content: Text('Would you like to see fewer puppet suggestions?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Keep Current'),
            ),
            TextButton(
              onPressed: () {
                final assistiveProvider =
                    Provider.of<AssistiveTouchProvider>(context, listen: false);
                assistiveProvider.toggleEnabled(false);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Puppet assistant disabled. You can re-enable it in settings.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: Text('Disable Puppet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final assistiveProvider = Provider.of<AssistiveTouchProvider>(context);

    // Handle auth provider safely for guest users
    Auth? authProvider;
    bool hasUnreadMessages = false;
    try {
      authProvider = Provider.of<Auth>(context);
      hasUnreadMessages = authProvider.unreadMessageCount > 0;
    } catch (e) {
      // Auth provider might not be available for guest users
      authProvider = null;
      hasUnreadMessages = false;
    }

    if (!assistiveProvider.isEnabled) {
      return const SizedBox.shrink();
    }

    final messages = assistiveProvider.messages;
    final showMessage = assistiveProvider.showMessage;
    final canPop = widget.mainNavKey.currentState?.canPop() ?? false;

    // Force full opacity when messages are showing
    if (showMessage) {
      _touchOpacity = 1.0;
    }
    final menuItems =
        canPop ? _menuItems : _menuItems.sublist(0, _menuItems.length - 1);

    return Stack(
      children: [
        // Rewards overlay - Redesigned version
        if (_showRewardsOverlay)
          RedesignedRewardsOverlay(
            navigatorKey: widget.mainNavKey,
            pusherEvents: _pusherEvents,
            notificationEvents: _notificationEvents,
            isForcedUpdate: _isForcedUpdate, // Pass forced update flag
            onClose: () {
              // Block closing if forced update is required
              if (_isForcedUpdate) {
                DebugLogger.info(
                    '⚠️ Cannot close overlay - forced update required');
                return;
              }
              setState(() {
                _showRewardsOverlay = false;
                _pusherEvents.clear(); // Clear all events after closing
                _notificationEvents.clear(); // Clear all notification events
              });
            },
          ),

        // Level up celebration
        if (_showLevelCelebration)
          Consumer<RewardsProvider>(
            builder: (context, rewardsProvider, _) {
              // Extract level number from levelName if possible (e.g., "Level 4" -> 4)
              int levelNumber = 1;
              try {
                final match =
                    RegExp(r'\d+').firstMatch(rewardsProvider.levelName);
                if (match != null) {
                  levelNumber = int.parse(match.group(0)!);
                }
              } catch (e) {
                levelNumber = 1;
              }

              return LevelUpCelebration(
                newLevel: levelNumber,
                levelName: rewardsProvider.levelName,
                onDismiss: () {
                  setState(() {
                    _showLevelCelebration = false;
                  });
                },
              );
            },
          ),

        if (_isMenuOpen)
          GestureDetector(
            onTap: _toggleMenu,
            child: Container(
              color: Colors.black54,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
            ),
          ),
        if (_isMenuOpen)
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOutBack,
              ),
              child: Container(
                width: 300,
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isMoreMenuOpen ? 'More Options' : 'Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildMenuItems(context, menuItems),
                  ],
                ),
              ),
            ),
          ),
        // Hide assistive touch button when overlay or more menu is active
        if (!_showRewardsOverlay && !_isMoreMenuOpen)
          Positioned(
            left: _left,
            top: _top,
            child: Stack(
              children: [
                GestureDetector(
                  onTapDown: (_) => setState(() => _touchOpacity = 1.0),
                  onTapUp: (_) {
                    // If completely hidden, pull it out on tap
                    final screenWidth = MediaQuery.of(context).size.width;
                    if (_left >= screenWidth - 5 || _left <= -50) {
                      setState(() {
                        if (_left >= screenWidth - 5) {
                          _left = screenWidth - 65; // Pull from right
                        } else {
                          _left = 10; // Pull from left
                        }
                      });
                      _savePosition();
                    }

                    // Always start auto-hide timer after any interaction
                    _visibilityTimer?.cancel();
                    _visibilityTimer = Timer(const Duration(seconds: 4), () {
                      if (mounted &&
                          !_isDragging &&
                          !_isMenuOpen &&
                          !_showRewardsOverlay) {
                        _snapToEdge(
                            context); // Auto-hide to completely off-screen
                      }
                    });
                  },
                  onTapCancel: () {
                    if (!_isMenuOpen) {
                      _visibilityTimer?.cancel();
                      _visibilityTimer = Timer(const Duration(seconds: 2), () {
                        if (mounted && !_isDragging && !_isMenuOpen) {
                          setState(() {
                            _touchOpacity = 0.3;
                          });
                        }
                      });
                    }
                  },
                  onTap: () {
                    // Check if user is authenticated before opening menu
                    bool isAuthenticated = false;
                    try {
                      final authProvider =
                          Provider.of<Auth>(context, listen: false);
                      isAuthenticated = authProvider.isAuth;
                    } catch (e) {
                      isAuthenticated = false;
                    }

                    if (!isAuthenticated) {
                      // Show login prompt for guest users
                      _showLoginPrompt();
                    } else {
                      // Open menu for authenticated users
                      _toggleMenu();
                    }
                  },
                  onPanStart: (_) => setState(() {
                    _isDragging = true;
                    _touchOpacity = 1.0;
                  }),
                  onPanUpdate: _updatePosition,
                  onPanEnd: (_) {
                    _snapToEdge(context);
                    setState(() {
                      _isDragging = false;
                    });

                    // Start auto-hide timer after drag
                    _visibilityTimer?.cancel();
                    _visibilityTimer = Timer(const Duration(seconds: 3), () {
                      if (mounted &&
                          !_isDragging &&
                          !_isMenuOpen &&
                          !_showRewardsOverlay) {
                        _snapToEdge(context);
                      }
                    });
                  },
                  child: AnimatedOpacity(
                    // Force full opacity if messages are showing, otherwise use touch opacity
                    opacity: showMessage ? 1.0 : _touchOpacity,
                    duration: const Duration(milliseconds: 200),
                    child: Consumer<RewardsProvider>(
                      builder: (context, rewardsProvider, child) {
                        // Get puppet image from auth provider, fallback to default
                        String puppetImageUrl =
                            "${Url.mediaUrl}/assets/puppetdev.png";
                        try {
                          final auth =
                              Provider.of<Auth>(context, listen: false);
                          if (auth.puppetImage != null &&
                              auth.puppetImage!.isNotEmpty) {
                            puppetImageUrl = auth.puppetImage!;
                          }
                        } catch (e) {
                          // Use default image for guest users or if auth not available
                        }

                        return Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: puppetImageUrl,
                              fit: BoxFit.contain,
                              width: 55,
                              height: 55,
                              errorWidget: (context, url, error) => Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Update notification badge
                if (hasUnreadMessages)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: AnimatedOpacity(
                      opacity: hasUnreadMessages
                          ? 1.0
                          : 0.0, // Always show when there are messages
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints:
                            BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            (authProvider?.unreadMessageCount ?? 0).toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // Arrow indicator when assistive touch is hidden (but not when overlay is active)
        if (_isInHiddenPosition() &&
            !_isMenuOpen &&
            !_showRewardsOverlay &&
            !showMessage)
          Positioned(
            left: _left >= MediaQuery.of(context).size.width - 5
                ? MediaQuery.of(context).size.width - 25 // Right side arrow
                : 5, // Left side arrow
            top: _top + 10,
            child: GestureDetector(
              onTap: () {
                // Pull out the hidden assistive touch
                final screenWidth = MediaQuery.of(context).size.width;
                setState(() {
                  if (_left >= screenWidth - 5) {
                    _left = screenWidth - 65; // Pull from right
                  } else {
                    _left = 10; // Pull from left
                  }
                });
                _savePosition();

                // Start auto-hide timer
                _visibilityTimer?.cancel();
                _visibilityTimer = Timer(const Duration(seconds: 4), () {
                  if (mounted &&
                      !_isDragging &&
                      !_isMenuOpen &&
                      !_showRewardsOverlay) {
                    _snapToEdge(context);
                  }
                });
              },
              child: AnimatedOpacity(
                opacity: 1.0, // Always fully visible when showing
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _left >= MediaQuery.of(context).size.width - 5
                        ? Icons
                            .arrow_back_ios // Right side - arrow pointing left
                        : Icons
                            .arrow_forward_ios, // Left side - arrow pointing right
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        if (showMessage) _buildMessageBubble(messages, showMessage),
      ],
    );
  }

  Widget _buildMenuItems(BuildContext context, List<MenuItemData> menuItems) {
    // Handle auth provider safely for guest users
    bool hasUnreadMessages = false;
    bool isAuthenticated = false;
    try {
      final authProvider = Provider.of<Auth>(context);
      hasUnreadMessages = authProvider.unreadMessageCount > 0;
      isAuthenticated = authProvider.isAuth;
    } catch (e) {
      // Auth provider might not be available for guest users
      hasUnreadMessages = false;
      isAuthenticated = false;
    }

    final displayItems = _isMoreMenuOpen ? _moreMenuItems : menuItems;

    // Fixed dimensions for grid and items
    const double gridWidth = 270.0; // Total grid width
    const double spacing = 12.0;
    const int columns = 3;

    // Calculate item width based on grid width and spacing
    final double itemWidth = (gridWidth - (spacing * (columns - 1))) / columns;
    final double itemHeight = itemWidth; // Keep items square

    // Calculate grid height
    final int rows = ((displayItems.length + columns - 1) / columns).ceil();
    final double totalHeight = (itemHeight * rows) + (spacing * (rows - 1));

    return Container(
      width: gridWidth,
      height: totalHeight,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: 1, // Square items
        ),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final item = displayItems[index];
          final showBadge = !_isMoreMenuOpen && index == 3 && hasUnreadMessages;

          // Determine if this item should show lock icon (for guest users)
          // Allow "Go Back" and "More" options for guest users
          final isGoBack = (_isMoreMenuOpen && index == 2) ||
              (!_isMoreMenuOpen && index == 8);
          final isMoreOption = !_isMoreMenuOpen && index == 7;
          final showLockIcon = !isAuthenticated && !isGoBack && !isMoreOption;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              _GridMenuButton(
                icon: item.icon,
                label: item.label,
                showLockIcon: showLockIcon,
                onTap: () => _isMoreMenuOpen
                    ? _handleMoreMenuItemTap(index)
                    : _handleMenuItemTap(index),
              ),
              if (showBadge)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black87, width: 1.5),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLevelProgressIndicator(Map<String, dynamic> levelProgress) {
    final currentLevel = levelProgress['current_level'];
    final nextLevel = levelProgress['next_level'];
    final progressPct = (levelProgress['progress_percentage'] ?? 0.0) as num;
    final remainingActions =
        levelProgress['remaining_actions'] as List<dynamic>? ?? [];

    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current level and next level
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Current level
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentLevel != null
                      ? currentLevel['name'] ?? 'Level ?'
                      : 'Level ?',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward,
                color: Colors.white60,
                size: 12,
              ),
              // Next level
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  nextLevel != null
                      ? nextLevel['name'] ?? 'Next Level'
                      : 'Next Level',
                  style: TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Background
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // Progress
                    FractionallySizedBox(
                      widthFactor:
                          (progressPct.toDouble() / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber, Colors.orange],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              Text(
                '${progressPct.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // First remaining action preview (if any)
          if (remainingActions.isNotEmpty) ...[
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    color: Colors.white70,
                    size: 10,
                  ),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _getActionPreview(remainingActions[0]),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  String _getActionPreview(dynamic action) {
    if (action is Map<String, dynamic>) {
      final actionType = action['action_type'] ?? '';
      final remainingCount = action['remaining_count'] ?? 0;
      final requiredCount = action['required_count'] ?? 0;

      switch (actionType) {
        case 'complete_challenge':
          return '$remainingCount/$requiredCount Challenges';
        case 'complete_episode':
          return '$remainingCount/$requiredCount Episodes';
        case 'complete_daily_task':
          return '$remainingCount/$requiredCount Daily Tasks';
        case 'maintain_streak':
          return '$remainingCount/$requiredCount Streak Days';
        case 'quiz_completion':
          return '$remainingCount/$requiredCount Quizzes';
        default:
          return '$remainingCount/$requiredCount Tasks';
      }
    }
    return 'Next goal';
  }

  @override
  void dispose() {
    messageTimer?.cancel();
    _visibilityTimer?.cancel();
    _rewardStreamSubscription?.cancel();
    _pusherStreamSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Helper method to show local notification for low-priority Pusher events
  void _showLowPriorityNotification(PusherEventData event) {
    // Format title and body based on event type
    String title = 'New Activity';
    String body = '';

    final actorName = event.actorName ?? event.actorUsername ?? 'Someone';
    final contentTitle = event.contentTitle ??
        event.data['shorts_title'] ??
        event.data['episode_title'] ??
        'your content';

    switch (event.type) {
      case 'shorts_liked':
        title = 'New Like';
        body = '👍 $actorName liked your shorts: $contentTitle';
        break;
      case 'shorts_commented':
        title = 'New Comment';
        body = '💬 $actorName commented on your shorts: $contentTitle';
        break;
      case 'shorts_donation_received':
        title = 'Donation Received';
        body =
            '💰 $actorName donated ${event.amount ?? 0} coins to your shorts!';
        break;
      case 'season_commented':
        title = 'New Comment';
        body = '💬 $actorName commented on your episode: $contentTitle';
        break;
      case 'season_donation_received':
        title = 'Donation Received';
        body =
            '💰 $actorName donated ${event.amount ?? 0} coins to your episode!';
        break;
      case 'content_view_milestone':
        final milestone =
            event.data['milestone'] ?? event.data['total_views'] ?? '';
        final type = event.contentType ?? 'content';
        title = 'Milestone Reached!';
        body = '🎉 Your $type \'$contentTitle\' reached $milestone views!';
        break;
      case 'user_followed':
        title = 'New Follower';
        body = '👤 $actorName started following you!';
        break;
      case 'badge_earned':
        final badgeTitle = event.data['badge_title'] ??
            event.data['badge_name'] ??
            'achievement';
        title = 'Badge Unlocked!';
        body = '🏆 You unlocked the badge: $badgeTitle!';
        break;
      case 'referral_joined':
        final referredUser = event.data['referred_user_name'] ?? actorName;
        title = 'Referral Success';
        body =
            '🎁 $referredUser joined using your referral code! You earned ${event.amount ?? event.data['coins_earned'] ?? 0} coins.';
        break;
      case 'challenge_won':
        final challengeTitle = event.data['challenge_title'] ??
            event.data['challenge_name'] ??
            'the challenge';
        title = 'Challenge Won!';
        body =
            '🏅 Congratulations! You won the challenge \'$challengeTitle\' and earned ${event.amount ?? event.data['coins_earned'] ?? 0} coins!';
        break;
      default:
        title = 'New Notification';
        body = event.message ?? 'You have a new update';
    }

    // Show local notification
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'engagement_channel',
      'Engagement Notifications',
      channelDescription: 'Notifications for likes, comments, follows, etc.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    flutterLocalNotificationsPlugin.show(
      event.hashCode, // Use event hashCode as unique ID
      title,
      body,
      notificationDetails,
    );

    DebugLogger.info(
        '🔔 ASSISTIVE: Showed local notification for ${event.type}: $title - $body');
  }
}

class MenuItemData {
  final IconData icon;
  final String label;

  MenuItemData(this.icon, this.label);
}

class _GridMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showLockIcon;

  const _GridMenuButton({
    Key? key,
    required this.icon,
    required this.label,
    this.onTap,
    this.showLockIcon = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: showLockIcon
              ? Colors.white.withValues(alpha: 0.08) // Dimmed for locked items
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: showLockIcon
                ? Colors.white
                    .withValues(alpha: 0.05) // Dimmed border for locked items
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Main content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: showLockIcon
                        ? Colors.white.withValues(
                            alpha: 0.5) // Dimmed icon for locked items
                        : Colors.white,
                    size: 24),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  width: double.infinity,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: showLockIcon
                          ? Colors.white.withValues(
                              alpha: 0.5) // Dimmed text for locked items
                          : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Lock icon overlay for guest users
            if (showLockIcon)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CloudPainter extends CustomPainter {
  final bool isLeftSide;

  CloudPainter({this.isLeftSide = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final r = 16.0;
    final path = Path();

    if (isLeftSide) {
      // Arrow on right side
      path.moveTo(r, 0);
      path.lineTo(size.width - r - 10, 0);
      path.quadraticBezierTo(size.width - 10, 0, size.width - 10, r);
      // Right edge with arrow
      path.lineTo(size.width - 10, size.height / 2 - 5);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(size.width - 10, size.height / 2 + 5);
      path.lineTo(size.width - 10, size.height - r);
      path.quadraticBezierTo(
          size.width - 10, size.height, size.width - r - 10, size.height);
      // Bottom edge
      path.lineTo(r, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - r);
      // Left edge
      path.lineTo(0, r);
      path.quadraticBezierTo(0, 0, r, 0);
      path.close();
    } else {
      // Arrow on left side
      path.moveTo(r + 10, 0);
      path.lineTo(size.width - r, 0);
      path.quadraticBezierTo(size.width, 0, size.width, r);
      path.lineTo(size.width, size.height - r);
      path.quadraticBezierTo(
          size.width, size.height, size.width - r, size.height);
      path.lineTo(r + 10, size.height);
      path.quadraticBezierTo(10, size.height, 10, size.height - r);
      // Left edge with arrow
      path.lineTo(10, size.height / 2 + 5);
      path.lineTo(0, size.height / 2);
      path.lineTo(10, size.height / 2 - 5);
      path.lineTo(10, r);
      path.quadraticBezierTo(10, 0, r + 10, 0);
      path.close();
    }

    canvas.drawShadow(path, Colors.black26, 8, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
