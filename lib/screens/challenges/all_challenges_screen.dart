import 'package:baakhapaa/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/challenge.dart';
import '../../providers/shorts.dart';
import '../../providers/auth.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/debug_logger.dart';
import '../../widgets/footer.dart';
import '../../widgets/header.dart';
import '../../widgets/loading.dart';

class AllChallengesScreen extends StatefulWidget {
  static const routeName = '/all-challenges-screen';

  const AllChallengesScreen({super.key});

  @override
  State<AllChallengesScreen> createState() => _AllChallengesScreenState();
}

class _AllChallengesScreenState extends State<AllChallengesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;

  static const List<String> _filters = ['All', 'Unlocked', 'Locked'];
  String _selectedFilter = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<PuppetInteractionProvider>().initState();
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }
    });

    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<Auth>();
      final userId = authProvider.userId;

      // Load both challenges and creator shorts to check participation
      await Future.wait([
        context.read<Challenge>().fetchChallenges(),
        context.read<Shorts>().fetchCreatorShorts(userId),
      ]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load challenges'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ...existing code...
  List<Map<String, dynamic>> _filtered(List challenges) {
    return challenges
        .where((c) {
          final title = (c['title'] ?? '').toString().toLowerCase();
          final matchesSearch = _searchQuery.isEmpty ||
              title.contains(_searchQuery.toLowerCase());

          final bool isExpired = _isExpired(c);

          bool matchesFilter;
          if (_selectedFilter == 'Unlocked') {
            // Show unlocked OR expired
            matchesFilter = c['is_locked'] == 0 || isExpired;
          } else if (_selectedFilter == 'Locked') {
            // Show only locked AND not expired
            matchesFilter = c['is_locked'] == 1 && !isExpired;
          } else {
            matchesFilter = true;
          }

          return matchesSearch && matchesFilter;
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }
// ...existing code...

  bool _isExpired(Map<String, dynamic> challenge) {
    try {
      final date = DateTime.parse(
        challenge['deadline'] ?? challenge['end_date'] ?? '',
      );
      return date.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _formatDeadline(String? deadline) {
    if (deadline == null) return 'Dec 11';
    try {
      final date = DateTime.parse(deadline);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}';
    } catch (_) {
      return 'Dec 11';
    }
  }

  List<Color> _buttonColors(bool locked, bool completed, bool expired) {
    if (completed || expired) {
      return [Colors.grey.shade600, Colors.grey.shade700];
    }
    if (locked) {
      return [const Color(0xFFFF4444), const Color(0xFFCC3333)];
    }
    return [const Color(0xFFFFCB0C), const Color(0xFFDC9903)];
  }

  // Get dynamic points reward from challenge data
  int _getPointsReward(Map<String, dynamic> challenge) {
    // Highest priority: actual reward
    if (challenge['unlock_points'] != null) {
      return _toInt(challenge['unlock_points']);
    }

    // Fallback: required points (what your API actually sends)
    if (challenge['unlock_points'] != null) {
      return _toInt(challenge['unlock_points']);
    }

    // Last fallback
    return 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _hasParticipated(Map<String, dynamic> challenge) {
    try {
      final challengeId = _toInt(challenge['id']);

      // Debug: Print challenge data to see available fields
      DebugLogger.info(
          '🔍 Challenge $challengeId data: ${challenge.keys.toList()}');
      DebugLogger.info(
          '🔍 user_participated: ${challenge['user_participated']}');
      DebugLogger.info('🔍 has_participated: ${challenge['has_participated']}');
      DebugLogger.info(
          '🔍 user_shorts_count: ${challenge['user_shorts_count']}');
      DebugLogger.info('🔍 participated: ${challenge['participated']}');
      DebugLogger.info('🔍 participants: ${challenge['participants']}');

      // Check if the challenge data has participation info
      if (challenge['user_participated'] == true ||
          challenge['user_participated'] == 1 ||
          challenge['has_participated'] == true ||
          challenge['has_participated'] == 1 ||
          challenge['participated'] == true ||
          challenge['participated'] == 1) {
        DebugLogger.info('✅ User has participated in challenge $challengeId');
        return true;
      }

      // Check participants list (if available)
      final participants = challenge['participants'];
      if (participants is List && participants.isNotEmpty) {
        final authProvider = context.read<Auth>();
        final currentUserId = authProvider.userId;

        final hasParticipated = participants.any((participant) {
          if (participant is Map) {
            final participantId = participant['user_id'] ??
                participant['participant_id'] ??
                participant['id'];
            return participantId == currentUserId;
          }
          return false;
        });

        if (hasParticipated) {
          DebugLogger.info(
              '✅ User found in participants list for challenge $challengeId');
          return true;
        }
      }

      // Check user's creator shorts for this challenge
      try {
        final shortsProvider = context.read<Shorts>();
        final creatorShorts = shortsProvider.creatorShorts;

        final hasShortForChallenge = creatorShorts.any((short) {
          final shortChallengeId = _toInt(short['challenge_id'] ?? 0);
          return shortChallengeId == challengeId;
        });

        if (hasShortForChallenge) {
          DebugLogger.info(
              '✅ User has shorts for challenge $challengeId in creatorShorts');
          return true;
        }
      } catch (e) {
        DebugLogger.info('⚠️ Error checking creatorShorts: $e');
      }

      // Check if user has shorts count
      if (challenge['user_shorts_count'] != null) {
        final count = _toInt(challenge['user_shorts_count']);
        if (count > 0) {
          DebugLogger.info(
              '✅ User has $count shorts in challenge $challengeId');
          return true;
        }
      }

      DebugLogger.info('❌ User has NOT participated in challenge $challengeId');
      return false;
    } catch (e) {
      DebugLogger.info('⚠️ Error checking participation: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF090909) : Colors.white,
      appBar: header(
        context: context,
        titleText: context.l10n.challenges,
        scaffoldKey: _scaffoldKey,
      ),
      body: RefreshIndicator(
        onRefresh: _loadChallenges,
        child: Column(
          children: [
            const SubHeader(),
            const SizedBox(height: 8),
            _FilterSection(
              filters: _filters,
              selected: _selectedFilter,
              onChanged: (f) => setState(() => _selectedFilter = f),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: Loading())
                  : Consumer<Challenge>(
                      builder: (_, provider, __) {
                        final challenges = _filtered(provider.challenges);

                        if (challenges.isEmpty) {
                          return const EmptyState();
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: EdgeInsets.only(
                            bottom: Footer.estimatedHeight(context) + 16,
                          ),
                          itemCount: challenges.length,
                          itemBuilder: (_, i) {
                            final c = challenges[i];
                            final isLocked = c['is_locked'] == 1;
                            final completed = c['is_completed'] == 1 ||
                                c['completed'] == true;
                            final expired = _isExpired(c);
                            final participated = _hasParticipated(c);

                            DebugLogger.info(
                                '🎯 Challenge ${c['id']} (${c['title']}) participated: $participated');

                            return _ChallengeCard(
                              challenge: c,
                              isLocked: isLocked,
                              completed: completed,
                              expired: expired,
                              hasParticipated: participated,
                              deadlineText: _formatDeadline(
                                  c['deadline'] ?? c['end_date']),
                              buttonColors: _buttonColors(
                                isLocked,
                                completed,
                                expired,
                              ),
                              pointsReward: _getPointsReward(c),
                            );
                          },
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

class SubHeader extends StatelessWidget {
  const SubHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
          // children: [
          //   // All Challenges (Active)
          //   Expanded(
          //     child: Container(
          //       height: 44,
          //       alignment: Alignment.center,
          //       decoration: BoxDecoration(
          //         color: const Color(0xFFFFFAD9), // light cream
          //         borderRadius: BorderRadius.circular(30),
          //       ),
          //       // child: Text(
          //       //   "All Challenges",
          //       //   style: GoogleFonts.poppins(
          //       //     fontSize: 15,
          //       //     fontWeight: FontWeight.w600,
          //       //     color: Colors.black87,
          //       //   ),
          //       // ),
          //     ),
          //   ),

          // ],
          ),
    );
  }
}

/* -------------------- CARD -------------------- */

class _ChallengeCard extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final bool isLocked;
  final bool completed;
  final bool expired;
  final bool hasParticipated;
  final String deadlineText;
  final List<Color> buttonColors;
  final int pointsReward;

  const _ChallengeCard({
    required this.challenge,
    required this.isLocked,
    required this.completed,
    required this.expired,
    required this.hasParticipated,
    required this.deadlineText,
    required this.buttonColors,
    required this.pointsReward,
  });

  // NEW METHOD: Determine if challenge should show NEW badge
  bool get isNew {
    // If locked, expired, or completed - no NEW badge
    if (isLocked || expired || completed) return false;

    // Method 1: Check backend flag (preferred)
    if (challenge.containsKey('is_new')) {
      return challenge['is_new'] == true || challenge['is_new'] == 1;
    }

    // Method 2: Check if status is ACTIVE (your current logic)
    final status = _getStatus();
    return status == 'ACTIVE';

    // Method 3: Date-based (alternative if you want time-based NEW)
    // return _isRecentlyCreated();
  }

  // Get challenge status
  String _getStatus() {
    if (challenge['is_locked'] == 1) return 'LOCKED';

    try {
      final deadline = DateTime.parse(
        challenge['deadline'] ?? challenge['end_date'] ?? '',
      );
      if (deadline.isBefore(DateTime.now())) {
        return 'EXPIRED';
      }
    } catch (_) {}

    return 'ACTIVE';
  }

  // Optional: Alternative date-based NEW logic
  // bool _isRecentlyCreated() {
  //   try {
  //     final createdAt = DateTime.parse(
  //       challenge['created_at'] ?? challenge['start_date'] ?? '',
  //     );
  //     final daysSinceCreated = DateTime.now().difference(createdAt).inDays;
  //     return daysSinceCreated <= 7; // NEW if created within 7 days
  //   } catch (_) {
  //     return false;
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          isLocked ? '/challenge-detail-screen' : '/challenge-detail-screen',
          arguments: challenge['id'],
        );
      },
      child: Stack(
        children: [
          Container(
            width: 368,
            height: 148,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                // Image with NEW badge overlay
                Stack(
                  children: [
                    // Challenge Image
                    Container(
                      width: 118,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: challenge['image_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: challenge['image_url'],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.black,
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.black,
                                ),
                              ),
                            )
                          : const SizedBox(),
                    ),

                    // NEW Badge (replaces ACTIVE status)
                    if (isNew)
                      Positioned(
                        top: -6,
                        left: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF6B35), // Orange
                                Color(0xFFFF4500), // Deep Orange
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepOrange.withOpacity(0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 16),

                // Challenge Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        challenge['title'] ?? 'Unknown Challenge',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Description
                      Text(
                        challenge['description'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFFFFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Deadline and Action Button Row
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Deadline
                              Text(
                                'Deadline: $deadlineText',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFFF3636),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Points Reward
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/coins.png',
                                    width: 16,
                                    height: 16,
                                    fit: BoxFit.cover,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$pointsReward Points',
                                    style: const TextStyle(
                                      color: Color(0xFFFFC107),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Action Button
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                isLocked
                                    ? '/challenge-detail-screen'
                                    : '/challenge-detail-screen',
                                arguments: challenge['id'],
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: buttonColors),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                completed || expired
                                    ? 'View'
                                    : isLocked
                                        ? 'Locked'
                                        : 'Enter',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
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
          ),
          // Green tick indicator for participated challenges
          if (hasParticipated)
            Positioned(
              top: 8,
              right: 16,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ALTERNATIVE: More advanced NEW badge with animation
class AnimatedNewBadge extends StatefulWidget {
  const AnimatedNewBadge({super.key});

  @override
  State<AnimatedNewBadge> createState() => _AnimatedNewBadgeState();
}

class _AnimatedNewBadgeState extends State<AnimatedNewBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF4500)],
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.deepOrange.withOpacity(0.4),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Text(
          'NEW',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/* -------------------- FILTER -------------------- */

class _FilterSection extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterSection({
    required this.filters,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 8),
      height: 50, // Increased height to prevent cutoff
      child: ListView.separated(
        padding: const EdgeInsets.only(
            left: 16, right: 16, top: 5, bottom: 5), // Added vertical padding
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(), // Better scroll physics
        itemBuilder: (_, i) {
          final filter = filters[i];
          final isSelected = selected == filter;

          return Container(
            alignment: Alignment.center, // Center the chip vertically
            child: ChoiceChip(
              showCheckmark: false,
              label: Text(filter),
              selected: isSelected,
              selectedColor: Colors.white,
              backgroundColor:
                  isSelected ? Color(0xFFFDFAD8) : Color(0xFF262626),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8), // Added padding
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                // side: BorderSide(
                //   color: isSelected
                //       ? Colors.white
                //       : Colors.grey.withValues(alpha: 0.3),
                // ),
              ),
              labelStyle: GoogleFonts.inter(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 14,
              ),
              onSelected: (_) {
                onChanged(filter);
              },
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: filters.length,
      ),
    );
  }
}

/* -------------------- EMPTY -------------------- */

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: FaIcon(
                FontAwesomeIcons.trophy,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Challenges Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull to refresh or try changing the filter to discover new challenges',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    size: 16,
                    color: Colors.amber,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
