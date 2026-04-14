import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/widgets/TicketWidget.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/loading.dart';
import 'package:baakhapaa/widgets/achievement_purchase_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../services/subscription_service.dart';
import '../../models/subscription.dart';
import '../../utils/debug_logger.dart';

class AchievementsScreen extends StatefulWidget {
  static const routeName = '/achievements-screen';
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with PuppetInteractionMixin {
  var _isInit = false;
  var _isLoading = true;
  late List<dynamic> _achievements = [];
  Map<String, List<Map<String, dynamic>>> categorizedAchievements = {};
  String _selectedCategory = 'Yours';

  UserBenefitUsage? _unlockAchievementBenefit;
  bool _isUnlockingAchievement = false;

  // Theme colors
  Color get primaryColor => const Color.fromARGB(255, 222, 211, 115);
  Color get darkBackgroundColor => const Color(0xFF082032);
  Color get darkSurfaceColor => const Color(0xFF2A2A3E);
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  Color get backgroundColor =>
      isDarkMode ? darkBackgroundColor : Colors.grey.shade50;
  Color get surfaceColor => isDarkMode ? darkSurfaceColor : Colors.white;
  Color get primaryTextColor => isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryTextColor =>
      isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600;
  Color get borderColor => isDarkMode ? Colors.white12 : Colors.grey.shade300;

  List<String> get _availableCategories {
    final categories = <String>{'Yours'};
    for (var achievement in _achievements) {
      final category = achievement['achievement_category'] ?? 'Other';
      categories.add(category);
    }
    return categories.toList();
  }

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      var _achievementsProvider = Provider.of<Auth>(context, listen: false);
      _achievementsProvider.getAchievements().then(
        (_) {
          setState(() {
            _achievements = _achievementsProvider.achievements.toList();
            _categorizeAchievements();
            _isLoading = false;
          });
        },
      );
      _checkSubscriptionBenefits();
      _isInit = true;
    }
    super.didChangeDependencies();
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
          try {
            // ID 6 is Unlock Achievement
            _unlockAchievementBenefit =
                response.items.first.benefits.firstWhere(
              (b) => b.benefitType.id == 6,
            );
          } catch (_) {
            _unlockAchievementBenefit = null;
          }
        });
      }
    } catch (e) {
      DebugLogger.error('Error checking achievement unlock benefit: $e');
    }
  }

  void _categorizeAchievements() {
    categorizedAchievements.clear();

    for (var achievement in _achievements) {
      String category = achievement['achievement_category'] ?? 'Other';

      if (!categorizedAchievements.containsKey(category)) {
        categorizedAchievements[category] = [];
      }

      categorizedAchievements[category]!.add(achievement);
    }
  }

  List<int> extractAchievementIds(dynamic achievements) {
    if (achievements == null) {
      return [];
    }
    return (achievements as List)
        .where((achievement) => _canClaimAchievement(achievement))
        .map<int>((achievement) => achievement['id'] as int)
        .toList();
  }

  // Normalize products shape from API to a list of product maps
  List<Map<String, dynamic>> _normalizeProducts(dynamic products) {
    if (products == null) return [];
    if (products is List) {
      return products
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (products is Map) {
      return products.values
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
          .toList();
    }
    return [];
  }

  // Normalize seasons
  List<Map<String, dynamic>> _normalizeSeasons(dynamic seasons) {
    if (seasons == null) return [];
    if (seasons is List) {
      return seasons
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
          .toList();
    }
    return [];
  }

  bool _canClaimAchievement(Map<String, dynamic> achievement) {
    // Already claimed
    if (achievement['claimed'] == 1) return false;

    // Must be obtained/unlocked first
    if (achievement['obtained'] != 1) return false;

    // If purchased via bypass, allow immediate claim
    if (achievement['purchased'] == 1) return true;

    // Check product purchase requirements
    final normalizedProducts = _normalizeProducts(achievement['products']);
    if (normalizedProducts.isNotEmpty) {
      final level = achievement['level'] ?? 1;
      for (final product in normalizedProducts) {
        final purchaseCount = product['purchase_count'] ?? 0;
        if (purchaseCount < level) {
          return false; // Not enough purchases for this level
        }
      }
    }

    // Check season unlock requirements
    final normalizedSeasons = _normalizeSeasons(achievement['seasons']);
    if (normalizedSeasons.isNotEmpty) {
      for (final season in normalizedSeasons) {
        final unlocked = season['unlocked'] ?? false;
        if (!unlocked) {
          return false; // Season not unlocked
        }
      }
    }

    return true;
  }

  // Calculate overall progress percentage using the progress object from API
  double _calculateProgressPercentage(Map<String, dynamic> achievement) {
    final progress = achievement['progress'];
    if (progress == null || progress is! Map) return 0.0;

    // If progress is empty, check claimed status
    if (progress.isEmpty) {
      return achievement['claimed'] == 1 ? 100.0 : 0.0;
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
      return achievement['claimed'] == 1 ? 100.0 : 0.0;
    }

    return totalPercent / criteriaCount;
  }

  String _getUserType(String? type) {
    if (type == null) return 'player';
    return type.toLowerCase();
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
        return primaryColor;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'common':
        return Icons.star;
      case 'special':
        return Icons.diamond;
      case 'elite':
      case 'elite ':
        return Icons.workspace_premium;
      case 'seasonal':
        return Icons.eco;
      case 'milestone':
        return Icons.flag;
      default:
        return Icons.emoji_events;
    }
  }

  Widget _buildOverallProgressHeader() {
    final totalAchievements = _achievements.length;
    final claimedAchievements =
        _achievements.where((a) => a['claimed'] == 1).length;
    final obtainedAchievements =
        _achievements.where((a) => a['obtained'] == 1).length;
    final progressPercentage =
        totalAchievements > 0 ? (claimedAchievements / totalAchievements) : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [const Color(0xFF2C2C2C), const Color(0xFF1A1A1A)]
              : [Colors.white, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.myAchievements,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.unlockBadgesAndEarnRewards,
                      style: TextStyle(
                        color: secondaryTextColor.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade400.withValues(alpha: 0.9),
                      Colors.amber.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.shade200.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$claimedAchievements / $totalAchievements',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.l10n.achievements} Claimed',
                      style: TextStyle(
                        color: secondaryTextColor.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$obtainedAchievements Unlocked',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progressPercentage),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        backgroundColor: isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.amber.shade600,
                        ),
                      ),
                    ),
                    Text(
                      '${(value * 100).toInt()}%',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildLevelTabs() {
    final categories = _availableCategories;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : surfaceColor,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? primaryColor : borderColor,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : primaryTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredAchievements() {
    if (_selectedCategory == 'Yours') {
      return _achievements
          .where((achievement) =>
              achievement['claimed'] == 1 ||
              achievement['obtained'] == 1 ||
              _canClaimAchievement(achievement))
          .cast<Map<String, dynamic>>()
          .toList();
    }

    return _achievements
        .where((achievement) =>
            (achievement['achievement_category'] ?? 'Other') ==
            _selectedCategory)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  Widget _buildAchievementsList() {
    final filteredAchievements = _getFilteredAchievements();

    if (filteredAchievements.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            _selectedCategory == 'Yours'
                ? 'No claimable or claimed achievements yet'
                : 'No achievements available',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredAchievements.length,
      itemBuilder: (context, index) {
        final achievement = filteredAchievements[index];
        return _buildAchievementListItem(achievement);
      },
    );
  }

  Widget _buildAchievementListItem(Map<String, dynamic> achievement) {
    final title = achievement['title'] ?? 'Unknown';
    final description = achievement['description'] ?? 'Details about the badge';
    final url = achievement['url'];
    final claimed = achievement['claimed'] == 1;
    final obtained = achievement['obtained'] == 1;
    final category = achievement['achievement_category'] ?? 'Other';
    final accentColor = _getCategoryAccentColor(category);
    final canClaim = _canClaimAchievement(achievement);
    final level =
        achievement['level'] != null ? 'Level ${achievement['level']}' : null;
    final progressValue = _calculateProgressPercentage(achievement) / 100;
    final bypassCost = (achievement['bypass_cost'] ?? 0) as int;
    final canBuy = bypassCost > 0 && !claimed;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (claimed) {
      statusText = 'Claimed';
      statusColor = Colors.grey.shade600;
      statusIcon = Icons.check_circle;
    } else if (canClaim || obtained) {
      statusText = 'Claim';
      statusColor = Colors.white;
      statusIcon = Icons.card_giftcard;
    } else if (canBuy) {
      statusText = 'Buy';
      statusColor = Colors.amber;
      statusIcon = Icons.shopping_cart;
    } else {
      statusText = 'Locked';
      statusColor = Colors.white;
      statusIcon = Icons.lock;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showAchievementDetails(achievement),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: claimed
                ? accentColor.withValues(alpha: 0.3)
                : (canClaim || obtained
                    ? Colors.green.withValues(alpha: 0.3)
                    : borderColor),
            width: claimed || canClaim || obtained ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- TITLE ----------
            Text(
              title,
              style: TextStyle(
                color: primaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ---------- LEVEL ----------
            if (level != null) ...[
              const SizedBox(height: 2),
              Text(
                level,
                style: TextStyle(
                  color: accentColor.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),

            // ---------- IMAGE + BUTTON ROW ----------
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ticket with image
                Container(
                  width: 144, // double width
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipPath(
                    clipper: TicketClipper(notchRadius: 7, notchDepth: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 240, 223, 174),
                        border: Border.all(
                          color: claimed
                              ? accentColor.withValues(alpha: 0.4)
                              : (canClaim
                                  ? Colors.green.withValues(alpha: 0.4)
                                  : Colors.grey.withValues(alpha: 0.2)),
                          width: 1,
                        ),
                      ),
                      child: (url != null && url.toString().trim().isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, _) => Container(
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.shield,
                                  color: claimed
                                      ? accentColor
                                      : (canClaim
                                          ? Colors.green
                                          : Colors.grey.shade400),
                                  size: 36,
                                ),
                              ),
                              errorWidget: (context, _, __) => Container(
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.shield,
                                  color: claimed
                                      ? accentColor
                                      : (canClaim
                                          ? Colors.green
                                          : Colors.grey.shade400),
                                  size: 36,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.white,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.shield,
                                color: claimed
                                    ? accentColor
                                    : (canClaim
                                        ? Colors.green
                                        : Colors.grey.shade400),
                                size: 36,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Action buttons
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Unlock with Benefit button
                      if (!claimed &&
                          !canClaim &&
                          !obtained &&
                          _unlockAchievementBenefit != null &&
                          _unlockAchievementBenefit!.canUse)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: _isUnlockingAchievement
                                ? null
                                : () =>
                                    _useUnlockAchievementBenefit(achievement),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isUnlockingAchievement
                                    ? Colors.grey.withValues(alpha: 0.2)
                                    : Colors.amber.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isUnlockingAchievement
                                      ? Colors.grey.withValues(alpha: 0.5)
                                      : Colors.amber.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.bolt,
                                color: _isUnlockingAchievement
                                    ? Colors.grey
                                    : Colors.amber,
                                size: 20,
                              ),
                            ),
                          ),
                        ),

                      // Claim/Buy/Locked button
                      GestureDetector(
                        onTap: () {
                          if (canClaim || obtained) {
                            _claimSingleAchievement(achievement);
                          } else if (canBuy) {
                            _showAchievementPurchaseDialog(achievement);
                          } else {
                            _showAchievementDetails(achievement);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: claimed
                                ? null
                                : (canClaim
                                    ? LinearGradient(
                                        colors: [
                                          Colors.green.shade400,
                                          Colors.green.shade600,
                                        ],
                                      )
                                    : null),
                            color: claimed
                                ? Colors.grey.shade300
                                : canClaim
                                    ? null
                                    : canBuy
                                        ? Colors.black.withValues(alpha: 0.5)
                                        : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: canClaim
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.green.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon,
                                color: statusColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ---------- DESCRIPTION ----------
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final truncated = description.length > 100;
                final visibleText = truncated
                    ? '${description.substring(0, 100)}...'
                    : description;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visibleText,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (truncated)
                      GestureDetector(
                        onTap: () => _showAchievementDetails(achievement),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'See more',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // ---------- PROGRESS BAR ----------
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  claimed
                      ? accentColor.withValues(alpha: 0.8)
                      : (canClaim
                          ? Colors.green
                          : (obtained ? Colors.orange : accentColor)),
                ),
              ),
            ),

            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(progressValue * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10,
                  color: claimed ? Colors.grey.shade700 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementPurchaseDialog(Map<String, dynamic> achievement) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AchievementPurchaseDialog(
          achievement: achievement,
          onSuccess: () {
            // Refresh achievements after successful purchase
            setState(() {
              _isLoading = true;
            });
            var auth = Provider.of<Auth>(context, listen: false);
            auth.getAchievements().then((_) {
              setState(() {
                _achievements = auth.achievements.toList();
                _categorizeAchievements();
                _isLoading = false;
              });
            }).catchError((error) {
              setState(() {
                _isLoading = false;
              });
              DebugLogger.log(
                  'Error refreshing achievements after purchase: $error');
            });
          },
        );
      },
    );
  }

  void _claimSingleAchievement(Map<String, dynamic> achievement) {
    final achievementId = achievement['id'] as int;
    var auth = Provider.of<Auth>(context, listen: false);

    auth.claimAchievements(achievementIds: [achievementId]).then((_) {
      setState(() {
        _isLoading = true;
      });
      auth.getAchievements().then((_) {
        setState(() {
          _achievements = auth.achievements.toList();
          _categorizeAchievements();
          _isLoading = false;
        });

        final claimedAchievements =
            _achievements.where((a) => a['id'] == achievementId).toList();

        _showClaimedBadgesModal(claimedAchievements);
      });
    }).catchError((error) {
      setState(() {
        _isLoading = false;
      });
      showScaffoldMessenger(
          context, 'Failed to claim achievement. Please try again.');
    });
  }

  Future<void> _useUnlockAchievementBenefit(
      Map<String, dynamic> achievement) async {
    if (_unlockAchievementBenefit == null) return;

    final achievementId = achievement['id'] as int;
    final achievementTitle = achievement['title'] ?? 'this achievement';

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
          'Your remaining benefit for Unlock Achievement is $remaining. Would you like to use 1 to unlock "$achievementTitle"? Your remaining benefit will be $afterUsage.',
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

      final auth = Provider.of<Auth>(context, listen: false);
      final subService = SubscriptionService(
        context: context,
        authToken: auth.token,
      );

      // 2. Claim the achievement
      await auth.claimAchievements(achievementIds: [achievementId]);

      // 3. Update benefit usage (V2 API)
      await subService.updateUserBenefitUsage(
        userBenefitUsageId: _unlockAchievementBenefit!.id,
        achievementId: achievementId,
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader

        // 4. Refresh achievements data
        setState(() => _isLoading = true);
        await auth.getAchievements();

        if (mounted) {
          setState(() {
            _achievements = auth.achievements.toList();
            _categorizeAchievements();
            _isLoading = false;
          });

          // 5. Refresh benefit status
          await _checkSubscriptionBenefits();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Achievement unlocked successfully!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );

          // Show the claimed badges modal
          final claimedAchievements =
              _achievements.where((a) => a['id'] == achievementId).toList();
          if (claimedAchievements.isNotEmpty) {
            _showClaimedBadgesModal(claimedAchievements);
          }
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      DebugLogger.error('Error unlocking achievement with benefit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUnlockingAchievement = false);
    }
  }

  void _showClaimedBadgesModal(List<dynamic> claimedAchievements) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor.withValues(alpha: 0.8),
                        primaryColor,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.celebration,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Congratulations!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'You have successfully claimed ${claimedAchievements.length} new badge${claimedAchievements.length > 1 ? 's' : ''}!',
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: claimedAchievements.length,
                            itemBuilder: (context, index) {
                              final achievement = claimedAchievements[index];
                              final category =
                                  achievement['achievement_category'] ??
                                      'Other';
                              final accentColor =
                                  _getCategoryAccentColor(category);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(
                                          color: accentColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(23),
                                        child: CachedNetworkImage(
                                          imageUrl: achievement['url'] ??
                                              achievement['image'] ??
                                              '',
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                            color: accentColor.withValues(
                                                alpha: 0.2),
                                            child: Icon(
                                              Icons.emoji_events,
                                              color: accentColor,
                                              size: 24,
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            color: accentColor.withValues(
                                                alpha: 0.2),
                                            child: Icon(
                                              Icons.emoji_events,
                                              color: accentColor,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            achievement['title'] ??
                                                'Achievement',
                                            style: TextStyle(
                                              color: primaryTextColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            category,
                                            style: TextStyle(
                                              color: accentColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (achievement['claimable_points'] !=
                                              null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.stars,
                                                  color: Colors.orange,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '+${achievement['claimable_points']} points',
                                                  style: const TextStyle(
                                                    color: Colors.orange,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (_normalizeProducts(
                                                  achievement['products'])
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            _buildProductProgress(
                                                achievement, accentColor),
                                          ],
                                        ],
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
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Awesome!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildProductProgress(
      Map<String, dynamic> achievement, Color accentColor) {
    final normalizedProducts = _normalizeProducts(achievement['products']);
    if (normalizedProducts.isEmpty) return const SizedBox.shrink();

    final level = achievement['level'] ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.shopping_cart,
              color: accentColor,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              'Purchase Progress:',
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...normalizedProducts.map((product) {
          final purchaseCount = product['purchase_count'] ?? 0;
          final progress = (purchaseCount / level).clamp(0.0, 1.0);
          final isCompleted = purchaseCount >= level;

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${product['title'] ?? 'Product'}: $purchaseCount/$level',
                        style: TextStyle(
                          color: isCompleted ? Colors.green : primaryTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isCompleted ? Colors.green : Colors.grey,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? Colors.green : accentColor,
                  ),
                  minHeight: 3,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showAchievementDetails(Map<String, dynamic> achievement) {
    final title = achievement['title'];
    final description = achievement['description'];
    final imageUrl = achievement['url'];
    final category = achievement['achievement_category'] ?? 'Other';
    final userType = _getUserType(achievement['type']);
    final accentColor = _getCategoryAccentColor(category);
    final claimed = achievement['claimed'] == 1;
    final level = achievement['level'];
    final discount = achievement['discount'];

    final List<Map<String, dynamic>> productsList =
        _normalizeProducts(achievement['products']);
    final List<Map<String, dynamic>> seasonsList =
        _normalizeSeasons(achievement['seasons']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: accentColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.1),
                  accentColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: claimed ? accentColor : Colors.grey.shade400,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: (imageUrl != null &&
                                imageUrl.toString().trim().isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.emoji_events, size: 32),
                              )
                            : const Icon(Icons.emoji_events, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title ?? 'Unknown',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (level != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Level $level',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (claimed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'CLAIMED',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
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
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTag(
                        icon: _getCategoryIcon(category),
                        label: category,
                        color: accentColor),
                    _buildTag(
                        icon: Icons.person_outline,
                        label: userType.toUpperCase(),
                        color: primaryColor),
                    if (discount != null && discount != '0.00')
                      _buildTag(
                          icon: Icons.discount,
                          label: '$discount% OFF',
                          color: Colors.red.shade600),
                  ],
                ),
              ],
            ),
          ),
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [surfaceColor, accentColor.withValues(alpha: 0.02)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (description != null) ...[
                    _buildDescriptionBox(description, accentColor),
                    const SizedBox(height: 12),
                  ],
                  _buildRequirementsSection(
                      achievement, accentColor, seasonsList, productsList),
                ],
              ),
            ),
          ),
          actions: [
            if (!claimed &&
                !_canClaimAchievement(achievement) &&
                achievement['obtained'] != 1 &&
                _unlockAchievementBenefit != null &&
                _unlockAchievementBenefit!.canUse)
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close details dialog
                    _useUnlockAchievementBenefit(achievement);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Unlock with ${_unlockAchievementBenefit!.benefitType.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDescriptionBox(String text, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text('Description',
                  style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style:
                TextStyle(color: primaryTextColor, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(
      {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsSection(
    Map<String, dynamic> achievement,
    Color accentColor,
    List<Map<String, dynamic>> seasonsList,
    List<Map<String, dynamic>> productsList,
  ) {
    final List<Widget> statCards = [];
    final progress = achievement['progress'];

    void addStatCard(String progressKey, IconData icon, String label,
        dynamic value, Color color,
        {Widget? iconWidget}) {
      if (value != null && value.toString().trim().isNotEmpty && value != 0) {
        String displayText = value.toString();
        if (progress != null &&
            progress is Map &&
            progress[progressKey] != null) {
          final progressData = progress[progressKey];
          final current = progressData['current'] ?? 0;
          final required = progressData['required'] ?? value;
          displayText = '$current/$required';
        }

        statCards.add(
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  contentPadding: const EdgeInsets.all(16),
                  content: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child:
                              iconWidget ?? Icon(icon, color: color, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$label: $displayText',
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OKAY'),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: color.withValues(alpha: 0.4), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconWidget ?? Icon(icon, color: color, size: 16),
                  const SizedBox(height: 2),
                  Text(
                    displayText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    addStatCard('time_spent', Icons.timer_outlined, 'Time Spent',
        achievement['time_spent'], Colors.orange);
    addStatCard('points_earned', Icons.monetization_on_outlined,
        'Points Earned', achievement['points_earned'], Colors.amber,
        iconWidget:
            Image.asset('assets/images/coins.png', width: 18, height: 18));
    addStatCard('points_spent', Icons.shopping_cart_outlined, 'Points Spent',
        achievement['points_spent'], Colors.teal);
    addStatCard('seasons_unlocked', Icons.lock_open_outlined,
        'Seasons Unlocked', achievement['seasons_unlocked'], Colors.cyan);
    addStatCard('leaderboard_min_rank', Icons.leaderboard_outlined, 'Min Rank',
        achievement['leaderboard_min_rank'], const Color(0xFFC347D8));
    addStatCard('leaderboard_max_rank', Icons.emoji_events_outlined, 'Max Rank',
        achievement['leaderboard_max_rank'], const Color(0xFFE08AEA));
    addStatCard('referral_count', Icons.people_alt_outlined, 'Referrals',
        achievement['referral_count'], const Color(0xFF7284EA));
    addStatCard('likes_per_post', Icons.favorite_outline, 'Likes/Post',
        achievement['likes_per_post'], const Color(0xFFE3ADBf));
    addStatCard('total_likes', Icons.thumb_up_alt_outlined, 'Total Likes',
        achievement['total_likes'], Colors.redAccent);
    addStatCard('total_shorts', Icons.video_library_outlined, 'Shorts',
        achievement['total_shorts'], const Color(0xFF8D5CC0));
    addStatCard('total_stories', Icons.auto_stories_outlined, 'Stories',
        achievement['total_stories'], Colors.blueAccent);
    addStatCard('claimable_points', Icons.star_outlined, 'Reward',
        achievement['claimable_points'], Colors.amber);

    if (statCards.isEmpty && seasonsList.isEmpty && productsList.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget buildShopCard({
      required String title,
      String? subtitle,
      String? price,
      bool? isUnlocked,
    }) {
      return Container(
        width: 100,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                      child: Icon(Icons.blur_on, size: 24, color: Colors.grey)),
                ),
                if (isUnlocked == true)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: primaryTextColor.withValues(alpha: 0.7),
                      fontSize: 10)),
            ],
            if (price != null) ...[
              const SizedBox(height: 2),
              Text(price,
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text('Achievement Requirements',
                  style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          if (statCards.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: statCards),
          if (seasonsList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Season Requirements',
                style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: seasonsList.map((s) {
                return buildShopCard(
                  title: s['title'] ?? 'Unnamed Season',
                  subtitle: 'Season',
                  isUnlocked: s['unlocked'] ?? false,
                );
              }).toList(),
            ),
          ],
          if (productsList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Product Requirements',
                style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: productsList.map((p) {
                final purchaseCount = p['purchase_count'] ?? 0;
                final level = achievement['level'] ?? 1;
                final isCompleted = purchaseCount >= level;

                return buildShopCard(
                  title: p['title'] ?? 'No Title',
                  subtitle:
                      'Purchased: $purchaseCount${level > 1 ? '/$level' : ''}',
                  price: 'Price: ${p['price'] ?? 'N/A'}',
                  isUnlocked: isCompleted,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: header(context: context, titleText: context.l10n.achievements),
        body: const Loading(),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: header(context: context, titleText: context.l10n.achievements),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildOverallProgressHeader(),
                  _buildLevelTabs(),
                  _buildAchievementsList(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
