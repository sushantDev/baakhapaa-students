import 'dart:io';
import 'dart:math' as math;
import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/providers/assistive_touch_provider.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/levels.dart';
import 'package:baakhapaa/providers/rewards_provider.dart';
import 'package:baakhapaa/providers/story.dart';
import 'package:baakhapaa/screens/collaboration/collaborations_screen.dart';
import 'package:baakhapaa/screens/gift/gift_screen.dart';
import 'package:baakhapaa/screens/leaderboard/leaderboard_screen.dart';
import 'package:baakhapaa/screens/messages/conversations_screen.dart';
import 'package:baakhapaa/screens/user/points_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

import '../providers/video_state_provider.dart';
import '../utils/debug_logger.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Design tokens
// ═══════════════════════════════════════════════════════════════════════════

const _kBg = Color(0xFF0D0D0D);
const _kCardBg = Color(0xFF1A1A1A);
const _kAccent = Color(0xFFF4B625);
const _kWhite = Color(0xFFFFFFFF);
const _kMuted = Color(0xFFAAAAAA);
const _kBorderColor = Color(0xFF333333);

// ═══════════════════════════════════════════════════════════════════════════
// PuppetDashboard — half-screen overlay triggered from header puppet tap
// ═══════════════════════════════════════════════════════════════════════════

class PuppetDashboard extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final VoidCallback onClose;

  const PuppetDashboard({
    Key? key,
    required this.navigatorKey,
    required this.onClose,
  }) : super(key: key);

  /// Show as top-half overlay
  static void show(
    BuildContext context, {
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PuppetDashboard',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim, secondaryAnim) {
        return PuppetDashboard(
          navigatorKey: navigatorKey,
          onClose: () => Navigator.of(ctx).pop(),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  State<PuppetDashboard> createState() => _PuppetDashboardState();
}

class _PuppetDashboardState extends State<PuppetDashboard>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  double _dragOffset = 0;

  // Rewarded Ad
  RewardedAd? _rewardedAd;
  final _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-8105529278923041/8001756243'
      : 'ca-app-pub-8105529278923041/5550852727';

  @override
  void initState() {
    super.initState();
    // Defer data load to post-frame to avoid setState/notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
        _loadRewardedAd();
      }
    });
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final rewards = Provider.of<RewardsProvider>(context, listen: false);
      final levels = Provider.of<Levels>(context, listen: false);
      await rewards.fetchDashboard(levels);

      // Auto-check level up if all tasks completed
      if (levels.remainingActions.isEmpty && !levels.isMaxLevel) {
        try {
          final result = await levels.checkLevelUp();
          if (result['leveled_up'] == true) {
            await rewards.fetchDashboard(levels);
          }
        } catch (_) {}
      }
    } catch (e) {
      DebugLogger.error('PuppetDashboard: Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (error) {
          DebugLogger.error('Rewarded ad failed: ${error.message}');
        },
      ),
    );
  }

  void _navigateTo(Widget screen) {
    // Pause any playing shorts video before navigating away
    try {
      final videoState = Provider.of<VideoStateProvider>(
        context,
        listen: false,
      );
      videoState.pauseVideo();
      videoState.clearAllActiveVideos();
    } catch (_) {}
    widget.onClose();
    widget.navigatorKey.currentState?.push(
      PageTransition(child: screen, type: PageTransitionType.fade),
    );
  }

  void _pushNamed(String routeName, {Object? arguments}) {
    try {
      final videoState = Provider.of<VideoStateProvider>(
        context,
        listen: false,
      );
      videoState.pauseVideo();
      videoState.clearAllActiveVideos();
    } catch (_) {}
    widget.onClose();
    widget.navigatorKey.currentState?.pushNamed(
      routeName,
      arguments: arguments,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Scrim — gradient fade for polish
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.black38, Colors.black26],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Dashboard sheet — supports swipe-up to close
        Align(
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {}, // absorb tap
            onVerticalDragUpdate: (details) {
              setState(() {
                _dragOffset = (_dragOffset + details.delta.dy).clamp(
                  -double.infinity,
                  0,
                );
              });
            },
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -300 || _dragOffset < -80) {
                widget.onClose();
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: EdgeInsets.only(top: topPad),
                  constraints: BoxConstraints(maxHeight: screenH * 0.55),
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    border: Border.all(color: _kBorderColor.withOpacity(0.5)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    child: Column(
                      children: [
                        // ── Drag handle ──
                        Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(top: 8, bottom: 4),
                          decoration: BoxDecoration(
                            color: _kBorderColor.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _buildPuppetPanel(context),
                              Container(
                                width: 1,
                                color: _kBorderColor.withOpacity(0.4),
                              ),
                              Expanded(child: _buildContentPanel(context)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // LEFT PANEL — Puppet image, points, ads
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildPuppetPanel(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    String puppetUrl = '${Url.mediaUrl}/assets/puppetdev.png';
    try {
      if (auth.puppetImage != null && auth.puppetImage!.isNotEmpty) {
        puppetUrl = auth.puppetImage!;
      } else {
        final puppet = auth.user['current_puppet'];
        if (puppet != null && puppet['image'] != null) {
          puppetUrl = puppet['image'];
        }
      }
    } catch (_) {}

    final coins = auth.userAvailableCoins;

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          // Puppet image — circular with golden border matching header style
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
              border: Border.all(color: _kAccent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: _kAccent.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: puppetUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.smart_toy, size: 50, color: _kAccent),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Level badge
          Consumer<Levels>(
            builder: (_, levels, __) {
              final lvl = levels.currentLevel;
              final lvlName = lvl?['name'] ?? 'Level 1';
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A1F00), Color(0xFF1A1A1A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  lvlName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Points button
          GestureDetector(
            onTap: () => _navigateTo(PointsScreen()),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2000), Color(0xFF1A1400)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/coins.png', width: 18, height: 18),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '$coins pts',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Compact stats radar chart
          const _CompactRadarChart(),
          const SizedBox(height: 8),

          // Watch ads button
          GestureDetector(
            onTap: _playRewardedAd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _kAccent.withOpacity(0.15),
                    _kAccent.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    size: 22,
                    color: _kAccent,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Watch Ad',
                    style: TextStyle(
                      color: _kWhite.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '+Bonus pts',
                    style: TextStyle(
                      color: _kAccent.withOpacity(0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // RIGHT PANEL — Tabs + content
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildContentPanel(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 10),
        // Quick-navigate icon row
        _buildQuickNavRow(),
        const SizedBox(height: 10),
        // Home content always visible
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _HomeTab(onNavigate: _navigateTo, onPushNamed: _pushNamed),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickNavRow() {
    // Each entry: (IconData?, label, accentColor, destinationScreen, optionalImageUrl?)
    final navItems = <(IconData?, String, Color, Widget, String?)>[
      (
        Icons.leaderboard_rounded,
        'Ranks',
        const Color(0xFFFF9800),
        LeaderboardScreen(),
        null,
      ),
      (Icons.redeem, 'Gifts', _kAccent, GiftScreen(), null),
      (
        Icons.people_rounded,
        'Collabs',
        const Color(0xFF2196F3),
        CollaborationsScreen() as Widget,
        null,
      ),
      (
        Icons.mail_rounded,
        'Messages',
        const Color(0xFF4CAF50),
        ConversationsScreen() as Widget,
        null,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: navItems.map((item) {
          final isMessagesItem = item.$2 == 'Messages';
          return Expanded(
            child: GestureDetector(
              onTap: () => _navigateTo(item.$4),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.$3.withOpacity(0.15),
                      item.$3.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: item.$3.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: item.$3.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: item.$5 != null
                              ? ClipOval(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CachedNetworkImage(
                                      imageUrl: item.$5!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Icon(
                                        Icons.card_giftcard_rounded,
                                        size: 15,
                                        color: item.$3,
                                      ),
                                    ),
                                  ),
                                )
                              : Icon(item.$1, size: 15, color: item.$3),
                        ),
                        if (isMessagesItem)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Consumer<Auth>(
                              builder: (context, auth, _) {
                                if (auth.unreadMessageCount <= 0) {
                                  return const SizedBox.shrink();
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5A5F),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF0F0F0F),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    auth.unreadMessageCount > 99
                                        ? '99+'
                                        : auth.unreadMessageCount.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      style: TextStyle(
                        color: _kWhite.withOpacity(0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _playRewardedAd() {
    if (_rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not ready yet. Try again.')),
      );
      _loadRewardedAd();
      return;
    }
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        DebugLogger.info('User earned reward: ${reward.amount} ${reward.type}');
        // Reward points via auth provider
        try {
          final auth = Provider.of<Auth>(context, listen: false);
          auth.claimDailyReward();
        } catch (_) {}
      },
    );
    _rewardedAd = null;
    _loadRewardedAd();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HOME TAB — Current Quest + Reward Progress + Streaks
// ═══════════════════════════════════════════════════════════════════════════

class _HomeTab extends StatelessWidget {
  final void Function(Widget screen) onNavigate;
  final void Function(String route, {Object? arguments}) onPushNamed;

  const _HomeTab({required this.onNavigate, required this.onPushNamed});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _CurrentQuestSection(
            onNavigate: onNavigate,
            onPushNamed: onPushNamed,
          ),
          const SizedBox(height: 10),
          _RewardProgressSection(onNavigate: onNavigate),
          const SizedBox(height: 10),
          const _StreaksSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Current Quest Section
// ═══════════════════════════════════════════════════════════════════════════

class _CurrentQuestSection extends StatefulWidget {
  final void Function(Widget screen) onNavigate;
  final void Function(String route, {Object? arguments}) onPushNamed;

  const _CurrentQuestSection({
    required this.onNavigate,
    required this.onPushNamed,
  });

  @override
  State<_CurrentQuestSection> createState() => _CurrentQuestSectionState();
}

class _CurrentQuestSectionState extends State<_CurrentQuestSection> {
  bool _expanded = true;

  /// Navigates directly to a specific season's episode list by ID.
  /// Fetches season details first, sets the provider state, then navigates.
  /// Shows a quest guidance hint below the header after navigation.
  Future<void> _navigateToSeasonById(int seasonId, {String? seasonName}) async {
    // Set guidance hint first (provider persists after dialog closes)
    try {
      final hint = (seasonName != null && seasonName.isNotEmpty)
          ? 'Tap any episode in "$seasonName" to watch and complete the quiz! 📺'
          : 'Tap any episode to watch it and complete the quiz! 📺';
      Provider.of<AssistiveTouchProvider>(
        context,
        listen: false,
      ).showQuestGuidance(hint);
    } catch (_) {}

    try {
      final storyProvider = Provider.of<Story>(context, listen: false);
      final details = await storyProvider.fetchSeasonDetails(seasonId);
      if (!mounted) return;
      if (details != null) {
        await storyProvider.setSelectedSeason(details);
      }
      if (!mounted) return;
      widget.onPushNamed('/episode-screen');
    } catch (_) {
      if (mounted) widget.onPushNamed('/story-screen');
    }
  }

  /// Returns a short, actionable guidance message for the given route +
  /// actionKey combination. The same route can have different guidance
  /// depending on which quest sent the user there.
  String _guidanceFor(String route, {Map? actionData}) {
    final actionKey = actionData?['action_key']?.toString() ?? '';

    // Donation — goes to /shorts-screen but the action is donating coins,
    // not watching. Guide user to the coin icon under the comment button.
    if (actionKey == 'points_donated') {
      return 'Tap the cup below the comment to donate points to that creator!';
    }
    // Watching shorts
    if (actionKey == 'shorts_watched') {
      return 'Watch a short video here — the quiz will appear at the end! ▶️';
    }

    switch (route) {
      case '/story-screen':
        return 'Browse the seasons below and tap one to open it! 🎬';
      case '/episode-screen':
        return 'Tap any episode to watch it and complete the quiz! 📺';
      case '/shorts-screen':
        return 'Watch a short video — tap question mark and quiz will appear to test you! ▶️';
      case '/single-shorts-screen':
        return 'Watch this short and answer the quiz correctly! ✅';
      case '/achievements-screen':
        return 'Tap an achievement card to see how to earn it! 🏆';
      case '/points-screen':
        return 'Watch content and complete quests to earn more coins! 🪙';
      case '/challenges-screen':
        return 'Join a challenge here and participate to complete your quest! 🎯';
      case '/referrals-screen':
        return 'Share your referral link with friends to complete this quest! 👥';
      case '/shop-screen':
        return 'Browse the shop and make a purchase to complete your quest! 🛍️';
      case '/create-shorts-screen':
        return 'Create and upload a short video to complete this quest! 🎥';
      case '/create-story-type':
        return 'Create a new episode here to advance to the next level! 🎬';
      default:
        return '';
    }
  }

  /// Derives a route (and optional argument) from a quest action map and
  /// closes the dashboard before navigating.
  void _navigateForQuest(Map action) {
    final actionData = (action['action'] as Map?) ?? {};
    final actionKey = actionData['action_key']?.toString() ?? '';
    final type = actionData['type']?.toString() ?? 'number';
    final options = actionData['options'];

    DebugLogger.info('🎯 QUEST NAV: full_action=$action');
    DebugLogger.info(
      '🎯 QUEST NAV: actionKey="$actionKey" type="$type" options="$options" (${options.runtimeType})',
    );
    // Normalise the options field to a plain string for matching.
    String optionsStr = '';
    if (options is String) {
      optionsStr = options;
    } else if (options is Map && options.isNotEmpty) {
      optionsStr =
          (options['entity_type'] ?? options['type'] ?? options.values.first)
              .toString();
    } else if (options is List && options.isNotEmpty) {
      optionsStr = options.first.toString();
    }
    // Strip embedded JSON quotes (e.g. DB stores '"badge"' → 'badge')
    optionsStr = optionsStr.replaceAll('"', '').trim();

    String route;
    Object? arguments;

    if (type == 'selection' || type == 'checkbox') {
      switch (optionsStr) {
        case 'shorts':
          final id = _parseQuestId(action['required_value']);
          if (id > 0) {
            route = '/single-shorts-screen';
            arguments = id;
          } else {
            route = '/shorts-screen';
          }
          break;
        case 'episode':
        case 'season':
          final rawId = action['required_id'];
          final seasonId = rawId is int
              ? rawId
              : int.tryParse(rawId?.toString() ?? '') ?? 0;
          final seasonName = action['required_value']?.toString() ?? '';
          if (seasonId > 0) {
            _navigateToSeasonById(seasonId, seasonName: seasonName);
            return;
          }
          route = '/story-screen';
          break;
        case 'badge':
          route = '/achievements-screen';
          break;
        default:
          route = '/shorts-screen';
      }
    } else {
      switch (actionKey) {
        case 'earned_coins':
        case 'available_coins':
          route = '/points-screen';
          break;
        case 'used_coins':
        case 'total_product_purchased':
          route = '/shop-screen';
          break;
        case 'shorts_watched':
          route = '/shorts-screen';
          break;
        case 'episodes_watched':
        case 'season_unlocked':
        case 'unlock_a_season':
          route = '/story-screen';
          break;
        case 'points_donated':
          route = '/shorts-screen';
          break;
        case 'shorts_uploaded':
          route = '/create-shorts-screen';
          break;
        case 'episodes_uploaded':
          route = '/create-story-type';
          break;
        case 'achievements_claimed':
        case 'badge_required':
          route = '/achievements-screen';
          break;
        case 'total_referals_count':
        case 'refer_others':
          route = '/referrals-screen';
          break;
        case 'challenge_participation_number':
          route = '/challenges-screen';
          break;
        default:
          // Fallback: infer route from title/description when action_key is
          // missing (e.g. backend didn't include it in the response).
          final title = (actionData['title'] ?? '').toString().toLowerCase();
          final desc = (actionData['description'] ?? '')
              .toString()
              .toLowerCase();
          final combined = '$title $desc';
          if (combined.contains('episode') || combined.contains('season')) {
            route = '/story-screen';
          } else if (combined.contains('short')) {
            route = '/shorts-screen';
          } else if (combined.contains('donat') || combined.contains('point')) {
            route = '/shorts-screen';
          } else if (combined.contains('challenge')) {
            route = '/challenges-screen';
          } else if (combined.contains('achievement') ||
              combined.contains('badge')) {
            route = '/achievements-screen';
          } else if (combined.contains('product') ||
              combined.contains('purchas')) {
            route = '/shop-screen';
          } else if (combined.contains('refer')) {
            route = '/referrals-screen';
          } else if (combined.contains('creator')) {
            route = '/creator-request-screen';
          } else {
            DebugLogger.info('🎯 QUEST NAV: no route match — skipping');
            return; // Unknown action — skip navigation.
          }
      }
    }

    DebugLogger.info(
      '\ud83c\udfaf QUEST NAV: navigating to route="$route" arguments=$arguments',
    );
    // Show quest guidance hint below the header on the destination screen
    final guidance = _guidanceFor(route, actionData: actionData);
    if (guidance.isNotEmpty) {
      try {
        Provider.of<AssistiveTouchProvider>(
          context,
          listen: false,
        ).showQuestGuidance(guidance);
      } catch (_) {}
    }
    widget.onPushNamed(route, arguments: arguments);
  }

  static int _parseQuestId(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final levels = Provider.of<Levels>(context);
    final progress = levels.userProgress;
    final remaining = levels.remainingActions;
    final completed = progress['completed_actions'] as List? ?? [];
    final totalActions = completed.length + remaining.length;
    final completedCount = completed.length;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? _kAccent.withOpacity(0.4)
                : _kBorderColor.withOpacity(0.6),
          ),
        ),
        child: Column(
          children: [
            // Header row — always visible
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_kAccent, _kAccent.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.black,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Quest',
                        style: TextStyle(
                          color: _kWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$completedCount of $totalActions completed',
                        style: const TextStyle(color: _kMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                // Progress + chevron
                Text(
                  '$completedCount/$totalActions',
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.chevron_right,
                    color: _kMuted,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Segmented progress bar — always visible
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Row(
                children: List.generate(
                  totalActions.clamp(1, 10),
                  (i) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: i < totalActions.clamp(1, 10) - 1 ? 2 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: i < completedCount
                            ? _kAccent
                            : _kBorderColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Expandable task cards
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: remaining.isNotEmpty
                  ? Column(
                      children: [
                        const SizedBox(height: 10),
                        ...remaining.take(4).map<Widget>((action) {
                          final desc =
                              action['action']?['description'] ??
                              'Complete task';
                          final hint = action['hint'] ?? '';
                          final current =
                              num.tryParse(
                                '${action['current_progress'] ?? 0}',
                              ) ??
                              0;
                          final required =
                              num.tryParse(
                                '${action['required_value'] ?? 1}',
                              ) ??
                              1;
                          final pct = required > 0
                              ? (current / required).clamp(0.0, 1.0)
                              : 0.0;

                          return _TaskRow(
                            title: desc,
                            subtitle: hint,
                            progress: pct.toDouble(),
                            progressText:
                                '${current.toInt()}/${required.toInt()}',
                            onTap: () => _navigateForQuest(action),
                          );
                        }),
                      ],
                    )
                  : const SizedBox.shrink(),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Reward Progress Section
// ═══════════════════════════════════════════════════════════════════════════

class _RewardProgressSection extends StatefulWidget {
  final void Function(Widget screen) onNavigate;

  const _RewardProgressSection({required this.onNavigate});

  @override
  State<_RewardProgressSection> createState() => _RewardProgressSectionState();
}

class _RewardProgressSectionState extends State<_RewardProgressSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final levels = Provider.of<Levels>(context);
    final progress = levels.userProgress;
    final remaining = levels.remainingActions;
    final completed = progress['completed_actions'] as List? ?? [];
    final totalActions = completed.length + remaining.length;
    final completedCount = completed.length;
    final pct = totalActions > 0 ? completedCount / totalActions : 0.0;

    // Extract next reward info from level progress
    final nextLevel = progress['next_level'];
    final nextLevelName = nextLevel is Map
        ? nextLevel['name'] ?? 'Next Level'
        : 'Next Level';
    final nextLevelReward = nextLevel is Map ? nextLevel['coin_reward'] : null;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? const Color(0xFF4CAF50).withOpacity(0.4)
                : _kBorderColor.withOpacity(0.6),
          ),
        ),
        child: Column(
          children: [
            // Header — always visible
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4CAF50),
                        const Color(0xFF4CAF50).withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rewards Earned',
                        style: TextStyle(
                          color: _kWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        nextLevelReward != null
                            ? 'Next: $nextLevelName (+$nextLevelReward pts)'
                            : 'Next: $nextLevelName',
                        style: const TextStyle(color: _kMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(pct * 100).round()}%',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.chevron_right,
                    color: _kMuted,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar — always visible
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: _kBorderColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Expandable detail — show COMPLETED tasks (vs quest which shows remaining)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: completed.isNotEmpty
                  ? Column(
                      children: [
                        const SizedBox(height: 10),
                        ...completed.take(4).map<Widget>((action) {
                          final desc =
                              action['action']?['description'] ??
                              action['description'] ??
                              'Completed task';
                          return _TaskRow(
                            title: '✓ $desc',
                            progress: 1.0,
                            progressText: 'Done',
                            accentColor: const Color(0xFF4CAF50),
                          );
                        }),
                        if (remaining.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${remaining.length} more to unlock $nextLevelName',
                              style: TextStyle(
                                color: _kMuted.withOpacity(0.7),
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Complete quests above to earn rewards!',
                        style: TextStyle(
                          color: _kMuted.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Streaks Section
// ═══════════════════════════════════════════════════════════════════════════

class _StreaksSection extends StatelessWidget {
  const _StreaksSection();

  @override
  Widget build(BuildContext context) {
    final story = Provider.of<Story>(context);
    final streak = story.readingStreak;
    final currentStreak = streak['current_streak'] as int? ?? 0;
    final longestStreak = streak['longest_streak'] as int? ?? currentStreak;

    // Show the current weekly cycle of the streak journey
    // Week 1: days 1-7, Week 2: 8-14, Week 3: 15-21, etc.
    final weekStart = currentStreak > 0
        ? ((currentStreak - 1) ~/ 7) * 7 + 1
        : 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorderColor.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF7043),
                      const Color(0xFFFF7043).withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Streak',
                      style: TextStyle(
                        color: _kWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Best: $longestStreak days',
                      style: const TextStyle(color: _kMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              // Current streak badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7043).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 12,
                      color: Color(0xFFFF7043),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$currentStreak',
                      style: const TextStyle(
                        color: Color(0xFFFF7043),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Day circles — weekly cycle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final dayNum = weekStart + i;
              final isActive = dayNum <= currentStreak;
              final isToday = dayNum == currentStreak + 1;
              return Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFF7043), Color(0xFFFF8A65)],
                            )
                          : null,
                      color: isActive
                          ? null
                          : isToday
                          ? const Color(0xFFFF7043).withOpacity(0.1)
                          : _kBorderColor.withOpacity(0.3),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFFF7043)
                            : isToday
                            ? const Color(0xFFFF7043).withOpacity(0.5)
                            : _kBorderColor.withOpacity(0.5),
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: isToday
                                  ? const Color(0xFFFF7043).withOpacity(0.5)
                                  : _kMuted.withOpacity(0.3),
                            ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$dayNum',
                    style: TextStyle(
                      color: isActive
                          ? _kWhite
                          : isToday
                          ? const Color(0xFFFF7043)
                          : _kMuted.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════

class _TaskRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final String progressText;
  final Color? accentColor;
  final VoidCallback? onTap;

  const _TaskRow({
    required this.title,
    this.subtitle = '',
    required this.progress,
    required this.progressText,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _kMuted, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              progressText,
              style: TextStyle(
                color: accentColor ?? _kAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  color: accentColor ?? _kAccent,
                  backgroundColor: _kBorderColor,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: _kMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Compact Radar Chart — for left panel below points
// ═══════════════════════════════════════════════════════════════════════════

class _CompactRadarChart extends StatelessWidget {
  const _CompactRadarChart();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context);
    final levels = Provider.of<Levels>(context);
    final story = Provider.of<Story>(context);
    final progress = levels.userProgress;

    final levelMap = progress['current_level'];
    final currentLevelNum =
        num.tryParse(
          '${levelMap is Map ? levelMap['level_number'] ?? levelMap['id'] ?? 1 : levelMap ?? 1}',
        ) ??
        1;
    final levelVal = (currentLevelNum / 50).clamp(0.0, 1.0);

    final completed = progress['completed_actions'] as List? ?? [];
    final remaining = levels.remainingActions;
    final totalActions = completed.length + remaining.length;
    final questVal = totalActions > 0
        ? (completed.length / totalActions).clamp(0.0, 1.0)
        : 0.0;

    final streak = story.readingStreak;
    final currentStreak = (streak['current_streak'] as int? ?? 0);
    final streakVal = (currentStreak / 7).clamp(0.0, 1.0);

    final coins = auth.userAvailableCoins;
    final pointsVal = (coins / 10000).clamp(0.0, 1.0);

    final earnedCoins = (auth.userInformation?['earned_coins'] as num?) ?? 0;
    final engageVal = (earnedCoins / 50000).clamp(0.0, 1.0);

    final stats = <_StatAxis>[
      _StatAxis('Lvl', levelVal.toDouble()),
      _StatAxis('Quest', questVal.toDouble()),
      _StatAxis('Strk', streakVal.toDouble()),
      _StatAxis('Pts', pointsVal.toDouble()),
      _StatAxis('XP', engageVal.toDouble()),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kAccent.withOpacity(0.08),
            _kCardBg,
            const Color(0xFF1E1A10),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAccent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withOpacity(0.06),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats header
          Row(
            children: [
              const Icon(Icons.radar_rounded, size: 10, color: _kAccent),
              const SizedBox(width: 4),
              const Text(
                'STATS',
                style: TextStyle(
                  color: _kAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 76,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    dataEntries: stats
                        .map((s) => RadarEntry(value: math.max(s.value, 0.05)))
                        .toList(),
                    fillColor: _kAccent.withValues(alpha: 0.2),
                    borderColor: _kAccent,
                    borderWidth: 1.5,
                    entryRadius: 2,
                  ),
                ],
                radarBorderData: const BorderSide(
                  color: _kBorderColor,
                  width: 0.3,
                ),
                radarBackgroundColor: Colors.transparent,
                tickBorderData: const BorderSide(
                  color: _kBorderColor,
                  width: 0.3,
                ),
                gridBorderData: const BorderSide(
                  color: _kBorderColor,
                  width: 0.3,
                ),
                tickCount: 3,
                ticksTextStyle: const TextStyle(fontSize: 0),
                titleTextStyle: const TextStyle(
                  color: _kMuted,
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                ),
                titlePositionPercentageOffset: 0.1,
                getTitle: (index, angle) {
                  if (index < stats.length) {
                    return RadarChartTitle(text: stats[index].label);
                  }
                  return const RadarChartTitle(text: '');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatAxis {
  final String label;
  final double value;
  const _StatAxis(this.label, this.value);
}
