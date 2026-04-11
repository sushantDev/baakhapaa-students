class DashboardResponse {
  final int userId;
  final String username;
  final int currentLevel;
  final String levelName;
  final int nextLevelId;
  final String nextLevelName;
  final double progressPercentage;
  final List<String> completedActions;
  final List<String> pendingActions;
  final int availableCoins;
  final int earnedCoins;
  final int usedCoins;
  final int lifetimeEarnings;
  final String lastUpdated;

  DashboardResponse({
    required this.userId,
    required this.username,
    required this.currentLevel,
    required this.levelName,
    required this.nextLevelId,
    required this.nextLevelName,
    required this.progressPercentage,
    required this.completedActions,
    required this.pendingActions,
    required this.availableCoins,
    required this.earnedCoins,
    required this.usedCoins,
    required this.lifetimeEarnings,
    required this.lastUpdated,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final level = data['level'] ?? {};
    final current = level['current'] ?? {};
    final next = level['next'] ?? {};
    final rewards = data['rewards'] ?? {};

    return DashboardResponse(
      userId: data['user_id'] ?? 0,
      username: data['username'] ?? '',
      currentLevel: current['id'] ?? 1,
      levelName: current['name'] ?? 'Level 1',
      nextLevelId: next['id'] ?? 2,
      nextLevelName: next['name'] ?? 'Level 2',
      progressPercentage: (level['progress_percentage'] ?? 0).toDouble(),
      completedActions: List<String>.from(level['completed_actions'] ?? []),
      pendingActions: List<String>.from(level['pending_actions'] ?? []),
      availableCoins: rewards['available_coins'] ?? 0,
      earnedCoins: rewards['earned_coins'] ?? 0,
      usedCoins: rewards['total_used_coins'] ?? 0,
      lifetimeEarnings: rewards['lifetime_earnings'] ?? 0,
      lastUpdated: data['last_updated'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'level': {
        'current': {
          'id': currentLevel,
          'name': levelName,
        },
        'next': {
          'id': nextLevelId,
          'name': nextLevelName,
        },
        'progress_percentage': progressPercentage,
        'completed_actions': completedActions,
        'pending_actions': pendingActions,
      },
      'rewards': {
        'available_coins': availableCoins,
        'earned_coins': earnedCoins,
        'total_used_coins': usedCoins,
        'lifetime_earnings': lifetimeEarnings,
      },
      'last_updated': lastUpdated,
    };
  }

  DashboardResponse copyWith({
    int? userId,
    String? username,
    int? currentLevel,
    String? levelName,
    int? nextLevelId,
    String? nextLevelName,
    double? progressPercentage,
    List<String>? completedActions,
    List<String>? pendingActions,
    int? availableCoins,
    int? earnedCoins,
    int? usedCoins,
    int? lifetimeEarnings,
    String? lastUpdated,
  }) {
    return DashboardResponse(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      currentLevel: currentLevel ?? this.currentLevel,
      levelName: levelName ?? this.levelName,
      nextLevelId: nextLevelId ?? this.nextLevelId,
      nextLevelName: nextLevelName ?? this.nextLevelName,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      completedActions: completedActions ?? this.completedActions,
      pendingActions: pendingActions ?? this.pendingActions,
      availableCoins: availableCoins ?? this.availableCoins,
      earnedCoins: earnedCoins ?? this.earnedCoins,
      usedCoins: usedCoins ?? this.usedCoins,
      lifetimeEarnings: lifetimeEarnings ?? this.lifetimeEarnings,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
