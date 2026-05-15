// ignore_for_file: duplicate_import, unused_local_variable, unused_import

import 'package:baakhapaa/providers/story.dart';
import 'package:baakhapaa/providers/story.dart';
import 'package:baakhapaa/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:baakhapaa/screens/story/video_screen.dart';
import 'package:baakhapaa/utils/debug_logger.dart' as debug;

class MyCourseListItem extends StatefulWidget {
  final dynamic course;
  final int index;

  const MyCourseListItem({
    Key? key,
    required this.course,
    required this.index,
  }) : super(key: key);

  @override
  State<MyCourseListItem> createState() => _MyCourseListItemState();
}

class _MyCourseListItemState extends State<MyCourseListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '0:00';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  bool _isEpisodeWatched(dynamic episode) {
    if (episode is! Map) return false;
    final watched = episode['watched'];
    return watched == true ||
        watched == 1 ||
        watched == '1' ||
        watched == 'true';
  }

  int? _episodeIdFrom(dynamic episode) {
    if (episode is! Map) return null;
    return _asInt(episode['id']) ?? _asInt(episode['episode_id']);
  }

  int _resumeSecondsFrom(dynamic source, int fallback) {
    if (source is! Map) return fallback;
    return _asInt(source['watched_duration_seconds']) ??
        _asInt(source['progress_seconds']) ??
        _asInt(source['resume_at_seconds']) ??
        fallback;
  }

  Future<void> _openResumeVideo({
    required BuildContext context,
    required Map<String, dynamic>? season,
    required int? initialEpisodeId,
    required int initialResumeSeconds,
  }) async {
    try {
      final story = Provider.of<Story>(context, listen: false);
      int? episodeId = initialEpisodeId;
      int resumeSeconds = initialResumeSeconds;
      List<dynamic> episodes = [];

      final seasonId =
          _asInt(season?['id']) ?? _asInt(widget.course['season_id']);

      if (episodeId == null) {
        final seasonEpisodes = season?['episodes'];
        if (seasonEpisodes is List) {
          episodes = seasonEpisodes;
        }

        if (episodes.isEmpty && seasonId != null) {
          final seasonDetails = await story.fetchSeasonDetails(seasonId);
          final detailsEpisodes = seasonDetails?['episodes'];
          if (detailsEpisodes is List) {
            episodes = detailsEpisodes;
          } else {
            episodes = await story.fetchSeasonEpisodes(seasonId);
          }
        }

        if (episodes.isNotEmpty) {
          dynamic episodeToPlay;
          try {
            episodeToPlay = episodes.firstWhere((ep) => !_isEpisodeWatched(ep));
          } catch (_) {
            episodeToPlay = episodes.first;
          }
          episodeId = _episodeIdFrom(episodeToPlay);
          resumeSeconds = _resumeSecondsFrom(episodeToPlay, resumeSeconds);
        }
      }

      if (episodeId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open this course. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (season != null) {
        await story.setSelectedSeason({
          ...season,
          if (seasonId != null) 'id': seasonId,
          if (episodes.isNotEmpty) 'episodes': episodes,
          'isCreatorSeason': false,
        });
      }

      if (!context.mounted) return;
      Navigator.push(
        context,
        PageTransition(
          child: const VideoScreen(),
          type: PageTransitionType.rightToLeftWithFade,
          settings: RouteSettings(
            name: VideoScreen.routeName,
            arguments: {
              'id': episodeId,
              'resumeAtSeconds': resumeSeconds,
            },
          ),
        ),
      );
    } catch (error) {
      debug.DebugLogger.error('My Courses resume failed: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open this course. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(context);
    final surfaceColor = AppColors.getSurface(context);
    final textColor = AppColors.getOnSurface(context);
    final secondaryColor = AppColors.getSecondary(context);

    // Extract data from continue watching item structure
    final season = _asMap(widget.course['season']);
    final completionPercentage =
        _asInt(widget.course['completion_percentage']) ?? 0;
    final lastWatchedEpisode = _asMap(widget.course['last_watched_episode']);

    // Get course data from season
    final courseTitle = season?['title'] ?? 'Untitled Course';
    final courseThumbnail = season?['course_thumbnail'] ?? season?['thumbnail'];
    final episodesCount = season?['episodes_count'] ?? 0;

    // Get resume position from last watched episode
    int lastWatchedSeconds = 0;
    int? lastWatchedEpisodeId;
    if (lastWatchedEpisode != null) {
      lastWatchedSeconds = _resumeSecondsFrom(lastWatchedEpisode, 0);
      lastWatchedEpisodeId = _episodeIdFrom(lastWatchedEpisode);
    }

    final fallbackEpisodeId = _asInt(widget.course['episode_id']) ??
        _asInt(widget.course['last_watched_episode_id']) ??
        _asInt(widget.course['current_episode_id']);

    if (lastWatchedEpisodeId == null && fallbackEpisodeId != null) {
      lastWatchedEpisodeId = fallbackEpisodeId;
      lastWatchedSeconds =
          _resumeSecondsFrom(widget.course, lastWatchedSeconds);
    }

    // Calculate watched episodes
    final watchedEpisodes =
        ((completionPercentage / 100) * episodesCount).toInt();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: () async {
            await _openResumeVideo(
              context: context,
              season: season,
              initialEpisodeId: lastWatchedEpisodeId,
              initialResumeSeconds: lastWatchedSeconds,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      surfaceColor,
                      surfaceColor.withValues(alpha: 0.8),
                    ],
                  ),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Course thumbnail section with overlay
                    Stack(
                      children: [
                        // Thumbnail image
                        if (courseThumbnail != null)
                          SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: CachedNetworkImage(
                              imageUrl: courseThumbnail,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: primaryColor.withValues(alpha: 0.1),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        primaryColor),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: primaryColor.withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.play_lesson,
                                  color: primaryColor,
                                  size: 40,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 180,
                            color: primaryColor.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.play_lesson,
                              color: primaryColor,
                              size: 40,
                            ),
                          ),

                        // Gradient overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Resume button overlay
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFFF9A56).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Color(0xFFFF9A56).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Resume',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Completion badge
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${completionPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Course details section
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Course title
                          Text(
                            courseTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Episodes count
                          Text(
                            '$watchedEpisodes of $episodesCount episodes completed',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: completionPercentage / 100,
                              minHeight: 6,
                              backgroundColor:
                                  primaryColor.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF9A56),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Resume position
                          if (lastWatchedSeconds > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Color(0xFFFF9A56).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      Color(0xFFFF9A56).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: Color(0xFFFF9A56),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Resume at ${_formatDuration(lastWatchedSeconds)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFFF9A56),
                                      fontWeight: FontWeight.w600,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
