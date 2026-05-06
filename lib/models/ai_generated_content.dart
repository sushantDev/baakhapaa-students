class AiGeneratedContent {
  final String title;
  final String description;
  final List<String> genres;
  final List<String> maturities;
  final int coins;
  final int pointsUsers;
  final int lives;
  final int duration;
  final DateTime publishDate;
  final List<Map<String, dynamic>> questions;

  const AiGeneratedContent({
    required this.title,
    required this.description,
    required this.genres,
    this.maturities = const [],
    required this.coins,
    required this.pointsUsers,
    required this.lives,
    required this.duration,
    required this.publishDate,
    required this.questions,
  });

  factory AiGeneratedContent.fromJson(Map<String, dynamic> json) {
    return AiGeneratedContent(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      genres: (json['genres'] as List?)?.cast<String>() ?? [],
      maturities: (json['maturities'] as List?)?.cast<String>() ?? [],
      coins: (json['coins'] as num?)?.toInt() ?? 1,
      pointsUsers: (json['points_users'] as num?)?.toInt() ?? 100,
      lives: (json['lives'] as num?)?.toInt() ?? 3,
      duration: (json['duration'] as num?)?.toInt() ?? 30,
      publishDate: json['publish_date'] != null
          ? DateTime.tryParse(json['publish_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      questions:
          (json['questions'] as List?)
              ?.map((q) => Map<String, dynamic>.from(q as Map))
              .toList() ??
          [],
    );
  }
}
