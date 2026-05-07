import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth.dart';
import '../../story/creator_story_screen.dart';
import '../../user/user_screen.dart';
import '../followers_list_screen.dart';

class FollowersTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String selectedPeriod;
  final bool showGraph;
  final VoidCallback onShowGraphToggle;
  final VoidCallback onPeriodPickerTap;
  final String username;

  const FollowersTab({
    Key? key,
    required this.stats,
    required this.selectedPeriod,
    required this.showGraph,
    required this.onShowGraphToggle,
    required this.onPeriodPickerTap,
    required this.username,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final followers = stats['followers'] as List? ?? [];
    final followersCount = stats['followers_count'] as int? ?? 0;
    final followingCount = stats['following_count'] as int? ?? 0;
    final mutualCount = stats['mutual_count'] as int? ?? 0;
    final growth = stats['growth'] as List? ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insights header
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onPeriodPickerTap,
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
                              selectedPeriod,
                              style: const TextStyle(color: Colors.white),
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
                        showGraph ? Icons.bar_chart : Icons.bar_chart_outlined,
                        color: showGraph ? Colors.amber : Colors.grey[600],
                      ),
                      tooltip: showGraph ? "Hide Graph" : "Show Graph",
                      onPressed: onShowGraphToggle,
                    ),
                  ],
                )
              ],
            ),
          ),

          // Stats Cards or Growth Graph based on showGraph flag
          if (!showGraph) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildFollowerMetricCard(
                          context,
                          'Followers',
                          followersCount.toString(),
                          Icons.people,
                          Colors.blue,
                          () => _navigateToFollowersList(context, 'followers'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFollowerMetricCard(
                          context,
                          'Following',
                          followingCount.toString(),
                          Icons.person_add,
                          Colors.green,
                          () => _navigateToFollowersList(context, 'following'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              _navigateToFollowersList(context, 'mutual'),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Mutual',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Icon(Icons.people_outline,
                                        color: Colors.purple, size: 20),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  mutualCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Ratio',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Icon(Icons.trending_up,
                                      color: Colors.amber, size: 20),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                followingCount > 0
                                    ? (followersCount / followingCount)
                                        .toStringAsFixed(1)
                                    : '0.0',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            if (growth.isNotEmpty) ...[
              _buildFollowerGrowthGraph(growth),
              const SizedBox(height: 20),
            ]
          ],
          const SizedBox(height: 20),

          // Recent Followers Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: const Text(
              'Followers List :',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Followers List
          followers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(Icons.people_outline,
                            color: Colors.grey, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No followers yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: followers.take(10).length,
                  itemBuilder: (context, index) {
                    final follower = followers[index];
                    return _FollowerItem(follower: follower);
                  },
                ),

          if (followers.length > 10)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: TextButton(
                  onPressed: () => _showAllFollowers(context, followers),
                  child: Text(
                    'View All ${followers.length} Followers',
                    style: const TextStyle(color: Colors.amber),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToFollowersList(BuildContext context, String listType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FollowersListScreen(
          listType: listType,
          username: username,
        ),
      ),
    );
  }

  Widget _buildFollowerMetricCard(BuildContext context, String label,
      String value, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowerGrowthGraph(List<dynamic> growth) {
    if (growth.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    int minY =
        growth.map((g) => g['count'] as int).reduce((a, b) => a < b ? a : b);
    int maxY =
        growth.map((g) => g['count'] as int).reduce((a, b) => a > b ? a : b);

    List<Map<String, dynamic>> sortedGrowth =
        List<Map<String, dynamic>>.from(growth);
    sortedGrowth
        .sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    for (int i = 0; i < sortedGrowth.length; i++) {
      spots.add(
          FlSpot(i.toDouble(), (sortedGrowth[i]['count'] as int).toDouble()));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follower Growth (Last 7 Days)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[800],
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx < 0 || idx >= sortedGrowth.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            sortedGrowth[idx]['date'],
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                      interval: 1,
                      reservedSize: 36,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval:
                          ((maxY - minY) ~/ 3).clamp(1, 999999).toDouble(),
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                      ),
                      reservedSize: 34,
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(color: Colors.grey[700]!),
                    bottom: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: (minY - 2).toDouble(),
                maxY: (maxY + 2).toDouble(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.blue.withOpacity(0.28),
                          Colors.blue.withOpacity(0.08),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.blue,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllFollowers(BuildContext context, List<dynamic> followers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'All Followers (${followers.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: followers.length,
                      itemBuilder: (context, index) {
                        return _FollowerItem(follower: followers[index]);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FollowerItem extends StatelessWidget {
  final dynamic follower;

  const _FollowerItem({Key? key, required this.follower}) : super(key: key);

  void _openProfile(BuildContext context) {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final currentUserId = auth.user['id'];

      final int? userId =
          (follower['id'] is int) ? follower['id'] as int : null;
      final String? username = follower['username']?.toString();

      if (userId != null && username != null && username.isNotEmpty) {
        if (userId == currentUserId) {
          Navigator.of(context).pushNamed(UserScreen.routeName);
        } else {
          Navigator.of(context).pushNamed(
            CreatorStoryScreen.routeName,
            arguments: [userId, username],
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openProfile(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[800],
              backgroundImage: follower['image'] != null &&
                      (follower['image'] as String).isNotEmpty
                  ? CachedNetworkImageProvider(follower['image'])
                  : null,
              child: (follower['image'] == null ||
                      (follower['image'] as String).isEmpty)
                  ? const CircleAvatar(
                      radius: 24,
                      backgroundImage: AssetImage('assets/images/logo.png'),
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    follower['name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '@${follower['username'] ?? 'unknown'}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (follower['is_following'] == true)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Text(
                  'Mutual',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
