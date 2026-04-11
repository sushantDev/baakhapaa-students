class RatingModel {
  final int id;
  final int userId;
  final int stars;
  final String description; // Keep as String, but handle null in fromJson
  final int ratingId;
  final String ratingType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel user;

  RatingModel({
    required this.id,
    required this.userId,
    required this.stars,
    required this.description,
    required this.ratingId,
    required this.ratingType,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id'],
      userId: json['user_id'],
      stars: json['stars'],
      description: json['description'] ?? '', // Handle null here
      ratingId: json['rating_id'],
      ratingType: json['rating_type'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      user: UserModel.fromJson(json['user']),
    );
  }
}

class UserModel {
  final int id;
  final String name;
  final String email;
  final String username;
  final String? image;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    this.image,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Extract image URL from images array
    String? imageUrl;
    if (json['images'] != null && (json['images'] as List).isNotEmpty) {
      imageUrl = json['images'][0]['url'] ?? json['images'][0]['thumbnail'];
    }

    return UserModel(
      id: json['id'],
      name: json['name'] ?? json['username'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      image: imageUrl,
    );
  }
}

class RatingStats {
  final int totalRatings;
  final double averageRating;

  RatingStats({
    required this.totalRatings,
    required this.averageRating,
  });

  factory RatingStats.fromJson(Map<String, dynamic> json) {
    return RatingStats(
      totalRatings: json['total_ratings'],
      averageRating: json['average_rating'].toDouble(),
    );
  }
}

class RatingResponse {
  final bool success;
  final List<RatingModel> ratings;
  final RatingStats stats;
  final String itemType;
  final Map<String, dynamic> item;

  RatingResponse({
    required this.success,
    required this.ratings,
    required this.stats,
    required this.itemType,
    required this.item,
  });

  factory RatingResponse.fromJson(Map<String, dynamic> json) {
    // Handle multiple possible API response formats
    List<dynamic> ratingsJson = [];

    // Try format 1: json['data']['data'] (nested structure)
    if (json['data'] is Map && json['data']['data'] is List) {
      ratingsJson = json['data']['data'] as List;
    }
    // Try format 2: json['data'] as direct list
    else if (json['data'] is List) {
      ratingsJson = json['data'] as List;
    }
    // Try format 3: json['ratings']
    else if (json['ratings'] is List) {
      ratingsJson = json['ratings'] as List;
    }

    List<RatingModel> ratingsList = [];
    if (ratingsJson.isNotEmpty) {
      ratingsList = ratingsJson
          .where((r) => r is Map<String, dynamic>)
          .map((r) => RatingModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    // Handle stats - also support multiple formats
    RatingStats stats;
    if (json['stats'] != null && json['stats'] is Map) {
      stats = RatingStats.fromJson(json['stats']);
    } else {
      // Fallback stats if not provided
      stats = RatingStats(
        totalRatings: ratingsList.length,
        averageRating: ratingsList.isEmpty
            ? 0.0
            : ratingsList.map((r) => r.stars).reduce((a, b) => a + b) /
                ratingsList.length,
      );
    }

    return RatingResponse(
      success: json['success'] ?? true,
      ratings: ratingsList,
      stats: stats,
      itemType: json['item_type'] ?? 'product',
      item: json['item'] ?? {},
    );
  }
}

class RatingRequest {
  final int stars;
  final String description;

  RatingRequest({
    required this.stars,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'stars': stars.toString(),
      'description':
          description.isEmpty ? ' ' : description, // Send space if empty
    };
  }
}
