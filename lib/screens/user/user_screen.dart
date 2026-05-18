// ignore_for_file: unused_field, unused_element, duplicate_ignore, unused_import, unused_local_variable

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/challenge.dart';
import 'package:baakhapaa/providers/levels.dart';
import 'package:baakhapaa/providers/shorts.dart';
import 'package:baakhapaa/providers/story.dart';
import 'package:baakhapaa/providers/video_state_provider.dart';
import 'package:baakhapaa/screens/analytics/analytics_screen.dart';
import 'package:baakhapaa/screens/create/story/create_story_type_screen.dart';
import 'package:baakhapaa/screens/others/creator_request_screen.dart';
import 'package:baakhapaa/screens/others/referrals_screen.dart';
import 'package:baakhapaa/screens/shorts/create/create_shorts_screen.dart';
import 'package:baakhapaa/screens/shorts/shorts_screen.dart';
import 'package:baakhapaa/screens/story/creator_story_screen.dart';
import 'package:baakhapaa/screens/story/episode_screen.dart';
import 'package:baakhapaa/screens/user/achievements_screen.dart';
import 'package:baakhapaa/screens/level_map/level_map_screen.dart';
import 'package:baakhapaa/screens/user/points_screen.dart';
import 'package:baakhapaa/screens/user/setting_screen.dart';
import 'package:baakhapaa/screens/challenges/all_challenges_screen.dart';
import 'package:baakhapaa/screens/challenges/challenge_detail_screen.dart';

import 'package:baakhapaa/screens/leaderboard/leaderboard_screen.dart';
// import 'package:baakhapaa/widgets/TaskCardWidget.dart';
import 'package:baakhapaa/widgets/TicketWidget.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/skeleton_loading.dart';
import 'package:baakhapaa/widgets/footer.dart';
import 'package:baakhapaa/widgets/nav_bar.dart';
import 'package:baakhapaa/utils/exit_confirmation_dialog.dart';
import 'package:baakhapaa/utils/puppet_screen_mapping.dart';
import 'package:baakhapaa/utils/guest_auth_helper.dart';
import 'package:baakhapaa/widgets/share_with_qr_modal.dart';
// ignore: unused_import
import 'package:baakhapaa/widgets/wallet_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:baakhapaa/utils/debug_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
// ignore: unused_import
import '../../services/ad_service.dart';

class UserScreen extends StatefulWidget {
  static const routeName = '/user-screen';

  const UserScreen({Key? key}) : super(key: key);

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with PuppetInteractionMixin {
  var _isLoading = true;
  var _isLoadingAchievements = true;
  var _isLoadingChallenges = true;
  var _isLoadingCreatorShorts = true;
  bool _isBioExpanded = false;
  late Map<String, dynamic> _user = {};
  late Map<String, dynamic> _userInformation = {};
  String _userContentTab = 'Shorts';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _hasAttemptedShortsLoad = false;

  List<dynamic> _localCreatorShorts = [];
  List<dynamic> _localCreatorSeasons = [];
  // int get followersCount => _followData['followers_count'] ?? 0;

  // Public view tabs (matching creator_story_screen.dart)
  String _activeTab = 'stories'; // 'stories' | 'shorts'
  String _activeProgressTab = 'achievements'; // 'achievements' | 'challenges'

  @override
  void initState() {
    super.initState();
    DebugLogger.info('👤 [INIT] UserScreen initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DebugLogger.info('👤 [INIT] UserScreen first frame callback');
      _initData();
    });
  }

  Future<void> _initData() async {
    try {
      // Cache provider references BEFORE any async operations
      final auth = Provider.of<Auth>(context, listen: false);
      final isUnauthenticated = auth.isGuest ||
          !auth.isAuth ||
          (auth.user.isEmpty && !auth.isLoadingUser);

      if (isUnauthenticated) {
        final didLogin = await GuestAuthHelper.showGuestLoginDialog(
          context,
          'user profile',
        );
        if (!didLogin && mounted) {
          Navigator.of(context).pushReplacementNamed('/story-screen');
        }
        return;
      }

      await auth.getUnreadMessageCount();

      // First load user data
      await auth.getUser();
      final userId = auth.user['id'];

      if (!mounted) return;

      // Update UI with user data immediately (defer to end of frame)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _user = auth.user;
          _userInformation = auth.userInformation ?? {};
          _isLoading = false; // Show UI now
        });

        // Validate userId before continuing
        if (userId == null) {
          DebugLogger.error('❌ Cannot load content: userId is null');
          if (mounted) {
            setState(() {
              _isLoadingCreatorShorts = false;
              _hasAttemptedShortsLoad = true;
              _localCreatorShorts = [];
              _localCreatorSeasons = [];
            });
          }
          return;
        }

        DebugLogger.info('👤 User loaded: $userId');

        // Check for streak recovery opportunity
        DebugLogger.info('🔥 [STREAK] Triggering streak recovery check');
        unawaited(_checkAndShowStreakRecoveryModal());

        // Run content loading after frame to avoid tree-locked setState and
        // reduce races with provider disposal. Each provider is looked up
        // fresh inside the called helpers.
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          int? id;
          if (userId is int) {
            id = userId;
          } else if (userId is String) {
            id = int.tryParse(userId);
          }

          if (id != null) {
            await _loadCreatorShortsWithId(id);
          } else {
            DebugLogger.error('❌ Invalid userId type for shorts: $userId');
            if (mounted) {
              setState(() {
                _isLoadingCreatorShorts = false;
                _hasAttemptedShortsLoad = true;
              });
            }
          }

          // Fetch creator seasons safely (fresh provider lookup)
          if (!mounted) return;
          try {
            final freshStory = Provider.of<Story>(context, listen: false);
            await freshStory.fetchCreatorSeasons(userId);
            if (mounted) {
              setState(() {
                _localCreatorSeasons = List.from(freshStory.creatorSeasons);
              });
              DebugLogger.info(
                '✅ Stories loaded: ${_localCreatorSeasons.length}',
              );
            }
          } catch (error) {
            DebugLogger.error('❌ Error loading stories: $error');
            if (mounted) {
              setState(() {
                _localCreatorSeasons = [];
              });
            }
          }

          await _loadAchievementsAndChallenges();
          await _loadLevelsData();

          // Fetch global shorts for "Discover" section if not already loaded
          if (!mounted) return;
          try {
            final shortsProvider = Provider.of<Shorts>(context, listen: false);
            if (shortsProvider.shorts.isEmpty) {
              await shortsProvider.fetchShorts();
            }
          } catch (e) {
            DebugLogger.error('Error fetching global shorts: $e');
          }
        });
      });
    } catch (error) {
      DebugLogger.error('Error in _initData: $error');
      if (mounted) {
        setState(() {
          _user = {};
          _userInformation = {};
          _isLoading = false;
          _isLoadingAchievements = false;
          _isLoadingChallenges = false;
          _isLoadingCreatorShorts = false;
          _hasAttemptedShortsLoad = true;
          _localCreatorShorts = [];
          _localCreatorSeasons = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile data'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _checkAndShowStreakRecoveryModal() async {
    if (!mounted) return;

    try {
      final story = Provider.of<Story>(context, listen: false);
      // ── Frequency guard: show at most 2× per calendar day ──────────
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final countKey = 'streak_recovery_shown_$today';
      final shownToday = prefs.getInt(countKey) ?? 0;
      if (shownToday >= 2) {
        DebugLogger.info(
          '🔥 [STREAK] Already shown streak recovery dialog $shownToday time(s) today — skipping',
        );
        return;
      }
      // ────────────────────────────────────────────────────────────────
      DebugLogger.info('🔥 [STREAK] Checking streak recovery eligibility');

      // Fetch reading streak
      await story.fetchReadingStreak(force: true);

      if (!mounted) return;

      // Check if streak is broken but recoverable
      final readingStreak = story.readingStreak;

      DebugLogger.info(
        '🔥 [STREAK] fetchReadingStreak completed. Data: $readingStreak',
      );

      // Safety check: readingStreak must not be empty
      if (readingStreak.isEmpty) {
        DebugLogger.info('🔥 [STREAK] readingStreak is empty, skipping modal');
        return;
      }

      // Use recovery_info from backend (single source of truth)
      final recoveryInfo = readingStreak['recovery_info'];
      if (recoveryInfo == null) {
        DebugLogger.info('🔥 [STREAK] recovery_info missing from streak data');
        return;
      }

      final canRecover = recoveryInfo['can_recover'] ?? false;
      final missedDays = recoveryInfo['missed_days'] ?? 0;
      final recoveryCost = recoveryInfo['recovery_cost'] ?? 0;

      DebugLogger.info(
        '🔥 [STREAK] recovery_info: can_recover=$canRecover, missed_days=$missedDays, cost=$recoveryCost',
      );

      if (!canRecover) {
        DebugLogger.info(
          '🔥 [STREAK] Backend indicates recovery not available',
        );
        return;
      }

      // Show recovery modal with server-calculated values
      if (mounted) {
        DebugLogger.info(
          '🔥 [STREAK] Showing streak recovery modal (days lost: $missedDays, coins needed: $recoveryCost)',
        );
        await _showStreakRecoveryModal(missedDays);
      }
    } catch (e, stackTrace) {
      DebugLogger.error('🔥 [STREAK] Error checking streak recovery: $e');
      DebugLogger.error('🔥 [STREAK] Stack trace: $stackTrace');
      // Silently fail - don't interrupt user experience
    }
  }

  Future<void> _showStreakRecoveryModal(int daysLost) async {
    if (!mounted || !context.mounted) return;

    final recoveryCost = daysLost * 100; // Cost is 100 coins per day missed

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.local_fire_department,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Recover Streak?',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'You missed $daysLost day${daysLost > 1 ? 's' : ''}. Spend $recoveryCost coins to cover the missed days and restore your streak. This is only available within 3 days of breaking your streak.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Recover using $recoveryCost points',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // User confirmed recovery
    if (!mounted) return;

    try {
      final story = Provider.of<Story>(context, listen: false);
      final result = await story.recoverStreak();

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Streak recovered! 🔥'),
            backgroundColor: Colors.green,
          ),
        );
        // Force refresh streak data
        await story.fetchReadingStreak(force: true);
        // Refresh UI
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to recover streak'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _loadCreatorShortsWithId(int userId) async {
    if (!mounted) return;

    DebugLogger.info('🎬 _loadCreatorShortsWithId called with userId: $userId');

    // Set loading state on next frame to avoid locking the tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCreatorShorts = true;
      });
    });

    try {
      DebugLogger.info('🎬 About to call fetchCreatorShorts...');

      // Use a fresh provider lookup so we don't hold onto a provider
      // reference across await boundaries (it may be disposed elsewhere).
      final shortsProvider = Provider.of<Shorts>(context, listen: false);
      await shortsProvider.fetchCreatorShorts(userId);

      DebugLogger.info('🎬 fetchCreatorShorts completed');
      DebugLogger.info(
        '🎬 Provider shorts count: ${shortsProvider.creatorShortsCount}',
      );

      // Copy provider data to local state on next frame to avoid calling
      // setState while tree is locked.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _localCreatorShorts = List.from(shortsProvider.creatorShorts);
          _hasAttemptedShortsLoad = true;
          _isLoadingCreatorShorts = false;
        });
        DebugLogger.info(
          '✅ Copied to local state - Shorts: ${_localCreatorShorts.length}',
        );
      });
    } catch (e) {
      DebugLogger.error('❌ Error fetching creator shorts: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _localCreatorShorts = [];
          _hasAttemptedShortsLoad = true;
          _isLoadingCreatorShorts = false;
        });
      });
    }
  }

  // Visibility Check Helpers (Public View)
  bool _isAchievementsVisible() {
    final visibility = _user['profile_visibility'];
    if (visibility == null) return true;
    return visibility['achievements'] ?? true;
  }

  List<dynamic> _earnedAchievements(List<dynamic> achievements) {
    return achievements.where((achievement) {
      if (achievement is! Map<String, dynamic>) return false;
      final obtained = achievement['obtained'];
      final claimed = achievement['claimed'];
      final purchased = achievement['purchased'];
      final isEarned = achievement['is_earned'] ?? achievement['earned'];

      return (obtained == 1 || obtained == true) ||
          (claimed == 1 || claimed == true) ||
          (purchased == 1 || purchased == true) ||
          (isEarned == 1 || isEarned == true);
    }).toList();
  }

  bool _isChallengesVisible() {
    final visibility = _user['profile_visibility'];
    if (visibility == null) return true;
    return visibility['challenges'] ?? true;
  }

  bool _isShortsVisible() {
    final visibility = _user['profile_visibility'];
    if (visibility == null) return true;
    final result = visibility['shorts'] ?? true;
    DebugLogger.info(
      '🔍 _isShortsVisible: visibility=$visibility, result=$result',
    );
    return result;
  }

  bool _isStoriesVisible() {
    final visibility = _user['profile_visibility'];
    if (visibility == null) return true;
    final result = visibility['stories'] ?? true;
    DebugLogger.info(
      '🔍 _isStoriesVisible: visibility=$visibility, result=$result',
    );
    return result;
  }

  bool _isLikesVisible() {
    final visibility = _user['profile_visibility'];
    if (visibility == null) return true;
    return visibility['likes'] ?? true;
  }

  bool _isViewCountVisible() {
    final visibility = _user['profile_visibility'];
    if (visibility == null) return true;
    return visibility['view_count'] ?? true;
  }

  // Helper method to convert role to display name
  String _getRoleDisplayName(dynamic role) {
    if (role == null) return 'Student';
    final roleStr = role.toString().toLowerCase().trim();
    switch (roleStr) {
      case 'creator':
        return 'Teacher';
      case 'player':
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

  Future<void> _loadAchievementsAndChallenges() async {
    var auth = Provider.of<Auth>(context, listen: false);

    // Load achievements and challenges in parallel
    await Future.wait([
      // Load achievements
      auth.getAchievements().then((_) {
        if (mounted) {
          setState(() {
            _isLoadingAchievements = false;
          });
        }
      }).catchError((error) {
        DebugLogger.api('Error fetching achievements: $error');
        if (mounted) {
          setState(() {
            _isLoadingAchievements = false;
          });
        }
      }),

      // Load challenges
      auth.getChallenges().then((_) {
        if (mounted) {
          setState(() {
            _isLoadingChallenges = false;
          });
        }
      }).catchError((error) {
        DebugLogger.api('Error fetching challenges: $error');
        if (mounted) {
          setState(() {
            _isLoadingChallenges = false;
          });
        }
      }),
    ]);
  }

  Future<void> _loadLevelsData() async {
    try {
      final levelsProvider = Provider.of<Levels>(context, listen: false);
      await levelsProvider.fetchUserProgress();
      DebugLogger.info('✅ Levels data loaded successfully');
    } catch (error) {
      DebugLogger.error('Error loading levels data: $error');
      // Don't show error to user as this is not critical for screen display
    }
  }

  Future<void> _loadCreatorShorts() async {
    final userId = _user['id'];
    if (userId == null) {
      DebugLogger.error('❌ _loadCreatorShorts called with null userId');
      return;
    }
    await _loadCreatorShortsWithId(userId);
  }

  void _showBioEditDialog() {
    final auth = Provider.of<Auth>(context, listen: false);
    final currentValue = _user['bio']?.toString() ?? '';
    final TextEditingController _bioController = TextEditingController(
      text: currentValue,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.description, color: Colors.purple),
              SizedBox(width: 8),
              Text('Edit Bio'),
            ],
          ),
          content: TextField(
            controller: _bioController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: "Write something about yourself",
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                final newBio = _bioController.text.trim();

                try {
                  await auth.updateUser({'bio': newBio});

                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bio updated successfully.')),
                  );

                  setState(() {
                    _user['bio'] = newBio;
                  });
                } catch (error) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update bio.')),
                  );
                }
              },
            ),
          ],
        );
      },
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
              ? Color(0xFF2A2A2A)
              : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
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
            SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.share_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Share Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 24),
            Consumer<Auth>(
              builder: (ctx, auth, _) => FutureBuilder(
                future: auth.fetchConversations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListSkeleton(itemCount: 3);
                  }
                  final conversations = auth.conversations;
                  if (conversations.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('No recent conversations'),
                    );
                  }
                  return Container(
                    height: 200,
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                            final authProvider = Provider.of<Auth>(
                              context,
                              listen: false,
                            );
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
                                SnackBar(
                                  content: Text('Shared Successfully!'),
                                ),
                              );
                              Navigator.pop(context);
                            }).catchError((error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to share. Please try again.',
                                  ),
                                ),
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
                              SizedBox(height: 4),
                              Text(
                                name.isEmpty ? username : name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
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
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.share, color: Colors.green, size: 20),
              ),
              title: Text('Share to Other Apps'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: shareText,
                    subject: "Join Skill Sikka and earn points!",
                    sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
                  ),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.qr_code),
              title: Text('Share using QR'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (context) => ShareWithQrModal(
                    data: shareText,
                    subject: "Join Skill Sikka and earn points!",
                  ),
                );
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isLoading = true;
      _isLoadingAchievements = true;
      _isLoadingChallenges = true;
      _isLoadingCreatorShorts = true;
    });

    try {
      final auth = Provider.of<Auth>(context, listen: false);

      await auth.getUnreadMessageCount();

      // First, refresh the main user data and show the screen
      await auth.getUser();

      setState(() {
        _user = auth.user;
        _userInformation = auth.userInformation ?? {};
        _isLoading = false; // Main content is now ready
      });

      // Then load achievements and challenges separately
      _loadAchievementsAndChallenges();
      // Reload creator shorts
      final userId = auth.user['id'];
      if (userId != null) {
        await _loadCreatorShortsWithId(userId);
      } else {
        DebugLogger.error('❌ Cannot reload creator shorts: userId is null');
      }
      // Reload levels data
      _loadLevelsData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile refreshed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      setState(() {
        _isLoading = false;
        _isLoadingAchievements = false;
        _isLoadingChallenges = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh profile data'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String get userImageUrl {
    if (_user.isEmpty || _user['images'] == null) {
      return 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
    }

    final images = json.encode(_user['images']);
    final decodedImage = json.decode(images).length;
    String imageUrl;
    if (decodedImage == 0) {
      imageUrl =
          'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
    } else {
      imageUrl = json.decode(images)[0]['thumbnail'];
    }
    return imageUrl;
  }

  String get coinExpiresAt {
    if (_userInformation['coin_expires_at'] == null) return 'Points expired';
    return DateFormat.yMMMd(
      'en_US',
    ).format(DateTime.parse(_userInformation['coin_expires_at'].toString()));
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: EdgeInsets.only(right: 16, left: 16, bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Top section with profile picture and user info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture with level indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Main profile picture
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            backgroundColor: Colors.transparent,
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.85,
                              decoration: BoxDecoration(
                                color: Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Stack(
                                children: [
                                  // Close button
                                  Positioned(
                                    top: 16,
                                    right: 16,
                                    child: GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Main content
                                  Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 16),
                                        // Profile Image with gradient border
                                        Stack(
                                          alignment: Alignment.topLeft,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFFE91E63),
                                                    Color(0xFFFF9800),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                              child: Container(
                                                padding: EdgeInsets.all(3),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Color(0xFF1C1C1E),
                                                ),
                                                child: ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl: userImageUrl,
                                                    width: 100,
                                                    height: 100,
                                                    fit: BoxFit.cover,
                                                    placeholder: (context,
                                                            url) =>
                                                        CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors.amber),
                                                      strokeWidth: 2,
                                                    ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Container(
                                                      color: Colors.grey[800],
                                                      width: 100,
                                                      height: 100,
                                                      child: Icon(
                                                        Icons.person,
                                                        size: 50,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        // Username with Premium Badge
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _user['username'] ?? 'Username',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        // Location
                                        Text(
                                          [
                                            if (_user['address'] != null)
                                              _user['address'],
                                            if (_user['country'] != null)
                                              _user['country'],
                                          ].join(', '),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Bio/Role
                                        Text(
                                          (_user['role'] ?? 'Player')
                                              .toString()
                                              .replaceAllMapped(
                                                RegExp(r'(^\w|\s\w)'),
                                                (match) => match
                                                    .group(0)!
                                                    .toUpperCase(),
                                              ),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        // Stats Row
                                        Consumer<Auth>(
                                          builder: (context, auth, _) {
                                            return Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                _buildStatColumn(
                                                  auth.followersCount
                                                      .toString(),
                                                  'Followers',
                                                ),
                                                _buildStatColumn(
                                                  _localCreatorShorts.length
                                                      .toString(),
                                                  'Shorts',
                                                ),
                                                _buildStatColumn(
                                                  context
                                                      .watch<Story>()
                                                      .creatorSeasons
                                                      .length
                                                      .toString(),
                                                  'Stories',
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        // Action Buttons
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildActionButton(
                                              icon: Icons.history,
                                              label: 'Points\nLog',
                                              onTap: () {
                                                Navigator.of(
                                                  context,
                                                ).pop(); // Close dialog first
                                                Navigator.of(context).pushNamed(
                                                  PointsScreen.routeName,
                                                );
                                              },
                                            ),
                                            _buildActionButton(
                                              icon: Icons.bar_chart,
                                              label: 'Analytics',
                                              onTap: () {
                                                Navigator.of(context).pushNamed(
                                                  '/analytics-screen',
                                                );
                                              },
                                            ),
                                            _buildActionButton(
                                              icon: Icons.qr_code,
                                              label: 'QR code',
                                              onTap: () {
                                                final shareText = Url.deepLink(
                                                    '/referral/${_user['username']}');

                                                showModalBottomSheet(
                                                  context: context,
                                                  shape:
                                                      const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                      top: Radius.circular(
                                                        24,
                                                      ),
                                                    ),
                                                  ),
                                                  builder: (_) =>
                                                      ShareWithQrModal(
                                                    data: shareText,
                                                    subject:
                                                        'Share ${_user['username']}',
                                                  ),
                                                );
                                              },
                                            ),
                                            _buildActionButton(
                                              icon: Icons.share_outlined,
                                              label: 'Share\nProfile',
                                              onTap: () async {
                                                // Share profile link with username using share_plus
                                                final profileLink = Url.deepLink(
                                                    '/referral/${_user['username']}');

                                                final shareText = '''
                                                  Check out my Baakhapaa profile!

                                                  👤 Username:  ${_user['username']}
                                                  🔗 View profile: $profileLink

                                                  Join Skill Sikka use my refer code! 🎁 We’ll both receive 25 bonus points when you create an account.
                                                  '''
                                                    .trim();

                                                _showShareProfileModal(
                                                  context,
                                                  shareText,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      margin: EdgeInsets.only(top: 20),
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.amber, Colors.orange, Colors.pink],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(4),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: userImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.amber,
                            ),
                            strokeWidth: 2,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.amber.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Level indicator at top left
                  Positioned(
                    top: 12,
                    left: 5,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context)
                            .pushNamed(LevelMapScreen.routeName);
                      },
                      child: Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue,
                              const Color.fromARGB(255, 21, 116, 194),
                            ],
                            begin: Alignment.bottomRight,
                            end: Alignment.topLeft,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color.fromARGB(255, 164, 164, 164),
                            width: 3,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'LV',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_user['level']?.toString() ?? '1'}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Creator badge at bottom right
                  Positioned(
                    bottom: -15,
                    left: 18,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushNamed(PointsScreen.routeName);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color.fromARGB(255, 163, 123, 4),
                              const Color.fromARGB(255, 255, 213, 79),
                            ],
                            begin: Alignment.bottomRight,
                            end: Alignment.topLeft,
                          ),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/coins.png',
                              width: 18,
                              height: 18,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _userInformation['available_coins']
                                        ?.toString() ??
                                    '0',
                                style: TextStyle(
                                  color: const Color.fromARGB(
                                    255,
                                    255,
                                    255,
                                    255,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
              ),
              SizedBox(width: 20),

              // User information section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _getRoleDisplayName(_user['role']),
                              style: TextStyle(
                                color: const Color.fromARGB(255, 175, 114, 186),
                                fontSize: 12,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(5.0),
                              child: Icon(
                                Icons.video_camera_front,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ],
                        ),
                        _buildActionButtons(),
                      ],
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _user['username'] ?? 'Username',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                    // Location
                    if (_user['address'] != null || _user['country'] != null)
                      Text(
                        [
                          if (_user['address'] != null) _user['address'],
                          if (_user['country'] != null) _user['country'],
                        ].join(','),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),

                    // Bio/Description
                    if (_user['email_verified_at'] == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Email not verified',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    GestureDetector(
                      onTap: _showBioEditDialog,
                      child: StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState) {
                          final bioText = _user['bio'] ??
                              'Openly being who you want,with the people you want, expressing and creating what you want, whenever you want.';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      bioText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                      maxLines: _isBioExpanded ? null : 3,
                                      overflow: _isBioExpanded
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.amber.withOpacity(0.8),
                                  ),
                                ],
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
                                      _isBioExpanded ? 'See less' : 'See more',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Bottom section with stats
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.start,
                      children: [
                        // Joined date
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Joined: ',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _user['created_at'] != null
                                    ? DateFormat('dd.MM.yyyy').format(
                                        DateTime.parse(_user['created_at']),
                                      )
                                    : '01/2020',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Level
                        Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Level: ',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                _user['level']?.toString() ?? '0',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Rank
                        GestureDetector(
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed(LeaderboardScreen.routeName);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Rank: ',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  _user['rank']?.toString() ?? '12',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
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
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods for dialog
  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[400],
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLevelProgress() {
    // Paste of TaskCardWidget from lib/widgets/TaskCardWidget.dart (lines 1-217)
    return Consumer<Levels>(
      builder: (context, levelsProvider, _) {
        // Check verification status
        final isVerified = _user['email_verified_at'] != null;

        final remainingActions = levelsProvider.remainingActions;
        final nextAction =
            remainingActions.isNotEmpty ? remainingActions.first : null;
        final actionData = nextAction?['action'] as Map<String, dynamic>?;

        // Determine content based on verification status
        final title = isVerified
            ? (actionData?['title'] as String? ?? 'All tasks completed')
            : 'Progress Paused';
        final description = isVerified
            ? (actionData?['description'] as String? ??
                'Nothing left to do here.')
            : 'Verify your email to continue earning experience.';

        final progress = levelsProvider.progressPercentage.clamp(0, 100);
        final progressFactor =
            isVerified ? (progress / 100).clamp(0.0, 1.0) : 0.0;

        return InkWell(
          onTap: () async {
            if (isVerified) {
              Navigator.of(context).pushNamed(LevelMapScreen.routeName);
            } else {
              // Trigger verification email
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sending verification email...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                await Provider.of<Auth>(
                  context,
                  listen: false,
                ).verifyUserEmail();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Verification email sent successfully! Please check your inbox.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to send verification email. Please try again later.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            height: 215, // Total height including overflow
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main yellow container
                Positioned(
                  top: 35, // Space for the header to overflow
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 175,
                    decoration: BoxDecoration(
                      color: isVerified
                          ? Color(0xFFFDB528)
                          : Colors.grey[400], // Grey out if unverified
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 50, 160, 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Black dot
                          Container(
                            width: 10,
                            height: 10,
                            margin: EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),

                          SizedBox(width: 12),
                          // Text content and progress
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 10),
                                // Progress bar or Action Button
                                if (isVerified)
                                  Container(
                                    width: double.infinity,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFE0E0E0),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Filled progress
                                        FractionallySizedBox(
                                          widthFactor: progressFactor,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Color(
                                                0xFF8B6239,
                                              ), // Brown color
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: Center(
                                            child: Text(
                                              '${nextAction != null ? (nextAction['current_progress'] ?? 0).toString() : '0'} / ${nextAction != null ? (nextAction['required_value'] ?? 0).toString() : '0'}',
                                              style: const TextStyle(
                                                color: Color(0xFFFFC83E),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                        255,
                                        175,
                                        31,
                                        31,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.black),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.mark_email_unread, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          'Send Verification',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Header with icon and title - positioned outside/above the container
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    height: 60,
                    padding: EdgeInsets.only(right: 10, top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          isVerified
                              ? 'assets/images/clipboard.png'
                              : 'assets/images/lock.png', // Use lock icon if possible, else clipboard
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.lock, color: Colors.grey),
                        ),
                        Text(
                          isVerified
                              ? 'Your Next Task'
                              : 'Verification Required',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Puppet image positioned outside/overlapping the right edge
                // Positioned(
                //   right: -20,
                //   bottom: 5,
                //   child: Image.asset(
                //     'assets/images/puppetdev.png',
                //     height: 200,
                //     fit: BoxFit.contain,
                //   ),
                // ),
                // Implementation of AnimatedOpacity avatar button from AssistiveTouch
                Positioned(
                  right: 0,
                  bottom: 45,
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Consumer<Auth>(
                      builder: (context, auth, child) {
                        String puppetImageUrl =
                            "${Url.mediaUrl}/assets/puppetdev.png";
                        if (auth.puppetImage != null &&
                            auth.puppetImage!.isNotEmpty) {
                          puppetImageUrl = auth.puppetImage!;
                        }
                        return Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: puppetImageUrl,
                              fit: BoxFit.contain,
                              width: 55,
                              height: 55,
                              errorWidget: (context, url, error) => Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      },
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

  // ignore: unused_element
  Widget _buildUserContainer() {
    bool isProfileEmailVerified() {
      final value = _user['email_verified_at'] ??
          (_user['information'] is Map<String, dynamic>
              ? (_user['information']
                  as Map<String, dynamic>)['email_verified_at']
              : null);
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value > 0;
      final normalized = value.toString().trim().toLowerCase();
      if (normalized.isEmpty ||
          normalized == 'null' ||
          normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no' ||
          normalized == 'not_verified' ||
          normalized == 'unverified') {
        return false;
      }
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      return DateTime.tryParse(value.toString()) != null;
    }

    void showEmailVerificationWarning() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email not verified yet. Please verify your email first.',
          ),
        ),
      );
    }

    final categories = ['Shorts', 'Courses', 'Challenges', 'Achievements'];

    Widget buildAddShortCard() {
      return InkWell(
        onTap: () {
          if (!isProfileEmailVerified()) {
            showEmailVerificationWarning();
            return;
          }
          final auth = Provider.of<Auth>(context, listen: false);
          if (auth.role != 'creator' && auth.role != 'student') {
            Navigator.of(context).pushNamed(CreatorRequestScreen.routeName);
            return;
          }
          Navigator.of(context).pushNamed(
            CreateShortsScreen.routeName,
            arguments: {'is_challenge': false},
          ).then((_) {
            // When returning from create shorts, reset the navigation flag
            if (mounted) {
              final videoProvider = Provider.of<VideoStateProvider>(
                context,
                listen: false,
              );
              if (videoProvider.isNavigatingToCreate) {
                videoProvider.setNavigatingToCreate(false);
                // If we're still on shorts screen, restore video state
                if (videoProvider.currentScreen == 'shorts') {
                  Future.delayed(Duration(milliseconds: 500), () {
                    if (mounted) {
                      videoProvider.forcePlayAfterNavigation();
                    }
                  });
                }
              }
            }

            // Always refresh creator shorts when returning so new uploads show up
            if (mounted) {
              _loadCreatorShorts();
            }
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 140,
          margin: EdgeInsets.only(right: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Colors.black, Colors.black.withValues(alpha: 0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(Icons.add, size: 40, color: Colors.white),
              ),
              SizedBox(height: 12),
              Text(
                'Add\nShorts',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildAddStoryCard() {
      return InkWell(
        onTap: () {
          if (!isProfileEmailVerified()) {
            showEmailVerificationWarning();
            return;
          }
          final auth = Provider.of<Auth>(context, listen: false);
          if (auth.role != 'creator' && auth.role != 'student') {
            Navigator.of(context).pushNamed(CreatorRequestScreen.routeName);
            return;
          }
          Navigator.of(context).pushNamed(CreateStoryTypeScreen.routeName).then(
            (_) {
              // Similar validation & reset as with Shorts
              if (mounted) {
                final videoProvider = Provider.of<VideoStateProvider>(
                  context,
                  listen: false,
                );
                if (videoProvider.isNavigatingToCreate) {
                  videoProvider.setNavigatingToCreate(false);

                  if (videoProvider.currentScreen == 'shorts') {
                    Future.delayed(Duration(milliseconds: 500), () {
                      if (mounted) {
                        videoProvider.forcePlayAfterNavigation();
                      }
                    });
                  }
                }
              }
              // Reload creator stories / seasons so new uploads show up
              if (mounted) {
                try {
                  final storyProvider = Provider.of<Story>(
                    context,
                    listen: false,
                  );
                  final userId = _user['id'];
                  if (userId != null) {
                    storyProvider.fetchCreatorSeasons(userId);
                  }
                } catch (e) {
                  DebugLogger.error('Error reloading creator stories: $e');
                }
              }
            },
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 140,
          margin: EdgeInsets.only(right: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Colors.black, Colors.black.withValues(alpha: 0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(Icons.add, size: 40, color: Colors.white),
              ),
              SizedBox(height: 12),
              Text(
                'Add\nCourse',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildShortsSliderGrid() {
      DebugLogger.info(
        '🔄 Building shorts grid - local count: ${_localCreatorShorts.length}',
      );
      DebugLogger.info('⏳ Loading state: $_isLoadingCreatorShorts');
      DebugLogger.info('🎯 Has attempted load: $_hasAttemptedShortsLoad');

      Widget buildShortsContent() {
        // Show loading indicator
        if (_isLoadingCreatorShorts) {
          DebugLogger.info('⏳ Showing loading indicator');
          return Container(
            padding: EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: const ShimmerLoading(
              child: Column(
                children: [
                  SkeletonBox(
                    width: double.infinity,
                    height: 80,
                    borderRadius: 12,
                  ),
                  SizedBox(height: 12),
                  SkeletonBox(
                    width: double.infinity,
                    height: 80,
                    borderRadius: 12,
                  ),
                ],
              ),
            ),
          );
        }

        if (_localCreatorShorts.isEmpty && _hasAttemptedShortsLoad) {
          DebugLogger.info(
            '📭 Showing empty state (load completed, no shorts found)',
          );
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: Column(
              children: [
                Row(
                  children: [
                    buildAddShortCard(),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Shorts Yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "+" to create shorts',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Show a horizontal FlickShortsPlayer row with 5 random shorts (if available)
                Builder(
                  builder: (context) {
                    final shortsProvider = Provider.of<Shorts>(
                      context,
                      listen: false,
                    );
                    final allShorts = List<dynamic>.from(shortsProvider.shorts);

                    if (allShorts.isEmpty) return const SizedBox.shrink();

                    List<dynamic> sampleShorts = [];
                    if (allShorts.length <= 5) {
                      sampleShorts = allShorts;
                    } else {
                      final random = Random();
                      final indices = <int>{};
                      while (indices.length < 5) {
                        indices.add(random.nextInt(allShorts.length));
                      }
                      sampleShorts = indices.map((i) => allShorts[i]).toList();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            child: Text(
                              "Discover Other Shorts",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 200,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: sampleShorts.length + 1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemBuilder: (ctx, idx) {
                                if (idx == sampleShorts.length) {
                                  return InkWell(
                                    onTap: () => Navigator.of(
                                      context,
                                    ).pushNamed(ShortsScreen.routeName),
                                    child: Container(
                                      width: 140,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          colors: [Colors.amber, Colors.orange],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.play_circle_filled_rounded,
                                            color: Colors.white,
                                            size: 48,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            '${AppLocalizations.of(context)!.viewAll}\n${AppLocalizations.of(context)!.sStories}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final short = sampleShorts[idx];
                                return Container(
                                  width: 140,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: FlickShortsPlayer(
                                      videoUrl: short['video_url'] ??
                                          short['video'] ??
                                          '',
                                      shortsId: short['id'] ?? 0,
                                      title: short['title']?.toString() ?? '',
                                      likesCount: short['likes_count'] ??
                                          short['likes'] ??
                                          0,
                                      usersCount: short['users_count'] ??
                                          short['views'] ??
                                          0,
                                      userId: short['user_id'] ?? 0,
                                      showLikes: _isLikesVisible(),
                                      showViews: _isViewCountVisible(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        // Show shorts grid using LOCAL state
        DebugLogger.info(
          '✅ Showing ${_localCreatorShorts.length} shorts from local state',
        );

        return SizedBox(
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 8;
              const int columns = 3;
              final double totalSpacing = spacing * (columns - 1);
              final double availableWidth = constraints.maxWidth - totalSpacing;
              final double computedWidth = availableWidth > 0
                  ? availableWidth / columns
                  : constraints.maxWidth / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.start,
                children: List.generate(_localCreatorShorts.length + 1, (
                  index,
                ) {
                  try {
                    if (index == 0) {
                      return SizedBox(
                        width: computedWidth,
                        child: buildAddShortCard(),
                      );
                    }

                    final short = _localCreatorShorts[index - 1];
                    final commentsCount = short['comments_count'] ?? 0;

                    return SizedBox(
                      width: computedWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.25),
                              Colors.black.withOpacity(0.05),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 16,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: FlickShortsPlayer(
                            shortsId: short['id'] ?? 0,
                            videoUrl: short['video_url'] ?? '',
                            title: short['title'] ?? '',
                            likesCount: short['likes_count'] ?? 0,
                            usersCount: short['users_count'] ?? 0,
                            userId: short['user_id'] ?? 0,
                            commentsCount: commentsCount,
                            showLikes: _isLikesVisible(),
                            showViews: _isViewCountVisible(),
                          ),
                        ),
                      ),
                    );
                  } catch (e) {
                    DebugLogger.error(
                      'Error rendering short at index $index: $e',
                    );
                    return const SizedBox.shrink();
                  }
                }),
              );
            },
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [buildShortsContent(), SizedBox(height: 16)],
      );
    }

    Widget _buildStoriesSliderGrid() {
      return Consumer<Story>(
        builder: (context, storyProvider, _) {
          final creatorSeasons = storyProvider.creatorSeasons;
          final userId = _user['id'];

          // If list is empty and userId present, fetch
          if (creatorSeasons.isEmpty && userId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  storyProvider.fetchCreatorSeasons(userId);
                } catch (e) {
                  DebugLogger.error('Error fetching creator seasons: $e');
                }
              }
            });
          }

          String resolveSeasonImage(Map<String, dynamic> season) {
            final thumbnail = season['thumbnail'];
            if (thumbnail is String && thumbnail.trim().isNotEmpty) {
              return thumbnail;
            }
            final images = season['images'];
            if (images is List && images.isNotEmpty) {
              final first = images.first;
              if (first is Map &&
                  first['url'] is String &&
                  first['url'].trim().isNotEmpty) return first['url'];
              if (first is String && first.trim().isNotEmpty) return first;
            }
            return 'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
          }

          String resolveSeasonSubtitle(Map<String, dynamic> season) {
            final candidates = [
              season['tagline'],
              season['short_description'],
              season['description'],
              season['summary'],
            ];
            for (final c in candidates) {
              if (c is String && c.trim().isNotEmpty) return c.trim();
            }
            return 'Tap to continue watching';
          }

          if (creatorSeasons.isEmpty) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Row(
                children: [
                  _buildAddStoryCard(),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No Courses Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap "+" to create Courses',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Compose list of stories widgets
          final List<Widget> storyCards = creatorSeasons.map<Widget>((
            seasonRaw,
          ) {
            final season = (seasonRaw is Map)
                ? Map<String, dynamic>.from(seasonRaw)
                : <String, dynamic>{};
            final imageUrl = resolveSeasonImage(season);
            final subtitle = resolveSeasonSubtitle(season);

            return CreatorStoryPreviewCard(
              title: season['title']?.toString() ?? 'Untitled Story',
              subtitle: subtitle,
              imageUrl: imageUrl,
              onTap: () {
                try {
                  final story = Provider.of<Story>(context, listen: false);
                  // Add creator information if available
                  Map<String, dynamic> seasonWithContext = Map.from(season);
                  if (_user['id'] != null) {
                    seasonWithContext['creatorId'] = _user['id'];
                    seasonWithContext['isCreatorSeason'] = true;
                  } else {
                    seasonWithContext['isCreatorSeason'] = false;
                  }
                  story.setSelectedSeason(seasonWithContext).then((_) {
                    Navigator.of(
                      context,
                    ).pushNamed(EpisodeScreen.routeName);
                  }).catchError((error) {
                    DebugLogger.error(
                      'Error navigating to episode screen: $error',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Unable to open story'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                } catch (e) {
                  DebugLogger.error('Error navigating to episode screen: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Unable to open story'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            );
          }).toList();

          return SizedBox(
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double spacing = 12;
                final int columns = 2;
                final double totalSpacing = spacing * (columns - 1);
                final double availableWidth = constraints.maxWidth -
                    totalSpacing -
                    32; // 16px padding on each side
                final double computedWidth = availableWidth > 0
                    ? availableWidth / columns
                    : constraints.maxWidth / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  alignment: WrapAlignment.start,
                  children: [
                    SizedBox(width: computedWidth, child: _buildAddStoryCard()),
                    ...storyCards.map(
                      (card) => SizedBox(width: computedWidth, child: card),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    }

    Widget tabContent() {
      switch (_userContentTab) {
        case 'Challenges':
          return _buildChallengesGrid();
        case 'Achievements':
          return _buildAchievementsGrid();
        case 'Courses':
          return _buildStoriesSliderGrid();
        default:
          return _buildShortsSliderGrid();
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF111111)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((category) {
                final isActive = category == _userContentTab;
                return Container(
                  margin: EdgeInsets.only(right: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _userContentTab = category;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color.fromRGBO(205, 205, 205, 1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            isActive ? null : null, // No border for inactive
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isActive
                              ? Colors.black
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.white),
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 16),
          tabContent(),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAnalytics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(AnalyticsScreen.routeName);
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                Colors.black,
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.orange.withOpacity(0.25)
                    : Colors.amber.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.amber.withOpacity(0.5)
                  : Colors.orange.withOpacity(0.35),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.14),
                blurRadius: 18,
                spreadRadius: 1,
                offset: Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_graph_rounded,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.amber
                    : Colors.orange,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                "Analytics",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                  letterSpacing: 0.1,
                  shadows: [
                    Shadow(
                      color: Colors.orange.withOpacity(0.18),
                      blurRadius: 4,
                      offset: Offset(0, 2),
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

  Widget _buildAchievementsGrid() {
    return Consumer<Auth>(
      builder: (context, auth, child) {
        final achievements = auth.achievements;
        final achievementCount = achievements.length;

        double _progressFor(Map<String, dynamic> achievement) {
          final progress = achievement['progress'];
          if (progress is Map && progress.isNotEmpty) {
            double totalPercent = 0;
            int criteria = 0;
            progress.forEach((_, value) {
              if (value is Map && value['percent'] != null) {
                totalPercent += (value['percent'] as num).toDouble();
                criteria++;
              }
            });
            if (criteria > 0) return (totalPercent / criteria) / 100;
          }
          if (achievement['obtained'] == 1) return 1.0;
          return 0.0;
        }

        bool _canClaim(Map<String, dynamic> achievement) {
          final claimed = achievement['claimed'] == 1;
          final obtained = achievement['obtained'] == 1;
          return obtained && !claimed;
        }

        return Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoadingAchievements
                            ? '${context.l10n.loading}...'
                            : '$achievementCount ${context.l10n.badges} ${context.l10n.earn}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamed(AchievementsScreen.routeName);
                    },
                    child: Text(
                      AppLocalizations.of(context)!.viewAll,
                      style: TextStyle(
                        color: const Color.fromARGB(255, 249, 249, 249),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Loading / Empty states
              if (_isLoadingAchievements)
                const SizedBox(
                  height: 100,
                  child: ShimmerLoading(
                    child: Row(
                      children: [
                        SkeletonBox(width: 80, height: 80, borderRadius: 8),
                        SizedBox(width: 12),
                        SkeletonBox(width: 80, height: 80, borderRadius: 8),
                        SizedBox(width: 12),
                        SkeletonBox(width: 80, height: 80, borderRadius: 8),
                      ],
                    ),
                  ),
                )
              else if (achievements.isEmpty)
                SizedBox(
                  height: 100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 40,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No achievements yet',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Achievements horizontal list with ticket and progress
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        achievements.length > 12 ? 12 : achievements.length,
                    itemBuilder: (context, index) {
                      final achievement = achievements[index];
                      final url = achievement['url'];
                      final title =
                          (achievement['title'] ?? '').toString().trim();
                      final canClaim = _canClaim(achievement);
                      final progress = _progressFor(
                        achievement,
                      ).clamp(0.0, 1.0);

                      return Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 10,
                          right: index ==
                                  (achievements.length > 12
                                      ? 11
                                      : achievements.length - 1)
                              ? 0
                              : 0,
                        ),
                        child: GestureDetector(
                          onTap: () => _showAchievementDetails(achievement),
                          child: Container(
                            width: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F1F1F),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: canClaim
                                    ? Colors.amber
                                    : Colors.grey.withValues(alpha: 0.2),
                                width: canClaim ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ticket image
                                TicketShape(
                                  height: 60,
                                  notchRadius: 4,
                                  notchDepth: 3,
                                  scallopRadius: 3,
                                  scallopCount: 5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                        255,
                                        240,
                                        223,
                                        174,
                                      ),
                                      border: Border.all(
                                        color: canClaim
                                            ? Colors.amber
                                            : Colors.grey.withValues(
                                                alpha: 0.25,
                                              ),
                                      ),
                                    ),
                                    child: (url != null &&
                                            url.toString().trim().isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl: url,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            placeholder: (context, _) =>
                                                Container(
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.emoji_events,
                                                color: Colors.amber.shade700,
                                                size: 24,
                                              ),
                                            ),
                                            errorWidget: (context, _, __) =>
                                                Container(
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.emoji_events,
                                                color: Colors.amber.shade700,
                                                size: 24,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.emoji_events,
                                            color: Colors.amber.shade700,
                                            size: 24,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                // Title / Claim text
                                Text(
                                  canClaim
                                      ? 'Claim Now'
                                      : (title.isNotEmpty ? title : 'Badge'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor: Colors.grey.withValues(
                                      alpha: 0.2,
                                    ),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      canClaim
                                          ? Colors.amber.shade600
                                          : Colors.orangeAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (achievements.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      '+${achievements.length - 10} ${context.l10n.more} ${context.l10n.achievements}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChallengesGrid() {
    return Consumer<Auth>(
      builder: (context, auth, child) {
        final challenges = auth.challenges;

        // Filter for active challenges only
        final activeChallenges = challenges.where((challenge) {
          if (challenge['deadline'] == null)
            return true; // No deadline means always active

          try {
            final deadline = DateTime.parse(challenge['deadline']);
            final now = DateTime.now();
            return deadline.isAfter(
              now,
            ); // Challenge is active if deadline is in the future
          } catch (e) {
            DebugLogger.error('Error parsing challenge deadline: $e');
            return true; // If we can't parse the deadline, assume it's active
          }
        }).toList();

        final challengeCount = activeChallenges.length;

        return Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        _isLoadingChallenges
                            ? '${context.l10n.loading}...'
                            : '$challengeCount ${context.l10n.activeChallenges}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamed(AllChallengesScreen.routeName);
                    },
                    child: Text(
                      AppLocalizations.of(context)!.viewAll,
                      style: TextStyle(
                        color: const Color.fromARGB(255, 249, 249, 249),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (_isLoadingChallenges)
                Container(
                  height: 100,
                  child: const ShimmerLoading(
                    child: Column(
                      children: [
                        SkeletonBox(
                          width: double.infinity,
                          height: 42,
                          borderRadius: 12,
                        ),
                        SizedBox(height: 8),
                        SkeletonBox(
                          width: double.infinity,
                          height: 42,
                          borderRadius: 12,
                        ),
                      ],
                    ),
                  ),
                )
              else if (activeChallenges.isEmpty)
                Container(
                  height: 100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flash_on_outlined,
                          size: 40,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.noActiveChallengesFound,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1, // Same as achievements
                  ),
                  itemCount: activeChallenges.length > 10
                      ? 10
                      : activeChallenges.length, // Show max 10 challenges
                  itemBuilder: (context, index) {
                    final challenge = activeChallenges[index];

                    // Check if challenge is expiring soon (within 24 hours)
                    bool isExpiringSoon = false;
                    if (challenge['deadline'] != null) {
                      try {
                        final deadline = DateTime.parse(challenge['deadline']);
                        final now = DateTime.now();
                        final difference = deadline.difference(now);
                        isExpiringSoon =
                            difference.inHours <= 24 && difference.inHours > 0;
                      } catch (e) {
                        // Ignore parsing errors
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        _showChallengeDetails(challenge);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isExpiringSoon
                                ? Colors.red.withValues(alpha: 0.5)
                                : Colors.orange.withValues(alpha: 0.3),
                            width: isExpiringSoon ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox.expand(
                                child: challenge['image_url'] != null
                                    ? CachedNetworkImage(
                                        imageUrl: challenge['image_url']!,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                        placeholder: (context, url) => Center(
                                          child: Icon(
                                            Icons.flash_on,
                                            color: Colors.orange,
                                            size: 24,
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Center(
                                          child: Icon(
                                            Icons.flash_on,
                                            color: Colors.orange,
                                            size: 24,
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.flash_on,
                                          color: Colors.orange,
                                          size: 24,
                                        ),
                                      ),
                              ),
                            ),
                            // Add urgent indicator for challenges expiring soon
                            if (isExpiringSoon)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.access_time,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (activeChallenges.length > 10)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      '+${activeChallenges.length - 10} more challenges',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showChallengeDetails(Map<String, dynamic> challenge) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.orange.withValues(alpha: 0.1),
                ),
                child: challenge['image_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: challenge['image_url'] ?? '',
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Icon(
                            Icons.flash_on,
                            color: Colors.orange,
                            size: 24,
                          ),
                        ),
                      )
                    : Icon(Icons.flash_on, color: Colors.orange, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  challenge['title'] ??
                      challenge['challenge_title'] ??
                      'Challenge',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge['description'] ?? 'No description available.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 12),

                // Challenge Details
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Challenge Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (challenge['platform'] != null)
                        _buildDetailRow('Platform', challenge['platform']),
                      if (challenge['deadline'] != null)
                        _buildDetailRow(
                          'Deadline',
                          _formatDeadline(challenge['deadline']),
                        ),
                      if (challenge['lives'] != null)
                        _buildDetailRow('Lives', challenge['lives'].toString()),
                      if (challenge['duration'] != null)
                        _buildDetailRow(
                          'Duration',
                          '${challenge['duration']} seconds',
                        ),
                      if (challenge['no_of_mcq'] != null)
                        _buildDetailRow(
                          'MCQ Questions',
                          challenge['no_of_mcq'].toString(),
                        ),
                      if (challenge['min_number_of_challenge_participation'] !=
                          null)
                        _buildDetailRow(
                          'Min. Participation',
                          challenge['min_number_of_challenge_participation']
                              .toString(),
                        ),
                    ],
                  ),
                ),

                // Rewards Section
                if (challenge['point_reward'] != null ||
                    challenge['gift_title'] != null) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.stars, color: Colors.orange, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Rewards',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        if (challenge['point_reward'] != null)
                          Text(
                            '• ${challenge['point_reward']} points',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 13,
                            ),
                          ),
                        if (challenge['gift_title'] != null)
                          Text(
                            '• ${challenge['gift_title']}',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.close),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate directly to the specific challenge screen
                Navigator.of(context).pushNamed(
                  ChallengeDetailScreen.routeName,
                  arguments: challenge['id'],
                );
              },
              child: Text('Join Challenge'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _formatDeadline(String deadline) {
    try {
      final deadlineDate = DateTime.parse(deadline);
      final now = DateTime.now();
      final difference = deadlineDate.difference(now);

      if (difference.isNegative) {
        return 'Expired';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days left (${DateFormat.yMMMd().format(deadlineDate)})';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours left';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes left';
      } else {
        return 'Expires soon';
      }
    } catch (e) {
      return deadline; // Return original if parsing fails
    }
  }

  void _showAchievementDetails(Map<String, dynamic> achievement) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: achievement['url'] ?? '',
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  achievement['title'] ?? 'Achievement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            achievement['description'] ?? 'No description available.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Challenges
        // _buildActionCard(
        //   'Challenges',
        //   'Join exciting challenges',
        //   Icons.flash_on,
        //   Colors.orange,
        //   () {
        //     Navigator.of(context).pushNamed(AllChallengesScreen.routeName);
        //   },
        // ),
        // SizedBox(height: 12),

        // Referral Code
        _buildActionCard(
          AppLocalizations.of(context)!.referralCode,
          context.l10n.referralCodeDescription,
          Icons.group_outlined,
          Colors.grey,
          () => Navigator.of(context).pushNamed(ReferralsScreen.routeName),
        ),
        SizedBox(width: 12),

        // Settings
        _buildActionCard(
          context.l10n.settings,
          context.l10n.manageAccount,
          Icons.settings,
          Colors.grey,
          () {
            Navigator.of(context).pushNamed(SettingScreen.routeName);
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  // Public view methods (matching creator_story_screen.dart but with disabled buttons)
  Widget _buildHiddenContentMessage(bool isDark) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF272727) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
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

  Widget _buildPublicAchievementsChallengesSection() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<Auth, Challenge>(
      builder: (_, auth, challenges, __) {
        final userId = _user['id'];
        final enrolledChallenges = userId != null
            ? auth.getCreatorEnrolledChallenges(userId)
            : <dynamic>[];

        // Get user achievements
        final userAchievements = auth.achievements;
        final earnedAchievements = _earnedAchievements(userAchievements);
        final achievementsCount = earnedAchievements.length;

        // Resolve challenges similar to creator_story_screen
        final creatorChallenges = _resolvePublicChallenges(
          auth.user,
          challenges.challenges,
          enrolledChallenges,
        );
        final displayChallenges = creatorChallenges.take(10).toList();
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
              _buildPublicProgressTabs(
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
                      ? _buildPublicAchievementsContent(
                          isDark,
                          userAchievements,
                        )
                      : _buildPublicChallengesContent(
                          displayChallenges,
                          isDark,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPublicProgressTabs({
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

  Widget _buildPublicAchievementsContent(
    bool isDark,
    List<dynamic> achievements,
  ) {
    final userName = _user['username'] ?? _user['display_name'] ?? 'User';
    final earnedAchievements = _earnedAchievements(achievements);

    // Check visibility first
    if (!_isAchievementsVisible()) {
      return _buildHiddenContentMessage(isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Your Achievements",
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
              onPressed: () {
                Navigator.of(context).pushNamed(AchievementsScreen.routeName);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View all',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingAchievements)
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
        else if (earnedAchievements.isEmpty)
          SizedBox(
            height: 55,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 32,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'No achievements yet',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: earnedAchievements.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final achievement =
                    earnedAchievements[index] as Map<String, dynamic>? ?? {};
                final imageUrl = achievement['url'] ?? achievement['image_url'];

                return Container(
                  width: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color.fromARGB(255, 240, 223, 174),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: (imageUrl != null &&
                            imageUrl.toString().trim().isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: imageUrl.toString(),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : const Center(
                            child: Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 26,
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

  Widget _buildPublicChallengesContent(
    List<Map<String, dynamic>> displayChallenges,
    bool isDark,
  ) {
    const subtitle = 'Challenges you have participated';

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
          _buildPublicEmptyChallengesState(isDark)
        else
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: displayChallenges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final challenge = displayChallenges[index];
                return _buildPublicChallengeChip(challenge, isDark);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPublicEmptyChallengesState(bool isDark) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF272727) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
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

  Widget _buildPublicChallengeChip(
    Map<String, dynamic> challenge,
    bool isDarkTheme,
  ) {
    final String? imageUrl =
        challenge['image_url'] ?? challenge['thumbnail'] ?? challenge['cover'];

    return GestureDetector(
      onTap: () {
        final challengeId = challenge['id'] ?? challenge['challenge_id'];
        if (challengeId == null) return;
        Navigator.of(
          context,
        ).pushNamed(ChallengeDetailScreen.routeName, arguments: challengeId);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          height: 72,
          child: imageUrl != null && imageUrl.toString().isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl.toString(),
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

  List<Map<String, dynamic>> _resolvePublicChallenges(
    Map<String, dynamic>? userData,
    List<dynamic> challengePool,
    List<dynamic> enrolledChallenges,
  ) {
    // Normalize enrolled challenges
    final fromEnrolled = <Map<String, dynamic>>[];
    for (final item in enrolledChallenges) {
      if (item is Map<String, dynamic>) {
        fromEnrolled.add(item);
      }
    }
    if (fromEnrolled.isNotEmpty) {
      return fromEnrolled;
    }

    // Try to get from user data
    if (userData != null) {
      final challenges = userData['challenges'];
      if (challenges is List) {
        final normalized = <Map<String, dynamic>>[];
        for (final item in challenges) {
          if (item is Map<String, dynamic>) {
            normalized.add(item);
          }
        }
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }

    return [];
  }

  // ignore: unused_element
  void _showPublicAchievementDetails(Map<String, dynamic> achievement) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  achievement['title'] ?? 'Achievement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            achievement['description'] ?? 'No description available.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPublicCreationsSection() {
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
          _buildPublicContentTabs(
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
                  ? _buildPublicStoriesSection()
                  : _buildPublicShortsSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicContentTabs({
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
                        colorFilter: ColorFilter.mode(
                          !isVisible
                              ? Colors.grey.withValues(alpha: 0.3)
                              : isActive
                                  ? Colors.white
                                  : Colors.grey,
                          BlendMode.srcIn,
                        ),
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

  Widget _buildPublicStoriesSection() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Check visibility first
    if (!_isStoriesVisible()) {
      return _buildHiddenContentMessage(isDark);
    }

    // if (_localCreatorSeasons.isEmpty) {
    //   return _buildPublicEmptyCoursesState();
    // }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const columns = 3;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildAddCourseCard(width: cardWidth),
            ),
            ..._localCreatorSeasons.map((season) {
              try {
                return SizedBox(
                  width: cardWidth,
                  child: _buildCourseStripCard(
                    season as Map<String, dynamic>,
                    width: cardWidth,
                  ),
                );
              } catch (e) {
                return const SizedBox.shrink();
              }
            }),
          ],
        );
      },
    );
  }

  Widget _buildCourseStripCard(
    Map<String, dynamic> season, {
    double width = 92,
  }) {
    final imageUrl = _resolvePublicSeasonImage(season);
    final title = season['title']?.toString() ?? 'Untitled Course';
    final meta = _resolvePublicCourseMeta(season);

    return GestureDetector(
      onTap: () => _openPublicSeason(season),
      child: Container(
        width: width,
        height: width + 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1A222B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: SizedBox(
                width: width,
                height: width,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      _buildStripFallback(Icons.menu_book_outlined),
                  errorWidget: (_, __, ___) =>
                      _buildStripFallback(Icons.menu_book_outlined),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$title - $meta',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.08,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicShortsSection() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Check visibility first
    if (!_isShortsVisible()) {
      return _buildHiddenContentMessage(isDark);
    }

    DebugLogger.info(
      '🎬 _buildPublicShortsSection called, _localCreatorShorts.length = ${_localCreatorShorts.length}',
    );
    DebugLogger.info('🎬 _activeTab = $_activeTab');

    if (_localCreatorShorts.isEmpty) {
      DebugLogger.info('📭 No shorts, showing empty state');
      return LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          const columns = 3;
          final cardWidth =
              (constraints.maxWidth - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: 10,
            children: [
              SizedBox(
                width: cardWidth,
                child: _buildAddShortCard(width: cardWidth),
              ),
              SizedBox(
                width: (cardWidth * 2) + spacing,
                child: _buildEmptyStripCard(
                  icon: Icons.video_collection_outlined,
                  title: 'No Shorts Yet',
                  description: 'Tap + to create shorts',
                  width: (cardWidth * 2) + spacing,
                  height: cardWidth + 38,
                ),
              ),
            ],
          );
        },
      );
    }

    DebugLogger.info('✅ Showing ${_localCreatorShorts.length} shorts');
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const columns = 3;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildAddShortCard(width: cardWidth),
            ),
            ..._localCreatorShorts.map((short) {
              try {
                if (short is! Map<String, dynamic>) {
                  return const SizedBox.shrink();
                }
                return SizedBox(
                  width: cardWidth,
                  child: _buildShortStripCard(short, width: cardWidth),
                );
              } catch (e) {
                return const SizedBox.shrink();
              }
            }),
          ],
        );
      },
    );
  }

  Widget _buildShortStripCard(
    Map<String, dynamic> short, {
    double width = 92,
  }) {
    final title = short['title']?.toString() ?? 'Untitled Short';
    final views = _formatPublicCompactCount(
      short['users_count'] ?? short['views'] ?? short['views_count'] ?? 0,
    );
    final thumbnailUrl = _resolveShortThumbnail(short);
    final videoUrl = _resolveShortVideoUrl(short);

    return GestureDetector(
      onTap: () {
        final shortId = _resolveInt(short['id']);
        Navigator.of(context).pushNamed(
          ShortsScreen.routeName,
          arguments: shortId > 0 ? {'returnToShortsId': shortId} : null,
        );
      },
      child: Container(
        width: width,
        height: width + 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1A222B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: SizedBox(
                width: width,
                height: width,
                child: thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildStripFallback(
                          Icons.play_circle_outline_rounded,
                        ),
                        errorWidget: (_, __, ___) => _buildStripFallback(
                          Icons.play_circle_outline_rounded,
                        ),
                      )
                    : _ShortVideoThumbnail(
                        videoUrl: videoUrl,
                        fallback: _buildStripFallback(
                          Icons.play_circle_outline_rounded,
                        ),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$title',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.08,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStripFallback(IconData icon) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2F3640),
            Color(0xFF171B20),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.78),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildEmptyStripCard({
    required IconData icon,
    required String title,
    required String description,
    double width = 168,
    double height = 92,
  }) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 10.5,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPublicEmptyCreationsState({
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
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

  Widget _buildCreateContentTile({
    required String label,
    required VoidCallback onPressed,
    double width = 92,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        height: width + 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF34383A),
              Color(0xFF171A1D),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.76),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.30),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_rounded,
              color: Color(0xFFFFD54F),
              size: 38,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddShortCard({double width = 92}) {
    bool isProfileEmailVerified() {
      final value = _user['email_verified_at'] ??
          (_user['information'] is Map<String, dynamic>
              ? (_user['information']
                  as Map<String, dynamic>)['email_verified_at']
              : null);
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value > 0;
      final normalized = value.toString().trim().toLowerCase();
      if (normalized.isEmpty ||
          normalized == 'null' ||
          normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no' ||
          normalized == 'not_verified' ||
          normalized == 'unverified') {
        return false;
      }
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      return DateTime.tryParse(value.toString()) != null;
    }

    void showEmailVerificationWarning() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email not verified yet. Please verify your email first.',
          ),
        ),
      );
    }

    return _buildCreateContentTile(
      label: 'Create Shorts',
      width: width,
      onPressed: () {
        if (!isProfileEmailVerified()) {
          showEmailVerificationWarning();
          return;
        }
        final auth = Provider.of<Auth>(context, listen: false);
        if (auth.role != 'creator' && auth.role != 'student') {
          Navigator.of(context).pushNamed(CreatorRequestScreen.routeName);
          return;
        }
        Navigator.of(context).pushNamed(
          CreateShortsScreen.routeName,
          arguments: {'is_challenge': false},
        ).then((_) {
          if (mounted) {
            final videoProvider = Provider.of<VideoStateProvider>(
              context,
              listen: false,
            );
            if (videoProvider.isNavigatingToCreate) {
              videoProvider.setNavigatingToCreate(false);
              if (videoProvider.currentScreen == 'shorts') {
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted) {
                    videoProvider.forcePlayAfterNavigation();
                  }
                });
              }
            }
          }
          if (mounted) {
            _loadCreatorShorts();
          }
        });
      },
    );
  }

  Widget _buildAddCourseCard({double width = 92}) {
    bool isProfileEmailVerified() {
      final value = _user['email_verified_at'] ??
          (_user['information'] is Map<String, dynamic>
              ? (_user['information']
                  as Map<String, dynamic>)['email_verified_at']
              : null);
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value > 0;
      final normalized = value.toString().trim().toLowerCase();
      if (normalized.isEmpty ||
          normalized == 'null' ||
          normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no' ||
          normalized == 'not_verified' ||
          normalized == 'unverified') {
        return false;
      }
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      return DateTime.tryParse(value.toString()) != null;
    }

    void showEmailVerificationWarning() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email not verified yet. Please verify your email first.',
          ),
        ),
      );
    }

    return _buildCreateContentTile(
      label: 'Create Courses',
      width: width,
      onPressed: () {
        if (!isProfileEmailVerified()) {
          showEmailVerificationWarning();
          return;
        }
        final auth = Provider.of<Auth>(context, listen: false);
        if (auth.role != 'creator' && auth.role != 'student') {
          Navigator.of(context).pushNamed(CreatorRequestScreen.routeName);
          return;
        }
        Navigator.of(context).pushNamed(CreateStoryTypeScreen.routeName).then(
          (_) {
            if (mounted) {
              final videoProvider = Provider.of<VideoStateProvider>(
                context,
                listen: false,
              );
              if (videoProvider.isNavigatingToCreate) {
                videoProvider.setNavigatingToCreate(false);
                if (videoProvider.currentScreen == 'shorts') {
                  Future.delayed(Duration(milliseconds: 500), () {
                    if (mounted) {
                      videoProvider.forcePlayAfterNavigation();
                    }
                  });
                }
              }
            }
            if (mounted) {
              try {
                final storyProvider = Provider.of<Story>(
                  context,
                  listen: false,
                );
                final userId = _user['id'];
                if (userId != null) {
                  storyProvider.fetchCreatorSeasons(userId);
                }
              } catch (e) {
                DebugLogger.error('Error reloading creator stories: $e');
              }
            }
          },
        );
      },
    );
  }

  void _openPublicSeason(Map<String, dynamic> season) {
    try {
      final story = Provider.of<Story>(
        context,
        listen: false,
      );
      Map<String, dynamic> seasonWithContext = Map.from(season);
      if (_user['id'] != null) {
        seasonWithContext['creatorId'] = _user['id'];
        seasonWithContext['isCreatorSeason'] = true;
      } else {
        seasonWithContext['isCreatorSeason'] = false;
      }
      story.setSelectedSeason(seasonWithContext).then((_) {
        Navigator.of(context).pushNamed(EpisodeScreen.routeName);
      }).catchError((error) {
        DebugLogger.error('Error navigating to episode screen: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open story'),
            backgroundColor: Colors.red,
          ),
        );
      });
    } catch (e) {
      DebugLogger.error('Error navigating to episode screen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open story'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _resolveShortThumbnail(Map<String, dynamic> short) {
    final candidates = [
      short['thumbnail'],
      short['thumbnail_url'],
      short['image'],
      short['image_url'],
      short['cover'],
      short['cover_image'],
      short['poster'],
    ];

    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
      if (candidate is Map &&
          candidate['url'] is String &&
          candidate['url'].toString().trim().isNotEmpty) {
        return candidate['url'].toString().trim();
      }
    }

    final images = short['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        final url = first['thumbnail'] ?? first['url'];
        if (url is String && url.trim().isNotEmpty) {
          return url.trim();
        }
      }
      if (first is String && first.trim().isNotEmpty) {
        return first.trim();
      }
    }
    return null;
  }

  String? _resolveShortVideoUrl(Map<String, dynamic> short) {
    final rawVideoUrl = short['video_url'] ?? short['video'];
    if (rawVideoUrl is! String || rawVideoUrl.trim().isEmpty) {
      return null;
    }
    final videoUrl = rawVideoUrl.trim();
    if (videoUrl.startsWith('http://') || videoUrl.startsWith('https://')) {
      return videoUrl;
    }
    return '${Url.mediaUrl}/$videoUrl';
  }

  int _resolveInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatPublicCompactCount(dynamic value) {
    final count = _resolveInt(value);
    if (count >= 1000000) {
      final formatted = (count / 1000000).toStringAsFixed(1);
      final trimmed = formatted.endsWith('.0')
          ? formatted.substring(0, formatted.length - 2)
          : formatted;
      return '${trimmed}M';
    }
    if (count >= 1000) {
      final formatted = (count / 1000).toStringAsFixed(1);
      final trimmed = formatted.endsWith('.0')
          ? formatted.substring(0, formatted.length - 2)
          : formatted;
      return '${trimmed}k';
    }
    return count.toString();
  }

  String _resolvePublicCourseMeta(Map<String, dynamic> season) {
    final episodes = season['episodes'];
    if (episodes is List && episodes.isNotEmpty) {
      return '${episodes.length}';
    }

    final count = _resolveInt(
      season['episodes_count'] ??
          season['episode_count'] ??
          season['total_episodes'] ??
          season['lessons_count'],
    );
    if (count > 0) return count.toString();

    return 'Course';
  }

  String _resolvePublicSeasonImage(Map<String, dynamic> season) {
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

  String _resolvePublicSeasonSubtitle(Map<String, dynamic> season) {
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
    return 'Tap to view';
  }

  @override
  Widget build(BuildContext context) {
    return ExitConfirmationDialog.wrapWithExitConfirmation(
      context: context,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: header(
          context: context,
          titleText: AppLocalizations.of(context)!.profile,
          scaffoldKey: _scaffoldKey,
        ),
        body: _isLoading
            ? const ProfileSkeleton()
            : RefreshIndicator(
                onRefresh: _refreshProfile,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      _buildPublicAchievementsChallengesSection(),
                      _buildPublicCreationsSection(),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _ShortVideoThumbnail extends StatefulWidget {
  final String? videoUrl;
  final Widget fallback;

  const _ShortVideoThumbnail({
    required this.videoUrl,
    required this.fallback,
  });

  @override
  State<_ShortVideoThumbnail> createState() => _ShortVideoThumbnailState();
}

class _ShortVideoThumbnailState extends State<_ShortVideoThumbnail> {
  Uint8List? _bytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant _ShortVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _bytes = null;
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final videoUrl = widget.videoUrl;
    if (videoUrl == null || videoUrl.trim().isEmpty) {
      return;
    }

    _isLoading = true;
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 256,
        quality: 70,
        timeMs: 1000,
      ).timeout(const Duration(seconds: 8), onTimeout: () => null);

      if (!mounted || videoUrl != widget.videoUrl) return;
      setState(() {
        _bytes = bytes != null && bytes.length > 5000 ? bytes : null;
      });
    } catch (e) {
      DebugLogger.error('Shorts thumbnail generation failed: $e');
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return widget.fallback;
    }
    return Image.memory(
      bytes,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }
}
