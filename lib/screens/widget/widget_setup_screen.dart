import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/story.dart';
import '../../services/home_widget_service.dart';
import '../../utils/debug_logger.dart';

class WidgetSetupScreen extends StatefulWidget {
  static const routeName = '/widget-setup';

  const WidgetSetupScreen({Key? key}) : super(key: key);

  @override
  State<WidgetSetupScreen> createState() => _WidgetSetupScreenState();
}

class _WidgetSetupScreenState extends State<WidgetSetupScreen> {
  bool _widgetPinned = false;
  bool _isPinning = false;
  int _currentStreak = 0;
  int _totalChapters = 0;
  int _totalBooks = 0;

  @override
  void initState() {
    super.initState();
    _loadStreakData();
  }

  Future<void> _loadStreakData() async {
    final story = Provider.of<Story>(context, listen: false);
    await story.fetchReadingStreak();
    if (mounted) {
      final streak = story.readingStreak;
      setState(() {
        _currentStreak = streak['current_streak'] ?? 0;
        _totalChapters = streak['total_chapters_read'] ?? 0;
        _totalBooks = streak['total_books_completed'] ?? 0;
      });
      // Update widget data
      await HomeWidgetService.updateWidget(
        currentStreak: _currentStreak,
        totalChapters: _totalChapters,
        totalBooks: _totalBooks,
      );
    }
  }

  Future<void> _addWidget() async {
    if (_isPinning) return;
    setState(() => _isPinning = true);

    try {
      if (Platform.isAndroid) {
        await HomeWidgetService.requestPinWidget();
        if (mounted) {
          setState(() => _widgetPinned = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Widget added to your home screen!'),
              backgroundColor: const Color(0xFF4ADE80),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      DebugLogger.error('Widget pin failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not add widget. Try manually.'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPinning = false);
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
          'Home Screen Widget',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Widget Preview
            _buildWidgetPreview(),
            const SizedBox(height: 28),

            // Add Widget button (Android)
            if (Platform.isAndroid) ...[
              _buildAddWidgetButton(),
              const SizedBox(height: 28),
            ],

            // Instructions
            _buildInstructions(),
            const SizedBox(height: 28),

            // What the widget shows
            _buildWidgetFeatures(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetPreview() {
    final emoji = _getStreakEmoji(_currentStreak);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Emoji + streak count row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 10),
                    Text(
                      '$_currentStreak',
                      style: GoogleFonts.poppins(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _currentStreak == 1 ? 'day' : 'days',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_totalChapters chapters',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                    Text(
                      '  •  ',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white38,
                      ),
                    ),
                    Text(
                      '$_totalBooks books',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Start reading today!',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.amber.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddWidgetButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isPinning ? null : _addWidget,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _widgetPinned
                  ? [const Color(0xFF4ADE80), const Color(0xFF22C55E)]
                  : [const Color(0xFF4A6CF7), const Color(0xFF6366F1)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (_widgetPinned
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFF4A6CF7))
                    .withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: _isPinning
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _widgetPinned
                            ? Icons.check_circle_rounded
                            : Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _widgetPinned
                            ? 'Widget Added!'
                            : 'Add Widget to Home Screen',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    final isAndroid = Platform.isAndroid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to Add Manually',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (isAndroid) ...[
          _buildStep(1, 'Long press on your home screen'),
          _buildStep(2, 'Tap "Widgets"'),
          _buildStep(3, 'Find "Baakhapaa" in the widget list'),
          _buildStep(4, 'Drag the Reading Streak widget to your home screen'),
        ] else ...[
          _buildStep(1, 'Long press on your home screen'),
          _buildStep(2, 'Tap the + button in the top left'),
          _buildStep(3, 'Search for "Baakhapaa"'),
          _buildStep(4, 'Select "Reading Streak" and tap "Add Widget"'),
        ],
      ],
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$number',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What the Widget Shows',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        _buildFeature(Icons.local_fire_department_rounded, Colors.amber,
            'Daily Streak', 'Your current reading/watching streak count'),
        _buildFeature(Icons.menu_book_rounded, const Color(0xFF4ADE80),
            'Reading Progress', 'Total chapters and books completed'),
        _buildFeature(Icons.emoji_events_rounded, const Color(0xFF4A6CF7),
            'Streak Tier', 'Emoji badge that upgrades as your streak grows'),
        _buildFeature(Icons.auto_stories_rounded, const Color(0xFFE879F9),
            'Last Book', 'Title of the last book you were reading'),
      ],
    );
  }

  Widget _buildFeature(
      IconData icon, Color color, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStreakEmoji(int days) {
    if (days >= 30) return '🏆';
    if (days >= 14) return '⭐';
    if (days >= 7) return '🔥';
    if (days >= 3) return '📖';
    return '📚';
  }
}
