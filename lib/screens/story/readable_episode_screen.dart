import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/story.dart';
import '../../providers/auth.dart';
import '../../utils/debug_logger.dart';
import '../../utils/guest_auth_helper.dart';
import '../../widgets/readable_page_card.dart';
import '../../widgets/tts_control_bar.dart';
import '../../services/tts_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/analytics_service.dart';
import 'question_screen.dart';
import 'crossword_screen.dart';
import 'image_puzzle_screen.dart';

class ReadableEpisodeScreen extends StatefulWidget {
  static const routeName = '/readable-episode-screen';

  const ReadableEpisodeScreen({Key? key}) : super(key: key);

  @override
  State<ReadableEpisodeScreen> createState() => _ReadableEpisodeScreenState();
}

class _ReadableEpisodeScreenState extends State<ReadableEpisodeScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  String _language = 'en';
  List<dynamic> _pages = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _episode = {};
  var _isInit = false;
  bool _showTtsBar = false;
  final TtsService _ttsService = TtsService();
  bool _chapterCompleteRecorded = false;
  bool _isAutoAdvancing = false;
  bool _isClosingTts = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      _isInit = true;
      _loadEpisodeAndPages();
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _ttsService.stop();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadEpisodeAndPages() async {
    try {
      final storyProvider = Provider.of<Story>(context, listen: false);
      final navArgs = ModalRoute.of(context)?.settings.arguments;

      // Get episode ID from route arguments or provider
      int episodeId = 0;
      if (navArgs is Map<String, dynamic> && navArgs['id'] != null) {
        episodeId = navArgs['id'] is int
            ? navArgs['id']
            : int.tryParse(navArgs['id'].toString()) ?? 0;
      } else if (navArgs is int) {
        episodeId = navArgs;
      }

      if (episodeId <= 0) {
        // Try from provider
        final providerEp = storyProvider.episode;
        if (providerEp.isNotEmpty && providerEp['id'] != null) {
          episodeId = providerEp['id'] is int
              ? providerEp['id']
              : int.tryParse(providerEp['id'].toString()) ?? 0;
        }
      }

      if (episodeId <= 0) {
        setState(() {
          _errorMessage = 'No chapter selected';
          _isLoading = false;
        });
        return;
      }

      DebugLogger.info('📖 Loading episode $episodeId and pages');

      // Fetch episode data (sets Provider.of<Story>.episode)
      await storyProvider.fetchEpisode(episodeId);

      if (!mounted) return;

      _episode = storyProvider.episode;

      // Fetch pages
      final pages = await storyProvider.fetchEpisodePages(episodeId);

      if (mounted) {
        // Build intro page from episode description if available
        final description = _episode['description'] ?? '';
        final nepaliDescription = _episode['nepali_description'];
        final hasDescription = description.toString().isNotEmpty ||
            (nepaliDescription != null &&
                nepaliDescription.toString().isNotEmpty);

        final allPages = <dynamic>[];
        if (hasDescription) {
          allPages.add({
            'title': _episode['title'] ?? 'Chapter Overview',
            'content': description,
            'nepali_title': _episode['nepali_title'],
            'nepali_content': nepaliDescription,
            'image_url': (_episode['thumbnail'] != null &&
                    _episode['thumbnail'] != 'None')
                ? _episode['thumbnail']
                : _episode['image_url'],
            'is_key_point': false,
            'is_summary': false,
            'is_intro': true,
          });
        }
        allPages.addAll(pages);

        setState(() {
          _pages = allPages;
          _isLoading = false;
          if (_pages.isEmpty) {
            _errorMessage = 'No content available for this chapter';
          }
        });

        // Track book read event
        final seasonId = _episode['season_id'] ?? _episode['story_id'] ?? 0;
        AnalyticsService.logBookRead(
          seasonId: seasonId is int
              ? seasonId
              : int.tryParse(seasonId.toString()) ?? 0,
          episodeId: episodeId,
          title: _episode['title'] ?? 'Unknown',
          language: _language,
        );
      }
    } catch (e) {
      DebugLogger.error('📖 Error loading episode/pages: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load content';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recordChapterComplete() async {
    _chapterCompleteRecorded = true;
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) return;

    final episodeId = _episode['id'];
    if (episodeId == null) return;

    final storyProvider = Provider.of<Story>(context, listen: false);
    final result = await storyProvider.recordChapterComplete(
      episodeId is int ? episodeId : int.tryParse(episodeId.toString()) ?? 0,
    );

    if (result.isNotEmpty && result['new_day'] == true && mounted) {
      // Update home screen widget with latest streak data
      HomeWidgetService.updateWidget(
        currentStreak: result['current_streak'] ?? 0,
        totalChapters: result['total_chapters_read'] ?? 0,
        totalBooks: result['total_books_completed'] ?? 0,
        lastBookTitle: _episode['season_title'] ?? '',
      );

      // Track streak continued
      AnalyticsService.logStreakContinued(
        streakDay: result['current_streak'] ?? 0,
      );
    }

    // Track book chapter completed
    final seasonId = _episode['season_id'] ?? _episode['story_id'] ?? 0;
    AnalyticsService.logBookCompleted(
      seasonId:
          seasonId is int ? seasonId : int.tryParse(seasonId.toString()) ?? 0,
      episodeId: episodeId is int
          ? episodeId
          : int.tryParse(episodeId.toString()) ?? 0,
      title: _episode['title'] ?? 'Unknown',
    );

    // Refresh continue watching list (removes completed books, updates progress)
    storyProvider.fetchContinueWatching();
  }

  void _navigateToQuiz() {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      GuestAuthHelper.showGuestLoginDialog(context, 'take quizzes');
      return;
    }
    final watched = _episode['watched'];
    final quizCompleted =
        watched == true || watched == 1 || watched == '1' || watched == 'true';
    if (quizCompleted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Challenge Completed'),
          content: Text(
            'You have already completed the quiz for this episode. Please choose another challenge.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Okay'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.of(context).pushNamed(
      QuestionScreen.routeName,
      arguments: {'language': _language},
    );
  }

  void _navigateToCrossword() {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      GuestAuthHelper.showGuestLoginDialog(context, 'play crossword');
      return;
    }
    Navigator.of(context).pushNamed(CrosswordScreen.routeName);
  }

  void _navigateToImagePuzzle() {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      GuestAuthHelper.showGuestLoginDialog(context, 'play image puzzle');
      return;
    }
    Navigator.of(context).pushNamed(ImagePuzzleScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final chapterTitle = _episode['title'] ?? 'Chapter';

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage.isNotEmpty
                ? _buildErrorState()
                : _buildReaderContent(chapterTitle),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.amber),
          SizedBox(height: 16),
          Text(
            'Loading chapter...',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderContent(String chapterTitle) {
    // Build the list of page widgets — regular pages + summary as last card
    final List<dynamic> allPages = List.from(_pages);

    // Get current page text for TTS
    String currentPageText = '';
    if (_currentPage < allPages.length) {
      final page = allPages[_currentPage];
      final isSummary = page['is_summary'] == true || page['is_summary'] == 1;
      if (!isSummary) {
        final npTitle = page['nepali_title'];
        final title = _language == 'ne' &&
                npTitle != null &&
                npTitle.toString().isNotEmpty
            ? npTitle
            : page['title'] ?? '';
        final npContent = page['nepali_content'];
        final content = _language == 'ne' &&
                npContent != null &&
                npContent.toString().isNotEmpty
            ? npContent
            : page['content'] ?? '';
        currentPageText = '$title. $content';
      }
    }

    return Stack(
      children: [
        Column(
          children: [
            // Top bar
            _buildTopBar(chapterTitle),

            // Page content with vertical page indicator on the right
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: allPages.length,
                      onPageChanged: (index) {
                        if (!_isAutoAdvancing && !_isClosingTts) {
                          _ttsService.stop();
                        }
                        if (_isClosingTts) {
                          // Ignore page changes triggered by layout shift during TTS close
                          _isClosingTts = false;
                          return;
                        }
                        setState(() {
                          _currentPage = index;
                        });
                        if (_isAutoAdvancing) {
                          _isAutoAdvancing = false;
                          // Auto-speak the next page after advance animation
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted &&
                                _showTtsBar &&
                                index < allPages.length) {
                              final page = allPages[index];
                              final isSummary = page['is_summary'] == true ||
                                  page['is_summary'] == 1;
                              if (!isSummary) {
                                final npTitle = page['nepali_title'];
                                final title = _language == 'ne' &&
                                        npTitle != null &&
                                        npTitle.toString().isNotEmpty
                                    ? npTitle
                                    : page['title'] ?? '';
                                final npContent = page['nepali_content'];
                                final content = _language == 'ne' &&
                                        npContent != null &&
                                        npContent.toString().isNotEmpty
                                    ? npContent
                                    : page['content'] ?? '';
                                _ttsService.speak('$title. $content');
                              }
                            }
                          });
                        }
                        // When user reaches the last page (summary), record chapter complete
                        if (index == allPages.length - 1 &&
                            !_chapterCompleteRecorded) {
                          _recordChapterComplete();
                        }
                      },
                      itemBuilder: (context, index) {
                        final page = allPages[index];
                        final isSummary = page['is_summary'] == true ||
                            page['is_summary'] == 1;

                        if (isSummary) {
                          final summaryPoints = page['summary_points'] is List
                              ? page['summary_points'] as List
                              : <dynamic>[];
                          final nepaliSummaryPoints =
                              page['nepali_summary_points'] is List
                                  ? page['nepali_summary_points'] as List
                                  : <dynamic>[];

                          return SummaryPageCard(
                            summaryPoints: summaryPoints,
                            nepaliSummaryPoints: nepaliSummaryPoints,
                            language: _language,
                            title: page['title'] ?? '',
                            content: page['content'] ?? '',
                            nepaliTitle: page['nepali_title'],
                            nepaliContent: page['nepali_content'],
                            onTakeQuiz: _navigateToQuiz,
                            onCrossword: _navigateToCrossword,
                            onImagePuzzle: _navigateToImagePuzzle,
                          );
                        }

                        final isKeyPoint = page['is_key_point'] == true ||
                            page['is_key_point'] == 1;
                        final isIntro = page['is_intro'] == true;

                        return ReadablePageCard(
                          key: ValueKey('page_${index}_$_language'),
                          title: page['title'] ?? '',
                          content: page['content'] ?? '',
                          imageUrl: page['image_url'],
                          isKeyPoint: isKeyPoint,
                          isIntro: isIntro,
                          pageIndex: index,
                          language: _language,
                          nepaliTitle: page['nepali_title'],
                          nepaliContent: page['nepali_content'],
                          onSwipeToNext: index < allPages.length - 1
                              ? () => _pageController.nextPage(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                  )
                              : null,
                          onSwipeToPrevious: index > 0
                              ? () => _pageController.previousPage(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                  )
                              : null,
                        );
                      },
                    ),
                  ),

                  // Page indicator dots (vertical, right side)
                  _buildVerticalPageIndicator(allPages.length),
                ],
              ),
            ),
          ],
        ),

        // TTS floating button (bottom-right)
        if (!_showTtsBar)
          Positioned(
            bottom: 60,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() => _showTtsBar = true);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.headphones_rounded,
                    color: Colors.black, size: 24),
              ),
            ),
          ),

        // TTS control bar (bottom)
        if (_showTtsBar)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TtsControlBar(
                  currentText: currentPageText,
                  language: _language,
                  onAutoAdvance: () {
                    if (_currentPage < allPages.length - 1) {
                      _isAutoAdvancing = true;
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  onAutoClose: () {
                    if (mounted) {
                      _isClosingTts = true;
                      setState(() => _showTtsBar = false);
                    }
                  },
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    _isClosingTts = true;
                    _ttsService.stop();
                    setState(() => _showTtsBar = false);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 16),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar(String chapterTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon:
                const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Chapter title
          Expanded(
            child: Text(
              chapterTitle,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Language toggle
          GestureDetector(
            onTap: () {
              _ttsService.stop();
              setState(() {
                _language = _language == 'en' ? 'ne' : 'en';
              });
              _ttsService.setLanguage(_language == 'ne' ? 'ne-NP' : 'en-US');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _language == 'en' ? 'EN' : 'ने',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalPageIndicator(int pageCount) {
    if (pageCount <= 1) return const SizedBox(width: 20);

    return Container(
      width: 20,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(pageCount, (index) {
          final isActive = index == _currentPage;
          if (pageCount > 10) {
            final showDot = index < 3 ||
                index > pageCount - 4 ||
                (index - _currentPage).abs() <= 1;
            if (!showDot) {
              if (index == 3 || index == pageCount - 4) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                );
              }
              return const SizedBox.shrink();
            }
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(vertical: 3),
            width: 8,
            height: isActive ? 24 : 8,
            decoration: BoxDecoration(
              color:
                  isActive ? Colors.amber : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
