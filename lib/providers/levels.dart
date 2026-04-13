import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/url.dart';
import '../utils/debug_logger.dart';

class Levels with ChangeNotifier {
  final String authToken;

  Map<String, dynamic> _userProgress = {};
  List<dynamic> _allLevels = [];
  Map<String, dynamic> _selectedLevel = {};

  // Add level up notification data
  Map<String, dynamic>? _lastLevelUpData;

  Levels(this.authToken);

  // Copy constructor to preserve state when token changes
  Levels.fromPrevious(Levels previous, String newToken)
      : authToken = newToken,
        _userProgress = {...previous._userProgress},
        _allLevels = [...previous._allLevels],
        _selectedLevel = {...previous._selectedLevel},
        _lastLevelUpData = previous._lastLevelUpData != null
            ? {...previous._lastLevelUpData!}
            : null;

  Map<String, dynamic> get userProgress => {..._userProgress};
  List<dynamic> get allLevels => [..._allLevels];
  Map<String, dynamic> get selectedLevel => {..._selectedLevel};

  // Level up notification getters
  Map<String, dynamic>? get lastLevelUpData => _lastLevelUpData;
  bool get hasLevelUpNotification =>
      _lastLevelUpData != null && _lastLevelUpData!['leveled_up'] == true;

  // Current level info
  Map<String, dynamic>? get currentLevel => _userProgress['current_level'];
  Map<String, dynamic>? get nextLevel => _userProgress['next_level'];
  double get progressPercentage =>
      _userProgress['progress_percentage']?.toDouble() ?? 0.0;
  List<dynamic> get completedActions =>
      _userProgress['completed_actions'] ?? [];
  List<dynamic> get remainingActions =>
      _userProgress['remaining_actions'] ?? [];
  bool get isMaxLevel => _userProgress['is_max_level'] ?? false;

  // Clear level up notification after it's been shown
  void clearLevelUpData() {
    _lastLevelUpData = null;
    notifyListeners();
  }

  // Auto-check level up (called by Auth provider)
  Future<bool> checkLevelUpAfterPointsGain() async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/levels/check-level-up')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success']) {
        final data = responseData['data'];

        // If user leveled up, refresh progress and store level up data
        if (data['leveled_up'] == true) {
          await fetchUserProgress();
          _lastLevelUpData = data;
          notifyListeners();

          DebugLogger.auth('🎉 User leveled up! ');
          return true; // Return true if leveled up
        } else {
          DebugLogger.info('📈 Progress tracked: ');
          return false; // Return false if no level up
        }
      } else {
        DebugLogger.error('Error checking level up: ');
        return false;
      }
    } catch (error) {
      DebugLogger.error('Error auto-checking level up: $error');
      return false; // Don't throw to avoid breaking coin transaction flow
    }
  }

  // Fetch user's level progress
  Future<void> fetchUserProgress() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/levels/user-progress')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success']) {
        _userProgress = responseData['data'];
        notifyListeners();
      } else {
        throw responseData['message'] ?? 'Failed to fetch user progress';
      }
    } catch (error) {
      throw error;
    }
  }

  // Manual check if user can level up (for UI button)
  Future<Map<String, dynamic>> checkLevelUp() async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/levels/check-level-up')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success']) {
        final data = responseData['data'];

        // If user leveled up, refresh progress
        if (data['leveled_up'] == true) {
          await fetchUserProgress();
        }

        return data;
      } else {
        throw responseData['message'] ?? 'Failed to check level up';
      }
    } catch (error) {
      throw error;
    }
  }

  // Upgrade level using subscription benefit
  Future<void> upgradeLevelWithBenefit({
    required int userBenefitUsageId,
    int? nextLevelId, // Required for V2 API
  }) async {
    try {
      // 1. Update benefit usage in backend (V2 API)
      final body = {
        'use_benefit': true,
        if (nextLevelId != null) 'level_id': nextLevelId,
      };

      DebugLogger.info(
          '🌐 API Request: PUT /subscription/user-benefit-usage/$userBenefitUsageId');
      DebugLogger.info('📦 Body: ${json.encode(body)}');

      final responseUsage = await http.put(
        Uri.parse(Url.baakhapaaApi(
            '/subscription/user-benefit-usage/$userBenefitUsageId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode(body),
      );

      DebugLogger.info('🌐 API Response Status: ${responseUsage.statusCode}');
      DebugLogger.info('📦 Response Body: ${responseUsage.body}');

      if (responseUsage.statusCode != 200) {
        throw 'Failed to update benefit usage: ${responseUsage.statusCode} - ${responseUsage.body}';
      }

      // 2. Trigger level upgrade check (REMOVED: V2 API handles this automatically)
      // await checkLevelUp();

      // 3. Refresh user progress to be sure
      await fetchUserProgress();
      notifyListeners();
    } catch (error) {
      DebugLogger.error('Error upgrading level with benefit: $error');
      rethrow;
    }
  }

  // Fetch all levels
  Future<void> fetchAllLevels() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/levels/all')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success']) {
        _allLevels = responseData['data']['items'];
        notifyListeners();
      } else {
        throw responseData['message'] ?? 'Failed to fetch all levels';
      }
    } catch (error) {
      throw error;
    }
  }

  // Fetch specific level by ID
  Future<void> fetchLevelById(int levelId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/levels/$levelId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success']) {
        _selectedLevel = responseData['data']['item'];
        notifyListeners();
      } else {
        throw responseData['message'] ?? 'Failed to fetch level';
      }
    } catch (error) {
      throw error;
    }
  }

  // Helper method to get readable requirement text
  String getReadableRequirement(Map<String, dynamic> action) {
    final title = action['title'] ?? '';
    final type = action['type'] ?? '';
    final value = action['pivot']?['value'] ?? '';

    if (type == 'number') {
      return '$title: ${value.replaceAll('"', '')}';
    } else if (type == 'selection' && title == 'Badge Required') {
      return 'Earn achievement: ${value.replaceAll('"', '')}';
    }

    return action['readable_requirement'] ?? '$title: $value';
  }

  // Generate hint for the next level based on remaining actions
  String? generateLevelHint() {
    if (_userProgress.isEmpty || remainingActions.isEmpty) {
      return null;
    }

    final nextLevelName = nextLevel?['name'] ?? 'the next level';

    // Collect all remaining hints (not just first) for richer context.
    final hints = <String>[];

    for (final item in remainingActions) {
      final action = (item['action'] as Map?) ?? {};
      final actionKey = action['action_key']?.toString() ?? '';
      final type = action['type']?.toString() ?? 'number';
      final options =
          (action['options']?.toString() ?? '').replaceAll('"', '').trim();
      final requiredValue = item['required_value'];
      final currentProgress = (item['current_progress'] as num?)?.toInt() ?? 0;
      final requiredNum = int.tryParse(requiredValue?.toString() ?? '0') ?? 0;
      final remaining = (requiredNum - currentProgress).clamp(0, requiredNum);

      if (type == 'selection' || type == 'checkbox') {
        // For selection actions the required_value is the target item's name.
        final targetName = requiredValue?.toString() ?? '';
        switch (options) {
          case 'season':
            hints.add(targetName.isNotEmpty
                ? 'Unlock the season "$targetName" to level up! 🎬'
                : 'Unlock a season to level up! 🎬');
            break;
          case 'episode':
            hints.add(targetName.isNotEmpty
                ? 'Complete the episode "$targetName" to progress! 📺'
                : 'Complete an episode to progress! 📺');
            break;
          case 'shorts':
            hints.add(targetName.isNotEmpty
                ? 'Watch the short "$targetName" to advance! ▶️'
                : 'Watch a specific short to advance! ▶️');
            break;
          case 'badge':
            hints.add(targetName.isNotEmpty
                ? 'Earn the "$targetName" badge to level up! 🏅'
                : 'Earn a badge to level up! 🏅');
            break;
          default:
            if (targetName.isNotEmpty) {
              hints.add('Complete "$targetName" to advance! 💪');
            }
        }
        continue;
      }

      // Number-type actions — match by action_key first, then title keywords.
      switch (actionKey) {
        case 'episodes_watched':
          hints.add(remaining == 1
              ? 'Watch 1 more episode to reach $nextLevelName! 📺'
              : 'Watch $remaining more episodes to reach $nextLevelName! 📺');
          break;
        case 'season_unlocked':
        case 'unlock_a_season':
          hints.add(remaining == 1
              ? 'Unlock 1 more season to reach $nextLevelName! 🎬'
              : 'Unlock $remaining more seasons to reach $nextLevelName! 🎬');
          break;
        case 'shorts_watched':
          hints.add(remaining == 1
              ? 'Watch 1 more short to level up! ▶️'
              : 'Watch $remaining more shorts to level up! ▶️');
          break;
        case 'shorts_uploaded':
          hints.add(remaining == 1
              ? 'Upload 1 more short to advance! 🎥'
              : 'Upload $remaining more shorts to advance! 🎥');
          break;
        case 'episodes_uploaded':
          hints.add(remaining == 1
              ? 'Upload 1 more episode to reach $nextLevelName! 🎬'
              : 'Upload $remaining more episodes to reach $nextLevelName! 🎬');
          break;
        case 'earned_coins':
          hints.add('Earn $remaining more coins to advance! 🪙');
          break;
        case 'used_coins':
        case 'available_coins':
          hints.add('Spend $remaining more coins to reach $nextLevelName! 🛍️');
          break;
        case 'points_donated':
          hints.add('Donate $remaining more coins to level up! 🎁');
          break;
        case 'achievements_claimed':
        case 'badge_required':
          hints.add(remaining == 1
              ? 'Claim 1 more achievement to reach $nextLevelName! 🏆'
              : 'Claim $remaining more achievements to reach $nextLevelName! 🏆');
          break;
        case 'challenge_participation_number':
          hints.add(remaining == 1
              ? 'Join 1 more challenge to level up! 🎯'
              : 'Join $remaining more challenges to level up! 🎯');
          break;
        case 'total_referals_count':
        case 'refer_others':
          hints.add(remaining == 1
              ? 'Refer 1 more friend to reach $nextLevelName! 👥'
              : 'Refer $remaining more friends to reach $nextLevelName! 👥');
          break;
        case 'total_product_purchased':
          hints.add(remaining == 1
              ? 'Purchase 1 more product from the shop! 🛒'
              : 'Purchase $remaining more products from the shop! 🛒');
          break;
        default:
          // Fallback to title keyword matching.
          final title = (action['title'] ?? '').toString().toLowerCase();
          if (title.contains('challenge')) {
            hints.add(
                'Complete $remaining more ${remaining == 1 ? "challenge" : "challenges"} to reach $nextLevelName! 🎯');
          } else if (title.contains('episode')) {
            hints.add(
                'Watch $remaining more ${remaining == 1 ? "episode" : "episodes"} to level up! 📺');
          } else if (title.contains('short')) {
            hints.add(
                'Watch $remaining more ${remaining == 1 ? "short" : "shorts"} to advance! ▶️');
          } else if (title.contains('coin') || title.contains('point')) {
            hints.add('Earn $remaining more coins to reach $nextLevelName! 🪙');
          } else if (title.contains('achievement') || title.contains('badge')) {
            hints.add(
                'Claim $remaining more ${remaining == 1 ? "achievement" : "achievements"}! 🏆');
          } else if (title.contains('refer')) {
            hints.add(
                'Refer $remaining more ${remaining == 1 ? "friend" : "friends"} to advance! 👥');
          } else {
            final actionTitle = action['title']?.toString() ?? actionKey;
            hints.add(
                '$actionTitle: $currentProgress/$requiredNum — $remaining more to go! 💪');
          }
      }

      // Limit to 2 hints to stay concise.
      if (hints.length >= 2) break;
    }

    if (hints.isEmpty) return null;
    return hints.join('\n');
  }

  // Get progress data for assistive touch
  Map<String, dynamic>? getLevelProgressForAssistiveTouch() {
    if (_userProgress.isEmpty) return null;

    return {
      'current_level': currentLevel,
      'next_level': nextLevel,
      'progress_percentage': progressPercentage,
      'completed_actions': completedActions,
      'remaining_actions': remainingActions,
      'is_max_level': isMaxLevel,
      'hint': generateLevelHint(),
    };
  }
}
