/// Collaboration models for the content collaboration system
/// Supports both Shorts and Seasons collaboration
///
/// Author: Baakhapaa Development Team
/// Date: February 2026

/// Lightweight collaborator info for displaying in shorts/seasons feed
/// This comes directly from GET /api/shorts or GET /api/seasons responses
class CollaboratorInfo {
  final int id;
  final String username;
  final String? name;
  final String? avatar;
  final String? role;
  final int? contributionPercentage;

  CollaboratorInfo({
    required this.id,
    required this.username,
    this.name,
    this.avatar,
    this.role,
    this.contributionPercentage,
  });

  /// Parse from API response
  /// Flexible parsing to handle various response formats
  factory CollaboratorInfo.fromJson(Map<String, dynamic> json) {
    return CollaboratorInfo(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      name: json['name'],
      avatar: json['avatar'],
      role: json['role'] ?? 'collaborator',
      contributionPercentage: json['contribution_percentage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'avatar': avatar,
      'role': role,
      'contribution_percentage': contributionPercentage,
    };
  }

  @override
  String toString() => '@$username${role != null ? ' ($role)' : ''}';
}

/// Participant in a collaboration invitation
/// Used in the collaboration request/management flow
class CollaborationParticipant {
  final int id;
  final Map<String, dynamic>
      user; // Full user object with id, username, name, image
  final String role; // 'initiator' or 'collaborator'
  final String status; // 'pending', 'accepted', 'declined'
  final String offerType; // 'points', 'gift', 'none'
  final int offerAmount;
  final Map<String, dynamic>? offerGift; // Gift product details
  final String? message;
  final double? timeRemainingHours;
  final DateTime? invitedAt;
  final DateTime? respondedAt;

  CollaborationParticipant({
    required this.id,
    required this.user,
    required this.role,
    required this.status,
    required this.offerType,
    this.offerAmount = 0,
    this.offerGift,
    this.message,
    this.timeRemainingHours,
    this.invitedAt,
    this.respondedAt,
  });

  /// Flexible parsing following app's pattern (try multiple response formats)
  factory CollaborationParticipant.fromJson(Map<String, dynamic> json) {
    return CollaborationParticipant(
      id: json['id'] ?? 0,
      user: json['user'] ?? {},
      role: json['role'] ?? 'collaborator',
      status: json['status'] ?? 'pending',
      offerType: json['offer_type'] ?? 'none',
      offerAmount: json['offer_amount'] ?? 0,
      offerGift: json['offer_gift'],
      message: json['message'],
      timeRemainingHours: json['time_remaining_hours'] != null
          ? (json['time_remaining_hours'] as num).toDouble()
          : null,
      invitedAt: json['invited_at'] != null
          ? DateTime.tryParse(json['invited_at'])
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'])
          : null,
    );
  }

  // Getters for user details
  int get userId => user['id'] ?? 0;
  String get username => user['username'] ?? '';
  String get userName => user['name'] ?? '';
  String? get userImage => user['avatar']; // Backend sends 'avatar' field
  String? get avatar => userImage; // Alias for compatibility

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isInitiator => role == 'initiator';

  // Offer getter for compatibility with screens
  Map<String, dynamic>? get offer {
    if (offerType == 'none') return null;
    return {
      'offer_type': offerType,
      'amount': offerAmount,
      'gift productDetails': offerGift,
    };
  }

  String get offerDescription {
    switch (offerType) {
      case 'points':
        return '$offerAmount points';
      case 'gift':
        return offerGift?['title'] ?? 'Gift';
      case 'none':
      default:
        return 'No offer';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user,
      'role': role,
      'status': status,
      'offer_type': offerType,
      'offer_amount': offerAmount,
      'offer_gift': offerGift,
      'message': message,
      'time_remaining_hours': timeRemainingHours,
      'invited_at': invitedAt?.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}

/// Main collaboration model for invitation/request management
class Collaboration {
  final int id;
  final String? title;
  final String? description;
  final String? contentType; // 'short' or 'season'
  final int? contentId;
  final int? challengeId;
  final Map<String, dynamic> initiator; // User who created the collaboration
  final List<CollaborationParticipant> participants;
  final int maxCollaborators;
  final String
      status; // 'pending', 'active', 'completed', 'cancelled', 'expired'
  final String? escrowStatus; // 'held', 'released', 'refunded'
  final int acceptedCount;
  final int pendingCount;
  final bool isReady;
  final bool isExpired;
  final double timeRemainingHours;
  final DateTime? offerExpiresAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  Collaboration({
    required this.id,
    this.title,
    this.description,
    this.contentType,
    this.contentId,
    this.challengeId,
    required this.initiator,
    required this.participants,
    this.maxCollaborators = 5,
    required this.status,
    this.escrowStatus,
    this.acceptedCount = 0,
    this.pendingCount = 0,
    this.isReady = false,
    this.isExpired = false,
    this.timeRemainingHours = 0,
    this.offerExpiresAt,
    this.acceptedAt,
    this.completedAt,
    required this.createdAt,
  });

  /// Flexible parsing following app's pattern
  /// Tries multiple response formats: response['data'], response['collaboration'], etc.
  factory Collaboration.fromJson(Map<String, dynamic> json) {
    // Try to extract data from various response formats
    Map<String, dynamic> data = json;
    if (json.containsKey('data')) {
      if (json['data'] is Map) {
        data = json['data'];
      } else if (json['data'] is List && (json['data'] as List).isNotEmpty) {
        data = json['data'][0];
      }
    } else if (json.containsKey('collaboration')) {
      data = json['collaboration'];
    }

    // Parse participants list
    List<CollaborationParticipant> participantsList = [];
    if (data['participants'] != null && data['participants'] is List) {
      participantsList = (data['participants'] as List)
          .map((p) => CollaborationParticipant.fromJson(p))
          .toList();
    }

    return Collaboration(
      id: data['id'] ?? 0,
      title: data['title'],
      description: data['description'],
      contentType: data['content_type'],
      contentId: data['content_id'],
      challengeId: data['challenge_id'],
      initiator: data['initiator'] ?? {},
      participants: participantsList,
      maxCollaborators: data['max_collaborators'] ?? 5,
      status: data['status'] ?? 'pending',
      escrowStatus: data['escrow_status'],
      acceptedCount: data['accepted_count'] ?? 0,
      pendingCount: data['pending_count'] ?? 0,
      isReady: data['is_ready'] ?? false,
      isExpired: data['is_expired'] ?? false,
      timeRemainingHours: data['time_remaining_hours'] != null
          ? (data['time_remaining_hours'] as num).toDouble()
          : 0.0,
      offerExpiresAt: data['offer_expires_at'] != null
          ? DateTime.tryParse(data['offer_expires_at'])
          : null,
      acceptedAt: data['accepted_at'] != null
          ? DateTime.tryParse(data['accepted_at'])
          : null,
      completedAt: data['completed_at'] != null
          ? DateTime.tryParse(data['completed_at'])
          : null,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
    );
  }

  // Getters for initiator details
  int get initiatorId => initiator['id'] ?? 0;
  String get initiatorUsername => initiator['username'] ?? '';
  String get initiatorName => initiator['name'] ?? '';
  String? get initiatorImage =>
      initiator['avatar']; // Backend sends 'avatar' field

  // Status checks
  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  // Content type checks
  bool get isShortCollaboration => contentType == 'short';
  bool get isSeasonCollaboration => contentType == 'season';
  bool get isForChallenge => challengeId != null;

  // Alias for compatibility with screens
  String? get collaborationType => contentType;
  DateTime? get expiresAt => offerExpiresAt;

  // Get current user's participation (requires Auth context)
  CollaborationParticipant? myParticipation;

  // Get accepted participants only
  List<CollaborationParticipant> get acceptedParticipants =>
      participants.where((p) => p.isAccepted).toList();

  // Get pending participants only
  List<CollaborationParticipant> get pendingParticipants =>
      participants.where((p) => p.isPending).toList();

  // Get list of all participant usernames
  String get participantUsernames {
    return participants.map((p) => '@${p.username}').join(', ');
  }

  Collaboration copyWith({
    int? id,
    String? title,
    String? description,
    String? contentType,
    int? contentId,
    int? challengeId,
    Map<String, dynamic>? initiator,
    List<CollaborationParticipant>? participants,
    int? maxCollaborators,
    String? status,
    String? escrowStatus,
    int? acceptedCount,
    int? pendingCount,
    bool? isReady,
    bool? isExpired,
    double? timeRemainingHours,
    DateTime? offerExpiresAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return Collaboration(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      contentType: contentType ?? this.contentType,
      contentId: contentId ?? this.contentId,
      challengeId: challengeId ?? this.challengeId,
      initiator: initiator ?? this.initiator,
      participants: participants ?? this.participants,
      maxCollaborators: maxCollaborators ?? this.maxCollaborators,
      status: status ?? this.status,
      escrowStatus: escrowStatus ?? this.escrowStatus,
      acceptedCount: acceptedCount ?? this.acceptedCount,
      pendingCount: pendingCount ?? this.pendingCount,
      isReady: isReady ?? this.isReady,
      isExpired: isExpired ?? this.isExpired,
      timeRemainingHours: timeRemainingHours ?? this.timeRemainingHours,
      offerExpiresAt: offerExpiresAt ?? this.offerExpiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content_type': contentType,
      'content_id': contentId,
      'challenge_id': challengeId,
      'initiator': initiator,
      'participants': participants.map((p) => p.toJson()).toList(),
      'max_collaborators': maxCollaborators,
      'status': status,
      'escrow_status': escrowStatus,
      'accepted_count': acceptedCount,
      'pending_count': pendingCount,
      'is_ready': isReady,
      'is_expired': isExpired,
      'time_remaining_hours': timeRemainingHours,
      'offer_expires_at': offerExpiresAt?.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'Collaboration #$id: $title (${participants.length} participants, $status)';
}
