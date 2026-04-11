import '../providers/auth.dart';
import '../providers/levels.dart';
import '../utils/debug_logger.dart';

class LevelManager {
  static LevelManager? _instance;
  static LevelManager get instance => _instance ??= LevelManager._();

  LevelManager._();

  Auth? _authProvider;
  Levels? _levelsProvider;

  void initialize(Auth authProvider, Levels levelsProvider) {
    _authProvider = authProvider;
    _levelsProvider = levelsProvider;

    // Set up the callback in auth provider
    _authProvider?.setLevelUpCallback(_handleLevelUpCheck);
  }

  Future<void> _handleLevelUpCheck(String token) async {
    try {
      if (_levelsProvider != null) {
        final leveledUp = await _levelsProvider!.checkLevelUpAfterPointsGain();

        // You can add additional logic here if needed
        if (leveledUp) {
          DebugLogger.success('🎉 Level up handled successfully!');
        }
      }
    } catch (error) {
      DebugLogger.error('Error handling level up check: $error');
    }
  }

  // Helper method to check if there's a pending level up notification
  bool get hasLevelUpNotification {
    return _levelsProvider?.hasLevelUpNotification ?? false;
  }

  // Helper method to get level up data
  Map<String, dynamic>? get levelUpData {
    return _levelsProvider?.lastLevelUpData;
  }

  // Helper method to clear level up notification
  void clearLevelUpNotification() {
    _levelsProvider?.clearLevelUpData();
  }
}
