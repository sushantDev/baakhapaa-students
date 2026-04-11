class SeasonAnalytics {
  final SeasonTotals totals;
  final SeasonInsights insights;

  SeasonAnalytics({
    required this.totals,
    required this.insights,
  });

  factory SeasonAnalytics.fromJson(Map<String, dynamic> json) {
    return SeasonAnalytics(
      totals: SeasonTotals.fromJson(json['totals'] ?? {}),
      insights: SeasonInsights.fromJson(json['insights'] ?? {}),
    );
  }
}

class SeasonTotals {
  final int seasonUnlocked;
  final int episodesUploaded;
  final int comments;
  final String donations;

  SeasonTotals({
    required this.seasonUnlocked,
    required this.episodesUploaded,
    required this.comments,
    required this.donations,
  });

  factory SeasonTotals.fromJson(Map<String, dynamic> json) {
    return SeasonTotals(
      seasonUnlocked:
          int.tryParse(json['season_unlocked']?.toString() ?? '0') ?? 0,
      episodesUploaded:
          int.tryParse(json['episodes_uploaded']?.toString() ?? '0') ?? 0,
      comments: int.tryParse((json['comments'] ??
                  json['comment'] ??
                  json['comments_count'] ??
                  json['comment_count'] ??
                  json['total_comments'] ??
                  '0')
              .toString()) ??
          0,
      donations: (json['donations'] ?? "0").toString(),
    );
  }
}

class SeasonInsights {
  final SeasonInsightItem today;
  final SeasonInsightItem weekly;
  final SeasonInsightItem monthly;

  SeasonInsights({
    required this.today,
    required this.weekly,
    required this.monthly,
  });

  factory SeasonInsights.fromJson(Map<String, dynamic> json) {
    return SeasonInsights(
      today: SeasonInsightItem.fromJson(json['today'] ?? {}),
      weekly: SeasonInsightItem.fromJson(json['weekly'] ?? {}),
      monthly: SeasonInsightItem.fromJson(json['monthly'] ?? {}),
    );
  }
}

class SeasonInsightItem {
  final SeasonInsightData data;
  final SeasonInsightChange change;

  SeasonInsightItem({
    required this.data,
    required this.change,
  });

  factory SeasonInsightItem.fromJson(Map<String, dynamic> json) {
    return SeasonInsightItem(
      data: SeasonInsightData.fromJson(json['data'] ?? {}),
      change: SeasonInsightChange.fromJson(json['change'] ?? {}),
    );
  }
}

class SeasonInsightData {
  final int seasonUnlocked;
  final int episodesUploaded;
  final int comments;
  final int donations;

  SeasonInsightData({
    required this.seasonUnlocked,
    required this.episodesUploaded,
    required this.comments,
    required this.donations,
  });

  factory SeasonInsightData.fromJson(Map<String, dynamic> json) {
    return SeasonInsightData(
      seasonUnlocked:
          int.tryParse(json['season_unlocked']?.toString() ?? '0') ?? 0,
      episodesUploaded:
          int.tryParse(json['episodes_uploaded']?.toString() ?? '0') ?? 0,
      comments: int.tryParse((json['comments'] ??
                  json['comment'] ??
                  json['comments_count'] ??
                  json['comment_count'] ??
                  json['total_comments'] ??
                  '0')
              .toString()) ??
          0,
      donations: int.tryParse(json['donations']?.toString() ?? '0') ?? 0,
    );
  }
}

class SeasonInsightChange {
  final double seasonUnlocked;
  final double episodesUploaded;
  final double comments;
  final double donations;

  SeasonInsightChange({
    required this.seasonUnlocked,
    required this.episodesUploaded,
    required this.comments,
    required this.donations,
  });

  factory SeasonInsightChange.fromJson(Map<String, dynamic> json) {
    return SeasonInsightChange(
      seasonUnlocked:
          double.tryParse(json['season_unlocked']?.toString() ?? '0') ?? 0.0,
      episodesUploaded:
          double.tryParse(json['episodes_uploaded']?.toString() ?? '0') ?? 0.0,
      comments: double.tryParse((json['comments'] ??
                  json['comment'] ??
                  json['comments_count'] ??
                  json['comment_count'] ??
                  json['total_comments'] ??
                  '0')
              .toString()) ??
          0.0,
      donations: double.tryParse(json['donations']?.toString() ?? '0') ?? 0.0,
    );
  }
}
