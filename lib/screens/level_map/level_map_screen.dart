import 'dart:ui';

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
import 'package:baakhapaa/services/subscription_service.dart';
import 'package:baakhapaa/models/subscription.dart';

import 'widgets/level_models.dart';
import 'widgets/level_timeline_item.dart';
import 'widgets/bottom_welcome_section.dart';

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
  static const double _itemHeight =
      280.0; // Increased to account for larger gap

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
          // In reverse list (L1...L10), bottom means L1 (start of list)
          // Since reverse: true, item 0 is at bottom.
          // Scroll offset 0 shows item 0.
          targetOffset = 0.0;
        } else if (_currentLevelIndex >= 0) {
          // Scroll up to the level
          targetOffset = (_currentLevelIndex * _itemHeight);
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

        // Use ascending order (L1 is index 0)
        final levels = mappedLevels;

        // Find and store current level index for auto-scroll
        int currentIdx = levels.indexWhere((l) => l.isCurrent);
        bool scrollToBottom = false;

        // If no active level found (Level 0 / Start), default to the first level
        if (currentIdx == -1 && levels.isNotEmpty) {
          currentIdx = 0;
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
          body: Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Image.asset(
                    'assets/images/level_map_bg.png',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.8),
                  ),
                ),
              ),

              SafeArea(
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
                              reverse: true, // Scroll from bottom (Level 1)
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              children: [
                                const BottomWelcomeSection(),
                                const SizedBox(height: 24),
                                // Level items with snake pattern layout
                                ...levels.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final level = entry.value;

                                  // In reversed ListView (L1 at bottom/index 0):
                                  // Visual Top is Last Index.
                                  // Visual Bottom is First Index.
                                  final isFirst =
                                      index == levels.length - 1; // Visual Top
                                  final isLast = index == 0; // Visual Bottom
                                  final isAlternateLeft =
                                      index % 2 == 0; // Even indices on left

                                  // Determine rail color for this segment
                                  final bool isAboveCurrent =
                                      !level.isCompleted && !level.isCurrent;

                                  final railColor = isAboveCurrent
                                      ? const Color(0xFF3A3A3A)
                                      : const Color(0xFFFF9F1C);

                                  return LevelTimelineItem(
                                    level: level,
                                    isFirst: isFirst,
                                    isLast: isLast,
                                    railColor: railColor,
                                    connectorColor: railColor,
                                    isAlternateLeft: isAlternateLeft,
                                    index: index,
                                    // Above corresponds to Next Index (Visually Higher)
                                    isAboveCompleted: index < levels.length - 1
                                        ? levels[index + 1].isCompleted
                                        : false,
                                    // Below corresponds to Previous Index (Visually Lower)
                                    isBelowCompleted: index > 0
                                        ? levels[index - 1].isCompleted
                                        : false,
                                    unlockAchievementBenefit:
                                        _unlockAchievementBenefit,
                                    isUnlockingAchievement:
                                        _isUnlockingAchievement,
                                    onUnlockAchievement: (id) =>
                                        _useUnlockAchievementBenefit(id),
                                  );
                                }).toList(),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
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

      String? imageUrl = raw['url'] ?? raw['image'] ?? raw['icon'];
      final images = raw['images'] as List?;
      if (images != null && images.isNotEmpty) {
        imageUrl = images[0]['thumbnail'] ?? imageUrl;
      }

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
                    'https://app.baakhapaa.com/storage/${images[0]['full']}';
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
