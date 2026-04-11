import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/story.dart';

/// An animated flame widget that flickers and glows.
class AnimatedFlame extends StatefulWidget {
  final double size;
  final bool isActive;

  const AnimatedFlame({Key? key, this.size = 80, this.isActive = true})
      : super(key: key);

  @override
  State<AnimatedFlame> createState() => _AnimatedFlameState();
}

class _AnimatedFlameState extends State<AnimatedFlame>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _flickerController;
  late Animation<double> _pulseAnim;
  late Animation<double> _flickerAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _flickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _flickerAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _flickerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _flickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Icon(Icons.local_fire_department_rounded,
          size: widget.size, color: Colors.grey.shade700);
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _flickerAnim]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnim.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.orange.withValues(alpha: 0.4 * _flickerAnim.value),
                  blurRadius: 30 * _flickerAnim.value,
                  spreadRadius: 8 * _flickerAnim.value,
                ),
                BoxShadow(
                  color:
                      Colors.amber.withValues(alpha: 0.2 * _flickerAnim.value),
                  blurRadius: 50 * _flickerAnim.value,
                  spreadRadius: 15 * _flickerAnim.value,
                ),
              ],
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFF6B35),
                  Color(0xFFFFD700),
                  Color(0xFFFF4500)
                ],
                stops: [0.0, 0.5, 1.0],
              ).createShader(bounds),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: widget.size,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class ReadingStreakScreen extends StatefulWidget {
  static const routeName = '/reading-streak';

  const ReadingStreakScreen({Key? key}) : super(key: key);

  @override
  State<ReadingStreakScreen> createState() => _ReadingStreakScreenState();
}

class _ReadingStreakScreenState extends State<ReadingStreakScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRecovering = false;
  late AnimationController _countController;
  late Animation<double> _countAnim;

  @override
  void initState() {
    super.initState();
    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _countAnim = CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final story = Provider.of<Story>(context, listen: false);
    await Future.wait([
      story.fetchReadingStreak(force: true),
      story.fetchReadingHistory(days: 30),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
      _countController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Daily Streak',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Consumer<Story>(
              builder: (context, story, _) {
                final streak = story.readingStreak;
                final history = story.readingHistory;
                final currentStreak = streak['current_streak'] ?? 0;
                final longestStreak = streak['longest_streak'] ?? 0;
                final totalChapters = streak['total_chapters_read'] ?? 0;
                final totalBooks = streak['total_books_completed'] ?? 0;
                final nextMilestone = streak['next_milestone'];
                final daysToNext = streak['days_to_next_milestone'];
                final lastReadDate = streak['last_read_date'];
                // Use server-side recovery_info if available (after backend deploy),
                // otherwise fall back to client-side calculation for backward compatibility
                final recoveryInfo = streak['recovery_info'];
                bool canRecover;
                int missedDays;
                int recoveryCost;

                if (recoveryInfo is Map<String, dynamic>) {
                  // Server provides recovery info — use it as single source of truth
                  canRecover = recoveryInfo['can_recover'] == true;
                  missedDays = (recoveryInfo['missed_days'] ?? 0) is int
                      ? recoveryInfo['missed_days']
                      : 0;
                  recoveryCost = (recoveryInfo['recovery_cost'] ?? 0) is int
                      ? recoveryInfo['recovery_cost']
                      : 0;
                } else {
                  // Fallback: client-side calculation (backward compatible)
                  int daysLost = 0;
                  if (lastReadDate != null) {
                    try {
                      final lastRead = DateTime.parse(lastReadDate.toString());
                      daysLost = DateTime.now().difference(lastRead).inDays;
                    } catch (_) {
                      daysLost = 0;
                    }
                  }
                  final clientMissedDays = daysLost > 0 ? daysLost - 1 : 0;
                  canRecover = currentStreak == 0 &&
                      lastReadDate != null &&
                      longestStreak > 0 &&
                      clientMissedDays >= 1 &&
                      clientMissedDays <= 3;
                  missedDays = clientMissedDays;
                  recoveryCost = clientMissedDays * 100;
                }

                return RefreshIndicator(
                  onRefresh: _loadData,
                  color: Colors.amber,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      children: [
                        _buildStreakHero(currentStreak, canRecover, missedDays,
                            recoveryCost),
                        const SizedBox(height: 20),
                        _buildStatsRow(
                          currentStreak: currentStreak,
                          longestStreak: longestStreak,
                          totalChapters: totalChapters,
                          totalBooks: totalBooks,
                        ),
                        const SizedBox(height: 20),
                        if (nextMilestone != null) ...[
                          _buildMilestoneProgress(
                              currentStreak, nextMilestone, daysToNext ?? 0),
                          const SizedBox(height: 20),
                        ],
                        _buildReadingCalendar(history),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStreakHero(
      int currentStreak, bool canRecover, int missedDays, int recoveryCost) {
    return AnimatedBuilder(
      animation: _countAnim,
      builder: (context, _) {
        final displayCount = (currentStreak * _countAnim.value).round();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: currentStreak > 0
                  ? [
                      const Color(0xFF1A1200),
                      const Color(0xFF2D1F00),
                      const Color(0xFF1A1200),
                    ]
                  : [
                      const Color(0xFF141414),
                      const Color(0xFF1A1A1A),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: currentStreak > 0
                  ? Colors.amber.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.06),
              width: 1.5,
            ),
            boxShadow: currentStreak > 0
                ? [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.08),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              AnimatedFlame(size: 72, isActive: currentStreak > 0),
              const SizedBox(height: 16),
              Text(
                '$displayCount',
                style: GoogleFonts.poppins(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: currentStreak > 0 ? Colors.amber : Colors.grey,
                  height: 1.0,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentStreak == 1 ? 'Day Streak' : 'Day Streak',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: currentStreak > 0
                      ? Colors.amber.withValues(alpha: 0.8)
                      : Colors.white38,
                ),
              ),
              if (currentStreak == 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    canRecover
                        ? 'Your streak was broken!'
                        : 'Read or watch something to start!',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: canRecover
                          ? Colors.redAccent.withValues(alpha: 0.8)
                          : Colors.white38,
                    ),
                  ),
                ),
                if (canRecover) ...[
                  const SizedBox(height: 16),
                  _buildRecoverStreakButton(missedDays, recoveryCost),
                ],
              ],
              if (currentStreak > 0) ...[
                const SizedBox(height: 12),
                Text(
                  _getMotivationalText(currentStreak),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white54,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow({
    required int currentStreak,
    required int longestStreak,
    required int totalChapters,
    required int totalBooks,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '🏆',
            '$longestStreak',
            'Best\nStreak',
            const Color(0xFFFFD700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            '📖',
            '$totalChapters',
            'Chapters\nDone',
            const Color(0xFF4ADE80),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            '📚',
            '$totalBooks',
            'Books\nDone',
            const Color(0xFF60A5FA),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String emoji, String value, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white38,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneProgress(
      int current, int nextMilestone, int daysToNext) {
    final progress = current / nextMilestone;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Next: $nextMilestone-day streak',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$daysToNext left',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _getMilestoneRewardText(nextMilestone),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingCalendar(List<Map<String, dynamic>> history) {
    final readDates = <String, int>{};
    for (final entry in history) {
      readDates[entry['date'] as String] = entry['chapters_read'] as int;
    }

    final today = DateTime.now();
    final days = List.generate(28, (i) {
      return today.subtract(Duration(days: 27 - i));
    });

    final firstDayWeekday = days[0].weekday;
    final offset = firstDayWeekday - 1;
    final totalCells = offset + 28;
    final totalRows = (totalCells / 7).ceil();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Last 4 Weeks',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white24,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(totalRows, (week) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (dayIdx) {
                  final cellIdx = week * 7 + dayIdx;
                  if (cellIdx < offset || cellIdx >= offset + 28) {
                    return const SizedBox(width: 36, height: 36);
                  }
                  final date = days[cellIdx - offset];
                  final dateStr =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  final chapters = readDates[dateStr] ?? 0;
                  final isToday = dateStr == todayStr;

                  Color bgColor;
                  Color textColor;
                  if (chapters >= 3) {
                    bgColor = Colors.amber;
                    textColor = Colors.black87;
                  } else if (chapters >= 1) {
                    bgColor = Colors.amber.withValues(alpha: 0.35);
                    textColor = Colors.white70;
                  } else {
                    bgColor = Colors.white.withValues(alpha: 0.04);
                    textColor = Colors.white.withValues(alpha: 0.2);
                  }

                  return Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: Colors.amber, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isToday || chapters > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: textColor,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildLegendDot(
                  Colors.white.withValues(alpha: 0.04), 'No activity'),
              const SizedBox(width: 14),
              _buildLegendDot(Colors.amber.withValues(alpha: 0.35), '1-2'),
              const SizedBox(width: 14),
              _buildLegendDot(Colors.amber, '3+'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
        ),
      ],
    );
  }

  Widget _buildRecoverStreakButton(int missedDays, int recoveryCost) {
    return GestureDetector(
      onTap: _isRecovering ? null : _recoverStreak,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8F00)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _isRecovering
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Recover Streak  🪙 $recoveryCost',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _recoverStreak() async {
    final story = Provider.of<Story>(context, listen: false);
    final streak = story.readingStreak;
    final recoveryInfo = streak['recovery_info'];
    int missedDays;
    int recoveryCost;

    if (recoveryInfo is Map<String, dynamic>) {
      missedDays = (recoveryInfo['missed_days'] ?? 0) is int
          ? recoveryInfo['missed_days']
          : 0;
      recoveryCost = (recoveryInfo['recovery_cost'] ?? 0) is int
          ? recoveryInfo['recovery_cost']
          : 0;
    } else {
      // Fallback: client-side calculation
      final lastReadDateData = streak['last_read_date'];
      int daysLost = 0;
      if (lastReadDateData != null) {
        try {
          final lastRead = DateTime.parse(lastReadDateData.toString());
          daysLost = DateTime.now().difference(lastRead).inDays;
        } catch (_) {
          daysLost = 1;
        }
      }
      missedDays = daysLost > 0 ? daysLost - 1 : 1;
      recoveryCost = missedDays * 100;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.local_fire_department,
                color: Colors.orange, size: 24),
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
          'You missed $missedDays day${missedDays > 1 ? 's' : ''}. Spend $recoveryCost points to fill the missed day${missedDays > 1 ? 's' : ''} and restore your streak. Recovery is available for up to 3 missed days.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                Text('Cancel', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Recover  🪙 $recoveryCost',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRecovering = true);

    try {
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
        _countController.forward(from: 0);
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
    } finally {
      if (mounted) {
        setState(() => _isRecovering = false);
      }
    }
  }

  String _getMotivationalText(int days) {
    if (days >= 365) return "1 YEAR! You're a legend! 🎖️";
    if (days >= 100) return "100 days! Master reader! 👑";
    if (days >= 50) return "50 days! Legendary! ⭐";
    if (days >= 30) return "1 month strong! Unstoppable! 🏆";
    if (days >= 14) return "2 weeks strong! Amazing! 💪";
    if (days >= 7) return "1 week streak! Keep it up! 🔥";
    if (days >= 3) return "Building a habit! Nice! ✨";
    return "You're on fire! Keep going! 🔥";
  }

  String _getMilestoneRewardText(int milestone) {
    switch (milestone) {
      case 3:
        return '🪙 +5 points at 3 days';
      case 7:
        return '🪙 +15 points at 7 days';
      case 14:
        return '🪙 +30 points at 14 days';
      case 30:
        return '🪙 +100 points at 30 days';
      case 50:
        return '🪙 +200 points at 50 days';
      case 100:
        return '🪙 +500 points at 100 days';
      default:
        return '🪙 Keep going for coin rewards!';
    }
  }
}
