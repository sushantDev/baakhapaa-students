import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../widgets/TicketWidget.dart';
import '../../../widgets/skeleton_loading.dart';

class AchievementsTab extends StatelessWidget {
  final bool isLoading;
  final List<dynamic> achievements;
  final VoidCallback onRefresh;

  const AchievementsTab({
    Key? key,
    required this.isLoading,
    required this.achievements,
    required this.onRefresh,
  }) : super(key: key);

  int get totalBadges => achievements.length;
  int get earnedBadges =>
      achievements.where((a) => (a['claimed'] ?? 0) == 1).length;
  int get missedBadges =>
      achievements.where((a) => (a['obtained'] ?? 0) != 1).length;

  double _calculateProgress(Map<String, dynamic> achievement) {
    final progress = achievement['progress'];
    if (progress == null || progress is! Map) return 0.0;

    if (progress.isEmpty) {
      return achievement['claimed'] == 1 ? 1.0 : 0.0;
    }

    double totalPercent = 0.0;
    int criteriaCount = 0;

    progress.forEach((key, value) {
      if (value is Map && value['percent'] != null) {
        totalPercent += (value['percent'] as num).toDouble();
        criteriaCount++;
      }
    });

    if (criteriaCount == 0) {
      return achievement['claimed'] == 1 ? 1.0 : 0.0;
    }

    return (totalPercent / criteriaCount) / 100;
  }

  Color _getCategoryAccentColor(String category) {
    switch (category.toLowerCase()) {
      case 'common':
        return Colors.blue.shade600;
      case 'special':
        return Colors.orange.shade600;
      case 'elite':
      case 'elite ':
        return Colors.purple.shade600;
      case 'seasonal':
        return Colors.green.shade600;
      case 'milestone':
        return Colors.amber.shade600;
      default:
        return Colors.amber.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: ListSkeleton(itemCount: 4),
      );
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
                GestureDetector(
                  onTap: onRefresh,
                  child: const Icon(Icons.refresh, color: Colors.amber),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: BadgesSummaryCard(
              totalBadges: totalBadges,
              earnedBadges: earnedBadges,
              missedBadges: missedBadges,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                LegendDot(color: Colors.blue, label: 'Earned Badges'),
                LegendDot(color: Colors.red, label: 'Missed Badges'),
                LegendDot(color: Color(0xFFB0BEC5), label: 'Total Badges'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            itemCount: achievements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final achievement =
                  (achievements[index] as Map<String, dynamic>? ?? {});
              final title = achievement['title'] ?? 'Achievement';
              final level = achievement['level'] != null
                  ? 'Level ${achievement['level']}'
                  : 'Level 1';
              final progress = _calculateProgress(achievement);
              final category =
                  (achievement['achievement_category'] ?? 'Other').toString();
              final accent = _getCategoryAccentColor(category);
              final imageUrl = achievement['url'];

              return BadgeProgressTile(
                title: title,
                levelLabel: level,
                progress: progress,
                accent: accent,
                imageUrl: imageUrl,
              );
            },
          ),
        ],
      ),
    );
  }
}

class BadgesSummaryCard extends StatelessWidget {
  final int totalBadges;
  final int earnedBadges;
  final int missedBadges;

  const BadgesSummaryCard({
    Key? key,
    required this.totalBadges,
    required this.earnedBadges,
    required this.missedBadges,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double earnedRatio =
        totalBadges == 0 ? 0 : earnedBadges / totalBadges;
    final double missedRatio =
        totalBadges == 0 ? 0 : missedBadges / totalBadges;

    return Container(
      decoration: BoxDecoration(
          color: Colors.grey[900], borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 18,
                  backgroundColor: Colors.grey[850],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFB0BEC5)),
                ),
              ),
              Transform.rotate(
                angle: -3.14 / 2,
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: missedRatio,
                    strokeWidth: 18,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                ),
              ),
              Transform.rotate(
                angle: 3.14 / 2,
                child: SizedBox(
                  width: 190,
                  height: 190,
                  child: CircularProgressIndicator(
                    value: earnedRatio,
                    strokeWidth: 18,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total Badges',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('$totalBadges',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot({Key? key, required this.color, required this.label})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class BadgeProgressTile extends StatelessWidget {
  final String title;
  final String levelLabel;
  final double progress;
  final Color accent;
  final dynamic imageUrl;

  const BadgeProgressTile({
    Key? key,
    required this.title,
    required this.levelLabel,
    required this.progress,
    required this.accent,
    this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.grey[900], borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          TicketShape(
            width: 86,
            height: 64,
            notchRadius: 7,
            notchDepth: 6,
            child: Container(
              color: const Color.fromARGB(255, 240, 223, 174),
              child: Center(
                child:
                    (imageUrl != null && imageUrl.toString().trim().isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: imageUrl.toString(),
                            fit: BoxFit.contain,
                            width: 48,
                            height: 48,
                            placeholder: (context, _) =>
                                Icon(Icons.shield, color: accent, size: 32),
                            errorWidget: (context, _, __) =>
                                Icon(Icons.shield, color: accent, size: 32),
                          )
                        : Icon(Icons.shield, color: accent, size: 32),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(levelLabel,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.grey[800],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${(progress * 100).toStringAsFixed(0)}%',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
