import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../providers/story_creation.dart';
import '../../../utils/debug_logger.dart';
import '../../../widgets/skeleton_loading.dart';
import 'create_episode_screen.dart';
import 'manage_episode_questions_screen.dart';

class ViewEpisodesScreen extends StatefulWidget {
  static const routeName = '/view-episodes';

  const ViewEpisodesScreen({Key? key}) : super(key: key);

  @override
  State<ViewEpisodesScreen> createState() => _ViewEpisodesScreenState();
}

class _ViewEpisodesScreenState extends State<ViewEpisodesScreen> {
  bool _isLoading = false;
  String _seasonTitle = '';
  int? _seasonId;
  List<dynamic> _episodes = [];
  List<dynamic> _filteredEpisodes = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _seasonId = args['seasonId'] as int?;
        _seasonTitle = args['seasonTitle'] as String? ?? 'Episodes';
        if (_seasonId != null) {
          _loadEpisodes();
        }
      }
    });
  }

  Future<void> _loadEpisodes() async {
    if (_seasonId == null) return;

    setState(() => _isLoading = true);

    try {
      final storyCreation = Provider.of<StoryCreation>(context, listen: false);
      final data = await storyCreation.fetchSeasonEpisodes(_seasonId!);

      setState(() {
        _seasonTitle = data['season_title'] ?? _seasonTitle;
        _episodes = data['episodes'] ?? [];
        _filteredEpisodes = data['episodes'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      DebugLogger.error('Error loading episodes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load episodes: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteEpisode(Map<String, dynamic> episode) async {
    final episodeId = episode['id'];
    final title = episode['title'] ?? 'Untitled Episode';

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final storyCreation = Provider.of<StoryCreation>(context, listen: false);
      await storyCreation.deleteEpisode(episodeId);

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        _showSuccessSnackBar('Episode "$title" deleted successfully');
        _loadEpisodes();
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        _showErrorSnackBar('Failed to delete episode: ${e.toString()}');
      }
    }
  }

  void _showEpisodeOptions(Map<String, dynamic> episode) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              episode['title'] ?? 'Episode Options',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Episode'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(
                  CreateEpisodeScreen.routeName,
                  arguments: {
                    'mode': 'edit',
                    'episode': episode,
                    'seasonId': _seasonId,
                    'seasonTitle': _seasonTitle,
                  },
                ).then((_) => _loadEpisodes());
              },
            ),
            ListTile(
              leading: const Icon(Icons.question_answer, color: Colors.green),
              title: const Text('Manage Questions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(
                  ManageEpisodeQuestionsScreen.routeName,
                  arguments: {
                    'episodeId': episode['id'],
                    'episodeTitle': episode['title'],
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Episode'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteEpisode(episode);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEpisode(Map<String, dynamic> episode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Episode'),
        content: Text(
          'Are you sure you want to delete "${episode['title']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEpisode(episode);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(Map<String, dynamic> episode) {
    final thumbnail = episode['thumbnail'] as String?;
    final title = episode['title'] as String? ?? 'Untitled Episode';
    final description = episode['description'] as String? ?? '';
    final duration = episode['duration'] as int? ?? 0;
    final coins = episode['coins'] as int? ?? 0;
    final coinsUsers = episode['coins_users'] as int? ?? 0;
    final lives = episode['lives'] as int? ?? 0;
    final questionsCount = episode['questions_count'] as int? ?? 0;
    final publishDate = episode['publish_date'] as String?;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Format publish date
    String formattedDate = '';
    if (publishDate != null && publishDate.isNotEmpty) {
      try {
        final date = DateTime.parse(publishDate);
        formattedDate = DateFormat('MMM dd, yyyy').format(date);
      } catch (e) {
        formattedDate = publishDate;
      }
    }

    // Validate thumbnail URL
    final hasValidThumbnail = thumbnail != null &&
        thumbnail.isNotEmpty &&
        thumbnail != 'null' &&
        thumbnail != 'none' &&
        (thumbnail.startsWith('http://') || thumbnail.startsWith('https://'));

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            // Navigate directly to manage questions
            Navigator.of(context).pushNamed(
              ManageEpisodeQuestionsScreen.routeName,
              arguments: {
                'episodeId': episode['id'],
                'episodeTitle': episode['title'],
              },
            );
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showEpisodeOptions(episode);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail with gradient overlay and badges
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: hasValidThumbnail
                            ? Image.network(
                                thumbnail,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF667eea),
                                          Color(0xFF764ba2)
                                        ],
                                      ),
                                    ),
                                    child: Icon(Icons.movie,
                                        size: 64, color: Colors.white70),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[300],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2)
                                    ],
                                  ),
                                ),
                                child: Icon(Icons.movie,
                                    size: 64, color: Colors.white70),
                              ),
                      ),
                    ),
                    // Gradient overlay
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    // Duration badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              '${duration}s',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Question count badge
                    if (questionsCount > 0)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.quiz, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                '$questionsCount ${questionsCount == 1 ? 'Question' : 'Questions'}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                // Content section
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 16),
                      // Stats row with icons
                      Row(
                        children: [
                          _buildCompactStat(
                              Icons.monetization_on, '$coins', Colors.amber,
                              isDark: isDark),
                          SizedBox(width: 12),
                          _buildCompactStat(
                              Icons.people, '$coinsUsers', Colors.green,
                              isDark: isDark),
                          SizedBox(width: 12),
                          _buildCompactStat(
                              Icons.favorite, '$lives', Colors.red,
                              isDark: isDark),
                        ],
                      ),
                      if (formattedDate.isNotEmpty) ...[
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color:
                                      isDark ? Colors.white60 : Colors.black45,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black45,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            // Quick action buttons
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context).pushNamed(
                                      CreateEpisodeScreen.routeName,
                                      arguments: {
                                        'mode': 'edit',
                                        'episode': episode,
                                        'seasonId': _seasonId,
                                        'seasonTitle': _seasonTitle,
                                      },
                                    ).then((_) => _loadEpisodes());
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.black
                                              .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _showEpisodeOptions(episode);
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.black
                                              .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.more_vert,
                                      size: 18,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _filterEpisodes(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredEpisodes = _episodes;
      } else {
        _filteredEpisodes = _episodes.where((episode) {
          final title = (episode['title'] ?? '').toString().toLowerCase();
          final description =
              (episode['description'] ?? '').toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return title.contains(searchLower) ||
              description.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildCompactStat(IconData icon, String value, Color color,
      {required bool isDark}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _seasonTitle,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_filteredEpisodes.length}${_searchQuery.isNotEmpty ? ' found' : ''} of ${_episodes.length} ${_episodes.length == 1 ? 'Episode' : 'Episodes'}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: _loadEpisodes,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(24.0),
              child: ListSkeleton(itemCount: 4),
            )
          : _episodes.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                          ),
                          child: Icon(
                            Icons.movie_outlined,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'No Episodes Yet',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Start creating episodes for this season.\nEach episode can have interactive questions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black54,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 32),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF667eea).withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.of(context).pushNamed(
                                CreateEpisodeScreen.routeName,
                                arguments: {
                                  'seasonId': _seasonId,
                                  'seasonTitle': _seasonTitle,
                                },
                              ).then((_) => _loadEpisodes());
                            },
                            icon: Icon(Icons.add_circle_outline, size: 24),
                            label: Text('Create First Episode'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 18,
                              ),
                              textStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              isDark ? Color(0xFF1E1E1E) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Color(0xFF2E2E2E)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _filterEpisodes,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search episodes...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _filterEpisodes('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Episodes List
                    Expanded(
                      child: _filteredEpisodes.isEmpty &&
                              _searchQuery.isNotEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(48),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black26,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No episodes found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Try a different search term',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadEpisodes,
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: _filteredEpisodes.length,
                                itemBuilder: (context, index) {
                                  return _buildEpisodeCard(
                                      _filteredEpisodes[index]);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _seasonId == null
          ? null
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF667eea).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pushNamed(
                    CreateEpisodeScreen.routeName,
                    arguments: {
                      'seasonId': _seasonId,
                      'seasonTitle': _seasonTitle,
                    },
                  ).then((_) => _loadEpisodes());
                },
                icon: Icon(Icons.add_circle_outline),
                label: Text(
                  'New Episode',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
            ),
    );
  }
}
