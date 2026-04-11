class PusherConfig {
  // Pusher credentials - Replace with your actual values
  static const String appKey = '09f62fb26d288c955778';
  static const String cluster = 'ap2';
  static const String authEndpoint =
      'https://school.baakhapaa.com/broadcasting/auth';

  // API endpoints
  static const String apiBaseUrl = 'https://school.baakhapaa.com/api';
  static const String dashboardEndpoint = '/user/progress/dashboard';
  static const String pointsBreakdownEndpoint =
      '/user/progress/points-breakdown';
  static const String levelRequirementsEndpoint =
      '/user/progress/level-requirements';
  static const String checkLevelEndpoint = '/user/progress/check-level';

  // Event names
  static const String levelUpgradedEvent = 'level.upgraded';
  static const String rewardEarnedEvent = 'reward.earned';
  static const String progressUpdatedEvent = 'progress.updated';
  static const String giftAvailableEvent = 'gift.available';

  // Channel naming
  static String getUserChannel(int userId) => 'private-user.$userId';

  // Cache settings
  static const Duration cacheDuration = Duration(minutes: 5);
  static const String dashboardCacheKey = 'rewards_dashboard_cache';
  static const String dashboardCacheTimeKey = 'rewards_dashboard_cache_time';
}
