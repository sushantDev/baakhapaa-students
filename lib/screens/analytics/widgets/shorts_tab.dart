import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/shorts.dart';
import '../../../models/shorts_analytics.dart';
import '../../../widgets/skeleton_loading.dart';
import 'analytics_common_widgets.dart';

class ShortsTab extends StatefulWidget {
  final String selectedPeriod;
  final bool showGraph;
  final VoidCallback onPeriodPickerTap;
  final VoidCallback onShowGraphToggle;
  final Future<void> Function() onRefresh;

  const ShortsTab({
    Key? key,
    required this.selectedPeriod,
    required this.showGraph,
    required this.onPeriodPickerTap,
    required this.onShowGraphToggle,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<ShortsTab> createState() => _ShortsTabState();
}

class _ShortsTabState extends State<ShortsTab> {
  Future<List<Map<String, dynamic>>> _loadShortsData() async {
    try {
      final shortsProvider = Provider.of<Shorts>(context, listen: false);
      final creatorShortsRaw = shortsProvider.creatorShorts;

      return List<Map<String, dynamic>>.generate(
        creatorShortsRaw.length,
        (i) {
          final short = creatorShortsRaw[i];
          final likesCount = safeToInt(short["likes_count"] ??
              short["likes"] ??
              short["total_likes"] ??
              0);
          final watchedCount = safeToInt(short["users_count"] ??
              short["views"] ??
              short["view_count"] ??
              short["watched"] ??
              short["watched_count"] ??
              0);
          final commentsCount = safeToInt(short["comments_count"] ??
              short["comment_count"] ??
              short["comments"] ??
              short["comment"] ??
              short["total_comments"] ??
              0);
          final donationsCount = safeToInt(short["donations_count"] ??
              short["donations"] ??
              short["total_donations"] ??
              0);

          return {
            "title": short["title"] ?? "Short ${i + 1}",
            "date": short["created_at"] != null
                ? DateFormat('d/M/yyyy').format(
                    DateTime.tryParse(short["created_at"]) ?? DateTime.now())
                : "",
            "likes": likesCount,
            "watched": watchedCount,
            "donations": donationsCount,
            "comments": commentsCount,
          };
        },
      );
    } catch (e) {
      debugPrint('📊 Error loading shorts data: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Shorts>(
      builder: (context, shortsProvider, child) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadShortsData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(36.0),
                child: ListSkeleton(itemCount: 4),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Failed to load shorts.\n${snapshot.error}",
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: widget.onRefresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final shorts = snapshot.data ?? [];
            final analytics = shortsProvider.shortsAnalytics;

            final int totalWatched = analytics?.totals.watched ??
                shorts.fold(0, (sum, s) => sum + (s['watched'] as int? ?? 0));
            final int totalLikes = analytics?.totals.likes ??
                shorts.fold(0, (sum, s) => sum + (s['likes'] as int? ?? 0));
            final int totalComments = analytics?.totals.comments ??
                shorts.fold(0, (sum, s) => sum + (s['comments'] as int? ?? 0));
            final String totalDonations = analytics?.totals.donations ??
                shorts
                    .fold(0, (sum, s) => sum + (s['donations'] as int? ?? 0))
                    .toString();

            InsightItem? selectedInsight;
            if (analytics != null) {
              if (widget.selectedPeriod == 'Today') {
                selectedInsight = analytics.insights.today;
              } else if (widget.selectedPeriod == 'Weekly') {
                selectedInsight = analytics.insights.weekly;
              } else if (widget.selectedPeriod == 'Monthly') {
                selectedInsight = analytics.insights.monthly;
              }
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Insights:',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: widget.onPeriodPickerTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[800]!),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      widget.selectedPeriod,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.keyboard_arrow_down,
                                        color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                widget.showGraph
                                    ? Icons.bar_chart
                                    : Icons.bar_chart_outlined,
                                color: widget.showGraph
                                    ? Colors.amber
                                    : Colors.grey[600],
                              ),
                              tooltip: widget.showGraph
                                  ? "Hide Graph"
                                  : "Show Graph",
                              onPressed: widget.onShowGraphToggle,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!widget.showGraph)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: (constraints.maxWidth - 12) / 2,
                                child: AnalyticsMetricCard(
                                  label: 'Watched',
                                  value: widget.selectedPeriod == 'Lifetime'
                                      ? formatNumber(totalWatched)
                                      : (analytics != null
                                          ? formatNumber(
                                              selectedInsight?.data.watched ??
                                                  0)
                                          : formatNumber(totalWatched)),
                                  percentage: widget.selectedPeriod ==
                                          'Lifetime'
                                      ? ''
                                      : (analytics != null
                                          ? "${(selectedInsight?.change.watched ?? 0).abs().toStringAsFixed(1)}%"
                                          : '0.0%'),
                                  isPositive:
                                      (selectedInsight?.change.watched ?? 0) >=
                                          0,
                                  bgColor: Colors.grey[850]!,
                                  graphColor: Colors.teal,
                                ),
                              ),
                              SizedBox(
                                width: (constraints.maxWidth - 12) / 2,
                                child: AnalyticsMetricCard(
                                  label: 'Donations',
                                  value: widget.selectedPeriod == 'Lifetime'
                                      ? totalDonations
                                      : (analytics != null
                                          ? (selectedInsight?.data.donations ??
                                                  0)
                                              .toString()
                                          : totalDonations),
                                  percentage: widget.selectedPeriod ==
                                          'Lifetime'
                                      ? ''
                                      : (analytics != null
                                          ? "${(selectedInsight?.change.donations ?? 0).abs().toStringAsFixed(1)}%"
                                          : '0.0%'),
                                  isPositive:
                                      (selectedInsight?.change.donations ??
                                              0) >=
                                          0,
                                  bgColor: Colors.grey[850]!,
                                  graphColor: Colors.amber,
                                ),
                              ),
                              SizedBox(
                                width: (constraints.maxWidth - 12) / 2,
                                child: AnalyticsMetricCard(
                                  label: 'Comments',
                                  value: widget.selectedPeriod == 'Lifetime'
                                      ? totalComments.toString()
                                      : (analytics != null
                                          ? (selectedInsight?.data.comments ??
                                                  0)
                                              .toString()
                                          : totalComments.toString()),
                                  percentage: widget.selectedPeriod ==
                                          'Lifetime'
                                      ? ''
                                      : (analytics != null
                                          ? "${(selectedInsight?.change.comments ?? 0).abs().toStringAsFixed(1)}%"
                                          : '0.0%'),
                                  isPositive:
                                      (selectedInsight?.change.comments ?? 0) >=
                                          0,
                                  bgColor: Colors.grey[850]!,
                                  graphColor: Colors.purple,
                                ),
                              ),
                              SizedBox(
                                width: (constraints.maxWidth - 12) / 2,
                                child: AnalyticsMetricCard(
                                  label: 'Likes',
                                  value: widget.selectedPeriod == 'Lifetime'
                                      ? formatNumber(totalLikes)
                                      : (analytics != null
                                          ? formatNumber(
                                              selectedInsight?.data.likes ?? 0)
                                          : formatNumber(totalLikes)),
                                  percentage: widget.selectedPeriod ==
                                          'Lifetime'
                                      ? ''
                                      : (analytics != null
                                          ? "${(selectedInsight?.change.likes ?? 0).abs().toStringAsFixed(1)}%"
                                          : '0.0%'),
                                  isPositive:
                                      (selectedInsight?.change.likes ?? 0) >= 0,
                                  bgColor: Colors.grey[850]!,
                                  graphColor: Colors.pinkAccent,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildShortsCombinedGraph(
                          analytics, widget.selectedPeriod, shorts),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: AnalyticsLegend(
                      items: [
                        LegendItem(Colors.pinkAccent, 'Likes'),
                        LegendItem(Colors.teal, 'Watched'),
                        LegendItem(Colors.amber, 'Donations'),
                        LegendItem(Colors.purple, 'Comments'),
                      ],
                    ),
                  ),
                  shorts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: Column(
                              children: [
                                const Text("No shorts found.",
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 16)),
                                const SizedBox(height: 16),
                                Text(
                                    "Provider has ${shortsProvider.creatorShorts.length} shorts",
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 14)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: widget.onRefresh,
                                  child: const Text('Refresh Shorts'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: shorts
                              .map((short) => _buildShortsItem(short))
                              .toList(),
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShortsCombinedGraph(ShortsAnalytics? analytics, String period,
      List<Map<String, dynamic>> shorts) {
    List<GraphMetric> metrics = [];
    String title = 'Lifetime Shorts Totals';
    bool isLifetime = true;

    if (analytics != null && period != 'Lifetime') {
      InsightItem? insight;
      if (period == 'Today') insight = analytics.insights.today;
      if (period == 'Weekly') insight = analytics.insights.weekly;
      if (period == 'Monthly') insight = analytics.insights.monthly;

      if (insight != null) {
        title = '$period Shorts Insights';
        isLifetime = false;
        metrics = [
          GraphMetric('Watched', insight.data.watched.toDouble(),
              insight.change.watched, Colors.teal),
          GraphMetric('Likes', insight.data.likes.toDouble(),
              insight.change.likes, Colors.pinkAccent),
          GraphMetric('Donations', insight.data.donations.toDouble(),
              insight.change.donations, Colors.amber),
          GraphMetric('Comments', insight.data.comments.toDouble(),
              insight.change.comments, Colors.purple),
        ];
      }
    }

    if (metrics.isEmpty) {
      final double watched = (analytics?.totals.watched ?? 0).toDouble() +
          shorts.fold<double>(
              0.0, (sum, s) => sum + (s['watched'] as num? ?? 0).toDouble());
      final double likes = (analytics?.totals.likes ?? 0).toDouble() +
          shorts.fold<double>(
              0.0, (sum, s) => sum + (s['likes'] as num? ?? 0).toDouble());
      final double donations =
          double.tryParse(analytics?.totals.donations ?? "0") ??
              shorts.fold<double>(0.0,
                  (sum, s) => sum + (s['donations'] as num? ?? 0).toDouble());
      final double comments = (analytics?.totals.comments ?? 0).toDouble() +
          shorts.fold<double>(
              0.0, (sum, s) => sum + (s['comments'] as num? ?? 0).toDouble());

      metrics = [
        GraphMetric('Watched', watched, 0, Colors.teal),
        GraphMetric('Likes', likes, 0, Colors.pinkAccent),
        GraphMetric('Donations', donations, 0, Colors.amber),
        GraphMetric('Comments', comments, 0, Colors.purple),
      ];
    }

    return ComparisonGraph(
        title: title, metrics: metrics, isLifetime: isLifetime);
  }

  Widget _buildShortsItem(Map<String, dynamic> short) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 72,
              height: 72,
              color: Colors.black.withOpacity(0.6),
              child: const Icon(Icons.play_circle_fill,
                  color: Colors.pinkAccent, size: 38),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  short["title"] ?? "Short",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  short["date"] ?? "",
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _detailStat(Icons.thumb_up_alt_outlined, short["likes"],
                        Colors.pinkAccent),
                    _detailStat(Icons.comment_outlined, short["comments"],
                        Colors.purple),
                    _detailStat(Icons.visibility_rounded, short["watched"],
                        Colors.teal),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailStat(IconData icon, int? value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 2),
        Text(
          (value ?? 0).toString(),
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
