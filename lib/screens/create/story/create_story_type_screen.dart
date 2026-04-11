import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/story_creation.dart';
import '../../../providers/challenge.dart';
import '../../../utils/debug_logger.dart';
import '../../../widgets/skeleton_loading.dart';
import 'create_season_screen.dart';
import 'create_episode_screen.dart';
import 'view_episodes_screen.dart';

class CreateStoryTypeScreen extends StatefulWidget {
  static const routeName = '/create-story-type';

  const CreateStoryTypeScreen({Key? key}) : super(key: key);

  @override
  State<CreateStoryTypeScreen> createState() => _CreateStoryTypeScreenState();
}

class _CreateStoryTypeScreenState extends State<CreateStoryTypeScreen> {
  bool _isLoading = true;
  List<dynamic> _mySeasons = [];
  List<dynamic> _filteredSeasons = [];
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Set<int> _challengeSeasonIds = {}; // Track challenge season IDs locally
  List<dynamic> _challenges = []; // Store challenges from API
  Map<int, dynamic> _seasonToChallengeMap =
      {}; // Map season ID to challenge data

  @override
  void initState() {
    super.initState();
    _loadChallengeSeasonIds();
    _loadChallenges(); // Load challenges first
    _loadSeasons();
  }

  Future<void> _loadChallengeSeasonIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> ids =
          prefs.getStringList('challenge_season_ids') ?? [];
      setState(() {
        _challengeSeasonIds = ids.map((id) => int.parse(id)).toSet();
      });
      DebugLogger.info(
          '📋 Loaded ${_challengeSeasonIds.length} challenge season IDs: $_challengeSeasonIds');
    } catch (e) {
      DebugLogger.error('Error loading challenge season IDs: $e');
    }
  }

  Future<void> _loadChallenges() async {
    try {
      final challengeProvider = Provider.of<Challenge>(context, listen: false);
      await challengeProvider.fetchChallenges();
      _challenges = challengeProvider.challenges;

      // Filter for Seasons platform challenges only
      final seasonsChallenges =
          _challenges.where((c) => c['platform'] == 'Seasons').toList();

      DebugLogger.info(
          '🏆 Loaded ${_challenges.length} total challenges, ${seasonsChallenges.length} for Seasons platform');

      // Log challenge details
      for (var challenge in seasonsChallenges) {
        DebugLogger.info(
            '   Challenge: ${challenge['title']} (ID: ${challenge['id']}) - heading_id: ${challenge['heading_id']}');
      }
    } catch (e) {
      DebugLogger.error('Error loading challenges: $e');
    }
  }

  Future<void> _loadSeasons() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final storyCreation = Provider.of<StoryCreation>(context, listen: false);
      final seasons = await storyCreation.fetchMySeasons();

      // Map challenges to seasons
      _mapChallengesToSeasons(seasons);

      // Debug: Log season data to check for is_challenge field
      for (var season in seasons) {
        final challengeData = _seasonToChallengeMap[season['id']];
        DebugLogger.info(
            '🎬 Season: ${season['title']} (ID: ${season['id']}) - is_challenge: ${season['is_challenge']}');
        if (challengeData != null) {
          DebugLogger.info(
              '   ✅ Mapped to challenge: ${challengeData['title']} (Challenge ID: ${challengeData['id']})');
        }
        DebugLogger.info('   All fields: ${season.keys.toList()}');
        // Check if episodes have challenge data
        if (season['episodes'] != null &&
            (season['episodes'] as List).isNotEmpty) {
          final firstEpisode = (season['episodes'] as List)[0];
          DebugLogger.info(
              '   First episode fields: ${firstEpisode.keys.toList()}');
          DebugLogger.info(
              '   Episode is_challenge: ${firstEpisode['is_challenge']}');
        }
      }

      setState(() {
        _mySeasons = seasons;
        _filteredSeasons = seasons;
        _isLoading = false;
      });
    } catch (e) {
      DebugLogger.error('Error loading seasons: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _mapChallengesToSeasons(List<dynamic> seasons) {
    _seasonToChallengeMap.clear();

    // Get Seasons platform challenges
    final seasonsChallenges =
        _challenges.where((c) => c['platform'] == 'Seasons').toList();

    for (var season in seasons) {
      // Check if season ID is in local storage (from creation)
      if (_challengeSeasonIds.contains(season['id'])) {
        // Try to find matching challenge by heading_id
        final headingsList = season['headings'];
        int? headingId;

        if (headingsList != null &&
            headingsList is List &&
            headingsList.isNotEmpty) {
          // Handle different structures: List<Map> or List<int>
          final firstHeading = headingsList[0];
          if (firstHeading is Map) {
            headingId = firstHeading['id'];
          } else if (firstHeading is int) {
            headingId = firstHeading;
          }
        }

        for (var challenge in seasonsChallenges) {
          if (challenge['heading_id'] == headingId) {
            _seasonToChallengeMap[season['id']] = challenge;
            // Update season data with challenge info
            season['is_challenge'] = true;
            season['challenge_id'] = challenge['id'];
            season['challenge_title'] = challenge['title'];
            season['challenge_points'] = challenge['points_required'];
            season['challenge_lives'] = challenge['lives'];
            season['no_of_mcq'] = challenge['no_of_mcq'];
            DebugLogger.info(
                '✅ Mapped season "${season['title']}" to challenge "${challenge['title']}"');
            break;
          }
        }
      }
    }

    // Save updated challenge season IDs
    _saveChallengeSeasonIds();
  }

  Future<void> _saveChallengeSeasonIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _challengeSeasonIds.map((id) => id.toString()).toList();
      await prefs.setStringList('challenge_season_ids', ids);
    } catch (e) {
      DebugLogger.error('Error saving challenge season IDs: $e');
    }
  }

  void _filterSeasons(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSeasons = _mySeasons;
      } else {
        _filteredSeasons = _mySeasons.where((season) {
          final title = (season['title'] ?? '').toString().toLowerCase();
          final description =
              (season['description'] ?? '').toString().toLowerCase();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your Stories',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: _loadSeasons,
          ),
        ],
      ),
      body: _buildBody(isDark),
      floatingActionButton: _mySeasons.isEmpty
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
                  Navigator.of(context)
                      .pushNamed(CreateSeasonScreen.routeName)
                      .then((_) => _loadSeasons());
                },
                icon: Icon(Icons.add_circle_outline),
                label: Text(
                  'New Season',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
            ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: ListSkeleton(itemCount: 4),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            SizedBox(height: 16),
            Text(
              'Failed to load seasons',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSeasons,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_mySeasons.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return _buildSeasonsList(isDark);
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
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
                Icons.video_library_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Seasons Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Start creating your first season to organize your video episodes and engage your audience with interactive quizzes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
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
                  Navigator.of(context)
                      .pushNamed(CreateSeasonScreen.routeName)
                      .then((_) => _loadSeasons());
                },
                icon: Icon(Icons.add_circle_outline, size: 24),
                label: Text('Create Your First Season'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 18),
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
    );
  }

  Widget _buildSeasonsList(bool isDark) {
    // Calculate statistics
    final totalEpisodes = _mySeasons.fold<int>(
      0,
      (sum, season) =>
          sum +
          ((season['episodes_count'] ?? season['episodes']?.length ?? 0)
              as int),
    );

    return CustomScrollView(
      slivers: [
        // Header and Statistics
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Creator\'s Studio',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage your content',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Statistics Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.video_library,
                      label: 'Seasons',
                      value: '${_mySeasons.length}',
                      color: Color(0xFF667eea),
                      isDark: isDark,
                    ),
                    SizedBox(width: 12),
                    _buildStatCard(
                      icon: Icons.movie_outlined,
                      label: 'Episodes',
                      value: '$totalEpisodes',
                      color: Color(0xFF4CAF50),
                      isDark: isDark,
                    ),
                    SizedBox(width: 12),
                    _buildStatCard(
                      icon: Icons.trending_up,
                      label: 'Active',
                      value:
                          '${_mySeasons.where((s) => !(s['is_locked'] == 1 || s['is_locked'] == true)).length}',
                      color: Color(0xFFFF9800),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              // Search Bar
              Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Color(0xFF1E1E1E) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Color(0xFF2E2E2E) : Colors.grey.shade200,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterSeasons,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search seasons...',
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
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _filterSeasons('');
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
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchQuery.isEmpty ? 'My Seasons' : 'Search Results',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      '${_filteredSeasons.length} ${_searchQuery.isEmpty ? 'total' : 'found'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: _filteredSeasons.isEmpty && _searchQuery.isNotEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No seasons found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final season = _filteredSeasons[index];
                      return _buildSeasonCard(season, isDark);
                    },
                    childCount: _filteredSeasons.length,
                  ),
                ),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildSeasonCard(dynamic season, bool isDark) {
    final title = season['title'] ?? 'Untitled Season';
    final description = season['description'] ?? '';
    final episodesCount =
        season['episodes_count'] ?? season['episodes']?.length ?? 0;
    // Handle thumbnail as string or nested object
    final imageUrl = season['thumbnail'] ??
        season['images']?[0]?['url'] ??
        season['image']?['url'];
    final isLocked = season['is_locked'] == 1 || season['is_locked'] == true;

    // Check if challenge: First from mapped challenge data, then API field, then local storage
    final challengeData = _seasonToChallengeMap[season['id']];
    bool isChallenge = challengeData != null ||
        season['is_challenge'] == 1 ||
        season['is_challenge'] == true;

    // Fallback 1: Check local storage (workaround for missing API field)
    if (!isChallenge && season['id'] != null) {
      isChallenge = _challengeSeasonIds.contains(season['id']);
    }

    // Fallback 2: Check if any episode has is_challenge flag
    if (!isChallenge && season['episodes'] != null) {
      final episodes = season['episodes'] as List;
      if (episodes.isNotEmpty) {
        isChallenge = episodes
            .any((ep) => ep['is_challenge'] == 1 || ep['is_challenge'] == true);
      }
    }

    // Get challenge title if available
    final challengeTitle = challengeData?['title'];

    final publishDate = season['publish_date'];

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
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            // Pass challenge info if in challenge mode
            Navigator.of(context).pushNamed(
              ViewEpisodesScreen.routeName,
              arguments: {
                'seasonId': season['id'],
                'seasonTitle': title,
                if (isChallenge) ...{
                  'is_challenge': true,
                  'challenge_id':
                      challengeData?['id'] ?? season['challenge_id'],
                  'challenge': challengeData ?? season['challenge'],
                }
              },
            );
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showSeasonOptions(season, isDark,
                challengeData: challengeData, isChallenge: isChallenge);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Header with Gradient Overlay
                Stack(
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF667eea),
                            Color(0xFF764ba2),
                          ],
                        ),
                      ),
                      child: imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                              child: Image.network(
                                imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                  child: Icon(
                                    Icons.video_library_rounded,
                                    size: 64,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.video_library_rounded,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                    ),
                    // Gradient Overlay
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
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                    // Challenge Badge
                    if (isChallenge)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFF6B6B),
                                Color(0xFFEE5A6F),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                challengeTitle != null
                                    ? 'Challenge: $challengeTitle'
                                    : 'Challenge',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Lock Badge
                    if (isLocked)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Locked',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Episodes Count Badge
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.movie_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '$episodesCount ${episodesCount == 1 ? 'Episode' : 'Episodes'}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // challenge title
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Content Section
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
                      // Debug indicator for challenge mode
                      if (isChallenge)
                        Container(
                          margin: EdgeInsets.only(top: 8),
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFFFF6B6B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color(0xFFFF6B6B),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                size: 14,
                                color: Color(0xFFFF6B6B),
                              ),
                              SizedBox(width: 4),
                              Text(
                                challengeTitle != null
                                    ? challengeTitle
                                    : 'Challenge Mode',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF6B6B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (description.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 12),
                      Row(
                        children: [
                          if (publishDate != null) ...[
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                            SizedBox(width: 4),
                            Text(
                              publishDate,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                            ),
                          ],
                          Spacer(),
                          // Quick action buttons
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pushNamed(
                                CreateSeasonScreen.routeName,
                                arguments: {
                                  'mode': 'edit',
                                  'season': season,
                                },
                              ).then((_) => _loadSeasons());
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showSeasonOptions(season, isDark);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.more_vert,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black54,
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
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: 140,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showSeasonOptions(dynamic season, bool isDark,
      {dynamic challengeData, bool isChallenge = false}) {
    final title = season['title'] ?? 'Untitled Season';
    final id = season['id'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.add_circle_outline,
              title: 'Add Episode',
              subtitle: 'Create a new episode for this season',
              color: Color(0xFF667eea),
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(
                  CreateEpisodeScreen.routeName,
                  arguments: {
                    'seasonId': id,
                    'seasonTitle': title,
                    if (isChallenge) ...{
                      'is_challenge': true,
                      'challenge_id':
                          challengeData?['id'] ?? season['challenge_id'],
                      'challenge': challengeData ?? season['challenge'],
                    }
                  },
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.list_alt,
              title: 'View Episodes',
              subtitle: 'See all episodes in this season',
              color: Color(0xFF4CAF50),
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(
                  ViewEpisodesScreen.routeName,
                  arguments: {
                    'seasonId': id,
                    'seasonTitle': title,
                    if (isChallenge) ...{
                      'is_challenge': true,
                      'challenge_id':
                          challengeData?['id'] ?? season['challenge_id'],
                      'challenge': challengeData ?? season['challenge'],
                    }
                  },
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.edit,
              title: 'Edit Season',
              subtitle: 'Modify season details',
              color: Color(0xFFFF9800),
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed(
                  CreateSeasonScreen.routeName,
                  arguments: {
                    'mode': 'edit',
                    'season': season,
                    if (isChallenge) ...{
                      'is_challenge': true,
                      'challenge_id':
                          challengeData?['id'] ?? season['challenge_id'],
                      'challenge': challengeData ?? season['challenge'],
                    }
                  },
                ).then((_) => _loadSeasons());
              },
            ),
            _buildOptionTile(
              icon: Icons.delete_outline,
              title: 'Delete Season',
              subtitle: 'Remove this season permanently',
              color: Colors.red,
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(season, isDark);
              },
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: isDark ? Colors.white30 : Colors.black26,
      ),
      onTap: onTap,
    );
  }

  Future<void> _deleteSeason(dynamic season) async {
    final seasonId = season['id'];
    final title = season['title'] ?? 'Untitled Season';

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      final storyCreation = Provider.of<StoryCreation>(context, listen: false);
      await storyCreation.deleteSeason(seasonId);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Season "$title" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload seasons list
        _loadSeasons();
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete season: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDelete(dynamic season, bool isDark) {
    final title = season['title'] ?? 'Untitled Season';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Color(0xFF1A1A1A) : Colors.white,
        title: Text(
          'Delete Season?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This will also delete all episodes and questions in this season. This action cannot be undone.',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSeason(season);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
