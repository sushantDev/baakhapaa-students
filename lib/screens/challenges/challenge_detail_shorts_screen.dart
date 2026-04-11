import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/challenge.dart';
import 'package:baakhapaa/providers/shorts.dart';
import 'package:baakhapaa/screens/shorts/create/create_shorts_screen.dart';
import 'package:baakhapaa/screens/others/creator_request_screen.dart';
import '../../services/subscription_service.dart';
import '../../models/subscription.dart';
// import 'package:baakhapaa/screens/subscription/subscription_screen.dart';
// import 'package:baakhapaa/screens/shorts/single_shorts_screen.dart';
// import 'package:baakhapaa/screens/user/achievements_screen.dart';
// import 'package:baakhapaa/theme/theme_constants.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/loading.dart';
// import 'package:baakhapaa/models/url.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import 'challenge_detail_widgets.dart';
import 'challenge_detail_screens_shared.dart'; // Shared header & other components

class ChallengeDetailShortsScreen extends StatefulWidget {
  static const routeName = '/challenge-detail-shorts';

  final Map<String, dynamic>? challenge;

  const ChallengeDetailShortsScreen({
    Key? key,
    this.challenge,
  }) : super(key: key);

  @override
  State<ChallengeDetailShortsScreen> createState() =>
      _ChallengeDetailShortsScreenState();
}

class _ChallengeDetailShortsScreenState
    extends State<ChallengeDetailShortsScreen> with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  List<dynamic> challengeShorts = [];
  List<dynamic> challenges = [];
  Map<String, dynamic>? challenge;
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
            'platform': 'Shorts',
          },
        );
      }

      // final auth = Provider.of<Auth>(context, listen: false);
      final int challengeId = challengeData?['id'] ?? 0;

      setState(() {
        challenge = challengeData;
        challenges = [];
        if (challenge != null) {
          normalizeChallenge(challenge!);
        }
      });

      // Fetch shorts for this challenge
      try {
        final shortsProvider = Provider.of<Shorts>(context, listen: false);
        await shortsProvider.fetchChallengeShorts(challengeId);
        DebugLogger.success(
            '? Loaded ${shortsProvider.challengeShorts.length} shorts');
        if (!mounted) return;
        setState(() {
          challengeShorts = shortsProvider.challengeShorts;
          _isLoading = false;
        });
      } catch (error) {
        DebugLogger.error('? Failed to fetch challenge shorts: $error');
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

  Map<String, dynamic> getChallengeProgressState() {
    final auth = Provider.of<Auth>(context, listen: false);
    final int myUserId = auth.userId;

    // Check participation from backend challenge_details (same as Season/Product)
    final bool hasParticipated = challengeShorts.any((short) {
      final details = short['challenge_details'];
      return details != null &&
          details.isNotEmpty &&
          short['user_id'] == myUserId;
    });

    DebugLogger.info('👤 User ID: $myUserId');
    DebugLogger.info('📋 Challenge Shorts count: ${challengeShorts.length}');
    DebugLogger.info('✅ Has Participated (from backend): $hasParticipated');

    final String? deadlineStr = challenge?['deadline'];
    bool isExpired = false;
    if (deadlineStr != null && deadlineStr.isNotEmpty) {
      String dateTimeStr = deadlineStr;
      if (!deadlineStr.contains('T')) {
        dateTimeStr = '$deadlineStr 23:59:59';
      }
      final DateTime? deadline = DateTime.tryParse(dateTimeStr);
      final DateTime now = DateTime.now();
      if (deadline != null && deadline.isBefore(now)) {
        isExpired = true;
      }
      DebugLogger.info(
          '⏰ Challenge deadline: $deadlineStr | Parsed: $deadline | Now: $now | Expired: $isExpired');
    }

    bool hasWinnerDeclared = challengeShorts.any((short) =>
        short['challenge_details'] != null &&
        short['challenge_details'].isNotEmpty &&
        short['challenge_details'][0]['is_winner'] == 1);

    DebugLogger.info(
        '🏆 Shorts Challenge - Checking ${challengeShorts.length} shorts for winner');

    final bool resultDeclared = isExpired || hasWinnerDeclared;

    DebugLogger.success(
        '📊 Challenge State: hasParticipated=$hasParticipated | isExpired=$isExpired | resultDeclared=$resultDeclared');

    ChallengeStepStatus step1Status;
    ChallengeStepStatus step2Status;
    ChallengeStepStatus step3Status;
    String buttonText;
    Color buttonColor;
    IconData buttonIcon;
    VoidCallback? buttonAction;
    bool shouldShow = true;

    if (isExpired && !hasParticipated) {
      DebugLogger.warning('🚫 Rule 1: Expired + Not Participated → HIDDEN');
      shouldShow = false;
      step1Status = ChallengeStepStatus.locked;
      step2Status = ChallengeStepStatus.locked;
      step3Status = ChallengeStepStatus.locked;
      buttonText = 'Challenge Expired';
      buttonColor = Colors.grey.shade700;
      buttonIcon = Icons.block;
      buttonAction = null;
    } else if (!isExpired && !hasParticipated) {
      DebugLogger.warning('📝 Rule 2: Not Expired + Not Participated');
      final bool locked = isChallengeLocked(challenge);

      if (locked) {
        final dynamic unlockPointsRaw = challenge?['unlock_points'];
        final int unlockPoints = unlockPointsRaw == null
            ? 0
            : (unlockPointsRaw is int
                ? unlockPointsRaw
                : int.tryParse(unlockPointsRaw.toString()) ?? 0);

        step1Status = ChallengeStepStatus.active;
        step2Status = ChallengeStepStatus.locked;
        step3Status = ChallengeStepStatus.locked;
        buttonText = unlockPoints == 0 ? 'Unlock Free' : 'Unlock Challenge';
        buttonColor = unlockPoints == 0
            ? const Color(0xFF3DDC84)
            : const Color(0xFFE50914);
        buttonIcon = Icons.lock_open;
        buttonAction = () => handleChallengeTap(context, challenge);
      } else {
        step1Status = ChallengeStepStatus.completed;
        step2Status = ChallengeStepStatus.active;
        step3Status = ChallengeStepStatus.locked;
        buttonText = 'Upload Video';
        buttonColor = const Color(0xFF3DDC84);
        buttonIcon = Icons.upload;
        buttonAction = () => navigateToCreateShortsScreen(context);
      }
    } else if (hasParticipated && !resultDeclared) {
      DebugLogger.warning('⏳ Rule 3: Participated + Not Expired → Waiting');
      step1Status = ChallengeStepStatus.completed;
      step2Status = ChallengeStepStatus.completed;
      step3Status = ChallengeStepStatus.waiting;
      buttonText = 'Waiting for Result';
      buttonColor = Colors.grey.shade600;
      buttonIcon = Icons.hourglass_top;
      buttonAction = null;
    } else {
      DebugLogger.success('✅ Rule 4: Participated + Expired → ALL COMPLETED');
      step1Status = ChallengeStepStatus.completed;
      step2Status = ChallengeStepStatus.completed;
      step3Status = ChallengeStepStatus.completed;
      buttonText = 'View Results';
      buttonColor = const Color(0xFF4CAF50);
      buttonIcon = Icons.emoji_events;
      buttonAction = null;
    }

    return {
      'step1': step1Status,
      'step2': step2Status,
      'step3': step3Status,
      'buttonText': buttonText,
      'buttonColor': buttonColor,
      'buttonIcon': buttonIcon,
      'buttonAction': buttonAction,
      'shouldShow': shouldShow,
      'isExpired': isExpired,
      'hasParticipated': hasParticipated,
    };
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
        navigateToCreateShortsScreen(context);
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
                      navigateToCreateShortsScreen(context);
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

  void navigateToCreateShortsScreen(BuildContext context) async {
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

    DebugLogger.info(
        '🚀 Navigating to CreateShortsScreen with challenge_id: ${challenge?['id']}');

    Navigator.of(context).pushNamed(
      CreateShortsScreen.routeName,
      arguments: {
        'is_challenge': true,
        'challenge_id': challenge?['id'],
        'shorts_topic_id': challenge?['shorts_topic_id'],
        'no_of_mcq': challenge?['no_of_mcq'],
        'points': challenge?['points_required'],
        'lives': challenge?['lives'],
      },
    ).then((_) {
      _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<dynamic> sortedChallengeShorts;
    final winnerIndex = challengeShorts.indexWhere((short) =>
        short['challenge_details'] != null &&
        short['challenge_details'].isNotEmpty &&
        short['challenge_details'][0]['is_winner'] == 1);
    if (winnerIndex != -1) {
      final winner = challengeShorts[winnerIndex];
      final others = [...challengeShorts]..removeAt(winnerIndex);
      others.sort((a, b) => (b['likes'] ?? 0).compareTo(a['likes'] ?? 0));
      sortedChallengeShorts = [winner, ...others];
    } else {
      sortedChallengeShorts = [...challengeShorts]
        ..sort((a, b) => (b['likes'] ?? 0).compareTo(a['likes'] ?? 0));
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
                              final progressState = getChallengeProgressState();
                              final shouldShow =
                                  progressState['shouldShow'] as bool;
                              if (!shouldShow) {
                                return const SizedBox.shrink();
                              }
                              return ChallengeProgressCard(
                                step1: progressState['step1']
                                    as ChallengeStepStatus,
                                step2: progressState['step2']
                                    as ChallengeStepStatus,
                                step3: progressState['step3']
                                    as ChallengeStepStatus,
                                step2Title: 'Upload Video',
                                primaryButtonText:
                                    progressState['buttonText'] as String,
                                primaryButtonColor:
                                    progressState['buttonColor'] as Color,
                                primaryIcon:
                                    progressState['buttonIcon'] as IconData,
                                primaryAction: progressState['buttonAction']
                                    as VoidCallback?,
                              );
                            },
                          ),
                          Builder(
                            builder: (context) {
                              final auth =
                                  Provider.of<Auth>(context, listen: false);
                              final int myUserId = auth.userId;
                              final myVideo = challengeShorts.firstWhere(
                                (short) => short['user_id'] == myUserId,
                                orElse: () => null,
                              );
                              if (myVideo != null) {
                                return MyVideoReportCard(videoData: myVideo);
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          if (challengeShorts.isNotEmpty)
                            ChallengeLeaderboard(
                              challengeShorts: sortedChallengeShorts,
                            ),
                          if (challengeShorts.isNotEmpty)
                            ParticipatedVideos(
                              challengeShorts: sortedChallengeShorts,
                            ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
