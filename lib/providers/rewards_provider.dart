import 'package:flutter/foundation.dart';
import 'package:baakhapaa/services/pusher_service.dart';
import 'package:baakhapaa/providers/levels.dart';
import 'dart:async';
import '../utils/debug_logger.dart';

class RewardsProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  bool _showRewardsOverlay = false;
  StreamSubscription? _pusherStreamSubscription;
  final PusherService _pusherService = PusherService();

  // Level progress data from /api/levels/user-progress
  String _levelName = 'New User';
  String _nextLevelName = 'Level 1';
  String? _levelDescription;
  String? _actionDescription;
  String? _levelHint;
  int _currentProgress = 0;
  int _requiredValue = 0;
  double _progressPercentage = 0.0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get showRewardsOverlay => _showRewardsOverlay;
  String get levelName => _levelName;
  String get nextLevelName => _nextLevelName;
  String? get levelDescription => _levelDescription;
  String? get actionDescription => _actionDescription;
  String? get levelHint => _levelHint;
  int get currentProgress => _currentProgress;
  int get requiredValue => _requiredValue;
  double get progressPercentage => _progressPercentage;

  void setShowRewardsOverlay(bool show) {
    _showRewardsOverlay = show;
    notifyListeners();
  }

  /// Initialize Pusher listener
  void listenToPusherEvents() {
    DebugLogger.info('🎁 PROVIDER: Setting up Pusher event listener');

    _pusherStreamSubscription = _pusherService.eventStream.listen(
      (event) {
        DebugLogger.info('🎁 PROVIDER: Received Pusher event: ${event.type}');
        _handlePusherEvent(event);
      },
      onError: (error) {
        DebugLogger.info('❌ PROVIDER: Pusher stream error: $error');
      },
    );
  }

  /// Handle events from Pusher
  void _handlePusherEvent(PusherEventData event) {
    try {
      switch (event.type) {
        case 'reward_earned':
          _handleRewardEarned(event);
          break;
        case 'progress_updated':
          _handleProgressUpdated(event);
          break;
        case 'gift_available':
          _handleGiftAvailable(event);
          break;
        case 'level_upgraded':
          _handleLevelUpgraded(event);
          break;
        default:
          DebugLogger.info('⚠️  PROVIDER: Unknown event type: ${event.type}');
      }
    } catch (e) {
      DebugLogger.info('❌ PROVIDER: Error handling Pusher event: $e');
    }
  }

  /// Public method to handle a single Pusher event (used by GlobalEventListener)
  void handlePusherEvent(PusherEventData event) => _handlePusherEvent(event);

  /// Handle reward earned from Pusher
  void _handleRewardEarned(PusherEventData event) {
    DebugLogger.info(
        '🎁 PROVIDER: Processing reward earned - Source: ${event.source}, Amount: ${event.amount}');
    _showRewardsOverlay = true;
    notifyListeners();
  }

  /// Handle progress updated from Pusher
  void _handleProgressUpdated(PusherEventData event) {
    DebugLogger.info(
        '🎁 PROVIDER: Progress updated - Type: ${event.progressType}');
    DebugLogger.info('   Data: ${event.progressData}');
    _showRewardsOverlay = true;
    notifyListeners();
  }

  /// Handle gift available from Pusher
  void _handleGiftAvailable(PusherEventData event) {
    DebugLogger.info('🎁 PROVIDER: Gift available - Type: ${event.giftType}');
    DebugLogger.info('   Details: ${event.giftDetails}');
    _showRewardsOverlay = true;
    notifyListeners();
  }

  /// Handle level upgraded from Pusher
  void _handleLevelUpgraded(PusherEventData event) {
    DebugLogger.info('🎁 PROVIDER: Level upgraded to: ${event.newLevel}');
    DebugLogger.info('   Reward: ${event.reward}');
    _showRewardsOverlay = true;
    notifyListeners();
  }

  void handleRewardNotification(Map<String, dynamic> data) {
    DebugLogger.info('🎁 PROVIDER: Handling reward notification');
    DebugLogger.info('🎁 PROVIDER: Data: $data');

    // Just show the overlay - data will be fetched fresh
    _showRewardsOverlay = true;
    DebugLogger.info('🎁 PROVIDER: Overlay set to: $_showRewardsOverlay');
    notifyListeners();
    DebugLogger.info('🎁 PROVIDER: Listeners notified!');
  }

  Future<void> fetchDashboard(Levels levelsProvider) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch fresh data from /api/levels/user-progress
      await levelsProvider.fetchUserProgress();

      // Extract current level data
      final currentLevel = levelsProvider.currentLevel;
      final nextLevel = levelsProvider.nextLevel;
      final remainingActions = levelsProvider.remainingActions;

      // Set level names
      _levelName = currentLevel?['name'] ?? 'New User';
      _nextLevelName = nextLevel?['name'] ?? 'Level 1';
      _levelDescription = currentLevel?['desc'];
      _progressPercentage = levelsProvider.progressPercentage;

      // Extract current task data from remaining actions
      if (remainingActions.isNotEmpty) {
        final firstAction = remainingActions[0];
        final actionData = firstAction['action'];

        _actionDescription = actionData?['description'];
        _levelHint = firstAction['hint'];

        // Handle current_progress as both int and String
        final currentProgressValue = firstAction['current_progress'];
        if (currentProgressValue is int) {
          _currentProgress = currentProgressValue;
        } else if (currentProgressValue is String) {
          _currentProgress = int.tryParse(currentProgressValue) ?? 0;
        } else {
          _currentProgress = 0;
        }

        _requiredValue =
            int.tryParse(firstAction['required_value']?.toString() ?? '0') ?? 0;
      } else {
        // No tasks remaining
        _actionDescription = null;
        _levelHint = null;
        _currentProgress = 0;
        _requiredValue = 0;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pusherStreamSubscription?.cancel();
    super.dispose();
  }
}
