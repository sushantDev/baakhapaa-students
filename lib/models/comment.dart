class Comment {
  final int id;
  final int? shortsId;
  final int? userId;
  final String username;
  final String? userImage;
  final String body;
  final dynamic createdAt;
  final int? parentCommentId;
  final List<Comment> replies;

  Comment({
    required this.id,
    this.shortsId,
    this.userId,
    required this.username,
    this.userImage,
    required this.body,
    required this.createdAt,
    this.parentCommentId,
    this.replies = const [],
  });

  DateTime get createdAtDateTime {
    if (createdAt is DateTime) {
      return createdAt as DateTime;
    } else if (createdAt is String) {
      try {
        return DateTime.parse(createdAt);
      } catch (e) {
        // Fallback to current time if parsing fails
        return DateTime.now();
      }
    } else {
      // Default fallback
      return DateTime.now();
    }
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    List<Comment> replies = [];
    if (json['replies'] != null && json['replies'] is List) {
      replies = (json['replies'] as List)
          .map((reply) => Comment.fromJson(reply))
          .toList();
    }

    // Extract username and user image from nested user object
    String username = 'Anonymous';
    String? userImage;

    if (json['user'] != null && json['user'] is Map) {
      username = json['user']['username'] ?? 'Anonymous';

      // Extract image from the user's images array if available
      if (json['user']['images'] != null &&
          json['user']['images'] is List &&
          (json['user']['images'] as List).isNotEmpty) {
        userImage = json['user']['images'][0]['url'];
      }
    }

    // For fields that might be missing, provide default values
    return Comment(
      id: json['id'] ?? 0, // Default to 0 if missing
      shortsId: json['shorts_id'],
      userId: json['user_id'],
      username: username,
      userImage: userImage,
      body: json['body'] ?? '', // Default to empty string if missing
      createdAt: json['created_at'] ??
          DateTime.now().toIso8601String(), // Default to now if missing
      parentCommentId: json['parent_comment_id'],
      replies: replies,
    );
  }
}
