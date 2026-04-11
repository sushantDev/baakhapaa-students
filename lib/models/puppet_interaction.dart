class PuppetInteraction {
  final int id;
  final String screenName;
  final String? title;
  final String message;
  final String? actionText;
  final String? elementSelector;
  final int priority;
  final bool isActive;
  final String? imageUrl;
  final String? videoUrl;
  final String? audioUrl;
  final String triggerType;
  final String? goToPage; // Added goToPage field
  final String? actionType; // Added actionType field
  final int? actionId; // Added actionId field
  final int? itemId; // Added itemId field for specific item targeting
  final String? itemType; // Added itemType field for item type specification
  final Map<String, dynamic>? actionData;
  final dynamic createdAt;
  final dynamic updatedAt;

  // Level progress data
  final Map<String, dynamic>? levelProgress; // User's current level progress
  final String? levelHint; // Auto-generated hint based on level requirements

  PuppetInteraction({
    required this.id,
    required this.screenName,
    this.title,
    required this.message,
    this.actionText,
    this.elementSelector,
    required this.priority,
    required this.isActive,
    this.imageUrl,
    this.videoUrl,
    this.audioUrl,
    required this.triggerType,
    this.goToPage, // Added goToPage parameter
    this.actionType, // Added actionType parameter
    this.actionId, // Added actionId parameter
    this.itemId, // Added itemId parameter
    this.itemType, // Added itemType parameter
    this.actionData,
    this.createdAt,
    this.updatedAt,
    this.levelProgress, // Level progress data
    this.levelHint, // Auto-generated hint
  });

  factory PuppetInteraction.fromJson(Map<String, dynamic> json) {
    return PuppetInteraction(
      id: json['id'] ?? 0,
      screenName: json['current_page'] ?? json['screen_name'] ?? '',
      title: json['title'],
      message: json['puppet_response'] ?? json['message'] ?? '',
      actionText: json['action_text'] ?? 'Got it!',
      elementSelector: json['target_element'] ?? json['element_selector'],
      priority: json['priority'] ?? 0,
      isActive:
          json['is_active'] ?? true, // Default to true if API doesn't specify
      imageUrl: json['image_url'],
      videoUrl: json['video_url'],
      audioUrl: json['audio_url'],
      triggerType:
          json['interaction_type'] ?? json['trigger_type'] ?? 'automatic',
      goToPage: json['go_to_page'], // Added goToPage parsing
      actionType: json['action_type'], // Added actionType parsing
      actionId: json['action_id'], // Added actionId parsing
      itemId: json['item_id'], // Added itemId parsing
      itemType: json['item_type'], // Added itemType parsing
      actionData: json['action_data'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      levelProgress: json['level_progress'], // Parse level progress
      levelHint: json['level_hint'], // Parse level hint
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'screen_name': screenName,
      'title': title,
      'message': message,
      'action_text': actionText,
      'element_selector': elementSelector,
      'level_progress': levelProgress,
      'level_hint': levelHint,
      'priority': priority,
      'is_active': isActive,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'audio_url': audioUrl,
      'trigger_type': triggerType,
      'go_to_page': goToPage, // Added goToPage to JSON
      'action_type': actionType, // Added actionType to JSON
      'action_id': actionId, // Added actionId to JSON
      'item_id': itemId, // Added itemId to JSON
      'item_type': itemType, // Added itemType to JSON
      'action_data': actionData,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  DateTime? get createdAtDateTime {
    if (createdAt is DateTime) {
      return createdAt as DateTime;
    } else if (createdAt is String) {
      try {
        return DateTime.parse(createdAt);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  DateTime? get updatedAtDateTime {
    if (updatedAt is DateTime) {
      return updatedAt as DateTime;
    } else if (updatedAt is String) {
      try {
        return DateTime.parse(updatedAt);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

class PuppetInteractionProgress {
  final int id;
  final int puppetInteractionId;
  final int? userId;
  final String sessionId;
  final bool isCompleted;
  final bool isSkipped;
  final bool isDismissed;
  final int viewCount;
  final int? timeSpentSeconds;
  final dynamic lastViewedAt;
  final dynamic completedAt;

  PuppetInteractionProgress({
    required this.id,
    required this.puppetInteractionId,
    this.userId,
    required this.sessionId,
    required this.isCompleted,
    required this.isSkipped,
    required this.isDismissed,
    required this.viewCount,
    this.timeSpentSeconds,
    this.lastViewedAt,
    this.completedAt,
  });

  factory PuppetInteractionProgress.fromJson(Map<String, dynamic> json) {
    return PuppetInteractionProgress(
      id: json['id'] ?? 0,
      puppetInteractionId: json['puppet_interaction_id'] ?? 0,
      userId: json['user_id'],
      sessionId: json['session_id'] ?? '',
      isCompleted: json['is_completed'] ?? false,
      isSkipped: json['is_skipped'] ?? false,
      isDismissed: json['is_dismissed'] ?? false,
      viewCount: json['view_count'] ?? 0,
      timeSpentSeconds: json['time_spent_seconds'],
      lastViewedAt: json['last_viewed_at'],
      completedAt: json['completed_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'puppet_interaction_id': puppetInteractionId,
      'user_id': userId,
      'session_id': sessionId,
      'is_completed': isCompleted,
      'is_skipped': isSkipped,
      'is_dismissed': isDismissed,
      'view_count': viewCount,
      'time_spent_seconds': timeSpentSeconds,
      'last_viewed_at': lastViewedAt,
      'completed_at': completedAt,
    };
  }
}
