import 'package:baakhapaa/providers/auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/loading.dart';
import 'package:baakhapaa/providers/levels.dart';
import 'package:baakhapaa/utils/debug_logger.dart';
import 'package:baakhapaa/providers/shop.dart';
import 'package:baakhapaa/providers/challenge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:baakhapaa/services/subscription_service.dart';
import 'package:baakhapaa/models/subscription.dart';

class LevelMapScreen extends StatefulWidget {
  static const routeName = '/level-map';

  const LevelMapScreen({Key? key}) : super(key: key);

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  bool _isInit = true;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  int _currentLevelIndex = -1;

  // Benefit variables
  UserBenefitUsage? _upgradeLevelBenefit;
  UserBenefitUsage? _unlockAchievementBenefit;
  bool _isUpgrading = false;
  bool _isUnlockingAchievement = false;

  // Estimated height per level item (card + connector gap)
  static const double _itemHeight = 180.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _loadData();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _loadData() async {
    try {
      final levelsProvider = Provider.of<Levels>(context, listen: false);
      final authProvider = Provider.of<Auth>(context, listen: false);
      final shopProvider = Provider.of<Shop>(context, listen: false);
      final challengeProvider = Provider.of<Challenge>(context, listen: false);

      await Future.wait([
        levelsProvider.fetchAllLevels(),
        levelsProvider.fetchUserProgress(),
        authProvider.getAchievements(),
        shopProvider.getForYouProducts(),
        challengeProvider.fetchChallenges(),
        _checkSubscriptionBenefits(),
      ]);

      if (mounted) {
        _scheduleAutoScroll();
      }
    } catch (e) {
      DebugLogger.error('Error loading level map data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Schedule auto-scroll after build
        _scheduleAutoScroll();
      }
    }
  }

  void _scheduleAutoScroll({bool toBottom = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        double targetOffset = 0.0;
        if (toBottom) {
          targetOffset = _scrollController.position.maxScrollExtent;
        } else if (_currentLevelIndex >= 0) {
          targetOffset = (_currentLevelIndex * _itemHeight) + 500;
        } else {
          return;
        }

        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 2000),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _checkSubscriptionBenefits() async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (!auth.isSubscribed) {
      return;
    }

    try {
      final subService = SubscriptionService(context: context);
      final response = await subService.getUserBenefitStatus();
      if (mounted && response.success && response.items.isNotEmpty) {
        setState(() {
          final benefits = response.items.first.benefits;

          try {
            // ID 1 is Upgrade level
            _upgradeLevelBenefit = benefits.firstWhere(
              (b) => b.benefitType.id == 1,
            );
          } catch (_) {
            _upgradeLevelBenefit = null;
          }

          try {
            // ID 6 is Unlock Achievement
            _unlockAchievementBenefit = benefits.firstWhere(
              (b) => b.benefitType.id == 6,
            );
          } catch (_) {
            _unlockAchievementBenefit = null;
          }
        });
      }
    } catch (e) {
      DebugLogger.error('Error checking subscription benefits: $e');
    }
  }

  Future<void> _useUpgradeLevelBenefit() async {
    if (_upgradeLevelBenefit == null) return;

    final remaining = _upgradeLevelBenefit!.usage.remaining;
    final afterUsage = _upgradeLevelBenefit!.usage.isUnlimited
        ? remaining
        : (remaining > 0 ? remaining - 1 : 0);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title:
            const Text('Upgrade Level', style: TextStyle(color: Colors.white)),
        content: Text(
          'Your remaining benefit for Upgrade Level is $remaining. Would you like to use 1 to skip all requirements and reach the next level? Your remaining benefit will be $afterUsage.',
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
                backgroundColor: const Color(0xFFFFC83E)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Upgrade Now',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpgrading = true);

    try {
      // 1. Show loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFC83E))),
      );

      final levelsProvider = Provider.of<Levels>(context, listen: false);

      // 2. Perform upgrade via provider
      final nextLevelId = levelsProvider.nextLevel?['id'];
      await levelsProvider.upgradeLevelWithBenefit(
        userBenefitUsageId: _upgradeLevelBenefit!.id,
        nextLevelId:
            nextLevelId != null ? int.tryParse(nextLevelId.toString()) : null,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader

        // 3. Refresh benefit status
        await _checkSubscriptionBenefits();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Level upgraded successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to upgrade level: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpgrading = false);
    }
  }

  Future<void> _useUnlockAchievementBenefit(int achievementId) async {
    if (_unlockAchievementBenefit == null) return;

    final remaining = _unlockAchievementBenefit!.usage.remaining;
    final afterUsage = _unlockAchievementBenefit!.usage.isUnlimited
        ? remaining
        : (remaining > 0 ? remaining - 1 : 0);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Unlock Achievement',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Your remaining benefit for Unlock Achievement is $remaining. Would you like to use 1 to unlock this achievement? Your remaining benefit will be $afterUsage.',
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
                backgroundColor: const Color(0xFFFFC83E)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unlock',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUnlockingAchievement = true);

    try {
      // 1. Show loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFC83E))),
      );

      final authProvider = Provider.of<Auth>(context, listen: false);
      final subService =
          SubscriptionService(context: context, authToken: authProvider.token);

      // 2. Claim achievement
      await authProvider.claimAchievements(achievementIds: [achievementId]);

      // 3. Update benefit usage
      await subService.updateUserBenefitUsage(
        userBenefitUsageId: _unlockAchievementBenefit!.id,
        usedCount: _unlockAchievementBenefit!.usage.usedCount + 1,
        availableCount: _unlockAchievementBenefit!.usage.availableCount,
        remaining: _unlockAchievementBenefit!.usage.isUnlimited
            ? _unlockAchievementBenefit!.usage.remaining
            : _unlockAchievementBenefit!.usage.remaining - 1,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader

        // 4. Refresh everything
        await _loadData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Achievement unlocked successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        Navigator.of(context, rootNavigator: true).pop(); // Close loader
      DebugLogger.error('Error unlocking achievement with benefit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUnlockingAchievement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: header(
          context: context,
          titleText: 'Level Map',
        ),
        body: const Loading(),
      );
    }

    return Consumer<Levels>(
      builder: (context, levelsProvider, _) {
        final mappedLevels = _mapLevelsFromProvider(levelsProvider);

        // Show latest / highest level at the top
        final levels = mappedLevels.reversed.toList();

        // Find and store current level index for auto-scroll
        int currentIdx = levels.indexWhere((l) => l.isCurrent);
        bool scrollToBottom = false;

        // If no active level found (Level 0 / Start), default to the bottom (Level 1)
        if (currentIdx == -1 && levels.isNotEmpty) {
          currentIdx = levels.length - 1;
          scrollToBottom = true;
        }

        if (currentIdx != -1 && _currentLevelIndex == -1) {
          _currentLevelIndex = currentIdx;
          _scheduleAutoScroll(toBottom: scrollToBottom);
        }

        return Scaffold(
          appBar: header(
            context: context,
            titleText: 'Level Map',
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF140B02),
                  Color(0xFF000000),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _buildProgressHeader(context),
                  const SizedBox(height: 8),
                  Expanded(
                    child: levels.isEmpty
                        ? const Center(
                            child: Text(
                              'No levels found.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: [
                              // Level items with snake pattern layout
                              ...levels.asMap().entries.map((entry) {
                                final index = entry.key;
                                final level = entry.value;
                                final isFirst = index == 0;
                                final isLast = index == levels.length - 1;
                                final isAlternateLeft =
                                    index % 2 == 0; // Even indices on left

                                // Determine rail color for this segment
                                // Orange for completed levels and current level
                                // Gray for locked levels
                                final bool isAboveCurrent =
                                    !level.isCompleted && !level.isCurrent;

                                final railColor = isAboveCurrent
                                    ? const Color(0xFF3A3A3A)
                                    : const Color(0xFFFF9F1C);

                                return _LevelTimelineItem(
                                  level: level,
                                  isFirst: isFirst,
                                  isLast: isLast,
                                  railColor: railColor,
                                  connectorColor: railColor,
                                  isAlternateLeft:
                                      isAlternateLeft && !level.isCompleted ||
                                          level.isCompleted && isAlternateLeft,
                                  index: index,
                                );
                              }).toList(),
                              const SizedBox(height: 24),
                              const _BottomWelcomeSection(),
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

  List<LevelData> _mapLevelsFromProvider(Levels levelsProvider) {
    final allLevels = levelsProvider.allLevels;
    final currentLevel = levelsProvider.currentLevel;

    if (allLevels.isEmpty) return [];

    int currentIndex = -1;
    if (currentLevel != null) {
      currentIndex = allLevels.indexWhere(
        (lvl) => lvl['id'] != null && lvl['id'] == currentLevel['id'],
      );
    }

    if (currentIndex != -1 && levelsProvider.remainingActions.isNotEmpty) {
      final currentLevelActions =
          (allLevels[currentIndex]['actions'] ?? []) as List;

      if (levelsProvider.remainingActions.isNotEmpty) {
        final remainingAction = levelsProvider.remainingActions.first;
        final remainingActionMap = remainingAction as Map<dynamic, dynamic>;
        final action = remainingActionMap['action'] as Map<dynamic, dynamic>? ??
            <String, dynamic>{};

        if (!currentLevelActions.any((a) => a['id'] == action['id'])) {
          currentIndex += 1;
          if (currentIndex >= allLevels.length) {
            currentIndex = allLevels.length - 1;
          }
        }
      }
    }

    return allLevels.asMap().entries.map((entry) {
      final index = entry.key;
      final raw = Map<String, dynamic>.from(entry.value as Map);

      final levelNumberRaw =
          raw['order'] ?? raw['level_no'] ?? raw['level_number'] ?? (index + 1);
      final levelNumber = levelNumberRaw is int
          ? levelNumberRaw
          : int.tryParse(levelNumberRaw.toString()) ?? (index + 1);

      final name = raw['name'] ?? 'Level $levelNumber';
      final subtitle = raw['desc'] ?? '';
      final imageUrl = raw['url'] ?? raw['image'] ?? raw['icon'];

      final List<RequirementData> requirements = [];
      final actions = raw['actions'] as List<dynamic>? ?? [];

      final isCurrent = currentIndex == index;
      final isCompleted = currentIndex != -1 && index < currentIndex;

      for (var actionItem in actions) {
        final actionMap = Map<String, dynamic>.from(actionItem as Map);
        String reqText = levelsProvider.getReadableRequirement(actionMap);
        int? currentVal;
        int? requiredVal;
        bool completedReq = isCompleted;

        final pivot = actionMap['pivot'] != null
            ? Map<String, dynamic>.from(actionMap['pivot'] as Map)
            : null;
        if (pivot != null) {
          final value = pivot['value'];
          // Safe conversion for required value
          if (value != null) {
            requiredVal = value is int ? value : int.tryParse(value.toString());
          }
        }

        if (isCurrent) {
          final allProviderActions = [
            ...levelsProvider.remainingActions,
            ...levelsProvider.completedActions,
          ];

          final actionId = actionMap['id'];
          final matchingProviderAction = Map<String, dynamic>.from(
            allProviderActions.firstWhere(
              (act) {
                final providerActionData = act as Map;
                final providerAction = providerActionData['action'] as Map?;
                return providerAction?['id'] == actionId;
              },
              orElse: () => <dynamic, dynamic>{},
            ) as Map,
          );

          if (matchingProviderAction.isNotEmpty) {
            // Safe conversion for current progress
            final currentProgress = matchingProviderAction['current_progress'];
            currentVal = currentProgress is int
                ? currentProgress
                : int.tryParse(currentProgress?.toString() ?? '');

            if (requiredVal == null) {
              final rVal = matchingProviderAction['required_value'];
              requiredVal =
                  rVal is int ? rVal : int.tryParse(rVal?.toString() ?? '');
            }
            completedReq = matchingProviderAction['completed'] ?? false;
          }
        } else if (isCompleted) {
          currentVal = requiredVal;
          completedReq = true;
        } else {
          currentVal = 0;
          completedReq = false;
        }

        final type = actionMap['type']?.toString().toLowerCase();
        final options = actionMap['options']?.toString().toLowerCase();
        String? imageUrl;
        String? itemId = pivot?['value']?.toString();

        if (type == 'selection') {
          if (options == 'badge' || actionMap['title'] == 'Badge Required') {
            final authProvider = Provider.of<Auth>(context, listen: false);
            final List achievements = authProvider.achievements;
            final dynamic match = achievements.firstWhere(
              (a) => a['id']?.toString() == itemId,
              orElse: () => null,
            );
            if (match != null) {
              reqText = 'Earn achievement: ${match['title']}';
              imageUrl = match['url'];
            }
          } else if (options == 'product') {
            final shopProvider = Provider.of<Shop>(context, listen: false);
            final List products = [
              ...shopProvider.forYouProducts,
              ...shopProvider.productsOnly
            ];
            final dynamic match = products.firstWhere(
              (p) => p['id']?.toString() == itemId,
              orElse: () => null,
            );
            if (match != null) {
              reqText = 'Purchase: ${match['title']}';
              final images = match['images'];
              if (images != null && images is List && images.isNotEmpty) {
                imageUrl =
                    'https://student.baakhapaa.com/storage/${images[0]['full']}';
              }
            }
          } else if (options == 'challenge') {
            final challengeProvider =
                Provider.of<Challenge>(context, listen: false);
            final List challenges = challengeProvider.challenges;
            final dynamic match = challenges.firstWhere(
              (c) => c['id']?.toString() == itemId,
              orElse: () => null,
            );
            if (match != null) {
              reqText = 'Join challenge: ${match['title']}';
            }
          }
        }

        // Store achievement ID for benefit usage
        int? achievementId;
        if (type == 'selection' &&
            (options == 'badge' || actionMap['title'] == 'Badge Required')) {
          achievementId = int.tryParse(itemId ?? '');
        }

        requirements.add(RequirementData(
          text: reqText,
          currentProgress: currentVal,
          requiredValue: requiredVal,
          isCompleted: completedReq,
          imageUrl: imageUrl,
          type: type,
          achievementId: achievementId,
        ));
      }

      // Fallback if no actions
      if (requirements.isEmpty) {
        requirements.add(RequirementData(
          text: 'Complete level objectives',
          isCompleted: isCompleted,
        ));
      }

      // Safe conversion for reward points
      final rewardPointsRaw =
          raw['reward_points'] ?? raw['points_reward'] ?? raw['reward'] ?? 0;
      final rewardPoints = rewardPointsRaw is int
          ? rewardPointsRaw
          : int.tryParse(rewardPointsRaw.toString()) ?? 0;
      return LevelData(
        number: levelNumber,
        title: name,
        subtitle: subtitle,
        requirements: requirements,
        isCurrent: isCurrent,
        isCompleted: isCompleted,
        rewardPoints: rewardPoints,
        imageUrl: imageUrl,
      );
    }).toList();
  }

  Widget _buildProgressHeader(BuildContext context) {
    return Consumer<Levels>(
      builder: (context, levelsProvider, child) {
        final state = context.findAncestorStateOfType<_LevelMapScreenState>();
        final hasBenefit = state?._upgradeLevelBenefit != null &&
            (state!._upgradeLevelBenefit!.canUse ||
                state._upgradeLevelBenefit!.usage.isUnlimited);
        final isMaxLevel = levelsProvider.isMaxLevel;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFFFC83E),
                child: Icon(
                  Icons.star,
                  color: Colors.black,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (levelsProvider.currentLevel != null)
                      Text(
                        levelsProvider.currentLevel!['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasBenefit && !isMaxLevel)
                TextButton.icon(
                  onPressed:
                      state._isUpgrading ? null : state._useUpgradeLevelBenefit,
                  icon: const Icon(Icons.bolt, color: Colors.amber, size: 18),
                  label: Text(
                    state._isUpgrading ? 'Upgrading...' : 'Upgrade Now',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber.withOpacity(0.1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.amber, width: 1),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class RequirementData {
  final String text;
  final int? currentProgress;
  final int? requiredValue;
  final bool isCompleted;
  final String? imageUrl;
  final String? type;
  final int? achievementId;

  const RequirementData({
    required this.text,
    this.currentProgress,
    this.requiredValue,
    this.isCompleted = false,
    this.imageUrl,
    this.type,
    this.achievementId,
  });
}

class LevelData {
  final int number;
  final String title;
  final String subtitle;
  final List<RequirementData> requirements;
  final bool isCurrent;
  final bool isCompleted;
  final int rewardPoints;
  final String? imageUrl;

  const LevelData({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.requirements,
    required this.rewardPoints,
    this.isCurrent = false,
    this.isCompleted = false,
    this.imageUrl,
  });
}

class _LevelTimelineItem extends StatelessWidget {
  final LevelData level;
  final bool isFirst;
  final bool isLast;
  final Color railColor;
  final Color connectorColor;
  final bool isAlternateLeft;
  final int index;

  const _LevelTimelineItem({
    Key? key,
    required this.level,
    required this.isFirst,
    required this.isLast,
    required this.railColor,
    required this.connectorColor,
    required this.isAlternateLeft,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = level.isCurrent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left side progress bar with avatar (width fixed at 58)
              SizedBox(
                width: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Vertical progress rail
                    if (isCurrent) ...[
                      // Split rail for current level: gray above, orange below
                      Positioned(
                        left: 11,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 6,
                          color: const Color(0xFF3A3A3A),
                        ),
                      ),
                      Positioned(
                        left: 11,
                        top: 80,
                        bottom: 0,
                        child: Container(
                          width: 6,
                          color: const Color(0xFFFF9F1C),
                        ),
                      ),
                    ] else
                      // Single color rail for other levels
                      Positioned(
                        left: 11,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 6,
                          decoration: BoxDecoration(
                            color: railColor,
                            borderRadius: isFirst
                                ? const BorderRadius.only(
                                    topLeft: Radius.circular(3),
                                    topRight: Radius.circular(3),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    // User avatar (only for current level)
                    if (isCurrent)
                      Positioned(
                        top: 70.0,
                        left: 0,
                        child: Consumer<Auth>(
                          builder: (context, auth, child) {
                            String imageUrl =
                                'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';

                            if (auth.image != null && auth.image!.isNotEmpty) {
                              imageUrl =
                                  auth.image!.first['thumbnail'] ?? imageUrl;
                            }

                            return Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundColor: Colors.black,
                                child: ClipOval(
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    width: 26,
                                    height: 26,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 18,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              // Right side cards with snake pattern
              Expanded(
                child: _buildSnakePatternCards(context),
              ),
            ],
          ),
        ),
        // Connector gap to next item
        if (!isLast)
          Row(
            children: [
              SizedBox(
                width: 58,
                height: 60,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(left: 11),
                    width: 6,
                    height: 60,
                    decoration: BoxDecoration(
                      color: connectorColor,
                      borderRadius: isLast
                          ? const BorderRadius.only(
                              bottomLeft: Radius.circular(3),
                              bottomRight: Radius.circular(3),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
      ],
    );
  }

  Widget _buildSnakePatternCards(BuildContext context) {
    final bool isCurrent = level.isCurrent;
    final bool isCompleted = level.isCompleted;
    final bool isLocked = !isCompleted && !isCurrent;
    final bool cardOnLeft = isCompleted && isAlternateLeft;

    if (isCurrent || isLocked) {
      // Current and locked levels: center the card
      return Align(
        alignment: Alignment.center,
        child: _LevelCard(level: level),
      );
    }

    // Snake pattern: alternate left-right for completed cards only
    if (cardOnLeft)
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(right: 80),
          child: _LevelCard(level: level),
        ),
      );
    else
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(left: 80),
          child: _LevelCard(level: level),
        ),
      );
  }
}

class _LevelCard extends StatelessWidget {
  final LevelData level;

  const _LevelCard({Key? key, required this.level}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (level.isCompleted) {
      return _buildCompletedCard(context);
    }

    final bool isCurrent = level.isCurrent;
    final List<RequirementData> visualReqs =
        level.requirements.where((r) => r.imageUrl != null).toList();
    final List<RequirementData> standardReqs =
        level.requirements.where((r) => r.imageUrl == null).toList();

    final int completedTasks =
        level.requirements.where((r) => r.isCompleted).length;
    final int totalTasks = level.requirements.length;
    final double progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1611),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF332A24), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Level Image
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                    image: level.imageUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(level.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: level.imageUrl == null
                      ? const Center(
                          child:
                              Icon(Icons.stars, color: Colors.amber, size: 32))
                      : null,
                ),
                const SizedBox(width: 16),
                // Level Info and Progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LEVEL ${level.number}'.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completedTasks / $totalTasks tasks complete',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          backgroundColor: const Color(0xFF3D2F26),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 0
                                ? const Color(0xFFD4A056)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Featured Task Section
          if (visualReqs.isNotEmpty) ...[
            _buildSectionDivider('FEATURED TASK'),
            const SizedBox(height: 8),
            SizedBox(
              height: 104, // Height of card + padding
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: visualReqs.map((req) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _showTasksPopup(context, level),
                        child: Container(
                          width: 240, // Fixed width for scrollable cards
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12, width: 1),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: req.imageUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      req.text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Progress this task to level up.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 10,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          // Task List Section
          if (standardReqs.isNotEmpty) ...[
            _buildSectionDivider('TASK LIST'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: standardReqs.map((req) {
                  return _buildRequirementRow(context, req, isCurrent);
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Footer Status
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                isCurrent ? 'In Progress' : 'Locked',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1611),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFD4A056).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Checkmark
          const Icon(
            Icons.check_rounded,
            color: Color(0xFFD4A056),
            size: 32,
          ),
          // Level Text
          Text(
            'LEVEL ${level.number}'.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          // Reward Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2C241E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/coins.png', width: 24, height: 24),
                Text(
                  '${level.requirements.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: Colors.white10, indent: 16, endIndent: 8)),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const Expanded(
              child: Divider(color: Colors.white10, indent: 8, endIndent: 16)),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(
      BuildContext context, RequirementData req, bool isCurrent) {
    final bool reqCompleted = req.isCompleted;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reqCompleted
              ? const Color(0xFFD4A056).withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: reqCompleted ? const Color(0xFFD4A056) : Colors.white24,
                width: 2,
              ),
              color: reqCompleted
                  ? const Color(0xFFD4A056).withOpacity(0.2)
                  : Colors.transparent,
            ),
            child: reqCompleted
                ? const Icon(Icons.check, size: 14, color: Color(0xFFD4A056))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.text,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (req.currentProgress != null &&
                    req.requiredValue != null &&
                    !reqCompleted) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${req.currentProgress} / ${req.requiredValue}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTasksPopup(BuildContext context, LevelData level) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF120903),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Colors.white12, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC83E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Level ${level.number}',
                    style: const TextStyle(
                      color: Color(0xFF2C1A0D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Level Requirements',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: level.requirements.length,
                itemBuilder: (context, index) {
                  final req = level.requirements[index];
                  final bool reqCompleted = req.isCompleted;
                  final state =
                      context.findAncestorStateOfType<_LevelMapScreenState>();
                  final benefit = state?._unlockAchievementBenefit;
                  final hasAchievementBenefit = benefit != null &&
                      (benefit.canUse || benefit.usage.isUnlimited);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: reqCompleted
                            ? const Color(0xFF4CAF50).withOpacity(0.3)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (req.imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: req.imageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 56,
                            height: 56,
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              reqCompleted ? Icons.check : Icons.list,
                              color: reqCompleted
                                  ? const Color(0xFF4CAF50)
                                  : Colors.white30,
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (req.currentProgress != null &&
                                  req.requiredValue != null) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (req.currentProgress ?? 0) /
                                        (req.requiredValue ?? 1),
                                    backgroundColor: Colors.white10,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      reqCompleted
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFFFC83E),
                                    ),
                                    minHeight: 4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Progress: ${req.currentProgress} / ${req.requiredValue}',
                                  style: TextStyle(
                                    color: reqCompleted
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFFFC83E),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!reqCompleted &&
                            req.achievementId != null &&
                            hasAchievementBenefit)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Tooltip(
                              message: 'Unlock with Benefit',
                              child: InkWell(
                                onTap: state!._isUnlockingAchievement == true
                                    ? null
                                    : () {
                                        Navigator.of(context)
                                            .pop(); // Close popup first
                                        state._useUnlockAchievementBenefit(
                                            req.achievementId!);
                                      },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.amber.withOpacity(0.5)),
                                  ),
                                  child: const Icon(Icons.bolt,
                                      color: Colors.amber, size: 20),
                                ),
                              ),
                            ),
                          ),
                        if (reqCompleted)
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Color(0xFF4CAF50),
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomWelcomeSection extends StatefulWidget {
  const _BottomWelcomeSection({Key? key}) : super(key: key);

  @override
  State<_BottomWelcomeSection> createState() => _BottomWelcomeSectionState();
}

class _BottomWelcomeSectionState extends State<_BottomWelcomeSection> {
  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    _checkIfShown();
  }

  void _checkIfShown() {
    setState(() {
      _showWelcome = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showWelcome) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0602),
        border: Border(
          top: BorderSide(
            color: Colors.white12,
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Welcome content
          Padding(
            padding: const EdgeInsets.only(
                right: 32), // Add padding to avoid overlap with close button
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SizedBox(height: 4),
                Text(
                  'Welcome',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Complete the tasks to level up and earn rewards.\nEvery task you complete brings you closer to your next reward.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
