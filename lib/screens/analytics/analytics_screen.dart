import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth.dart';
import '../../providers/shorts.dart';
import '../../providers/story.dart';
import '../../widgets/skeleton_loading.dart';
import './widgets/analytics_common_widgets.dart';
import './widgets/point_log_tab.dart';
import './widgets/achievements_tab.dart';
import './widgets/followers_tab.dart';
import './widgets/shorts_tab.dart';
import './widgets/seasons_tab.dart';

class AnalyticsScreen extends StatefulWidget {
  static const routeName = '/analytics-screen';

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedTab = 0;
  String selectedPeriod = 'Lifetime';
  bool showGraph = false;

  // For Achievements tab
  bool _achievementsLoading = false;
  List<dynamic> _achievements = [];

  // Async futures for data loading
  late Future<Map<String, dynamic>> _pointLogsFuture;
  late Future<Map<String, dynamic>> _followerStatsFuture;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    _pointLogsFuture = _loadPointLogs();
    _followerStatsFuture = _loadFollowerStats();

    // Trigger loads based on initial tab (0 by default)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedTab == 0) {
        // Handled by FutureBuilder
      }
    });
  }

  void _onTabSelected(int idx) async {
    if (_selectedTab == idx) return;
    setState(() {
      _selectedTab = idx;
    });

    if (idx == 0) {
      setState(() {
        _followerStatsFuture = _loadFollowerStats();
      });
    } else if (idx == 1) {
      await Provider.of<Shorts>(context, listen: false).fetchShortsAnalytics();
      await _loadCreatorShorts();
    } else if (idx == 2) {
      await Provider.of<Story>(context, listen: false).fetchSeasonAnalytics();
      await _loadCreatorSeasons();
    } else if (idx == 3) {
      setState(() {
        _pointLogsFuture = _loadPointLogs();
      });
    } else if (idx == 4 && _achievements.isEmpty) {
      await _loadAchievements();
    }
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _achievementsLoading = true;
    });
    final auth = Provider.of<Auth>(context, listen: false);
    await auth.getAchievements();
    if (mounted) {
      setState(() {
        _achievements = auth.achievements.toList();
        _achievementsLoading = false;
      });
    }
  }

  Future<void> _loadCreatorShorts() async {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final shortsProvider = Provider.of<Shorts>(context, listen: false);
      await shortsProvider.fetchCreatorShorts(auth.userId, returnList: false);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ ANALYTICS: Error loading creator shorts: $e');
    }
  }

  Future<void> _loadCreatorSeasons() async {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final storyProvider = Provider.of<Story>(context, listen: false);
      await storyProvider.fetchCreatorSeasons(auth.userId, returnList: false);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ ANALYTICS: Error loading creator seasons: $e');
    }
  }

  Future<Map<String, dynamic>> _loadFollowerStats() async {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final username = auth.username;
      if (username == null || username.isEmpty) return _emptyFollowerStats();

      await auth.fetchFollowers(username, perPage: 100);
      await auth.fetchFollowing(username, perPage: 100);

      final followers = auth.followers;
      final following = auth.following;

      return {
        'followers': followers,
        'following': following,
        'followers_count': followers.length,
        'following_count': following.length,
        'growth': _generateGrowthData(followers.length),
        'mutual_count': _calculateMutualFollows(followers, following),
      };
    } catch (e) {
      debugPrint('Error loading follower stats: $e');
      return _emptyFollowerStats();
    }
  }

  Map<String, dynamic> _emptyFollowerStats() {
    return {
      'followers': [],
      'following': [],
      'followers_count': 0,
      'following_count': 0,
      'growth': [],
      'mutual_count': 0,
    };
  }

  int _calculateMutualFollows(
      List<dynamic> followers, List<dynamic> following) {
    final followerIds = followers.map((f) => f['id']).toSet();
    return following.where((f) => followerIds.contains(f['id'])).length;
  }

  List<Map<String, dynamic>> _generateGrowthData(int currentCount) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final baseCount = currentCount > 7
          ? (currentCount - (7 - i) * (currentCount ~/ 20))
          : i;
      return {
        'date': DateFormat('EEE').format(date),
        'count': baseCount.clamp(0, currentCount),
      };
    });
  }

  Future<Map<String, dynamic>> _loadPointLogs() async {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      await auth.getUser();
      final currentBalance = int.tryParse(
              auth.userInformation?['available_coins']?.toString() ?? '0') ??
          0;

      final response = await auth.getCoinLogs(page: 1);
      final logs = (response['data'] ?? []) as List<dynamic>;

      final mapped = logs.map<Map<String, dynamic>>((tx) {
        final isDebited = tx['status'] == 'debited';
        return {
          'title': isDebited ? 'Debited' : 'Credited',
          'date': tx['created_at']?.toString() ?? '',
          'points': safeToInt(tx['coin']),
          'isPositive': !isDebited,
          'notes': tx['remarks'] ?? '',
          'status': tx['status'] ?? '',
          'transactionId': tx['id']?.toString() ?? '',
          'remarks': tx['remarks'] ?? '',
        };
      }).toList();

      return {'logs': mapped, 'currentBalance': currentBalance};
    } catch (e) {
      debugPrint('Error loading point logs: $e');
      return {'logs': <Map<String, dynamic>>[], 'currentBalance': 0};
    }
  }

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Today', 'Weekly', 'Monthly', 'Lifetime'].map((period) {
              final isSelected = selectedPeriod == period;
              return ListTile(
                title: Text(
                  period,
                  style: TextStyle(
                      color: isSelected ? Colors.amber : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.amber)
                    : null,
                onTap: () {
                  setState(() {
                    selectedPeriod = period;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analytics',
          style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AnalyticsTabChip(
                      label: "Followers",
                      isActive: _selectedTab == 0,
                      onTap: () => _onTabSelected(0)),
                  const SizedBox(width: 20),
                  AnalyticsTabChip(
                      label: "Shorts",
                      isActive: _selectedTab == 1,
                      onTap: () => _onTabSelected(1)),
                  const SizedBox(width: 20),
                  AnalyticsTabChip(
                      label: "Seasons",
                      isActive: _selectedTab == 2,
                      onTap: () => _onTabSelected(2)),
                  const SizedBox(width: 20),
                  AnalyticsTabChip(
                      label: "Sikka log",
                      isActive: _selectedTab == 3,
                      onTap: () => _onTabSelected(3)),
                  const SizedBox(width: 20),
                  AnalyticsTabChip(
                      label: "Achievements",
                      isActive: _selectedTab == 4,
                      onTap: () => _onTabSelected(4)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return FutureBuilder<Map<String, dynamic>>(
          future: _followerStatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(36.0),
                  child: ListSkeleton(itemCount: 4));
            }
            if (snapshot.hasError) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                          "Failed to load follower stats.\n${snapshot.error}",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center)));
            }
            return FollowersTab(
              stats: snapshot.data ?? {},
              selectedPeriod: selectedPeriod,
              showGraph: showGraph,
              onShowGraphToggle: () => setState(() => showGraph = !showGraph),
              onPeriodPickerTap: () => _showPeriodPicker(context),
              username:
                  Provider.of<Auth>(context, listen: false).username ?? '',
            );
          },
        );
      case 1:
        return ShortsTab(
          selectedPeriod: selectedPeriod,
          showGraph: showGraph,
          onShowGraphToggle: () => setState(() => showGraph = !showGraph),
          onPeriodPickerTap: () => _showPeriodPicker(context),
          onRefresh: () async {
            await Provider.of<Shorts>(context, listen: false)
                .fetchShortsAnalytics();
            await _loadCreatorShorts();
          },
        );
      case 2:
        return SeasonsTab(
          selectedPeriod: selectedPeriod,
          showGraph: showGraph,
          onShowGraphToggle: () => setState(() => showGraph = !showGraph),
          onPeriodPickerTap: () => _showPeriodPicker(context),
          onRefresh: () async {
            await Provider.of<Story>(context, listen: false)
                .fetchSeasonAnalytics();
            await _loadCreatorSeasons();
          },
        );
      case 3:
        return FutureBuilder<Map<String, dynamic>>(
          future: _pointLogsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(36.0),
                  child: ListSkeleton(itemCount: 4));
            }
            if (snapshot.hasError) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Text(
                          "Failed to load point log.\n${snapshot.error}",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center)));
            }
            final data = snapshot.data ?? {};
            return PointLogTab(
              pointLogs: (data['logs'] as List<Map<String, dynamic>>?) ?? [],
              currentBalance: (data['currentBalance'] as int?) ?? 0,
            );
          },
        );
      case 4:
        return AchievementsTab(
          achievements: _achievements,
          isLoading: _achievementsLoading,
          onRefresh: _loadAchievements,
        );
      default:
        return const Center(
            child: Text("Feature coming soon.",
                style: TextStyle(color: Colors.white38, fontSize: 16)));
    }
  }
}
