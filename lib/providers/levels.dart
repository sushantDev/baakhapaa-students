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

    // Get the first incomplete action
    final firstRemaining = remainingActions.first;
    final action = firstRemaining['action'];
    final currentProgress = firstRemaining['current_progress'] ?? 0;
    final requiredValue =
        int.tryParse(firstRemaining['required_value']?.toString() ?? '0') ?? 0;
    final remaining = requiredValue - currentProgress;

    final actionTitle = action['title'] ?? '';

    // Generate contextual hints based on action type
    if (actionTitle.toLowerCase().contains('challenge')) {
      return 'Complete $remaining more ${remaining == 1 ? "challenge" : "challenges"} to reach ${nextLevel?["name"] ?? "the next level"}! 🎯';
    } else if (actionTitle.toLowerCase().contains('episode')) {
      return 'Watch $remaining more ${remaining == 1 ? "episode" : "episodes"} to level up! 📺';
    } else if (actionTitle.toLowerCase().contains('daily')) {
      return 'Claim your daily rewards for $remaining more ${remaining == 1 ? "day" : "days"} to advance! 🎁';
    } else if (actionTitle.toLowerCase().contains('streak')) {
      return 'Maintain your streak for $remaining more ${remaining == 1 ? "day" : "days"}! 🔥';
    } else if (actionTitle.toLowerCase().contains('quiz')) {
      return 'Complete $remaining more ${remaining == 1 ? "quiz" : "quizzes"} correctly! 📝';
    } else {
      return '$actionTitle: $currentProgress/$requiredValue - ${remaining} more to go! 💪';
    }
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
