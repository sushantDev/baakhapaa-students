import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/story/reading_streak_screen.dart';

class StreakCelebrationOverlay extends StatefulWidget {
  final int streakDays;
  final int reward;
  final bool bookCompleted;
  final VoidCallback onDismiss;

  const StreakCelebrationOverlay({
    Key? key,
    required this.streakDays,
    required this.reward,
    required this.onDismiss,
    this.bookCompleted = false,
  }) : super(key: key);

  @override
  State<StreakCelebrationOverlay> createState() =>
      _StreakCelebrationOverlayState();
}

class _StreakCelebrationOverlayState extends State<StreakCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fire emoji
                    Text(
                      '🔥',
                      style: const TextStyle(fontSize: 56),
                    ),
                    const SizedBox(height: 12),

                    // Streak count
                    Text(
                      '${widget.streakDays}-Day Streak!',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Message
                    Text(
                      _getStreakMessage(widget.streakDays),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Reward section
                    if (widget.reward > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              '+${widget.reward} coins!',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Book completed badge
                    if (widget.bookCompleted) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📚', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            'Book Completed!',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        widget.onDismiss();
                        Navigator.of(context)
                            .pushNamed(ReadingStreakScreen.routeName);
                      },
                      child: Text(
                        'View Streak Details →',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.amber.withValues(alpha: 0.8),
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.amber.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to continue',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getStreakMessage(int days) {
    if (days >= 365) return "1 YEAR! Ultimate champion! 🎖️";
    if (days >= 100) return "100 DAYS! Master reader! 👑";
    if (days >= 50) return "50 days! Legendary reader! ⭐";
    if (days >= 30) return "1 month! You're unstoppable! 🏆";
    if (days >= 14) return "2 weeks strong! 💪";
    if (days >= 7) return "1 week streak! Keep it up!";
    if (days >= 3) return "3-day streak! You're building a habit!";
    return "Keep reading daily to build your streak!";
  }
}
