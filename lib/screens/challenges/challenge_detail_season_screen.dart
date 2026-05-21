import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/challenge.dart';
import 'package:baakhapaa/providers/story.dart';
import 'package:baakhapaa/screens/create/story/create_season_screen.dart';
import 'package:baakhapaa/screens/others/creator_request_screen.dart';
import '../../services/subscription_service.dart';
import '../../models/subscription.dart';
// import 'package:baakhapaa/theme/theme_constants.dart';
import 'package:baakhapaa/widgets/footer.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/loading.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import 'challenge_detail_widgets.dart';
import 'challenge_detail_screens_shared.dart';

class ChallengeDetailSeasonScreen extends StatefulWidget {
  static const routeName = '/challenge-detail-season';

  final Map<String, dynamic>? challenge;

  const ChallengeDetailSeasonScreen({
    Key? key,
    this.challenge,
  }) : super(key: key);

  @override
  State<ChallengeDetailSeasonScreen> createState() =>
      _ChallengeDetailSeasonScreenState();
}

class _ChallengeDetailSeasonScreenState
    extends State<ChallengeDetailSeasonScreen> with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  List<dynamic> challengeSeasons = [];
  Map<String, dynamic>? challenge;
  Map<String, dynamic>? mySeasonDetails;
  bool _isDescriptionExpanded = false;
  UserBenefitUsage? _unlockChallengeBenefit;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _fetchData();
      _checkChallengeBenefit();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _checkChallengeBenefit() async {
    if (!mounted) return;
    final auth = Provider.of<Auth>(context, listen: false);
    if (!auth.isSubscribed) return;

    try {
      final subService = SubscriptionService(context: context);
      final response = await subService.getUserBenefitStatus();
      if (mounted && response.success && response.items.isNotEmpty) {
        setState(() {
          try {
            _unlockChallengeBenefit = response.items.first.benefits.firstWhere(
              (b) => b.benefitType.id == 7,
            );
          } catch (_) {
            _unlockChallengeBenefit = null;
          }
        });
      }
    } catch (e) {
      DebugLogger.error('❌ Error checking challenge unlock benefit: $e');
    }
  }

  Future<void> _useUnlockChallengeBenefit() async {
    if (_unlockChallengeBenefit == null || challenge == null) return;

    final challengeId = challenge!['id'] as int;
    final challengeTitle = challenge!['title'] ?? 'this challenge';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Colors.amber, size: 24),
            SizedBox(width: 10),
            Text('Unlock Challenge',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Use 1 benefit to unlock "$challengeTitle"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC83E),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unlock Now',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFC83E))),
      );

      final auth = Provider.of<Auth>(context, listen: false);
      final challengeProvider = Provider.of<Challenge>(context, listen: false);
      final subService =
          SubscriptionService(context: context, authToken: auth.token);

      await challengeProvider.unlockChallenge(challengeId);
      await subService.updateUserBenefitUsage(
        userBenefitUsageId: _unlockChallengeBenefit!.id,
        challengeId: challengeId,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          challenge!['unlocked'] = true;
          challenge!['is_locked'] = 0;
        });
        await _checkChallengeBenefit();
        showScaffoldMessenger(context, '🎉 Challenge unlocked successfully!');
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showScaffoldMessenger(context, 'Failed to unlock: $e');
      }
    }
  }

  Future<void> _setChallengeLocked(int challengeId, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('challenge_${challengeId}_user_$userId', true);
    DebugLogger.info(
        '🔒 Locked participation for challenge $challengeId, user $userId');
  }

  Future<void> _fetchData() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Use passed challenge or fetch from route arguments
      Map<String, dynamic>? challengeData = widget.challenge;

      if (challengeData == null) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        int challengeId;
        if (arguments is Map) {
          challengeId = arguments['id'] ?? arguments['challengeId'] ?? 0;
        } else if (arguments is int) {
          challengeId = arguments;
        } else if (arguments is String) {
          challengeId = int.tryParse(arguments) ?? 0;
        } else {
          challengeId = 0;
        }

        DebugLogger.info('?? Loading challenge ID: $challengeId');

        final challengeProvider =
            Provider.of<Challenge>(context, listen: false);
        await challengeProvider.fetchChallenges();
        if (!mounted) return;

        challengeData = challengeProvider.challenges.firstWhere(
          (c) => c['id'] == challengeId,
          orElse: () => <String, dynamic>{
            'id': challengeId,
            'title': 'Unknown Challenge',
            'deadline': 'Unknown',
            'points_required': 0,
            'unlock_points': 0,
            'is_locked': 0,
            'platform': 'Seasons',
          },
        );
      }

      final auth = Provider.of<Auth>(context, listen: false);
      final int myUserId = auth.userId;
      final int challengeId = challengeData?['id'] ?? 0;

      setState(() {
        challenge = challengeData;
        if (challenge != null) {
          normalizeChallenge(challenge!);
        }
      });

      // Fetch seasons for this challenge
      try {
        final challengeProvider =
            Provider.of<Challenge>(context, listen: false);
        await challengeProvider.fetchChallengeSeasonsForChallenge(challengeId);
        final seasons = challengeProvider.challengeSeasons;
        DebugLogger.success('? Loaded ${seasons.length} challengeSeasons');

        if (!mounted) return;
        setState(() {
          challengeSeasons = seasons;
        });

        // Fetch my season details if I have participated
        final mySeasonEntry = seasons.firstWhere(
          (s) => s['user_id'] == myUserId,
          orElse: () => null,
        );

        if (mySeasonEntry != null) {
          final int seasonId = mySeasonEntry['id'];
          DebugLogger.success(
              '?? Fetching season-details for seasonId=$seasonId');

          final storyProvider = Provider.of<Story>(context, listen: false);
          final details = await storyProvider.fetchSeasonDetails(seasonId);

          if (mounted) {
            setState(() {
              mySeasonDetails = details;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              mySeasonDetails = null;
              _isLoading = false;
            });
          }
        }
      } catch (error) {
        DebugLogger.error('? Failed to fetch challengeSeasons: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (error) {
      DebugLogger.error('? Error fetching challenge data: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load challenge: $error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void normalizeChallenge(Map<String, dynamic> c) {
    final bool backendUnlocked = c['has_unlocked'] == true;
    final bool localUnlocked = c['unlocked'] == true;
    final bool isUnlocked = backendUnlocked || localUnlocked;
    c['unlocked'] = isUnlocked;
    c['is_locked'] = isUnlocked ? 0 : 1;
  }

  bool isChallengeLocked(Map<String, dynamic>? challenge) {
    if (challenge == null) return true;
    return challenge['unlocked'] != true;
  }

  SeasonProgressState getSeasonProgressState({
    required bool unlocked,
    required Map<String, dynamic>? seasonDetails,
    required bool isExpired,
  }) {
    final step1 =
        unlocked ? ChallengeStepStatus.completed : ChallengeStepStatus.active;

    final List episodes = mySeasonDetails?['episodes'] ?? [];
    final bool hasUploadedEpisode = episodes.any(
      (e) => (e['video_url'] ?? '').toString().trim().isNotEmpty,
    );

    ChallengeStepStatus step2;
    if (!unlocked) {
      step2 = ChallengeStepStatus.locked;
    } else if (hasUploadedEpisode) {
      step2 = ChallengeStepStatus.completed;
    } else {
      step2 = ChallengeStepStatus.active;
    }

    final auth = Provider.of<Auth>(context, listen: false);
    final int myUserId = auth.userId;

    final mySeason = challengeSeasons.firstWhere(
      (s) => s['user_id'] == myUserId,
      orElse: () => null,
    );

    final bool isWinner = mySeason != null && mySeason['is_winner'] == 1;

    ChallengeStepStatus step3;
    if (!unlocked || !hasUploadedEpisode) {
      step3 = ChallengeStepStatus.locked;
    } else if (isExpired) {
      step3 = ChallengeStepStatus.completed;
      DebugLogger.success('✅ Step 3: Challenge expired → ALL COMPLETED');
    } else if (isWinner) {
      step3 = ChallengeStepStatus.completed;
    } else {
      step3 = ChallengeStepStatus.waiting;
    }

    return SeasonProgressState(
      step1: step1,
      step2: step2,
      step3: step3,
    );
  }

  void handleChallengeTap(
      BuildContext context, Map<String, dynamic>? challenge) {
    if (!mounted) return;

    final String? deadlineStr = challenge?['deadline'];
    bool isExpired = false;
    if (deadlineStr != null && deadlineStr.isNotEmpty) {
      String dateTimeStr = deadlineStr;
      if (!deadlineStr.contains('T')) {
        dateTimeStr = '$deadlineStr 23:59:59';
      }
      final DateTime? deadline = DateTime.tryParse(dateTimeStr);
      if (deadline != null && deadline.isBefore(DateTime.now())) {
        isExpired = true;
      }
    }

    if (isExpired) {
      showScaffoldMessenger(
        context,
        'This challenge has expired. You can no longer participate.',
      );
      return;
    }

    final authProvider = Provider.of<Auth>(context, listen: false);

    if (authProvider.userAvailableCoins >=
        (challenge?['points_required'] ?? 0)) {
      if (challenge?['unlocked'] == true) {
        navigateToCreateSeasonScreen(context);
      } else if (challenge?['achievement_id'] != null &&
          !(challenge?['has_obtained_achievement'] ?? false)) {
        if (!mounted) return;
        showScaffoldMessenger(
          context,
          'You need to obtain the achievement "${challenge?['achievement_title']}" to unlock this challenge.',
        );
      } else if (challenge?['product_id'] != null &&
          !(challenge?['has_purchased_product'] ?? false)) {
        if (!mounted) return;
        showScaffoldMessenger(
          context,
          'You need to purchase the required product "${challenge?['product_title']}" to unlock this challenge.',
        );
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            String unlockMessage;

            if (challenge?['unlock_points'] != null) {
              unlockMessage =
                  'This challenge is locked. Do you want to unlock it using ${challenge?['unlock_points']} points?';
            } else if (challenge?['achievement_id'] != null &&
                (challenge?['has_obtained_achievement'] ?? false)) {
              unlockMessage =
                  'You have the achievement "${challenge?['achievement_title']}". Do you want to use it to unlock this challenge?';
            } else if (challenge?['product_id'] != null &&
                (challenge?['has_purchased_product'] ?? false)) {
              unlockMessage =
                  'You have purchased the product "${challenge?['product_title']}". Do you want to use it to unlock this challenge?';
            } else {
              unlockMessage =
                  'This challenge is locked. Do you want to unlock it?';
            }

            return AlertDialog(
              title: Text('Unlock Challenge'),
              content: Text(unlockMessage),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('No'),
                ),
                TextButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    try {
                      var challengeProvider =
                          Provider.of<Challenge>(context, listen: false);
                      await challengeProvider.unlockChallenge(challenge?['id']);

                      if (!mounted) return;

                      setState(() {
                        challenge?['is_locked'] = 0;
                        challenge?['unlocked'] = true;
                        challenge?['has_unlocked'] = true;
                      });

                      nav.pop();
                      showScaffoldMessenger(
                          context, 'Challenge has been unlocked successfully!');
                      navigateToCreateSeasonScreen(context);
                    } catch (e) {
                      if (!mounted) return;
                      nav.pop();
                      showScaffoldMessenger(
                          context, 'Failed to unlock challenge: $e');
                    }
                  },
                  child: Text('Yes, Unlock Now'),
                ),
              ],
            );
          },
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'You need ${challenge?['points_required']} coins to enter this challenge'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void navigateToCreateSeasonScreen(BuildContext context) async {
    final auth = Provider.of<Auth>(context, listen: false);

    final String? deadlineStr = challenge?['deadline'];
    bool isExpired = false;
    if (deadlineStr != null && deadlineStr.isNotEmpty) {
      String dateTimeStr = deadlineStr;
      if (!deadlineStr.contains('T')) {
        dateTimeStr = '$deadlineStr 23:59:59';
      }
      final DateTime? deadline = DateTime.tryParse(dateTimeStr);
      if (deadline != null && deadline.isBefore(DateTime.now())) {
        isExpired = true;
      }
    }

    if (isExpired) {
      showScaffoldMessenger(
        context,
        'This challenge has expired. You can no longer upload content.',
      );
      return;
    }

    if (auth.role != 'creator') {
      Navigator.of(context).pushNamed(CreatorRequestScreen.routeName);
      return;
    }

    final int challengeId = challenge?['id'] ?? 0;
    final int myUserId = auth.userId;
    await _setChallengeLocked(challengeId, myUserId);

    if (mounted) {
      // Removed unused local participation lock tracking
    }

    Navigator.of(context).pushNamed(
      CreateSeasonScreen.routeName,
      arguments: {
        'is_challenge': true,
        'challenge_id': challenge?['id'],
        'story_topic_id': challenge?['shorts_topic_id'],
        'no_of_mcq': challenge?['no_of_mcq'],
        'points': challenge?['points_required'],
        'lives': challenge?['lives'],
        'heading_id': challenge?['heading_id'],
      },
    ).then((_) {
      _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<dynamic> sortedChallengeSeasons;
    final winnerIndex = challengeSeasons.indexWhere((s) => s['is_winner'] == 1);
    if (winnerIndex != -1) {
      final winner = challengeSeasons[winnerIndex];
      final others = [...challengeSeasons]..removeAt(winnerIndex);
      others.sort(
          (a, b) => (b['total_likes'] ?? 0).compareTo(a['total_likes'] ?? 0));
      sortedChallengeSeasons = [winner, ...others];
    } else {
      sortedChallengeSeasons = [...challengeSeasons]..sort(
          (a, b) => (b['total_likes'] ?? 0).compareTo(a['total_likes'] ?? 0));
    }

    return Scaffold(
      backgroundColor: isDark ? Color.fromARGB(255, 9, 9, 9) : Colors.white,
      appBar: header(context: context, titleText: 'Challenge'),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF090909), const Color(0xFF082032)]
                  : [Colors.white, Colors.grey.shade300],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _isLoading
              ? const Loading()
              : challenge == null
                  ? const ErrorState()
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      child: Column(
                        children: [
                          ChallengeHeader(
                            challenge: challenge!,
                            isDescriptionExpanded: _isDescriptionExpanded,
                            onToggleDescription: () {
                              setState(() {
                                _isDescriptionExpanded =
                                    !_isDescriptionExpanded;
                              });
                            },
                          ),
                          UnlockRewardsTabs(
                            challengeData: challenge,
                            unlockChallengeBenefit: _unlockChallengeBenefit,
                            onUseUnlockChallengeBenefit:
                                _useUnlockChallengeBenefit,
                          ),
                          Builder(
                            builder: (context) {
                              bool isExpired = false;
                              final String? deadlineStr =
                                  challenge?['deadline'];
                              if (deadlineStr != null &&
                                  deadlineStr.isNotEmpty) {
                                String dateTimeStr = deadlineStr;
                                if (!deadlineStr.contains('T')) {
                                  dateTimeStr = '$deadlineStr 23:59:59';
                                }
                                final deadline = DateTime.tryParse(dateTimeStr);
                                if (deadline != null &&
                                    deadline.isBefore(DateTime.now())) {
                                  isExpired = true;
                                }
                              }

                              final auth =
                                  Provider.of<Auth>(context, listen: false);
                              final int myUserId = auth.userId;
                              final bool hasParticipated = challengeSeasons.any(
                                (s) => s['user_id'] == myUserId,
                              );

                              if (isExpired && !hasParticipated) {
                                DebugLogger.warning(
                                    '🏆 Hiding season progress (expired + not participated)');
                                return const SizedBox.shrink();
                              }

                              final unlocked = challenge?['unlocked'] == true;
                              final mySeason = challengeSeasons.firstWhere(
                                (s) => s['user_id'] == myUserId,
                                orElse: () => null,
                              );
                              final seasonProgress = getSeasonProgressState(
                                unlocked: unlocked,
                                seasonDetails: mySeason,
                                isExpired: isExpired,
                              );
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C1C1C),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Challenge Progression',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 12),
                                    ChallengeStepTile(
                                        step: 1,
                                        title: 'Unlock the Challenge',
                                        status: seasonProgress.step1),
                                    ChallengeStepTile(
                                        step: 2,
                                        title: 'Upload Season',
                                        status: seasonProgress.step2),
                                    ChallengeStepTile(
                                      step: 3,
                                      title: 'Result & Rewards',
                                      status: seasonProgress.step3,
                                    ),
                                    const SizedBox(height: 14),
                                    Builder(
                                      builder: (context) {
                                        if (seasonProgress.step1 ==
                                                ChallengeStepStatus.completed &&
                                            seasonProgress.step2 ==
                                                ChallengeStepStatus.completed &&
                                            seasonProgress.step3 ==
                                                ChallengeStepStatus.completed) {
                                          return Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4CAF50),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.check_circle,
                                                    color: Colors.white,
                                                    size: 18),
                                                SizedBox(width: 10),
                                                Text('Completed',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ],
                                            ),
                                          );
                                        }

                                        if (!unlocked) {
                                          return unlockChallengeButton(
                                            onTap: () => handleChallengeTap(
                                                context, challenge),
                                            text: 'Unlock Challenge',
                                          );
                                        } else if (seasonProgress.step2 ==
                                            ChallengeStepStatus.active) {
                                          return GestureDetector(
                                            onTap: () =>
                                                navigateToCreateSeasonScreen(
                                                    context),
                                            child: Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 14),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3DDC84),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(Icons.movie_creation,
                                                      color: Colors.white,
                                                      size: 18),
                                                  SizedBox(width: 10),
                                                  Text('Create Season',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          );
                                        } else {
                                          return Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade600,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.hourglass_top,
                                                    color: Colors.white,
                                                    size: 18),
                                                SizedBox(width: 10),
                                                Text('Waiting for Result',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          if (mySeasonDetails != null)
                            Builder(
                              builder: (context) {
                                final List episodes =
                                    mySeasonDetails!['episodes'] ?? [];
                                final mySeasonId = mySeasonDetails!['id'];
                                final sortedSeasons = [...challengeSeasons]
                                  ..sort((a, b) {
                                    final aPoints =
                                        (a['totalPoints'] as num?)?.toInt() ??
                                            0;
                                    final bPoints =
                                        (b['totalPoints'] as num?)?.toInt() ??
                                            0;
                                    return bPoints.compareTo(aPoints);
                                  });

                                final myIndex = sortedSeasons
                                    .indexWhere((s) => s['id'] == mySeasonId);

                                final myLeaderboardEntry = myIndex != -1
                                    ? sortedSeasons[myIndex]
                                    : null;

                                final report = SeasonReport(
                                  seasonImage:
                                      mySeasonDetails!['thumbnail'] ?? '',
                                  seasonTitle: mySeasonDetails!['title'] ?? '',
                                  totalEpisodes: episodes.length,
                                  uploadedEpisodes: episodes.length,
                                  totalLikes: (myLeaderboardEntry?['totalLikes']
                                              as num?)
                                          ?.toInt() ??
                                      0,
                                  rank: myIndex != -1 ? myIndex + 1 : 0,
                                  rewardEarned:
                                      myLeaderboardEntry?['isWinner'] == true,
                                );

                                return buildSeasonReportCard(report);
                              },
                            ),
                          Builder(
                            builder: (context) {
                              bool isExpired = false;
                              final String? deadlineStr =
                                  challenge?['deadline'];
                              if (deadlineStr != null &&
                                  deadlineStr.isNotEmpty) {
                                String dateTimeStr = deadlineStr;
                                if (!deadlineStr.contains('T')) {
                                  dateTimeStr = '$deadlineStr 23:59:59';
                                }
                                final deadline = DateTime.tryParse(dateTimeStr);
                                if (deadline != null &&
                                    deadline.isBefore(DateTime.now())) {
                                  isExpired = true;
                                }
                              }

                              final auth =
                                  Provider.of<Auth>(context, listen: false);
                              final int myUserId = auth.userId;
                              final bool hasParticipated = challengeSeasons.any(
                                (s) => s['user_id'] == myUserId,
                              );

                              if (isExpired && !hasParticipated) {
                                return const SizedBox.shrink();
                              }

                              final sortedSeasons = [...challengeSeasons]
                                ..sort((a, b) {
                                  final aPoints =
                                      (a['totalPoints'] as num?)?.toInt() ?? 0;
                                  final bPoints =
                                      (b['totalPoints'] as num?)?.toInt() ?? 0;
                                  return bPoints.compareTo(aPoints);
                                });

                              final List<SeasonLeaderboardItem> items =
                                  sortedSeasons.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final s = entry.value;
                                return SeasonLeaderboardItem(
                                  rank: idx + 1,
                                  username: s['title'] ?? 'Unknown',
                                  totalUsersWatched:
                                      (s['totalUsersWatched'] as num?)
                                              ?.toInt() ??
                                          0,
                                  totalUsersUnlocked:
                                      (s['totalUsersUnlocked'] as num?)
                                              ?.toInt() ??
                                          0,
                                  totalDonations:
                                      (s['totalDonations'] as num?)?.toInt() ??
                                          0,
                                  totalPoints:
                                      (s['totalPoints'] as num?)?.toInt() ?? 0,
                                );
                              }).toList();
                              return buildSeasonLeaderboard(items);
                            },
                          ),
                          if (challengeSeasons.isNotEmpty)
                            ParticipatedSeasons(
                              challengeSeasons: sortedChallengeSeasons,
                            ),
                          Footer.scrollBottomSpacer(context),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget buildSeasonReportCard(SeasonReport report) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              report.seasonImage,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.seasonTitle,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18)),
                const SizedBox(height: 8),
                Text('Episodes Uploaded: ${report.uploadedEpisodes}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14)),
                Text('Total Likes: ${report.totalLikes}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14)),
                Text('Rank: ${report.rank}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSeasonLeaderboard(List<SeasonLeaderboardItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Leaderboard',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                SizedBox(width: 50, child: Text("Rank", style: _headerStyle)),
                SizedBox(width: 100, child: Text("Name", style: _headerStyle)),
                SizedBox(
                    width: 70, child: Text("Watched", style: _headerStyle)),
                SizedBox(
                    width: 70, child: Text("Unlocked", style: _headerStyle)),
                SizedBox(
                    width: 80, child: Text("Donations", style: _headerStyle)),
                SizedBox(width: 70, child: Text("Points", style: _headerStyle)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: item.rank == 1
                      ? const Color(0xFFDC9903)
                      : (item.rank == 2
                          ? const Color(0xFFB3B3B3)
                          : (item.rank == 3
                              ? const Color(0xFFA05B28)
                              : const Color(0xFF262626))),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: Text('${item.rank}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))),
                    Expanded(
                        flex: 2,
                        child: Text(item.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13))),
                    Expanded(
                        child: Text('${item.totalUsersWatched}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12))),
                    Expanded(
                        child: Text('${item.totalUsersUnlocked}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12))),
                    Expanded(
                        child: Text('${item.totalDonations}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12))),
                    Expanded(
                        child: Text('${item.totalPoints}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  fontFamily: 'Inter',
  color: Colors.white60,
  fontSize: 10,
  fontWeight: FontWeight.w500,
);

// ==================== PARTICIPATED SEASONS ====================
class ParticipatedSeasons extends StatelessWidget {
  final List<dynamic> challengeSeasons;

  const ParticipatedSeasons({
    super.key,
    required this.challengeSeasons,
  });

  String _formatCount(dynamic v) {
    final n = (v is int) ? v : int.tryParse('$v') ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _smallTile(dynamic s) {
    final String thumbnailUrl = s['image_url'] ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 81.5,
        height: 126.03053283691406,
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade800,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.movie, color: Colors.white38),
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      _formatCount((s['totalPoints'] as num?)?.toInt() ?? 0),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 6,
              child: SizedBox(
                width: 65,
                child: Text(
                  s['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _featuredTile(dynamic s) {
    final bool isWinner = s['is_winner'] == 1;
    final String thumbnailUrl = s['image_url'] ?? '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: isWinner ? scale : 1,
          child: Container(
            decoration: isWinner
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.6),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 163,
                height: 254,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade800,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.movie,
                              size: 48, color: Colors.white38),
                        ),
                      ),
                    ),
                    if (isWinner)
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(seconds: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.amber.withOpacity(0.3),
                                Colors.transparent,
                                Colors.amber.withOpacity(0.2),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (isWinner)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (_, v, __) => Transform.scale(
                            scale: v,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFA500)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.emoji_events,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'WINNER',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 12,
                      left: 10,
                      right: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.visibility,
                                  size: 12, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                _formatCount(
                                    (s['totalUsersWatched'] as num?)?.toInt() ??
                                        0),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.volunteer_activism,
                                  size: 12, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                _formatCount(
                                    (s['totalDonations'] as num?)?.toInt() ??
                                        0),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (challengeSeasons.isEmpty) return const SizedBox();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final featured = challengeSeasons[0];
    final rightTop = challengeSeasons.skip(1).take(4).toList();
    final remaining = challengeSeasons.skip(5).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Participated Seasons:',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${challengeSeasons.length} Seasons',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _featuredTile(featured),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: rightTop.isNotEmpty
                                ? _smallTile(rightTop[0])
                                : const SizedBox()),
                        const SizedBox(width: 10),
                        Expanded(
                            child: rightTop.length > 1
                                ? _smallTile(rightTop[1])
                                : const SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: rightTop.length > 2
                                ? _smallTile(rightTop[2])
                                : const SizedBox()),
                        const SizedBox(width: 10),
                        Expanded(
                            child: rightTop.length > 3
                                ? _smallTile(rightTop[3])
                                : const SizedBox()),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
          if (remaining.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: remaining.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 9 / 16,
              ),
              itemBuilder: (_, i) => _smallTile(remaining[i]),
            ),
          ]
        ],
      ),
    );
  }
}
