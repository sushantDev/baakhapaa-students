// ignore_for_file: unused_import

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/skeleton_loading.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;

import '../../models/url.dart';
import '../../providers/shorts.dart';
import '../../screens/shorts/single_shorts_screen.dart';
import '../challenges/challenge_detail_screen.dart';
import '../../providers/auth.dart';
import '../../providers/story.dart';
import '../../providers/challenge.dart';
import '../../widgets/header.dart';
import '../../widgets/TicketWidget.dart';
import '../../widgets/footer.dart';
import '../../widgets/share_with_qr_modal.dart';
import '../messages/messages_screen.dart';
import './episode_screen.dart';
import '../others/referrals_screen.dart';
// import '../analytics/analytics_screen.dart';
import '../../utils/debug_logger.dart';
import '../../utils/guest_auth_helper.dart';

class CreatorStoryScreen extends StatefulWidget {
  static const routeName = '/creator-story-screen';

  const CreatorStoryScreen({Key? key}) : super(key: key);

  @override
  State<CreatorStoryScreen> createState() => _CreatorStoryScreenState();
}

class _CreatorStoryScreenState extends State<CreatorStoryScreen> {
  var _isInit = true;
  var _isLoading = true;
  late List? _args;
  late int? _creatorId;
  Map<String, dynamic>? _creatorData; // Store full creator object if available
  bool _isAchievementsLoading = true;
  List<dynamic> _creatorAchievements = [];
  Map<String, dynamic> _creatorProfile = {}; // Store creator's profile data
  // ignore: unused_field
  int _creatorAchievementsCompleted = 0;
  // ignore: unused_field
  int _creatorAchievementsTotal = 0;

  // Store creator content data directly in widget state
  List<dynamic> _localCreatorSeasons = [];
  List<dynamic> _localCreatorShorts = [];

  // controls which content list is visible
  String _activeTab = 'stories'; // 'stories' | 'shorts'
  String _activeProgressTab = 'achievements'; // 'achievements' | 'challenges'
  bool _isBioExpanded = false;

  final _supportFormKey = GlobalKey<FormState>();
  final TextEditingController _supportPointsController =
      TextEditingController();
  final TextEditingController _supportMessageController =
      TextEditingController();
  bool _isFollowLoading = false;
  bool _isFollowing = false;
  int _followersCount = 0;
  String get creatorName {
    return (_args != null && _args!.length > 1) ? _args![1] : 'Creator';
  }

  // Visibility Check Helpers
  bool _isAchievementsVisible() {
    if (_creatorProfile.isEmpty) return true;
    final visibility = _creatorProfile['profile_visibility'];
    if (visibility == null || visibility is! Map) return true;
    return visibility['achievements'] != false;
  }

  bool _isChallengesVisible() {
    if (_creatorProfile.isEmpty) return true;
    final visibility = _creatorProfile['profile_visibility'];
    if (visibility == null || visibility is! Map) return true;
    return visibility['challenges'] != false;
  }

  bool _isShortsVisible() {
    if (_creatorProfile.isEmpty) return true;
    final visibility = _creatorProfile['profile_visibility'];
    if (visibility == null || visibility is! Map) return true;
    return visibility['shorts'] != false;
  }

  bool _isStoriesVisible() {
    if (_creatorProfile.isEmpty) return true;
    final visibility = _creatorProfile['profile_visibility'];
    if (visibility == null || visibility is! Map) return true;
    return visibility['stories'] != false;
  }

  // ignore: unused_element
  bool _isFollowersVisible() {
    if (_creatorProfile.isEmpty) return true;
    final visibility = _creatorProfile['profile_visibility'];
    if (visibility == null || visibility is! Map) return true;
    return visibility['followers'] != false;
  }

  bool _isPointsEarnedVisible() {
    if (_creatorProfile.isEmpty) return true;
    final visibility = _creatorProfile['profile_visibility'];
    if (visibility == null || visibility is! Map) return true;
    return visibility['points_earned'] != false;
  }

  bool _isLikesVisible() {
    if (_creatorProfile.isEmpty) return true;
    final visibility = _creatorProfile['profile_visibility'];
    if (visibility == null || visibility is! Map) return true;
    return visibility['likes'] != false;
  }

  bool _isViewCountVisible() {
    if (_creatorProfile.isEmpty) return true;
    final visibility = _creatorProfile['profile_visibility'];
    if (visibility == null || visibility is! Map) return true;
    return visibility['view_count'] != false;
  }

  // Fetch creator's public profile with privacy settings

  Widget _buildChallengeChip(Map<String, dynamic> challenge, bool isDarkTheme) {
    final String? imageUrl =
        challenge['image_url'] ?? challenge['thumbnail'] ?? challenge['cover'];

    return GestureDetector(
      onTap: () => _openChallenge(challenge),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          height: 72,
          child: imageUrl != null && imageUrl.toString().isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                    child: Icon(Icons.emoji_events, color: Colors.amber),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.emoji_events, color: Colors.amber),
                  ),
                )
              : const Center(
                  child: Icon(Icons.emoji_events, color: Colors.amber),
                ),
        ),
      ),
    );
  }

  void _openChallenge(Map<String, dynamic> challenge) {
    final challengeId = challenge['id'] ?? challenge['challenge_id'];
    if (challengeId == null) return;

    // Check if this is a season challenge
    final bool isSeason =
        challenge['is_challenge'] == true || challenge['is_challenge'] == 1;

    Navigator.of(context).pushNamed(
      ChallengeDetailScreen.routeName,
      arguments: isSeason
          ? {
              'id': challengeId,
              'isSeason': true,
            }
          : challengeId,
    );
  }

  List<Map<String, dynamic>> _resolveCreatorChallenges(
    Map<String, dynamic>? rankings,
    List<dynamic> challengePool,
    List<dynamic> enrolledChallenges,
  ) {
    final fromEnrolled = _normalizeChallengeList(enrolledChallenges);
    if (fromEnrolled.isNotEmpty) {
      return fromEnrolled;
    }

    final fromRankings = _extractChallengesFromRankings(rankings);
    if (fromRankings.isNotEmpty) {
      return fromRankings;
    }

    if (_creatorId == null) return [];
    final creatorId = _creatorId!;

    final filtered = challengePool
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((challenge) {
      final ownerId =
          _parseStatValue(challenge['user_id'] ?? challenge['creator_id']);
      if (ownerId == creatorId) return true;

      final participants = challenge['participants'];
      if (participants is List &&
          participants.any((participant) {
            final map = _asMap(participant);
            if (map == null) return false;
            final participantId = _parseStatValue(
                map['user_id'] ?? map['participant_id'] ?? map['id']);
            return participantId == creatorId;
          })) {
        return true;
      }

      final enrollments = challenge['enrollments'];
      if (enrollments is List &&
          enrollments.any((enrollment) {
            final map = _asMap(enrollment);
            if (map == null) return false;
            final enrolleeId =
                _parseStatValue(map['user_id'] ?? map['id'] ?? map['user']);
            return enrolleeId == creatorId;
          })) {
        return true;
      }

      return false;
    }).toList();

    return filtered;
  }

  List<Map<String, dynamic>> _extractChallengesFromRankings(
      Map<String, dynamic>? rankings) {
    if (rankings == null) return [];

    final List<dynamic> sources = [
      rankings['challenges'],
      rankings['creator_challenges'],
      rankings['enrolled_challenges'],
      rankings['challenge_enrollments'],
      rankings['user']?['challenges'],
      rankings['user']?['enrolled_challenges'],
    ];

    for (final source in sources) {
      final list = _normalizeChallengeList(source);
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  List<Map<String, dynamic>> _normalizeChallengeList(dynamic source) {
    final normalized = _normalizeToList(source);
    return normalized
        .map((item) => _asMap(item))
        .where((map) => map != null && map.isNotEmpty)
        .map((map) => Map<String, dynamic>.from(map!))
        .toList();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _isInit = false;

      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs == null) {
        // Handle invalid or missing arguments
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid creator data')),
            );
          }
        });
        return;
      }

      // Handle both old format (List) and new format (Map)
      if (routeArgs is List && routeArgs.length >= 2) {
        // Old format: [id, name]
        _args = routeArgs;
        _creatorId = _args?[0];
        _creatorData = null; // No full creator data in old format
      } else if (routeArgs is Map<String, dynamic>) {
        // New format: full creator object
        _creatorData = routeArgs;
        _creatorId = _creatorData?['id'];
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid creator data format')),
            );
          }
        });
        return;
      }

      // Validate creator ID before making API calls
      if (_creatorId == null) {
        DebugLogger.error('Creator ID is null');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid creator ID')),
            );
          }
        });
        return;
      }

      // Defer to post-frame to avoid setState() during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadInitialData();
      });
    }
    super.didChangeDependencies();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    try {
      // Cache all provider references BEFORE any async operations
      // This ensures we're checking the same provider instances that performed the fetch
      final storyProvider = Provider.of<Story>(context, listen: false);
      final shortsProvider = Provider.of<Shorts>(context, listen: false);
      final authProvider = Provider.of<Auth>(context, listen: false);
      final challengeProvider = Provider.of<Challenge>(context, listen: false);

      DebugLogger.info('All providers cached before async operations');

      // Execute fetches one by one with mounted checks to prevent disposed provider errors
      if (!mounted) return;

      final futures = <Future>[];

      // Story provider
      try {
        futures.add(storyProvider.fetchCreatorSeasons(_creatorId!));
        DebugLogger.info('Story provider fetch added to queue');
      } catch (e) {
        DebugLogger.error('Story provider error: $e');
      }

      // Shorts provider
      if (!mounted) return;
      try {
        futures.add(shortsProvider.fetchCreatorShorts(_creatorId!));
        DebugLogger.info('Shorts provider fetch added to queue');
      } catch (e) {
        DebugLogger.error('Shorts provider error: $e');
      }

      // Auth provider
      if (!mounted) return;
      try {
        futures.add(authProvider.fetchCreatorsRankings(_creatorId!));
        futures.add(authProvider.fetchCreatorEnrolledChallenges(_creatorId!));
        DebugLogger.info('Auth provider fetches added to queue');
      } catch (e) {
        DebugLogger.error('Auth provider error: $e');
      }

      // Challenge provider - only if still mounted
      if (mounted) {
        try {
          futures.add(challengeProvider.fetchChallenges());
          DebugLogger.info('Challenge provider fetch added to queue');
        } catch (e) {
          DebugLogger.error('Challenge provider error: $e');
        }
      }

      // Execute all fetches in parallel
      if (futures.isNotEmpty) {
        DebugLogger.info('Executing ${futures.length} fetch operations...');

        // Wait for all futures but catch errors individually
        final results = await Future.wait(
          futures.map((future) => future.catchError((error) {
                // Silently catch disposal errors
                if (error
                    .toString()
                    .contains('was used after being disposed')) {
                  DebugLogger.info(
                      'Provider disposed during fetch (expected if navigating away)');
                  return null;
                }
                DebugLogger.error('Fetch error: $error');
                return null;
              })),
          eagerError: false,
        );

        DebugLogger.info('All fetch operations completed');

        // Log successful operations
        for (var i = 0; i < results.length; i++) {
          if (results[i] != null) {
            DebugLogger.info('Fetch operation $i completed successfully');
          }
        }
      }

      if (!mounted) return;

      // Check what data we actually have after fetching
      // Use the SAME cached provider references from before async operations
      try {
        DebugLogger.info('Checking provider data using cached references...');
        DebugLogger.info(
            'After fetch - Stories count: ${storyProvider.creatorSeasonsCount}');
        DebugLogger.info(
            'After fetch - Shorts count: ${shortsProvider.creatorShortsCount}');
        DebugLogger.info(
            'After fetch - Stories data length: ${storyProvider.creatorSeasons.length}');
        DebugLogger.info(
            'After fetch - Shorts data length: ${shortsProvider.creatorShorts.length}');

        // Copy data to local state to ensure it persists
        _localCreatorSeasons = List.from(storyProvider.creatorSeasons);
        _localCreatorShorts = List.from(shortsProvider.creatorShorts);

        DebugLogger.info(
            '✅ Copied to local state - Stories: ${_localCreatorSeasons.length}, Shorts: ${_localCreatorShorts.length}');

        // Extract creator profile from rankings immediately to show subscription badge
        final rankings = authProvider.creatorsRankings;
        if (rankings.isNotEmpty) {
          if (_creatorProfile.isEmpty) {
            // Combine all ranking data into profile
            setState(() {
              _creatorProfile = Map<String, dynamic>.from(rankings);
            });
            DebugLogger.info('📊 Extracted profile from rankings');
            DebugLogger.info(
                '📊 Profile keys: ${_creatorProfile.keys.toList()}');
            DebugLogger.info(
                '📊 profile_visibility: ${_creatorProfile['profile_visibility']}');
            DebugLogger.info(
                'Creator Story Screen - Extracted full profile from rankings: ${_creatorProfile.keys.toList()}');
            DebugLogger.info(
                'Creator Story Screen - profile_visibility in rankings: ${_creatorProfile['profile_visibility']}');
            DebugLogger.info(
                'Creator Story Screen - Subscription expires at: ${_creatorProfile['subscription_expires_at']}');

            // Fetch creator's full user profile (including bio) using the username
            if (rankings['username'] != null) {
              try {
                final username = rankings['username'] as String;
                await authProvider.showUser(username);
                // After fetching user profile, update _creatorProfile with the full user data
                if (authProvider.teamMember.isNotEmpty) {
                  setState(() {
                    // Merge user data into profile, prioritizing user data for common fields
                    _creatorProfile.addAll(authProvider.teamMember);
                    DebugLogger.info(
                        'Updated profile with user data including bio');
                  });
                }
              } catch (e) {
                DebugLogger.error('Error fetching creator user profile: $e');
              }
            }
          }
        }

        // No need for separate fetch - profile_visibility is already in rankings
      } catch (e) {
        DebugLogger.error('Error checking provider data: $e');
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      await Future.wait([
        _loadCreatorAchievementsAndExtras(),
        _loadFollowRelationship(),
      ]);
    } catch (error) {
      DebugLogger.error('Error loading creator data: $error');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load creator data')),
      );
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isAchievementsLoading = true;
    });

    try {
      // Execute fetches one by one with mounted checks to prevent disposed provider errors
      if (!mounted) return;

      final futures = <Future>[];

      // Story provider
      try {
        final storyProvider = Provider.of<Story>(context, listen: false);
        futures.add(storyProvider.fetchCreatorSeasons(_creatorId!));
      } catch (e) {
        DebugLogger.error('Story provider error: $e');
      }

      // Shorts provider
      if (!mounted) return;
      try {
        final shortsProvider = Provider.of<Shorts>(context, listen: false);
        futures.add(shortsProvider.fetchCreatorShorts(_creatorId!));
      } catch (e) {
        DebugLogger.error('Shorts provider error: $e');
      }

      // Auth provider
      if (!mounted) return;
      try {
        final authProvider = Provider.of<Auth>(context, listen: false);
        futures.add(authProvider.fetchCreatorsRankings(_creatorId!));
        futures.add(authProvider.fetchCreatorEnrolledChallenges(_creatorId!));
      } catch (e) {
        DebugLogger.error('Auth provider error: $e');
      }

      // Challenge provider - only if still mounted
      if (mounted) {
        try {
          final challengeProvider =
              Provider.of<Challenge>(context, listen: false);
          futures.add(challengeProvider.fetchChallenges());
        } catch (e) {
          DebugLogger.error('Challenge provider error: $e');
        }
      }

      // Execute all fetches in parallel
      if (futures.isNotEmpty) {
        await Future.wait(futures, eagerError: false);
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      await Future.wait([
        _loadCreatorAchievementsAndExtras(),
        _loadFollowRelationship(),
      ]);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Creator data refreshed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      DebugLogger.error('Error refreshing creator data: $error');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isAchievementsLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh creator data'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadCreatorAchievements() async {
    if (_creatorId == null) {
      if (mounted) {
        setState(() {
          _isAchievementsLoading = false;
          _creatorAchievements = [];
          _creatorAchievementsCompleted = 0;
          _creatorAchievementsTotal = 0;
        });
      }
      return;
    }

    if (!mounted) return;

    try {
      // Get provider before async gap
      final auth = Provider.of<Auth>(context, listen: false);
      final result = await auth.fetchCreatorAchievements(_creatorId!);

      if (!mounted) return;

      List<dynamic> items = (result['items'] as List<dynamic>? ?? [])
          .where((item) => item != null)
          .toList();
      int completedFromApi =
          result['completed'] is int ? result['completed'] as int : 0;
      int totalFromApi = result['total'] is int ? result['total'] as int : 0;

      if (items.isEmpty) {
        items = _extractAchievementsFromRankings(auth.creatorsRankings);
      }

      if (totalFromApi == 0) {
        totalFromApi = _extractAchievementStat(
          auth.creatorsRankings,
          ['total', 'total_achievements', 'achievements_total'],
          defaultValue: items.length,
        );
      }

      if (completedFromApi == 0) {
        completedFromApi = _extractAchievementStat(
          auth.creatorsRankings,
          [
            'completed',
            'achievements_completed',
            'completed_achievements',
            'obtained',
            'claimed'
          ],
          defaultValue: _countCompletedAchievements(items),
        );
      }

      if (!mounted) return;

      setState(() {
        _creatorAchievements = items;
        _creatorAchievementsCompleted = completedFromApi > 0
            ? completedFromApi
            : _countCompletedAchievements(items);
        _creatorAchievementsTotal =
            totalFromApi > 0 ? totalFromApi : items.length;
      });
    } catch (error) {
      DebugLogger.error('Error loading creator achievements: $error');
      if (!mounted) return;
      setState(() {
        _creatorAchievements = [];
        _creatorAchievementsCompleted = 0;
        _creatorAchievementsTotal = 0;
      });
    }
  }

  Future<void> _loadCreatorAchievementsAndExtras() async {
    if (!mounted) return;
    setState(() {
      _isAchievementsLoading = true;
    });
    try {
      await _loadCreatorAchievements();
    } finally {
      if (mounted) {
        setState(() {
          _isAchievementsLoading = false;
        });
      }
    }
  }

  Future<void> _loadFollowRelationship() async {
    if (_creatorId == null) return;

    try {
      final auth = Provider.of<Auth>(context, listen: false);
      final rankings = auth.creatorsRankings;

      // Check if we have creator data from navigation (includes subscription info)
      if (_creatorData != null && _creatorData!.isNotEmpty) {
        DebugLogger.info(
            'Creator Story Screen - Using creator data from navigation: ${_creatorData!.keys.toList()}');
        DebugLogger.info(
            'Creator Story Screen - Creator data subscription: ${_creatorData!['subscription_expires_at']}');

        if (mounted) {
          setState(() {
            _creatorProfile = Map<String, dynamic>.from(_creatorData!);
          });
        }
      }

      // Get creator username from rankings
      final creatorUsername = _resolveCreatorUsername(rankings);

      DebugLogger.info(
          'Creator Story Screen - Creator ID: $_creatorId, Resolved Username: $creatorUsername, Display Name: $creatorName');
      DebugLogger.info(
          'Creator Story Screen - Rankings data keys: ${rankings.keys.toList()}');
      if (rankings.containsKey('user')) {
        DebugLogger.info(
            'Creator Story Screen - Rankings user object keys: ${(rankings['user'] as Map<String, dynamic>?)?.keys.toList() ?? []}');
        final userObj = rankings['user'] as Map<String, dynamic>?;
        if (userObj != null) {
          DebugLogger.info(
              'Creator Story Screen - Rankings user subscription: ${userObj['subscription_expires_at']}');
          DebugLogger.info(
              'Creator Story Screen - Rankings user premium: ${userObj['premium_expires_at']}');

          // If we don't have creator data from navigation, use rankings user data
          if (_creatorProfile.isEmpty && mounted) {
            setState(() {
              _creatorProfile = Map<String, dynamic>.from(userObj);
            });
            DebugLogger.info(
                'Creator Story Screen - Using rankings user data for profile');
          }
        }
      }

      // Ensure subscription data from rankings root is included if present
      if (rankings.containsKey('subscription_expires_at') &&
          !_creatorProfile.containsKey('subscription_expires_at')) {
        if (mounted) {
          setState(() {
            _creatorProfile['subscription_expires_at'] =
                rankings['subscription_expires_at'];
          });
          DebugLogger.info(
              'Creator Story Screen - Added subscription data from rankings root level');
        }
      }

      // Try multiple username options
      final usernameToUse =
          creatorUsername.isNotEmpty ? creatorUsername : creatorName;

      DebugLogger.info(
          'Creator Story Screen - Will try to fetch profile with username: $usernameToUse');

      if (usernameToUse.isEmpty) {
        DebugLogger.error('No username available for creator');
        return;
      }

      // Check relationship with this creator
      await auth.checkUserRelationship(usernameToUse);

      // If we still don't have creator profile data, try other sources
      if (_creatorProfile.isEmpty) {
        // Try rankings data first
        if (rankings.containsKey('user') &&
            rankings['user'] is Map<String, dynamic>) {
          final userFromRankings = rankings['user'] as Map<String, dynamic>;
          DebugLogger.info(
              'Creator Story Screen - Using user data from rankings: ${userFromRankings.keys.toList()}');
          DebugLogger.info(
              'Creator Story Screen - Rankings user subscription data: ${userFromRankings['subscription_expires_at']}');

          if (mounted) {
            setState(() {
              _creatorProfile = Map<String, dynamic>.from(userFromRankings);
              // Also include subscription data from root level if present
              if (rankings.containsKey('subscription_expires_at') &&
                  !_creatorProfile.containsKey('subscription_expires_at')) {
                _creatorProfile['subscription_expires_at'] =
                    rankings['subscription_expires_at'];
              }
            });
          }
        } else {
          // Fallback: try to fetch creator's profile data
          try {
            DebugLogger.info(
                'Creator Story Screen - No creator data available, fetching profile for: $usernameToUse');
            await auth.fetchPlayerProfile(usernameToUse);
            DebugLogger.info(
                'Creator Story Screen - Profile fetched successfully');

            if (mounted) {
              setState(() {
                _creatorProfile = Map<String, dynamic>.from(auth.playerProfile);
                // Merge subscription data from rankings if not in playerProfile
                if (rankings.containsKey('subscription_expires_at') &&
                    !_creatorProfile.containsKey('subscription_expires_at')) {
                  _creatorProfile['subscription_expires_at'] =
                      rankings['subscription_expires_at'];
                }
              });
              DebugLogger.info(
                  'Creator Story Screen - Creator profile set: ${_creatorProfile.keys.toList()}');
              DebugLogger.info(
                  'Creator Story Screen - Subscription data: ${_creatorProfile['subscription_expires_at']}');
            }
          } catch (e) {
            DebugLogger.error('Error fetching creator profile: $e');
            // Continue without profile data - premium badge will be hidden
          }
        }
      } else {
        // If we already have _creatorProfile, ensure it has subscription data from rankings
        if (!_creatorProfile.containsKey('subscription_expires_at') &&
            rankings.containsKey('subscription_expires_at')) {
          setState(() {
            _creatorProfile['subscription_expires_at'] =
                rankings['subscription_expires_at'];
          });
          DebugLogger.info(
              'Creator Story Screen - Added missing subscription data to existing profile');
        }
      }

      if (!mounted) return;

      setState(() {
        _isFollowing = auth.followData['is_following'] ?? false;
        _followersCount = auth.followData['followers_count'] ?? 0;
      });

      DebugLogger.info(
          'Follow relationship loaded: following=$_isFollowing, followers=$_followersCount');
    } catch (error) {
      DebugLogger.error('Error loading follow relationship: $error');
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_isFollowLoading || _creatorId == null) return;

    final auth = Provider.of<Auth>(context, listen: false);

    // Check if user is guest
    if (auth.isGuest) {
      GuestAuthHelper.showGuestLoginDialog(context, 'follow creators');
      return;
    }

    // Get creator username
    final rankings = auth.creatorsRankings;
    final creatorUsername = _resolveCreatorUsername(rankings);

    if (creatorUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to follow: Creator information not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isFollowLoading = true);

    try {
      final result = await auth.toggleFollowUser(creatorUsername);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _isFollowing = result['following'];
          if (result['following']) {
            _followersCount++;
          } else {
            _followersCount =
                (_followersCount - 1).clamp(0, double.infinity).toInt();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      DebugLogger.error('Error toggling follow: $error');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to ${_isFollowing ? 'unfollow' : 'follow'} creator'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  int _countCompletedAchievements(List<dynamic> achievements) {
    return achievements.where((achievement) {
      if (achievement is Map<String, dynamic>) {
        final claimed = achievement['claimed'];
        final obtained = achievement['obtained'];
        final completed = achievement['completed'];
        return claimed == 1 ||
            claimed == true ||
            obtained == 1 ||
            obtained == true ||
            completed == true;
      }
      return false;
    }).length;
  }

  String get creatorImageUrl {
    final auth = Provider.of<Auth>(context, listen: false);
    final creatorsRankings = auth.creatorsRankings;

    // 1. Use locally-available creator data passed via navigation args (freshest)
    for (final source in [
      _creatorData,
      _creatorProfile.isNotEmpty ? _creatorProfile : null
    ]) {
      if (source == null) continue;
      final url = source['user_image_url']?.toString() ??
          source['image_url']?.toString() ??
          source['image']?.toString();
      if (url != null && url.isNotEmpty) return url;
      // Try nested images array
      final imgs = source['images'];
      if (imgs is List && imgs.isNotEmpty) {
        final thumb =
            imgs[0]['thumbnail']?.toString() ?? imgs[0]['full']?.toString();
        if (thumb != null && thumb.isNotEmpty) return thumb;
      }
    }

    // 2. Rankings from provider (may still be previous creator's during load)
    if (creatorsRankings['user_image_url'] != null &&
        creatorsRankings['user_image_url'].toString().isNotEmpty) {
      return creatorsRankings['user_image_url'];
    }

    // 3. Nested user images in rankings
    final rankUser = creatorsRankings['user'];
    if (rankUser is Map &&
        rankUser['images'] is List &&
        (rankUser['images'] as List).isNotEmpty) {
      return (rankUser['images'] as List)[0]['thumbnail'] ??
          'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
    }

    // Final fallback
    return 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
  }

  String get creatorBio {
    final auth = Provider.of<Auth>(context, listen: false);
    final data = auth.creatorsRankings;
    String? bio;

    // First, try to get bio from creatorsRankings (flat structure)
    if (data['bio'] != null) {
      bio = data['bio']?.toString();
    }
    // Try _creatorProfile which might have been populated with user data
    else if (_creatorProfile.isNotEmpty && _creatorProfile['bio'] != null) {
      bio = _creatorProfile['bio']?.toString();
    }
    // Fallback to nested structure if it exists
    else if (data['user'] != null && data['user'] is Map) {
      bio = data['user']['bio']?.toString();
    }

    // Try 'about' field as fallback
    if ((bio == null || bio.isEmpty) && data['about'] != null) {
      bio = data['about']?.toString();
    }

    final roleValue = _resolveCreatorRoleValue(data);
    final roleDisplayName = _getRoleDisplayName(roleValue);

    final trimmed = bio?.trim();
    return (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : '$roleDisplayName and Guide';
  }

  // Helper method to convert role to display name
  String _getRoleDisplayName(dynamic role) {
    if (role == null) return 'Tutor';
    final roleStr = role.toString().toLowerCase().trim();
    switch (roleStr) {
      case 'creator':
      case 'teacher':
      case 'tutor':
        return 'Tutor';
      case 'player':
      case 'student':
        return 'Student';
      case 'vendor':
        return 'Vendor';
      default:
        return roleStr.replaceAllMapped(
          RegExp(r'(^\w|\s\w)'),
          (match) => match.group(0)!.toUpperCase(),
        );
    }
  }

  dynamic _resolveCreatorRoleValue(Map<String, dynamic> rankings) {
    return _creatorData?['role'] ??
        _creatorData?['user_type'] ??
        _creatorData?['type'] ??
        _creatorProfile['role'] ??
        _creatorProfile['user_type'] ??
        _creatorProfile['type'] ??
        rankings['role'] ??
        rankings['user_type'] ??
        rankings['type'] ??
        (rankings['user'] is Map ? rankings['user']['role'] : null) ??
        (rankings['user'] is Map ? rankings['user']['user_type'] : null) ??
        (rankings['user'] is Map ? rankings['user']['type'] : null);
  }

  @override
  Widget build(BuildContext context) {
    final _authProvider = Provider.of<Auth>(context, listen: false);

    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        extendBody: true,
        appBar: _isLoading
            ? null // Hide app bar during loading
            : header(context: context, titleText: creatorName),
        body: Stack(
          children: [
            // Show loading indicator that covers everything
            if (_isLoading)
              Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color(0xFF121212)
                    : Colors.white,
                child: const CreatorProfileSkeleton(),
              )
            else
              RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  child: Column(
                    children: [
                      _buildCreatorProfileHeader(),
                      // Stats are now shown inside the profile header
                      _buildActionsRow(_authProvider),
                      // _buildActivitySection(_authProvider),
                      _buildAchievementsChallengesSection(),
                      _buildCreationsSection(),
                      Footer.scrollBottomSpacer(context),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void StartConversation(Auth _authProvider, BuildContext context) {
    if (!mounted) return;

    // Validate creator ID before proceeding
    if (_creatorId == null) {
      DebugLogger.error('Creator ID is null in startConversation');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot start conversation: Invalid creator')),
      );
      return;
    }

    List<int> userIds = [_creatorId!];
    bool conversationStarted =
        _authProvider.creatorsRankings['conversation_started'] ?? false;

    // If conversation is already started, directly navigate to MessagesScreen
    if (conversationStarted) {
      _authProvider.startConversations(userIds).then((_) {
        Navigator.pushReplacementNamed(
          context,
          MessagesScreen.routeName,
          arguments: {
            'conversation_id': _authProvider.selectedConversationId,
            'user_name': creatorName,
          },
        );
      }).catchError((error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      });
      return;
    }

    // Otherwise show confirmation dialog for new conversation
    int conversationFee = int.parse(
        _authProvider.user['interaction_points_fee']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.send, color: Colors.amber),
              SizedBox(width: 8),
              Text('Start Conversation', style: TextStyle(color: Colors.amber)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      'Message $creatorName',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'It costs $conversationFee points to start a conversation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Once started, you can message this creator directly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                try {
                  Navigator.of(dialogContext).pop();

                  await _authProvider.startConversations(userIds);

                  if (!mounted) return;

                  if (conversationFee > 0) {
                    await _authProvider.coinTransaction(
                        conversationFee,
                        'debited',
                        'Fee for starting a conversation with $creatorName.');
                  }

                  if (!mounted) return;

                  await Navigator.of(context).pushReplacementNamed(
                    MessagesScreen.routeName,
                    arguments: {
                      'conversation_id': _authProvider.selectedConversationId,
                      'user_name': creatorName,
                    },
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to start conversation: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text("Start Chat"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreatorProfileHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.black, // Solid black background to match screenshot
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Consumer<Auth>(
        builder: (_, auth, __) {
          final rankings = auth.creatorsRankings;
          final roleValue = _resolveCreatorRoleValue(rankings);
          final creatorRoleLabel = _getRoleDisplayName(roleValue);
          final int bpts = _resolveCreatorPoints(rankings);
          final int leaderboardRank = _resolveLeaderboardRank(rankings);
          final int referralRank = _parseStatValue(rankings['referral_rank']);
          final String leaderboardRankLabel =
              leaderboardRank > 0 ? '$leaderboardRank' : 'N/A';
          final String referralRankLabel =
              referralRank > 0 ? '$referralRank' : 'N/A';
          final int level = _resolveCreatorLevel(rankings);
          final String joinedDate = _formatJoinedDate(rankings);
          final String location = _resolveCreatorLocation(rankings);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture with Overlays
                  GestureDetector(
                    onTap: () => _showProfilePreview(auth),
                    child: Transform.translate(
                      offset: const Offset(0, 6),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 132,
                            height: 132,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: creatorImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(Icons.person,
                                        color: Colors.white70),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(Icons.person,
                                        color: Colors.white70),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Level Badge (top-left)
                          Positioned(
                            top: -6,
                            left: -6,
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(
                                    255, 17, 16, 40), // Purple
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    'Level $level',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Currency Badge (bottom-center) - Only show if points_earned is visible
                          if (_isPointsEarnedVisible())
                            Positioned(
                              bottom: -6,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(
                                          'assets/images/coins.png',
                                          width: 14,
                                          height: 14,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          bpts.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ]),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Add breathing room between avatar and details to match button spacing
                  const SizedBox(width: 12),
                  // Creator Information Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Name row with actions inline
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Role label
                                  Text(
                                    creatorRoleLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  // Keep name on a single line; scale down slightly if needed
                                  FittedBox(
                                    alignment: Alignment.centerLeft,
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          creatorName,
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            height: 1.05,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.visible,
                                          softWrap: false,
                                        ),
                                        const SizedBox(width: 6),
                                        Builder(
                                          builder: (context) {
                                            // Build comprehensive profile data for badge
                                            final profileToUse =
                                                Map<String, dynamic>.from(
                                                    _creatorProfile);

                                            // If subscription data is missing from profile, check rankings
                                            if (!profileToUse.containsKey(
                                                    'subscription_expires_at') &&
                                                rankings.containsKey(
                                                    'subscription_expires_at')) {
                                              profileToUse[
                                                      'subscription_expires_at'] =
                                                  rankings[
                                                      'subscription_expires_at'];
                                            }

                                            // Also check premium_expires_at
                                            if (!profileToUse.containsKey(
                                                    'premium_expires_at') &&
                                                rankings.containsKey(
                                                    'premium_expires_at')) {
                                              profileToUse[
                                                      'premium_expires_at'] =
                                                  rankings[
                                                      'premium_expires_at'];
                                            }

                                            // Check if rankings has a user object with subscription data
                                            if (profileToUse.isEmpty &&
                                                rankings.containsKey('user') &&
                                                rankings['user'] is Map) {
                                              final userFromRankings =
                                                  rankings['user']
                                                      as Map<String, dynamic>;
                                              profileToUse
                                                  .addAll(userFromRankings);
                                            }

                                            DebugLogger.info(
                                                'Creator Story Screen - Rendering badge with profile: ${profileToUse.keys.toList()}');
                                            DebugLogger.info(
                                                'Creator Story Screen - Subscription field: ${profileToUse['subscription_expires_at']}');
                                            DebugLogger.info(
                                                'Creator Story Screen - Premium field: ${profileToUse['premium_expires_at']}');
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Transform.scale(
                              scale: 0.85,
                              child: _circleIconButton(
                                icon: Icons.share_outlined,
                                onTap: () async {
                                  final shareText = '''
          Check out $creatorName on Baakhapaa!

                                  🔗 View profile: ${Url.deepLink('/referral/$creatorName')}

          Using  $creatorName as refer code and both receive 25 bonus points when you create an account.
          '''
                                      .trim();

                                  try {
                                    await SharePlus.instance.share(
                                      ShareParams(
                                        text: shareText,
                                        sharePositionOrigin:
                                            Rect.fromLTWH(0, 0, 100, 100),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to share profile link'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Transform.scale(
                              scale: 0.85,
                              child: _circleIconButton(
                                icon: Icons.group_outlined,
                                onTap: () => Navigator.of(context)
                                    .pushNamed(ReferralsScreen.routeName),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Transform.scale(
                              scale: 0.85,
                              child: _circleIconButton(
                                icon: Icons.flag_outlined,
                                onTap: () =>
                                    _showReportCreatorDialog(context, auth),
                              ),
                            ),
                          ],
                        ),
                        // Location - No gap, tightly packed
                        const SizedBox(height: 6),
                        Text(
                          location,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Bio/Description - Matching profile page styling
                        Builder(
                          builder: (BuildContext context) {
                            final bioText = creatorBio;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bioText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  maxLines: _isBioExpanded ? null : 3,
                                  overflow: _isBioExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                ),
                                if (bioText.length > 65)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isBioExpanded = !_isBioExpanded;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        _isBioExpanded
                                            ? 'See less'
                                            : 'See more',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        // Info badges inline with a slight right offset to align with action buttons
                        Transform.translate(
                          offset: const Offset(-1, -1),
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _infoBadge('Joined at: $joinedDate'),
                                const SizedBox(width: 3),
                                _infoBadge('Rank: $leaderboardRankLabel'),
                                const SizedBox(width: 3),
                                _infoBadge('Referral Rank: $referralRankLabel'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16), // More circular/pill-shaped
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 30,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.visible,
        softWrap: true,
      ),
    );
  }

  Widget _circleIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showReportCreatorDialog(BuildContext context, Auth auth) {
    final int? creatorId = auth.creatorsRankings['user'] is Map
        ? int.tryParse((auth.creatorsRankings['user']['id'] ?? '').toString())
        : null;
    String _selectedReason = 'Spam';
    final List<String> reasons = [
      'Spam',
      'Harassment or bullying',
      'Hate speech',
      'Inappropriate content',
      'Impersonation',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.flag_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Report Creator'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why are you reporting $creatorName?',
                  style: TextStyle(fontSize: 13)),
              SizedBox(height: 12),
              ...reasons.map((r) => RadioListTile<String>(
                    dense: true,
                    title: Text(r, style: TextStyle(fontSize: 13)),
                    value: r,
                    groupValue: _selectedReason,
                    onChanged: (v) =>
                        setDialogState(() => _selectedReason = v!),
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await auth.reportContent(
                    type: 'creator',
                    targetId: creatorId ?? 0,
                    reason: _selectedReason,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Report submitted. Thank you.'),
                      backgroundColor: Colors.green,
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareProfileModal(BuildContext context, String shareText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Share Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Consumer<Auth>(
              builder: (ctx, auth, _) => FutureBuilder(
                future: auth.fetchConversations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListSkeleton(itemCount: 3);
                  }
                  final conversations = auth.conversations;
                  if (conversations.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No recent conversations'),
                    );
                  }
                  return SizedBox(
                    height: 200,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: conversations.length,
                      itemBuilder: (ctx, index) {
                        final conversation = conversations[index];
                        final userImage = conversation['user_image'] ?? '';
                        final name = conversation['name'] ?? '';
                        final username = conversation['username'];

                        return GestureDetector(
                          onTap: () {
                            final authProvider =
                                Provider.of<Auth>(context, listen: false);
                            authProvider
                                .sendMessages(
                              conversation['conversation_id'],
                              shareText,
                              'text',
                              null,
                              null,
                            )
                                .then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Shared Successfully!')),
                              );
                              Navigator.pop(context);
                            }).catchError((error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Failed to share. Please try again.')),
                              );
                            });
                          },
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: userImage.isNotEmpty
                                    ? CachedNetworkImageProvider(userImage)
                                    : null,
                                child: userImage.isEmpty
                                    ? Text(name.isEmpty ? username[0] : name[0])
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                name.isEmpty ? username : name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.share,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              title: const Text('Share to Other Apps'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: shareText,
                    subject: "Join Skill Sikka and earn points!",
                    sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
                  ),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Share using QR'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => ShareWithQrModal(
                    data: shareText,
                    subject: "Join Skill Sikka and earn points!",
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showProfilePreview(Auth auth) {
    if (!mounted) return;
    final rootContext = context;
    final rankings = auth.creatorsRankings;
    final int creationCount =
        _localCreatorSeasons.length + _localCreatorShorts.length;
    final String followers = _formatCompactNumber(_followersCount);
    final String creations = _formatCompactNumber(creationCount);
    final int level = _resolveCreatorLevel(rankings);
    final String location = _resolveCreatorLocation(rankings);
    final String bio = creatorBio;
    final String shareText = 'Check out $creatorName on Baakhapaa';
    final int storiesCount = _localCreatorSeasons.length;
    final int shortsCount = _localCreatorShorts.length;

    showDialog(
      context: rootContext,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        void closeDialog() {
          Navigator.of(dialogContext).maybePop();
        }

        void handleFollow() {
          closeDialog();
          _handleFollowToggle();
        }

        void handleQrShare() {
          closeDialog();
          showModalBottomSheet(
            context: rootContext,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => ShareWithQrModal(
              data: shareText,
              subject: 'Share $creatorName',
            ),
          );
        }

        void handleShare() {
          closeDialog();
          final shareText = '''
          Check out $creatorName on Baakhapaa!

            🔗 View profile: ${Url.deepLink('/referral/$creatorName')}

          Using  $creatorName as refer code and both receive 25 bonus points when you create an account.
          '''
              .trim();
          _showShareProfileModal(rootContext, shareText);
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: _buildProfilePreviewCard(
            imageUrl: creatorImageUrl,
            name: creatorName,
            location: location,
            bio: bio,
            followers: followers,
            creations: creations,
            level: level,
            shortsCount: shortsCount,
            storiesCount: storiesCount,
            onClose: closeDialog,
            onFollow: handleFollow,
            // onAnalytics: handleAnalytics,
            onQr: handleQrShare,
            onShare: handleShare,
          ),
        );
      },
    );
  }

  Widget _buildProfilePreviewCard({
    required String imageUrl,
    required String name,
    required String location,
    required String bio,
    required String followers,
    required int shortsCount,
    required int storiesCount,
    required String creations,
    required int level,
    required VoidCallback onClose,
    required VoidCallback onFollow,
    // required VoidCallback onAnalytics,
    required VoidCallback onQr,
    required VoidCallback onShare,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F0F0F), Color(0xFF2B1A0E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(colors: [
                Colors.amber,
                Colors.deepOrange,
                Colors.pinkAccent,
                Colors.amber,
              ]),
            ),
            child: CircleAvatar(
              radius: 70,
              backgroundColor: Colors.black,
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 132,
                  height: 132,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.person,
                        color: Colors.white70, size: 40),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.person,
                        color: Colors.white70, size: 40),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            location,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _profilePreviewFollowersStat('Followers', followers)),
              const SizedBox(width: 10),
              Expanded(
                  child: _profilePreviewStat('Shorts', shortsCount.toString())),
              const SizedBox(width: 10),
              Expanded(
                  child:
                      _profilePreviewStat('Stories', storiesCount.toString())),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _profilePreviewActionButton(
                icon: _isFollowing ? Icons.check : Icons.person_add_alt_1,
                label: _isFollowing ? 'Following' : 'Follow',
                onTap: onFollow,
              ),
              // _profilePreviewActionButton(
              //   icon: Icons.analytics_outlined,
              //   label: 'Analytics',
              //   onTap: onAnalytics,
              // ),
              _profilePreviewActionButton(
                icon: Icons.qr_code,
                label: 'QR code',
                onTap: onQr,
              ),
              _profilePreviewActionButton(
                icon: Icons.share_outlined,
                label: 'Share Profile',
                onTap: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profilePreviewStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _profilePreviewFollowersStat(String label, String value) {
    if (_isFollowersVisible()) {
      return _profilePreviewStat(label, value);
    }
    // Show locked icon when followers count is hidden
    return Column(
      children: [
        Icon(
          Icons.lock,
          size: 24,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _profilePreviewActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCompactNumber(int value) {
    if (value >= 1000000) {
      final double millions = value / 1000000;
      return millions.toStringAsFixed(
              millions.truncateToDouble() == millions ? 0 : 1) +
          'M';
    }
    if (value >= 1000) {
      final double thousands = value / 1000;
      return thousands.toStringAsFixed(
              thousands.truncateToDouble() == thousands ? 0 : 1) +
          'K';
    }
    return value.toString();
  }

  int _resolveCreatorLevel(Map<String, dynamic>? rankings) {
    if (rankings == null) return 1;
    final user = rankings['user'] as Map<String, dynamic>?;
    final candidates = [
      rankings['current_level'],
      rankings['level'],
      rankings['creator_level'],
      user?['level'],
      user?['current_level'],
      user?['creator_level'],
      user?['xp_level'],
    ];
    for (final candidate in candidates) {
      final parsed = _parseStatValue(candidate);
      if (parsed > 0) {
        return parsed;
      }
    }
    return 1;
  }

  int _resolveLeaderboardRank(Map<String, dynamic>? rankings) {
    if (rankings == null) return 0;
    final user = rankings['user'] as Map<String, dynamic>?;
    final candidates = [
      rankings['leaderboard_rank'],
      rankings['rank'],
      rankings['overall_rank'],
      user?['leaderboard_rank'],
      user?['rank'],
    ];

    for (final candidate in candidates) {
      final parsed = _parseStatValue(candidate);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  String _resolveCreatorLocation(Map<String, dynamic>? rankings) {
    if (rankings == null) return 'Worldwide';
    final user = rankings['user'] as Map<String, dynamic>?;
    final String? city = _firstNonEmptyString([
      rankings['city'],
      rankings['location_city'],
      rankings['location'],
      user?['city'],
      user?['location_city'],
      user?['location'],
    ]);
    final String? country = _firstNonEmptyString([
      rankings['country'],
      rankings['location_country'],
      user?['country'],
      user?['location_country'],
    ]);

    if (city != null && country != null) {
      return '$city, $country';
    }
    return city ?? country ?? 'Kathmandu, Nepal';
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }
    return null;
  }

  String _formatJoinedDate(Map<String, dynamic>? rankings) {
    if (rankings == null) return '1/1/2020';
    final user = rankings['user'] as Map<String, dynamic>?;
    final candidates = [
      rankings['created_at'],
      rankings['joined_at'],
      user?['created_at'],
      user?['joined_at'],
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      try {
        DateTime date;
        if (candidate is String) {
          date = DateTime.parse(candidate);
        } else if (candidate is DateTime) {
          date = candidate;
        } else {
          continue;
        }
        return '${date.month}/${date.day}/${date.year}';
      } catch (e) {
        continue;
      }
    }
    return '1/1/2020';
  }

  String _achievementTitle(Map<String, dynamic> data) {
    final possibles = [
      data['title'],
      data['name'],
      data['label'],
      data['achievement'],
    ];
    return possibles
        .firstWhere(
          (value) => value != null && value.toString().trim().isNotEmpty,
          orElse: () => 'Achievement',
        )
        .toString();
  }

  String _achievementDescription(Map<String, dynamic> data) {
    final possibles = [
      data['description'],
      data['details'],
      data['summary'],
      data['about'],
    ];
    return possibles
        .firstWhere(
          (value) => value != null && value.toString().trim().isNotEmpty,
          orElse: () => 'No description available',
        )
        .toString();
  }

  String? _achievementImageUrl(Map<String, dynamic> data) {
    final possibles = [
      data['badge_url'],
      data['image_url'],
      data['url'],
      data['icon'],
      data['thumbnail'],
      data['logo'],
    ];
    for (final candidate in possibles) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  bool _isAchievementUnlocked(Map<String, dynamic> data) {
    final candidates = [
      data['claimed'],
      data['obtained'],
      data['completed'],
      data['status'],
      data['unlocked'],
    ];

    return candidates.any((value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value > 0;
      if (value is String) {
        final normalized = value.toLowerCase();
        return normalized.contains('true') ||
            normalized.contains('done') ||
            normalized.contains('complete') ||
            normalized.contains('unlocked') ||
            normalized.contains('claimed');
      }
      return false;
    });
  }

  List<dynamic> _extractAchievementsFromRankings(
      Map<String, dynamic> rankings) {
    final candidates = [
      rankings['achievements'],
      rankings['creator_achievements'],
      rankings['achievement_badges'],
      rankings['badges'],
      rankings['user']?['achievements'],
      rankings['user']?['achievement_badges'],
      rankings['user']?['achievements']?['items'],
    ];

    for (final candidate in candidates) {
      final normalized = _normalizeToList(candidate);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return [];
  }

  List<dynamic> _normalizeToList(dynamic source) {
    if (source == null) return [];
    if (source is List) {
      return source.where((item) => item != null).toList();
    }
    if (source is Map) {
      if (source['items'] is List) {
        return (source['items'] as List).where((item) => item != null).toList();
      }
      final listEntry = source.entries.firstWhere(
        (entry) => entry.value is List,
        orElse: () => const MapEntry<String, dynamic>('', []),
      );
      if (listEntry.value is List) {
        return (listEntry.value as List).where((item) => item != null).toList();
      }
    }
    return [];
  }

  int _extractAchievementStat(
    Map<String, dynamic> rankings,
    List<String> candidateKeys, {
    int defaultValue = 0,
  }) {
    for (final key in candidateKeys) {
      final value = rankings[key] ??
          rankings['user']?[key] ??
          rankings['achievements']?[key] ??
          rankings['user']?['achievements']?[key];
      final parsed = _parseStatValue(value);
      if (parsed > 0) {
        return parsed;
      }
    }
    return defaultValue;
  }

  int _parseStatValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  int _resolveCreatorPoints(Map<String, dynamic>? rankings) {
    if (rankings == null) return 0;

    final root = rankings;
    final user = _asMap(rankings['user']);
    final stats = _asMap(rankings['stats']);
    final meta = _asMap(rankings['meta']);
    final achievements = _asMap(rankings['achievements']);
    final information = user != null ? _asMap(user['information']) : null;
    final wallet = user != null ? _asMap(user['wallet']) : null;
    final walletList = user?['wallets'];

    final candidateKeys = [
      'interaction_points_balance',
      'interaction_points',
      'coins',
      'coin',
      'total_points',
      'total_coins',
      'total_coin',
      'points',
      'sikka',
      'total_sikka',
      'points_balance',
      'coins_balance',
      'coin_balance',
      'points_total',
      'available_points',
      'available_coins',
      'available_sikka',
      'available_sikka',
      'available_baakhapaa_point',
      'total_points_balance',
      'total_coins_balance',
      'total_available_points',
      'baakhapaa_points',
      'baakhapaa_point_balance',
      'baakhapaa_points_balance',
      'total_baakhapaa_points',
    ];

    final mapsToSearch = [
      root,
      user,
      stats,
      meta,
      achievements,
      information,
      wallet,
    ];

    for (final map in mapsToSearch) {
      if (map == null) continue;
      for (final key in candidateKeys) {
        final parsed = _parseStatValue(map[key]);
        if (parsed > 0) {
          return parsed;
        }
      }
    }

    if (walletList is List) {
      for (final walletEntry in walletList) {
        final map = _asMap(walletEntry);
        if (map == null) continue;
        for (final key in candidateKeys) {
          final parsed = _parseStatValue(map[key]);
          if (parsed > 0) {
            return parsed;
          }
        }
      }
    }

    if (user != null) {
      final fallback = _searchPointsInsideUser(user);
      if (fallback > 0) {
        return fallback;
      }
    }

    return 0;
  }

  int _searchPointsInsideUser(dynamic node) {
    if (node is Map<String, dynamic>) {
      for (final entry in node.entries) {
        final key = entry.key.toLowerCase();
        final value = entry.value;
        if (value == null) continue;

        if (value is Map<String, dynamic> || value is List) {
          final nested = _searchPointsInsideUser(value);
          if (nested > 0) return nested;
        } else if ((key.contains('point') || key.contains('bpt')) &&
            !key.contains('fee') &&
            !key.contains('required')) {
          final parsed = _parseStatValue(value);
          if (parsed > 0) {
            return parsed;
          }
        }
      }
    } else if (node is List) {
      for (final item in node) {
        final nested = _searchPointsInsideUser(item);
        if (nested > 0) return nested;
      }
    }
    return 0;
  }

  // ignore: unused_element
  String _resolveCreatorUsername(Map<String, dynamic>? rankings) {
    if (rankings == null) return '';
    final user = rankings['user'] as Map<String, dynamic>?;
    final candidates = [
      rankings['username'],
      rankings['user_name'],
      user?['username'],
      user?['user_name'],
      user?['display_name'],
      user?['name'],
    ];

    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return '';
  }

  void _showAllAchievementsSheet() {
    if (_creatorAchievements.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1C1C1C)
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${creatorName}'s ${context.l10n.achievements}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${_creatorAchievements.length}',
                          style: TextStyle(
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _creatorAchievements.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final achievement = _creatorAchievements[index];
                        // ignore: unused_local_variable
                        // _normalizeAchievement(_creatorAchievements[index]);
                        final unlocked = _isAchievementUnlocked(achievement);
                        final imageUrl = _achievementImageUrl(achievement);

                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          tileColor: unlocked
                              ? Colors.amber.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.08),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                unlocked ? Colors.amber : Colors.grey.shade400,
                            child: imageUrl != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      width: 48,
                                      height: 48,
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.emoji_events),
                                    ),
                                  )
                                : const Icon(Icons.emoji_events,
                                    color: Colors.white),
                          ),
                          title: Text(
                            _achievementTitle(achievement),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            _achievementDescription(achievement),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: unlocked
                              ? Icon(Icons.check_circle,
                                  color: Colors.green.shade600)
                              : Icon(Icons.lock_outline,
                                  color: Colors.grey.shade600),
                          onTap: () => _showAchievementDetails(achievement),
                        );
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

  void _showAchievementDetails(Map<String, dynamic> achievement) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final unlocked = _isAchievementUnlocked(achievement);
        final imageUrl = _achievementImageUrl(achievement);

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                unlocked ? Icons.emoji_events : Icons.lock_outline,
                color: unlocked ? Colors.amber : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_achievementTitle(achievement))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                _achievementDescription(achievement),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.close),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionsRow(Auth authProvider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          // Follow/Following Button
          Expanded(
            child: ElevatedButton(
              onPressed: _isFollowLoading ? null : _handleFollowToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isFollowing ? Colors.black : const Color(0xFFFFD700),
                foregroundColor:
                    _isFollowing ? const Color(0xFFFFD700) : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: const Color(0xFFFFD700),
                    width: 1,
                  ),
                ),
                elevation: 0,
                disabledBackgroundColor: Colors.grey,
              ),
              child: _isFollowLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isFollowing ? Icons.check : Icons.person_add,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Message Button
          Expanded(
            child: ElevatedButton(
              onPressed: () => StartConversation(authProvider, context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2A2A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/svgs/message_2.svg',
                    height: 18,
                    width: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Message',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Donation Icon Button
          Container(
            width: 56,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openSupportCreatorSheet,
                borderRadius: BorderRadius.circular(12),
                child: const Center(
                  child: Icon(
                    Icons.volunteer_activism,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupportCreatorSheet() async {
    if (_creatorId == null) return;

    final auth = Provider.of<Auth>(context, listen: false);

    if (auth.isGuest) {
      GuestAuthHelper.showGuestLoginDialog(
        context,
        context.l10n.supportCreator,
      );
      return;
    }

    final availablePoints = auth.userAvailableCoins;
    _supportPointsController.clear();
    _supportMessageController.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Future<void> _submitSupport() async {
          final form = _supportFormKey.currentState;
          if (form == null || !form.validate()) return;

          final points =
              int.tryParse(_supportPointsController.text.trim()) ?? 0;
          final message = _supportMessageController.text.trim();

          try {
            await auth.donation(points, _creatorId!, message, 'creator');
            if (!mounted) return;
            Navigator.of(sheetContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Thanks for supporting $creatorName!'),
              ),
            );
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to process support right now.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.pink.shade400,
                              Colors.red.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.supportCreator,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              'Support $creatorName with baakhapaa points.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8C383).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/coins.png',
                          width: 22,
                          height: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Available: $availablePoints',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [50, 100, 250, 500].map((amount) {
                      return ActionChip(
                        label: Text('$amount'),
                        onPressed: () =>
                            _supportPointsController.text = amount.toString(),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _supportFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _supportPointsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Points',
                            hintText: 'Enter points to send',
                          ),
                          validator: (value) {
                            final parsed = int.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid amount';
                            }
                            if (parsed > availablePoints) {
                              return 'Not enough baakhapaa points';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _supportMessageController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Message (optional)',
                            hintText: 'Add a note for this creator',
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _submitSupport,
                            child: const Text(
                              'Support now',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
      },
    );
  }

  // ignore: unused_element
  Widget _buildActivitySection(Auth auth) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final rankings = auth.creatorsRankings;
    final metrics = [
      {
        'icon': Icons.emoji_events_rounded,
        'label': 'Challenges',
        'value': _parseStatValue(rankings['challenges_enrolled_count'] ??
            rankings['challenges_count']),
        'color': Colors.orangeAccent,
      },
      {
        'icon': Icons.visibility_rounded,
        'label': 'Episode Views',
        'value': _parseStatValue(
          rankings['episode_enrollments_count'] ??
              rankings['episode_views'] ??
              rankings['views_count'],
        ),
        'color': Colors.greenAccent,
      },
      {
        'icon': Icons.movie_filter_rounded,
        'label': 'Seasons',
        'value': _localCreatorSeasons.length,
        'color': Colors.purpleAccent,
      },
      {
        'icon': Icons.favorite_rounded,
        'label': 'Likes',
        'value': _parseStatValue(rankings['shorts_likes_count']),
        'color': Colors.pinkAccent,
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Detailed activity coming soon.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  context.l10n.viewAll,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: metrics.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final metric = metrics[index];
                return _activityMetricChip(
                  icon: metric['icon'] as IconData,
                  label: metric['label'] as String,
                  value: metric['value'] as int,
                  color: metric['color'] as Color,
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityMetricChip({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatCompactNumber(value),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsChallengesSection() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<Auth, Challenge>(
      builder: (_, auth, challenges, __) {
        final enrolledChallenges = auth.getCreatorEnrolledChallenges(
          _creatorId ?? 0,
        );
        final creatorChallenges = _resolveCreatorChallenges(
          auth.creatorsRankings,
          challenges.challenges,
          enrolledChallenges,
        );
        final displayChallenges = creatorChallenges.take(10).toList();

        final achievementsCount = _creatorAchievements.length;
        final challengesCount = creatorChallenges.length;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : const Color(0xFF141414),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.20),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressTabs(
                isDark: isDark,
                achievementsCount: achievementsCount,
                challengesCount: challengesCount,
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_activeProgressTab),
                  child: _activeProgressTab == 'achievements'
                      ? _buildAchievementsContent(isDark)
                      : _buildChallengesContent(displayChallenges, isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressTabs({
    required bool isDark,
    required int achievementsCount,
    required int challengesCount,
  }) {
    // Always include all tabs, but disable visually if not visible
    final tabs = [
      {
        'key': 'achievements',
        'label': 'Achievements',
        'count': achievementsCount,
        'isVisible': _isAchievementsVisible(),
      },
      {
        'key': 'challenges',
        'label': 'Challenges',
        'count': challengesCount,
        'isVisible': _isChallengesVisible(),
      },
    ];

    return Row(
      children: tabs.map((tab) {
        final key = tab['key'] as String;
        final label = tab['label'] as String;
        final count = tab['count'] as int;
        final isVisible = tab['isVisible'] as bool;
        final bool isActive = _activeProgressTab == key;

        return Expanded(
          child: GestureDetector(
            onTap: isVisible
                ? () => setState(() => _activeProgressTab = key)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: !isVisible
                              ? Colors.grey.withValues(alpha: 0.4)
                              : isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: !isVisible
                              ? Colors.grey.withValues(alpha: 0.3)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: !isVisible
                          ? Colors.transparent
                          : isActive
                              ? Colors.grey
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHiddenContentMessage(bool isDark) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF272727) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outlined,
              color: Colors.grey.withValues(alpha: 0.6),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              'User has kept this hidden',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsContent(bool isDark) {
    // Check visibility first
    if (!_isAchievementsVisible()) {
      return _buildHiddenContentMessage(isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "${creatorName}'s Achievements",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            TextButton(
              onPressed: _creatorAchievements.isEmpty
                  ? null
                  : () => _showAllAchievementsSheet(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                "View all",
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_isAchievementsLoading)
          const SizedBox(
            height: 55,
            child: ShimmerLoading(
              child: Row(
                children: [
                  SkeletonBox(width: 55, height: 55, borderRadius: 8),
                  SizedBox(width: 8),
                  SkeletonBox(width: 55, height: 55, borderRadius: 8),
                  SizedBox(width: 8),
                  SkeletonBox(width: 55, height: 55, borderRadius: 8),
                ],
              ),
            ),
          )
        else if (_creatorAchievements.isEmpty)
          SizedBox(
            height: 55,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.emoji_events_outlined,
                      size: 32, color: Colors.grey),
                  SizedBox(height: 4),
                  Text('No achievements yet',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _creatorAchievements.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final achievement =
                    _creatorAchievements[index] as Map<String, dynamic>? ?? {};
                final imageUrl = _achievementImageUrl(achievement);

                return GestureDetector(
                  onTap: () => _showAchievementDetails(achievement),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: TicketShape(
                      height: 50,
                      notchRadius: 3,
                      notchDepth: 2.5,
                      scallopRadius: 2,
                      scallopCount: 3,
                      child: Container(
                        width: 90,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 240, 223, 174),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: (imageUrl != null &&
                                imageUrl.toString().trim().isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildChallengesContent(
    List<Map<String, dynamic>> displayChallenges,
    bool isDark,
  ) {
    const subtitle = 'Challenges user has participated';

    // Check visibility first
    if (!_isChallengesVisible()) {
      return _buildHiddenContentMessage(isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 12),
        if (displayChallenges.isEmpty)
          _buildEmptyChallengesState(isDark)
        else
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: displayChallenges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final challenge = displayChallenges[index];
                return _buildChallengeChip(challenge, isDark);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyChallengesState(bool isDark) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF272727) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Center(
        child: Text(
          'No challenges enrolled yet.',
          style: TextStyle(
            color: Colors.grey.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCreationsSection() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int storiesCount = _localCreatorSeasons.length;
    final int shortsCount = _localCreatorShorts.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContentTabs(
            isDark: isDark,
            storiesCount: storiesCount,
            shortsCount: shortsCount,
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(_activeTab),
              child: _activeTab == 'courses'
                  ? _buildStoriesSection()
                  : _buildShortsSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTabs({
    required bool isDark,
    required int storiesCount,
    required int shortsCount,
  }) {
    // Always include all tabs, but disable visually if not visible
    final tabs = [
      {
        'assetIcon': "assets/svgs/shorts-playlist.svg",
        'key': 'shorts',
        'label': 'Shorts',
        'count': shortsCount,
        'isVisible': _isShortsVisible(),
      },
      {
        'assetIcon': "assets/svgs/story-playlist.svg",
        'key': 'courses',
        'label': 'Courses',
        'count': storiesCount,
        'isVisible': _isStoriesVisible(),
      },
    ];

    return Row(
      children: tabs.map((tab) {
        final key = tab['key'] as String;
        final label = tab['label'] as String;
        final count = tab['count'] as int;
        final assetIcon = tab['assetIcon'] as String;
        final isVisible = tab['isVisible'] as bool;
        final bool isActive = _activeTab == key;

        return Expanded(
          child: GestureDetector(
            onTap: isVisible ? () => setState(() => _activeTab = key) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        assetIcon,
                        width: 16,
                        height: 16,
                        color: !isVisible
                            ? Colors.grey.withValues(alpha: 0.3)
                            : isActive
                                ? Colors.white
                                : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: !isVisible
                              ? Colors.grey.withValues(alpha: 0.4)
                              : isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: !isVisible
                              ? Colors.grey.withValues(alpha: 0.3)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: !isVisible
                          ? Colors.transparent
                          : isActive
                              ? Colors.grey
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==========================
// STORIES SECTION
// ==========================
  Widget _buildStoriesSection() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Check visibility first
    if (!_isStoriesVisible()) {
      return _buildHiddenContentMessage(isDark);
    }

    DebugLogger.info(
        '🎬 Building stories section - local count: ${_localCreatorSeasons.length}');

    if (_localCreatorSeasons.isEmpty) {
      return _buildEmptyCreationsState(
        icon: Icons.video_library_outlined,
        title: 'No Courses Yet',
        description: 'This teacher hasn\'t posted any courses.',
      );
    }

    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 12;
          final int columns = _resolveCreationsColumns(constraints.maxWidth);
          final double totalSpacing = spacing * (columns - 1);
          final double availableWidth = constraints.maxWidth - totalSpacing;
          final double computedWidth = availableWidth > 0
              ? availableWidth / columns
              : constraints.maxWidth / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.start,
            children: List.generate(_localCreatorSeasons.length, (index) {
              try {
                final season =
                    _localCreatorSeasons[index] as Map<String, dynamic>;
                final imageUrl = _resolveSeasonImage(season);
                final subtitle = _resolveSeasonSubtitle(season);

                return SizedBox(
                  width: computedWidth,
                  child: CreatorStoryPreviewCard(
                    title: season['title']?.toString() ?? 'Untitled Story',
                    subtitle: subtitle,
                    imageUrl: imageUrl,
                    onTap: () => _openSeason(season),
                  ),
                );
              } catch (e) {
                DebugLogger.error('Error rendering story at index $index: $e');
                return const SizedBox.shrink();
              }
            }),
          );
        },
      ),
    );
  }

// ==========================
// SHORTS SECTION
// ==========================
  Widget _buildShortsSection() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Check visibility first
    if (!_isShortsVisible()) {
      return _buildHiddenContentMessage(isDark);
    }

    DebugLogger.info(
        '🎥 Building shorts section - local count: ${_localCreatorShorts.length}');

    if (_localCreatorShorts.isEmpty) {
      return _buildEmptyCreationsState(
        icon: Icons.video_collection_outlined,
        title: 'No Shorts Yet',
        description: 'This teacher hasn\'t posted any shorts.',
      );
    }

    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 8; // Reduced spacing for 3 columns
          const int columns = 3; // Fixed to 3 columns
          final double totalSpacing = spacing * (columns - 1);
          final double availableWidth = constraints.maxWidth - totalSpacing;
          final double computedWidth = availableWidth > 0
              ? availableWidth / columns
              : constraints.maxWidth / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.start,
            children: List.generate(_localCreatorShorts.length, (index) {
              try {
                final short = _asMap(_localCreatorShorts[index]);
                if (short == null) {
                  DebugLogger.error('Short at index $index is not a valid map');
                  return const SizedBox.shrink();
                }

                final shortsId = _resolveShortsId(short);
                final videoUrl = _resolveShortsVideoUrl(short);
                final title = _resolveShortsTitle(short);
                final likesCount = _resolveLikesCount(short);
                final usersCount = _resolveUsersCount(short);
                final userId = _resolveUserId(short);
                final commentsCount = _resolveShortsComments(short);

                if (shortsId == 0 || videoUrl.isEmpty) {
                  DebugLogger.error(
                      'Short at index $index missing critical data: id=$shortsId, url=$videoUrl');
                  return const SizedBox.shrink();
                }

                DebugLogger.info(
                    '🎥 Short $shortsId: title=$title, url=$videoUrl, likes=$likesCount, views=$usersCount');

                return SizedBox(
                  width: computedWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: FlickShortsPlayer(
                        shortsId: shortsId,
                        videoUrl: videoUrl,
                        title: title,
                        likesCount: likesCount,
                        usersCount: usersCount,
                        userId: userId,
                        commentsCount: commentsCount,
                        showLikes: _isLikesVisible(),
                        showViews: _isViewCountVisible(),
                      ),
                    ),
                  ),
                );
              } catch (e, st) {
                DebugLogger.error(
                    'Error rendering short at index $index: $e\n$st');
                return const SizedBox.shrink();
              }
            }),
          );
        },
      ),
    );
  }

  Widget _buildEmptyCreationsState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Colors.grey),
          SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSeason(Map<String, dynamic> season) async {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      if (auth.isGuest) {
        GuestAuthHelper.showGuestLoginDialog(context, 'view stories');
        return;
      }

      final storyProvider = Provider.of<Story>(context, listen: false);
      final enrichedSeason = Map<String, dynamic>.from(season)
        ..['creatorId'] = _creatorId
        ..['isCreatorSeason'] = true;

      await storyProvider.setSelectedSeason(enrichedSeason);
      if (!mounted) return;
      Navigator.of(context).pushNamed(EpisodeScreen.routeName);
    } catch (error) {
      DebugLogger.error('Failed to open season: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to open story'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _resolveCreationsColumns(double maxWidth) {
    if (maxWidth >= 1024) return 4;
    if (maxWidth >= 780) return 3;
    return 2;
  }

  int _resolveShortsId(Map<String, dynamic> short) {
    final candidates = [
      short['id'],
      short['shorts_id'],
      short['short_id'],
    ];
    for (final candidate in candidates) {
      final parsed = _parseStatValue(candidate);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  String _resolveShortsVideoUrl(Map<String, dynamic> short) {
    final candidates = [
      short['video_url'],
      short['videoUrl'],
      short['video'],
      short['url'],
      short['media_url'],
      short['mediaUrl'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    DebugLogger.warning('⚠️ No video URL found for short: ${short['id']}');
    return '';
  }

  String _resolveShortsTitle(Map<String, dynamic> short) {
    final candidates = [
      short['title'],
      short['name'],
      short['heading'],
      short['short_title'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return 'Untitled Short';
  }

  int _resolveLikesCount(Map<String, dynamic> short) {
    final candidates = [
      short['likes_count'],
      short['likesCount'],
      short['likes'],
      short['like_count'],
    ];
    for (final candidate in candidates) {
      final parsed = _parseStatValue(candidate);
      if (parsed >= 0) return parsed;
    }
    return 0;
  }

  int _resolveUsersCount(Map<String, dynamic> short) {
    final candidates = [
      short['users_count'],
      short['usersCount'],
      short['view_count'],
      short['viewCount'],
      short['views'],
      short['views_count'],
      short['enrollments_count'],
    ];
    for (final candidate in candidates) {
      final parsed = _parseStatValue(candidate);
      if (parsed >= 0) return parsed;
    }
    return 0;
  }

  int _resolveUserId(Map<String, dynamic> short) {
    final candidates = [
      short['user_id'],
      short['userId'],
      short['creator_id'],
      short['creatorId'],
    ];
    for (final candidate in candidates) {
      final parsed = _parseStatValue(candidate);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  int _resolveShortsComments(dynamic shortsData) {
    if (shortsData is! Map<String, dynamic>) return 0;

    final candidates = [
      shortsData['comments_count'],
      shortsData['commentsCount'],
      shortsData['comments_total'],
      shortsData['commentsTotal'],
      shortsData['stats'] is Map<String, dynamic>
          ? shortsData['stats']['comments_count']
          : null,
    ];

    for (final candidate in candidates) {
      final parsed = _parseStatValue(candidate);
      if (parsed > 0) {
        return parsed;
      }
    }

    final comments = shortsData['comments'];
    if (comments is List) {
      return comments.length;
    }

    return 0;
  }

  String _resolveSeasonImage(Map<String, dynamic> season) {
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

    return 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
  }

  String _resolveSeasonSubtitle(Map<String, dynamic> season) {
    final candidates = [
      season['tagline'],
      season['short_description'],
      season['description'],
      season['summary'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return 'Tap to continue watching';
  }

  @override
  void dispose() {
    _supportPointsController.dispose();
    _supportMessageController.dispose();
    super.dispose();
  }
}

class CreatorStoryPreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;

  const CreatorStoryPreviewCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.25),
              Colors.black.withValues(alpha: 0.05),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 9 / 16,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const ShimmerLoading(
                    child: SkeletonBox(
                        width: double.infinity, height: double.infinity),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade300,
                    child: Icon(
                      Icons.menu_book,
                      size: 36,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FlickShortsPlayer extends StatefulWidget {
  final int shortsId;
  final String videoUrl;
  final String title;
  final int likesCount;
  final int usersCount;
  final int userId;
  final int commentsCount;
  final bool showLikes;
  final bool showViews;

  FlickShortsPlayer({
    required this.shortsId,
    required this.videoUrl,
    required this.title,
    required this.likesCount,
    required this.usersCount,
    required this.userId,
    int? commentsCount,
    this.showLikes = true,
    this.showViews = true,
  }) : commentsCount = commentsCount ?? 0;

  @override
  _FlickShortsPlayerState createState() => _FlickShortsPlayerState();
}

class _FlickShortsPlayerState extends State<FlickShortsPlayer> {
  late FlickManager _flickManager;
  bool _flickManagerInitialized = false;
  final TextStyle _textStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    shadows: [
      Shadow(
        offset: Offset(1.0, 1.0),
        blurRadius: 2.0,
        color: Colors.black,
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _flickManager = FlickManager(
      videoPlayerController: VideoPlayerController.networkUrl(Uri.parse(
        '${Url.mediaUrl}/${widget.videoUrl}',
      )),
      autoPlay: false,
      autoInitialize: true,
    );
    _flickManagerInitialized = true;
  }

  @override
  void dispose() {
    if (_flickManagerInitialized) _flickManager.dispose();
    super.dispose();
  }

  void _onLongPress() {
    if (_flickManager.flickVideoManager!.isPlaying) {
      _flickManager.flickControlManager!.pause();
    } else {
      _flickManager.flickControlManager!.play();
    }
  }

  void _onTap() {
    Navigator.of(context).pushNamed(
      SingleShortsScreen.routeName,
      arguments: widget.shortsId,
    );
  }

  void _onDeletePress() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Shorts', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(
            'Are you sure you want to delete this shorts? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await Provider.of<Shorts>(context, listen: false)
                    .deleteShorts(widget.shortsId);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Shorts deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete shorts: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  Widget _buildStatPill(IconData icon, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.40),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          SizedBox(width: 5),
          Text(
            _formatCount(value),
            style: _textStyle.copyWith(fontSize: 10, height: 1.15),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _onLongPress,
      onTap: _onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 9 / 16,
                child: FlickVideoPlayer(
                  flickManager: _flickManager,
                  flickVideoWithControls: FlickVideoWithControls(
                    videoFit: BoxFit.cover,
                    controls: Container(), // Hide controls
                  ),
                  flickVideoWithControlsFullscreen: FlickVideoWithControls(
                    videoFit: BoxFit.cover,
                    controls:
                        Container(), // Hide controls in fullscreen as well
                  ),
                ),
              ),

              // Gradient overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Title overlay
              Positioned(
                bottom: 35,
                left: 8,
                right: 8,
                child: Text(
                  widget.title.length > 15
                      ? '${widget.title.substring(0, 15)}...'
                      : widget.title,
                  style: _textStyle.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Delete button for owner
              if (widget.userId ==
                  Provider.of<Auth>(context, listen: false).userId)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _onDeletePress,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.delete, color: Colors.white, size: 16),
                    ),
                  ),
                ),

              // Stats row - Only show likes and views if permitted by privacy settings
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.showLikes)
                      _buildStatPill(Icons.thumb_up, widget.likesCount),
                    // _buildStatPill(
                    //     Icons.chat_bubble_outline, widget.commentsCount),
                    if (widget.showViews)
                      _buildStatPill(Icons.play_arrow, widget.usersCount),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
