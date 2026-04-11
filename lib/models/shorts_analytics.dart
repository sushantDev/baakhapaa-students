class ShortsAnalytics {
  final ShortsTotals totals;
  final ShortsInsights insights;

  ShortsAnalytics({
    required this.totals,
    required this.insights,
  });

  factory ShortsAnalytics.fromJson(Map<String, dynamic> json) {
    return ShortsAnalytics(
      totals: ShortsTotals.fromJson(json['totals'] ?? {}),
      insights: ShortsInsights.fromJson(json['insights'] ?? {}),
    );
  }
}

class ShortsTotals {
  final int watched;
  final int likes;
  final int comments;
  final String donations;

  ShortsTotals({
    required this.watched,
    required this.likes,
    required this.comments,
    required this.donations,
  });

  factory ShortsTotals.fromJson(Map<String, dynamic> json) {
    return ShortsTotals(
      watched: int.tryParse(json['watched']?.toString() ?? '0') ?? 0,
      likes: int.tryParse(json['likes']?.toString() ?? '0') ?? 0,
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

class ShortsInsights {
  final InsightItem today;
  final InsightItem weekly;
  final InsightItem monthly;

  ShortsInsights({
    required this.today,
    required this.weekly,
    required this.monthly,
  });

  factory ShortsInsights.fromJson(Map<String, dynamic> json) {
    return ShortsInsights(
      today: InsightItem.fromJson(json['today'] ?? {}),
      weekly: InsightItem.fromJson(json['weekly'] ?? {}),
      monthly: InsightItem.fromJson(json['monthly'] ?? {}),
    );
  }
}

class InsightItem {
  final InsightData data;
  final InsightChange change;

  InsightItem({
    required this.data,
    required this.change,
  });

  factory InsightItem.fromJson(Map<String, dynamic> json) {
    return InsightItem(
      data: InsightData.fromJson(json['data'] ?? {}),
      change: InsightChange.fromJson(json['change'] ?? {}),
    );
  }
}

class InsightData {
  final int watched;
  final int likes;
  final int comments;
  final int donations;

  InsightData({
    required this.watched,
    required this.likes,
    required this.comments,
    required this.donations,
  });

  factory InsightData.fromJson(Map<String, dynamic> json) {
    return InsightData(
      watched: int.tryParse(json['watched']?.toString() ?? '0') ?? 0,
      likes: int.tryParse(json['likes']?.toString() ?? '0') ?? 0,
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

class InsightChange {
  final double watched;
  final double likes;
  final double comments;
  final double donations;

  InsightChange({
    required this.watched,
    required this.likes,
    required this.comments,
    required this.donations,
  });

  factory InsightChange.fromJson(Map<String, dynamic> json) {
    return InsightChange(
      watched: double.tryParse(json['watched']?.toString() ?? '0') ?? 0.0,
      likes: double.tryParse(json['likes']?.toString() ?? '0') ?? 0.0,
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
