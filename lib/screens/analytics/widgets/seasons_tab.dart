import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/story.dart';
import '../../../models/season_analytics.dart';
import '../../../widgets/skeleton_loading.dart';
import 'analytics_common_widgets.dart';

class SeasonsTab extends StatefulWidget {
  final String selectedPeriod;
  final bool showGraph;
  final VoidCallback onPeriodPickerTap;
  final VoidCallback onShowGraphToggle;
  final Future<void> Function() onRefresh;

  const SeasonsTab({
    Key? key,
    required this.selectedPeriod,
    required this.showGraph,
    required this.onPeriodPickerTap,
    required this.onShowGraphToggle,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<SeasonsTab> createState() => _SeasonsTabState();
}

class _SeasonsTabState extends State<SeasonsTab> {
  Future<List<Map<String, dynamic>>> _loadSeasonsData() async {
    try {
      final storyProvider = Provider.of<Story>(context, listen: false);
      final creatorSeasonsRaw = storyProvider.creatorSeasons;

      return List<Map<String, dynamic>>.generate(
        creatorSeasonsRaw.length,
        (i) {
          final season = creatorSeasonsRaw[i];
          final seasonUnlocked = safeToInt(
              season["season_unlocked"] ?? season["unlocked_count"] ?? 0);
          final episodesUploaded = safeToInt(
              season["episodes_uploaded"] ?? season["episode_count"] ?? 0);
          final commentsCount = safeToInt(
              season["comments_count"] ?? season["comment_count"] ?? 0);
          final donationsCount =
              safeToInt(season["donations_count"] ?? season["donations"] ?? 0);

          return {
            ...season,
            "title": season["title"] ?? "Season ${i + 1}",
            "season_unlocked": seasonUnlocked,
            "episodes_uploaded": episodesUploaded,
            "donations": donationsCount,
            "comments": commentsCount,
          };
        },
      );
    } catch (e) {
      debugPrint('📊 Error loading seasons data: $e');
      return [];
    }
  }

  String _getSeasonImage(Map<String, dynamic> season) {
    final thumbnail = season['thumbnail'];
    if (thumbnail is String && thumbnail.trim().isNotEmpty) {
      return thumbnail;
    }
    final images = season['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map &&
          first['url'] is String &&
          first['url'].trim().isNotEmpty) {
        return first['url'];
      }
      if (first is String && first.trim().isNotEmpty) {
        return first;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Story>(
      builder: (context, storyProvider, child) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadSeasonsData(),
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
                        "Failed to load seasons.\n${snapshot.error}",
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

            final seasons = snapshot.data ?? [];
            final analytics = storyProvider.seasonAnalytics;

            final int totalSeasonUnlocked = analytics?.totals.seasonUnlocked ??
                seasons.fold(
                    0, (sum, s) => sum + (s['season_unlocked'] as int? ?? 0));
            final int totalEpisodesUploaded = analytics
                    ?.totals.episodesUploaded ??
                seasons.fold(
                    0, (sum, s) => sum + (s['episodes_uploaded'] as int? ?? 0));
            final int totalComments = analytics?.totals.comments ??
                seasons.fold(0, (sum, s) => sum + (s['comments'] as int? ?? 0));
            final String totalDonations = analytics?.totals.donations ??
                seasons
                    .fold(0, (sum, s) => sum + (s['donations'] as int? ?? 0))
                    .toString();

            SeasonInsightItem? selectedInsight;
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
                                  label: 'Season Unlocked',
                                  value: widget.selectedPeriod == 'Lifetime'
                                      ? formatNumber(totalSeasonUnlocked)
                                      : (analytics != null
                                          ? formatNumber(selectedInsight
                                                  ?.data.seasonUnlocked ??
                                              0)
                                          : formatNumber(totalSeasonUnlocked)),
                                  percentage: widget.selectedPeriod ==
                                          'Lifetime'
                                      ? ''
                                      : (analytics != null
                                          ? "${(selectedInsight?.change.seasonUnlocked ?? 0).abs().toStringAsFixed(1)}%"
                                          : '0.0%'),
                                  isPositive:
                                      (selectedInsight?.change.seasonUnlocked ??
                                              0) >=
                                          0,
                                  bgColor: Colors.grey[850]!,
                                  graphColor: Colors.blue,
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
                                  label: 'Episodes',
                                  value: widget.selectedPeriod == 'Lifetime'
                                      ? formatNumber(totalEpisodesUploaded)
                                      : (analytics != null
                                          ? formatNumber(selectedInsight
                                                  ?.data.episodesUploaded ??
                                              0)
                                          : formatNumber(
                                              totalEpisodesUploaded)),
                                  percentage: widget.selectedPeriod ==
                                          'Lifetime'
                                      ? ''
                                      : (analytics != null
                                          ? "${(selectedInsight?.change.episodesUploaded ?? 0).abs().toStringAsFixed(1)}%"
                                          : '0.0%'),
                                  isPositive: (selectedInsight
                                              ?.change.episodesUploaded ??
                                          0) >=
                                      0,
                                  bgColor: Colors.grey[850]!,
                                  graphColor: Colors.green,
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
                      child: _buildSeasonsCombinedGraph(
                          analytics, widget.selectedPeriod, seasons),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: AnalyticsLegend(
                      items: [
                        LegendItem(Colors.blue, 'Unlocked'),
                        LegendItem(Colors.amber, 'Donations'),
                        LegendItem(Colors.green, 'Episodes'),
                        LegendItem(Colors.purple, 'Comments'),
                      ],
                    ),
                  ),
                  seasons.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: Column(
                              children: [
                                const Text("No seasons found.",
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 16)),
                                const SizedBox(height: 16),
                                Text(
                                    "Provider has ${storyProvider.creatorSeasons.length} seasons",
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 14)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: widget.onRefresh,
                                  child: const Text('Refresh Seasons'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: seasons
                              .map((season) => _buildSeasonItem(season))
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

  Widget _buildSeasonsCombinedGraph(SeasonAnalytics? analytics, String period,
      List<Map<String, dynamic>> seasons) {
    List<GraphMetric> metrics = [];
    String title = 'Lifetime Seasons Totals';
    bool isLifetime = true;

    if (analytics != null && period != 'Lifetime') {
      SeasonInsightItem? insight;
      if (period == 'Today') insight = analytics.insights.today;
      if (period == 'Weekly') insight = analytics.insights.weekly;
      if (period == 'Monthly') insight = analytics.insights.monthly;

      if (insight != null) {
        title = '$period Seasons Insights';
        isLifetime = false;
        metrics = [
          GraphMetric('Unlocked', insight.data.seasonUnlocked.toDouble(),
              insight.change.seasonUnlocked, Colors.blue),
          GraphMetric('Episodes', insight.data.episodesUploaded.toDouble(),
              insight.change.episodesUploaded, Colors.green),
          GraphMetric('Donations', insight.data.donations.toDouble(),
              insight.change.donations, Colors.amber),
          GraphMetric('Comments', insight.data.comments.toDouble(),
              insight.change.comments, Colors.purple),
        ];
      }
    }

    if (metrics.isEmpty) {
      final double unlocked = (analytics?.totals.seasonUnlocked ?? 0)
              .toDouble() +
          seasons.fold<double>(0.0,
              (sum, s) => sum + (s['season_unlocked'] as num? ?? 0).toDouble());
      final double episodes =
          (analytics?.totals.episodesUploaded ?? 0).toDouble() +
              seasons.fold<double>(
                  0.0,
                  (sum, s) =>
                      sum + (s['episodes_uploaded'] as num? ?? 0).toDouble());
      final double donations =
          double.tryParse(analytics?.totals.donations ?? "0") ??
              seasons.fold<double>(0.0,
                  (sum, s) => sum + (s['donations'] as num? ?? 0).toDouble());
      final double comments = (analytics?.totals.comments ?? 0).toDouble() +
          seasons.fold<double>(
              0.0, (sum, s) => sum + (s['comments'] as num? ?? 0).toDouble());

      metrics = [
        GraphMetric('Unlocked', unlocked, 0, Colors.blue),
        GraphMetric('Episodes', episodes, 0, Colors.green),
        GraphMetric('Donations', donations, 0, Colors.amber),
        GraphMetric('Comments', comments, 0, Colors.purple),
      ];
    }

    return ComparisonGraph(
        title: title, metrics: metrics, isLifetime: isLifetime);
  }

  Widget _buildSeasonItem(Map<String, dynamic> season) {
    final String imageUrl = _getSeasonImage(season);

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
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[800]),
                    errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.movie, color: Colors.blue)),
                  )
                : Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey[800],
                    child: const Icon(Icons.movie, color: Colors.blue),
                  ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  season["title"] ?? "Season",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  "Season ${season['season_number'] ?? ''}",
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _detailStat(Icons.lock_open_rounded,
                        season["season_unlocked"], Colors.blue),
                    _detailStat(Icons.video_collection_rounded,
                        season["episodes_uploaded"], Colors.green),
                    _detailStat(Icons.comment_outlined, season["comments"],
                        Colors.purple),
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
