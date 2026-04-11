import 'dart:io';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/popup.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:share_plus/share_plus.dart';
import '../../widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import '../../models/url.dart';
import '../../providers/auth.dart';
import '../../providers/leaderboard.dart';
import '../user/player_profile_screen.dart';
import '../story/creator_story_screen.dart';
import '../../widgets/my_upgrader_messages.dart';
import '../../widgets/share_with_qr_modal.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import '../../services/ad_service.dart';

class LeaderboardScreen extends StatefulWidget {
  static const routeName = '/leaderboard-screen';

  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin, PuppetInteractionMixin {
  List<dynamic> _leaderboard = [];
  List<dynamic> _referralLeaderboard = [];
  Map<String, dynamic> leaderpopup = {};
  int _page = 1;
  var _isInit = true;
  var _isLoading = true;
  var _isReferralLoading = true;
  late int _myRank;
  late int _totalCount;
  final controller = ScrollController();
  var _authProvider;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize puppet provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<PuppetInteractionProvider>().initState();
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }
    });
  }

  void _openProfileFromLeaderboard(Map<String, dynamic> item) {
    try {
      final Map<String, dynamic> user =
          (item['user'] is Map<String, dynamic>) ? item['user'] : item;

      final dynamic roleValue = user['role'] ?? item['role'];
      final String role = (roleValue is String) ? roleValue : '';
      final bool isCreator = role == 'creator' ||
          user['is_creator'] == true ||
          item['is_creator'] == true ||
          user['creator_id'] != null ||
          item['creator_id'] != null;

      if (isCreator) {
        final int? creatorId = (user['user_id'] is int)
            ? user['user_id'] as int
            : (user['id'] is int)
                ? user['id'] as int
                : (item['user_id'] is int)
                    ? item['user_id'] as int
                    : (item['id'] is int)
                        ? item['id'] as int
                        : null;
        final String creatorName = (user['name']?.toString() ??
                user['username']?.toString() ??
                item['username']?.toString() ??
                'Creator')
            .toString();

        if (creatorId != null) {
          Navigator.of(context).pushNamed(
            CreatorStoryScreen.routeName,
            arguments: [creatorId, creatorName],
          );
          return;
        }
      }

      final String? username =
          (user['username'] ?? item['username'])?.toString();
      if (username != null && username.isNotEmpty) {
        Navigator.of(context).pushNamed(
          PlayerProfileScreen.routeName,
          arguments: username,
        );
      }
    } catch (_) {}
  }

  void _showUserMetricsModal(Map<String, dynamic> user) {
    final metrics = user['metrics'] ?? {};
    final leaderboardScore = user['leaderboard_score'] ?? 0;
    final username = user['username'] ?? 'User';
    final name = user['name'] ?? username;
    final imageUrl = user['image'] == null || user['image'].toString().isEmpty
        ? 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg'
        : '${Url.mediaUrl}/${user['image']}';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF2A2A2A)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with avatar and name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: CachedNetworkImageProvider(imageUrl),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '@$username',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Total Leaderboard Score
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade400, Colors.purple.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Column(
                        children: [
                          Text(
                            'Leaderboard Score',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            leaderboardScore.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Metrics breakdown
                Text(
                  'Score Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),

                _buildMetricRow(
                    'Level',
                    metrics['current_level']?.toString() ?? '0',
                    Icons.trending_up,
                    Colors.orange),
                _buildMetricRowWithImage(
                    'Available Points',
                    metrics['available_coins']?.toString() ?? '0',
                    Colors.amber),
                _buildMetricRow(
                    'Followers',
                    metrics['follower_count']?.toString() ?? '0',
                    Icons.people,
                    Colors.blue),
                _buildMetricRow(
                    'Challenges',
                    metrics['challenge_participation']?.toString() ?? '0',
                    Icons.emoji_events,
                    Colors.green),
                _buildMetricRow(
                    'Products Purchased',
                    metrics['products_purchased']?.toString() ?? '0',
                    Icons.shopping_bag,
                    Colors.pink),
                _buildMetricRow(
                    'Seasons Completed',
                    metrics['seasons_completed']?.toString() ?? '0',
                    Icons.calendar_today,
                    Colors.teal),
                _buildMetricRow(
                    'Shorts Completed',
                    metrics['shorts_completed']?.toString() ?? '0',
                    Icons.video_library,
                    Colors.red),

                SizedBox(height: 24),

                // View Profile Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openProfileFromLeaderboard(user);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'View Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRowWithImage(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/images/coins.png',
              width: 20,
              height: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();

    // Clear puppet interactions when leaving screen
    clearPuppetInteractions();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      var auth = Provider.of<Auth>(context, listen: false);
      _myRank = auth.userRank;
      _totalCount = auth.totalCount;
      _authProvider = auth;

      fetchLeaderboard();
      fetchReferralLeaderboard();
      fetchLeaderPopup();

      controller.addListener(() {
        if (controller.position.maxScrollExtent == controller.offset) {
          fetchLeaderboard();
        }
      });
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future fetchLeaderboard() async {
    Provider.of<Leaderboard>(context, listen: false)
        .fetchLeaderboard(_page)
        .then(
      (_) {
        setState(
          () {
            _leaderboard
              ..addAll(
                  Provider.of<Leaderboard>(context, listen: false).leaderboard);
            _page = _page + 1;
          },
        );
        if (_page > 1) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> fetchReferralLeaderboard() async {
    try {
      await Provider.of<Leaderboard>(context, listen: false)
          .fetchReferralLeaderboard();
      setState(() {
        _referralLeaderboard = Provider.of<Leaderboard>(context, listen: false)
            .referralLeaderboard;
        _isReferralLoading = false;
      });
    } catch (error) {
      DebugLogger.api('Error fetching referral leaderboard: $error');
      setState(() {
        _isReferralLoading = false;
      });
    }
  }

  Future<void> fetchLeaderPopup() async {
    try {
      await Provider.of<Leaderboard>(context, listen: false)
          .fetchLeaderboardPopup();
      setState(() {
        leaderpopup = {
          'popups':
              Provider.of<Leaderboard>(context, listen: false).leaderboardPopups
        };
      });
    } catch (error) {
      throw ('Error fetching leader popups: $error');
    }
  }

  /// Shares the leaderboard information with the user's rank and available coins.
  void _shareLeaderboard() {
    final username = _authProvider.username;
    final rank = _myRank;
    final points = _authProvider.userAvailableCoins;
    final message =
        "🏆 I'm ranked #$rank on the Baakhapaa Leaderboard with $points points! "
        "Join me and compete for the top spot! 🔥\n"
        "Download the app now: https://baakhapaa.com\n\n"
        "Use my referral code **$username** to get 25 points free!";
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ShareWithQrModal(
          data: message, subject: "Check out my Baakhapaa ranking!"),
    );
  }

  /// Shares the user's referral ranking and referral code for bonus points.
  void _shareReferralRanking() {
    final username = _authProvider.username;
    final referralCount = _referralLeaderboard.firstWhere(
      (user) => user['username'] == username,
      orElse: () => {'referral_count': 0},
    )['referral_count'];
    final message =
        "🎉 I'm a top referrer on Baakhapaa with $referralCount referrals! "
        "Join Baakhapaa and use my referral code **$username** to get 25 points free. "
        "Download the app now: https://baakhapaa.com";
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ShareWithQrModal(
          data: message, subject: "Join Baakhapaa and earn points!"),
    );
  }

  String get userImageUrl {
    String imageUrl;
    if (_authProvider.image.length == 0) {
      imageUrl =
          'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
    } else {
      imageUrl = _authProvider.image.first['thumbnail'];
    }
    return imageUrl;
  }

  Widget _buildMainLeaderboard() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Loading(),
      );
    }

    return Column(
      children: <Widget>[
        // Modern header section
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.group,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.totalUsers,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _totalCount.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.share, color: Colors.amber),
                  onPressed: _shareLeaderboard,
                  tooltip: context.l10n.shareMyRanking,
                ),
              ),
            ],
          ),
        ),
        // Modern podium section
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Second place
              if (_leaderboard.length > 1)
                _buildPodiumCard(
                  rank: 2,
                  user: _leaderboard[1],
                  isWinner: false,
                )
              else
                Expanded(child: SizedBox()),
              // First place (winner)
              if (_leaderboard.length > 0)
                _buildPodiumCard(
                  rank: 1,
                  user: _leaderboard[0],
                  isWinner: true,
                )
              else
                Expanded(child: SizedBox()),
              // Third place
              if (_leaderboard.length > 2)
                _buildPodiumCard(
                  rank: 3,
                  user: _leaderboard[2],
                  isWinner: false,
                )
              else
                Expanded(child: SizedBox()),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF2A2A2A)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]),
            child: ListView.builder(
              controller: controller,
              padding: EdgeInsets.all(8),
              itemCount: _leaderboard.length - 3,
              itemBuilder: (context, index) {
                int userRank = index + 4;
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF1E1E1E)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade700
                          : Colors.grey.shade200,
                      width: 0.5,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _openProfileFromLeaderboard(
                        _leaderboard[index + 3] as Map<String, dynamic>),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        // Rank
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              userRank.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),

                        // Avatar
                        GestureDetector(
                          onTap: () =>
                              _showUserMetricsModal(_leaderboard[index + 3]),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: _leaderboard[index + 3]['image'] ==
                                            null ||
                                        _leaderboard[index + 3]['image']
                                            .toString()
                                            .isEmpty
                                    ? 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg'
                                    : '${Url.mediaUrl}/${_leaderboard[index + 3]['image']}',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),

                        // Username
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                _showUserMetricsModal(_leaderboard[index + 3]),
                            child: Text(
                              _leaderboard[index + 3]['username'],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // Leaderboard Score
                        GestureDetector(
                          onTap: () =>
                              _showUserMetricsModal(_leaderboard[index + 3]),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade300,
                                  Colors.purple.shade500
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _leaderboard[index + 3]['leaderboard_score']
                                      .toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        MediaQuery.of(context).size.width < 360
                                            ? 11
                                            : 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Modern current user rank section
        InkWell(
          onTap: () {
            final int? creatorId = (_authProvider.userId is int)
                ? _authProvider.userId as int
                : null;
            final String creatorName =
                (_authProvider.username)?.toString() ?? 'Creator';

            if (creatorId != null) {
              Navigator.of(context).pushNamed(
                CreatorStoryScreen.routeName,
                arguments: [creatorId, creatorName],
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF2A2A2A)
                      : Colors.white,
                  Theme.of(context).brightness == Brightness.dark
                      ? Color(0xFF1E1E1E)
                      : Colors.grey.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // My Rank badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade400],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '#${_myRank.toString()}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(width: 16),

                // Modern avatar with enhanced styling
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade300, Colors.orange.shade300],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(3),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: CachedNetworkImageProvider(userImageUrl),
                    ),
                  ),
                ),
                SizedBox(width: 16),

                // Username and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _authProvider.username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'My Ranking',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Points with modern styling
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade300, Colors.amber.shade400],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/coins.png',
                        width: 20,
                        height: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _authProvider.userAvailableCoins.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferralLeaderboard() {
    if (_isReferralLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Loading(),
      );
    }

    if (_referralLeaderboard.isEmpty) {
      return Center(child: Text('No referral data available'));
    }

    return Column(
      children: <Widget>[
        // Modern header section for referrals
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.top10Referrers,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        context.l10n.leadingReferralUsers,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.share, color: Colors.amber),
                  onPressed: _shareReferralRanking,
                  tooltip: 'Share my ranking',
                ),
              ),
            ],
          ),
        ),
        // Modern referral podium section
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Second place
              _buildReferralPodiumCard(
                rank: 2,
                user: _referralLeaderboard[1],
                isWinner: false,
              ),
              // First place (winner)
              _buildReferralPodiumCard(
                rank: 1,
                user: _referralLeaderboard[0],
                isWinner: true,
              ),
              // Third place
              _buildReferralPodiumCard(
                rank: 3,
                user: _referralLeaderboard[2],
                isWinner: false,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF2A2A2A)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]),
            child: ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _referralLeaderboard.length > 3
                  ? _referralLeaderboard.length - 3
                  : 0,
              itemBuilder: (context, index) {
                int userRank = index + 4;
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF1E1E1E)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade700
                          : Colors.grey.shade200,
                      width: 0.5,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        // Rank
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              userRank.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),

                        // Avatar
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: _referralLeaderboard[index + 3]
                                      ['image_url'] ??
                                  'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),

                        // Username
                        Expanded(
                          child: GestureDetector(
                            child: Text(
                              _referralLeaderboard[index + 3]['username'],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // Referral count
                        GestureDetector(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade300,
                                  Colors.blue.shade400
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _referralLeaderboard[index + 3]
                                          ['referral_count']
                                      .toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: 30),
      ],
    );
  }

  Widget _buildPodiumCard({
    required int rank,
    required Map<String, dynamic> user,
    required bool isWinner,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => _openProfileFromLeaderboard(user),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: rank == 1
                  ? [Colors.amber.shade300, Colors.amber.shade500]
                  : rank == 2
                      ? [Colors.grey.shade300, Colors.grey.shade400]
                      : [Colors.brown.shade300, Colors.brown.shade400],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWinner) ...[
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/images/crown.png', height: 24),
                ),
                SizedBox(height: 8),
              ] else
                SizedBox(height: 40),

              // Rank badge
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    rank.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),

              // Avatar
              GestureDetector(
                onTap: () => _showUserMetricsModal(user),
                child: CircleAvatar(
                  radius: isWinner ? 40 : 35,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: isWinner ? 38 : 33,
                    backgroundImage: CachedNetworkImageProvider(
                      user['image'] == null || user['image'].toString().isEmpty
                          ? 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg'
                          : '${Url.mediaUrl}/${user['image']}',
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),

              // Username
              GestureDetector(
                onTap: () => _showUserMetricsModal(user),
                child: Text(
                  user['username'].length > 8
                      ? user['username'].substring(0, 8)
                      : user['username'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 4),

              // Leaderboard Score
              GestureDetector(
                onTap: () => _showUserMetricsModal(user),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      user['leaderboard_score'].toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize:
                            MediaQuery.of(context).size.width < 360 ? 10 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralPodiumCard({
    required int rank,
    required Map<String, dynamic> user,
    required bool isWinner,
  }) {
    return Expanded(
      child: InkWell(
        // onTap: () => _openProfileFromLeaderboard(user),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: rank == 1
                  ? [Colors.blue.shade300, Colors.blue.shade500]
                  : rank == 2
                      ? [Colors.grey.shade300, Colors.grey.shade400]
                      : [Colors.brown.shade300, Colors.brown.shade400],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isWinner) ...[
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/images/crown.png', height: 24),
                ),
                SizedBox(height: 8),
              ] else
                SizedBox(height: 40),

              // Rank badge
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    rank.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),

              // Avatar
              CircleAvatar(
                radius: isWinner ? 40 : 35,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: isWinner ? 38 : 33,
                  backgroundImage: CachedNetworkImageProvider(
                    user['image_url'] ??
                        'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg',
                  ),
                ),
              ),
              SizedBox(height: 8),

              // Username
              GestureDetector(
                // onTap: () => _openProfileFromLeaderboard(user),
                child: Text(
                  user['username'].length > 8
                      ? user['username'].substring(0, 8)
                      : user['username'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 4),

              // Referral count
              GestureDetector(
                // onTap: () => _openProfileFromLeaderboard(user),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      user['referral_count'].toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color.fromARGB(255, 9, 9, 9)
          : Colors.white,
      appBar: header(context: context, titleText: context.l10n.leaderboard),
      body: _isLoading && _isReferralLoading
          ? const Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Loading(),
            )
          : UpgradeAlert(
              showLater: false,
              barrierDismissible: false,
              showIgnore: false,
              dialogStyle: Platform.isIOS
                  ? UpgradeDialogStyle.cupertino
                  : UpgradeDialogStyle.material,
              upgrader: Upgrader(
                debugDisplayAlways: false,
                messages: MyUpgraderMessages(),
              ),
              child: Container(
                child: Popup(
                  popupArr: leaderpopup['popups'] as List<dynamic>? ?? [],
                  child: Column(
                    children: [
                      const BaakhaBannerAd(),
                      // Modern Tab bar for switching between Users and Referrals
                      Container(
                        margin: EdgeInsets.all(16),
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFF2A2A2A)
                                  : Colors.white,
                              Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFF1E1E1E)
                                  : Colors.grey.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.15),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.shade400,
                                Colors.orange.shade400
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey[600],
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                          unselectedLabelStyle: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          tabs: [
                            Tab(
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.emoji_events, size: 18),
                                    SizedBox(width: 8),
                                    Text(context.l10n.users),
                                  ],
                                ),
                              ),
                            ),
                            Tab(
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_alt_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(context.l10n.referrals),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tab bar view
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Main leaderboard tab
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: _buildMainLeaderboard(),
                            ),

                            // Referrals leaderboard tab
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: _buildReferralLeaderboard(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
