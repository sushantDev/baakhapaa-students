import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Gradient presets that cycle by page index for visual variety
const List<List<Color>> _cardGradients = [
  [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
  [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
  [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
  [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
  [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
  [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
  [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
  [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
];

/// Standard insight card for readable content
class ReadablePageCard extends StatefulWidget {
  final String title;
  final String content;
  final String? imageUrl;
  final bool isKeyPoint;
  final bool isIntro;
  final int pageIndex;
  final String language; // 'en' or 'ne'
  final String? nepaliTitle;
  final String? nepaliContent;
  final VoidCallback? onSwipeToNext; // called when overscrolled at bottom
  final VoidCallback? onSwipeToPrevious; // called when overscrolled at top

  const ReadablePageCard({
    super.key,
    required this.title,
    required this.content,
    this.imageUrl,
    this.isKeyPoint = false,
    this.isIntro = false,
    required this.pageIndex,
    this.language = 'en',
    this.nepaliTitle,
    this.nepaliContent,
    this.onSwipeToNext,
    this.onSwipeToPrevious,
  });

  @override
  State<ReadablePageCard> createState() => _ReadablePageCardState();
}

class _ReadablePageCardState extends State<ReadablePageCard> {
  bool _pageSwitchTriggered = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _cardGradients[widget.pageIndex % _cardGradients.length];
    final bool isNepali = widget.language == 'ne';
    final displayTitle =
        isNepali && widget.nepaliTitle != null && widget.nepaliTitle!.isNotEmpty
            ? widget.nepaliTitle!
            : widget.title;
    final displayContent = isNepali &&
            widget.nepaliContent != null &&
            widget.nepaliContent!.isNotEmpty
        ? widget.nepaliContent!
        : widget.content;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (_pageSwitchTriggered) return false;
                if (notification is ScrollEndNotification) {
                  final metrics = notification.metrics;
                  // At the very bottom, next swipe up → go to next page
                  if (metrics.pixels >= metrics.maxScrollExtent &&
                      metrics.maxScrollExtent > 0) {
                    // User is at the bottom; check if they're trying to scroll further
                  }
                }
                if (notification is OverscrollNotification) {
                  if (notification.overscroll > 0 &&
                      widget.onSwipeToNext != null) {
                    _pageSwitchTriggered = true;
                    widget.onSwipeToNext!();
                    Future.delayed(const Duration(milliseconds: 600), () {
                      if (mounted) _pageSwitchTriggered = false;
                    });
                    return true;
                  } else if (notification.overscroll < 0 &&
                      widget.onSwipeToPrevious != null) {
                    _pageSwitchTriggered = true;
                    widget.onSwipeToPrevious!();
                    Future.delayed(const Duration(milliseconds: 600), () {
                      if (mounted) _pageSwitchTriggered = false;
                    });
                    return true;
                  }
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Intro badge
                      if (widget.isIntro)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_stories,
                                  color: Colors.blue, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                isNepali ? 'अध्याय परिचय' : 'Chapter Overview',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Key point indicator
                      if (widget.isKeyPoint)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lightbulb,
                                  color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                isNepali ? 'मुख्य विचार' : 'Key Insight',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Nepali language indicator
                      if (isNepali &&
                          widget.nepaliContent != null &&
                          widget.nepaliContent!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'नेपालीमा',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white54,
                            ),
                          ),
                        ),

                      // Optional illustration
                      if (widget.imageUrl != null &&
                          widget.imageUrl!.isNotEmpty &&
                          widget.imageUrl != 'None') ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: widget.imageUrl!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 160,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            errorWidget: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Title
                      Text(
                        displayTitle,
                        style: GoogleFonts.merriweather(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Body content
                      Text(
                        displayContent,
                        style: GoogleFonts.merriweather(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Final summary card with key takeaways and game mode buttons
class SummaryPageCard extends StatelessWidget {
  final List<dynamic> summaryPoints;
  final String language;
  final List<dynamic>? nepaliSummaryPoints;
  final String? title;
  final String? content;
  final String? nepaliTitle;
  final String? nepaliContent;
  final VoidCallback onTakeQuiz;
  final VoidCallback? onCrossword;
  final VoidCallback? onImagePuzzle;

  const SummaryPageCard({
    super.key,
    required this.summaryPoints,
    this.language = 'en',
    this.nepaliSummaryPoints,
    this.title,
    this.content,
    this.nepaliTitle,
    this.nepaliContent,
    required this.onTakeQuiz,
    this.onCrossword,
    this.onImagePuzzle,
  });

  @override
  Widget build(BuildContext context) {
    List<dynamic> displayPoints = language == 'ne' &&
            nepaliSummaryPoints != null &&
            nepaliSummaryPoints!.isNotEmpty
        ? nepaliSummaryPoints!
        : summaryPoints;

    // Fallback: if summary_points is empty, derive from content text
    if (displayPoints.isEmpty) {
      final fallbackContent =
          language == 'ne' && nepaliContent != null && nepaliContent!.isNotEmpty
              ? nepaliContent!
              : content ?? '';
      if (fallbackContent.isNotEmpty) {
        // Split content into sentences as bullet points
        displayPoints = fallbackContent
            .split(RegExp(r'[.।]\s*'))
            .where((s) => s.trim().length > 10)
            .toList();
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      language == 'ne' ? 'मुख्य बुँदाहरू' : 'Key Takeaways',
                      style: GoogleFonts.merriweather(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Summary title (from page title when summary_points was null)
                if (summaryPoints.isEmpty && title != null && title!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      language == 'ne' &&
                              nepaliTitle != null &&
                              nepaliTitle!.isNotEmpty
                          ? nepaliTitle!
                          : title!,
                      style: GoogleFonts.merriweather(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ),

                // Summary points
                ...displayPoints.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 32),

                // Divider between takeaways and games
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        thickness: 1,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        language == 'ne'
                            ? 'आफ्नो ज्ञान परीक्षण गर्नुहोस्'
                            : 'Test Your Knowledge',
                        style: GoogleFonts.merriweather(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Game mode buttons
                _buildGameButton(
                  icon: Icons.quiz,
                  label: language == 'ne' ? 'क्विज खेल्नुहोस्' : 'Take Quiz',
                  color: const Color(0xFF2964FA),
                  onTap: onTakeQuiz,
                ),
                if (onCrossword != null) ...[
                  const SizedBox(height: 10),
                  _buildGameButton(
                    icon: Icons.grid_on,
                    label: language == 'ne' ? 'क्रसवर्ड' : 'Crossword',
                    color: const Color(0xFF7B2FF7),
                    onTap: onCrossword!,
                  ),
                ],
                if (onImagePuzzle != null) ...[
                  const SizedBox(height: 10),
                  _buildGameButton(
                    icon: Icons.extension,
                    label: language == 'ne' ? 'पजल' : 'Image Puzzle',
                    color: const Color(0xFFE91E63),
                    onTap: onImagePuzzle!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
