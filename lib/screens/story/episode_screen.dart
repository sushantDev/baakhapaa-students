import 'package:baakhapaa/screens/challenges/challenge_detail_screen.dart';
import 'package:baakhapaa/screens/story/creator_story_screen.dart';
import 'package:baakhapaa/widgets/skeleton_loading.dart';
import 'package:baakhapaa/widgets/rating_sheet.dart';
import 'package:baakhapaa/widgets/rating_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';

import './video_screen.dart';
import './readable_episode_screen.dart';
import './search_screen.dart';
import '../subscription/subscription_screen.dart';
import '../../providers/story.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../providers/auth.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import '../../widgets/header.dart';
import '../../widgets/share_with_qr_modal.dart';
import '../../theme/theme_constants.dart';
import '../../utils/guest_auth_helper.dart';
import '../../utils/season_unlock_helper.dart';
import 'package:http/http.dart' as http;
import '../../services/subscription_service.dart';
import '../../services/ad_service.dart';
import '../../models/subscription.dart';
import '../../models/url.dart';

//**
// Bugs Fixes:
// 1. Season Unlocked but authentication failed app need to be reload to see the unlocked season
// 2. User can play and by pass question but there is issue with the timer
// 3. Add life is possible but error appears after adding life multiple life at once
// 3.1. Timer speed is increased after bypass question
// 4. Level is updated but not visible in the app
// 5. Achievement is unlocked but doesnot shoe as claimed in Your Achievements
// */
class EpisodeScreen extends StatefulWidget {
  static const routeName = '/episode-screen';

  const EpisodeScreen({Key? key}) : super(key: key);

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen>
    with PuppetInteractionMixin {
  List<dynamic> _episodes = [];
  Map<String, dynamic>? _detailedSeasonData;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isInit = true;

  // Getter to access episodes from child widgets
  List<dynamic> get episodes => _episodes;

  // Cache constants for preventing duplicate API calls on navigation
  static const String _cacheKeyEpisodes = 'episode_cache_episodes';
  static const String _cacheKeySeasonDetails = 'episode_cache_season_details';
  static const String _cacheKeyEpisodesTimestamp = 'episode_cache_episodes_ts';
  static const Duration _cacheExpiration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();

    // Fetch creators to ensure we have images for the storyteller
    Provider.of<Auth>(context, listen: false)
        .fetchAllCreators()
        .catchError((e) {
      DebugLogger.error('Failed to pre-fetch creators: $e');
    });

    // Initialize puppet provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<PuppetInteractionProvider>().initState();
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }
    });
    _fetchSeasonDetails();
  }

  Future<void> _refreshSeasonWithId(int seasonId, String seasonTitle) async {
    try {
      DebugLogger.api(
          '🎬 Episode Screen: Refreshing season with ID: $seasonId');

      // Fetch detailed season information directly with the provided ID
      final seasonDetails = await Provider.of<Story>(context, listen: false)
          .fetchSeasonDetails(seasonId);

      DebugLogger.api(
          '🎬 Episode Screen: Season details received: ${seasonDetails != null ? 'Success' : 'Null'}');

      if (seasonDetails != null) {
        DebugLogger.api(
            '🎬 Episode Screen: Season unlock status: ${seasonDetails['is_locked']} / watched: ${seasonDetails['watched']}');

        // Create updated season data with unlocked status
        final updatedSeasonData = Map<String, dynamic>.from(seasonDetails);
        updatedSeasonData['id'] = seasonId;
        updatedSeasonData['title'] = seasonTitle;

        // ✅ Preserve thumbnail if not in response
        if (updatedSeasonData['thumbnail'] == null) {
          final currentSeason =
              Provider.of<Story>(context, listen: false).selectedSeason;
          updatedSeasonData['thumbnail'] = currentSeason['thumbnail'];
        }

        // Set this as the selected season for the story provider
        try {
          final storyProvider = Provider.of<Story>(context, listen: false);
          await storyProvider.setSelectedSeason(updatedSeasonData);
          DebugLogger.api(
              '🎬 Episode Screen: Updated selectedSeason with refreshed data');
        } catch (providerError) {
          DebugLogger.api(
              '🎬 Episode Screen: Provider error during setSelectedSeason: $providerError');
        }
      }

      if (mounted && seasonDetails != null) {
        DebugLogger.api(
            '🎬 Episode Screen: Updating state with refreshed season details');
        setState(() {
          _detailedSeasonData = seasonDetails;

          // Extract episodes from the fetched data
          if (seasonDetails['episodes'] != null) {
            _episodes = seasonDetails['episodes'];
            DebugLogger.api(
                '🎬 Episodes found in refreshed season details: ${_episodes.length}');
          }

          _isLoading = false;
        });
      } else if (mounted) {
        DebugLogger.api(
            '🎬 Episode Screen: No season details in refresh, setting error');
        setState(() {
          _errorMessage = 'Failed to refresh season details after unlock';
          _isLoading = false;
        });
      }
    } catch (e) {
      DebugLogger.api('🎬 Episode Screen: Error refreshing season with ID: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to refresh season details: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _isInit = false;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkAndRestoreEpisodeCache();
    });
  }

  Future<bool> _isCacheStaleOrMissing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedEpisodes = prefs.getString(_cacheKeyEpisodes);
      final timestampMs = prefs.getInt(_cacheKeyEpisodesTimestamp) ?? 0;

      if (cachedEpisodes == null || timestampMs == 0) {
        DebugLogger.api('🎬 Episode Screen: Cache missing or empty');
        return true;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      final isExpired = DateTime.now().difference(cacheTime) > _cacheExpiration;
      if (isExpired) {
        DebugLogger.api('🎬 Episode Screen: Cache is expired');
      }
      return isExpired;
    } catch (e) {
      DebugLogger.api('🎬 Episode Screen: Cache validation failed: $e');
      return true;
    }
  }

  Future<void> _cacheSeasonDataToPrefs(
      Map<String, dynamic> seasonDetails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final episodesJson = json.encode(seasonDetails['episodes'] ?? []);
      final seasonDetailsJson = json.encode(seasonDetails);
      await prefs.setString(_cacheKeyEpisodes, episodesJson);
      await prefs.setString(_cacheKeySeasonDetails, seasonDetailsJson);
      await prefs.setInt(
        _cacheKeyEpisodesTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
      DebugLogger.api('🎬 Episode Screen: Saved season data to cache');
    } catch (e) {
      DebugLogger.api('🎬 Episode Screen: Failed to cache season data: $e');
    }
  }

  Future<void> _checkAndRestoreEpisodeCache() async {
    if (await _isCacheStaleOrMissing()) {
      DebugLogger.api(
          '🎬 Episode Screen: Cache stale or missing, refreshing data');
      await _fetchSeasonDetails();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedSeasonDetails = prefs.getString(_cacheKeySeasonDetails);
      if (cachedSeasonDetails == null) {
        DebugLogger.api('🎬 Episode Screen: Cached season details missing');
        await _fetchSeasonDetails();
        return;
      }

      final seasonDetails =
          json.decode(cachedSeasonDetails) as Map<String, dynamic>;
      final cachedEpisodes = seasonDetails['episodes'] as List<dynamic>? ?? [];

      setState(() {
        _detailedSeasonData = seasonDetails;
        _episodes = cachedEpisodes;
        _isLoading = false;
      });

      final storyProvider = Provider.of<Story>(context, listen: false);
      final currentSeason =
          Map<String, dynamic>.from(storyProvider.selectedSeason);
      currentSeason['episodes'] = _episodes;
      storyProvider.setSelectedSeason(currentSeason);

      DebugLogger.api(
          '🎬 Episode Screen: Restored ${_episodes.length} episodes from cache');
    } catch (e) {
      DebugLogger.api('🎬 Episode Screen: Failed to restore cache: $e');
      await _fetchSeasonDetails();
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetchSeasonDetails() async {
    try {
      DebugLogger.api('🎬 Episode Screen: Starting _fetchSeasonDetails');

      final storyProvider = Provider.of<Story>(context, listen: false);
      final story = storyProvider.selectedSeason;

      // Check if selectedSeason exists
      if (story.isEmpty) {
        DebugLogger.api('🎬 Episode Screen: No selected season available');
        if (mounted) {
          setState(() {
            _errorMessage = 'No season selected';
            _isLoading = false;
          });
        }
        return;
      }

      final seasonId = story['id'];

      // Ensure seasonId is valid
      if (seasonId == null) {
        DebugLogger.api('🎬 Episode Screen: Season ID is null');
        if (mounted) {
          setState(() {
            _errorMessage = 'Invalid season ID';
            _isLoading = false;
          });
        }
        return;
      }

      final int validSeasonId =
          seasonId is int ? seasonId : int.tryParse(seasonId.toString()) ?? 0;
      if (validSeasonId <= 0) {
        DebugLogger.api('🎬 Episode Screen: Invalid season ID: $seasonId');
        if (mounted) {
          setState(() {
            _errorMessage = 'Invalid season ID format';
            _isLoading = false;
          });
        }
        return;
      }

      DebugLogger.api(
          '🎬 Episode Screen: Fetching season details for ID: $validSeasonId');

      // Fetch detailed season information
      final seasonDetails = await Provider.of<Story>(context, listen: false)
          .fetchSeasonDetails(validSeasonId);

      DebugLogger.api(
          '🎬 Episode Screen: Season details received: ${seasonDetails != null ? 'Success' : 'Null'}');

      if (seasonDetails != null) {
        DebugLogger.api(
            '🎬 Episode Screen: Season unlock status: ${seasonDetails['is_locked']} / watched: ${seasonDetails['watched']}');
      }

      if (mounted && seasonDetails != null) {
        DebugLogger.api(
            '🎬 Episode Screen: Updating state with season details');

        // Inject creator_id if this is a creator season
        final creatorId = story['creatorId'] ?? story['creator_id'];
        if (creatorId != null) {
          seasonDetails['creator_id'] = creatorId;
          DebugLogger.api(
              '👤 Injected creator_id into seasonDetails: $creatorId');
        }

        setState(() {
          _detailedSeasonData = seasonDetails;

          // ✅ CRITICAL FIX: Extract episodes from the fetched data
          if (seasonDetails['episodes'] != null) {
            _episodes = seasonDetails['episodes'];
            DebugLogger.api(
                '🎬 Episodes found in season details: ${_episodes.length}');

            // Update selectedSeason to include episodes for video screen compatibility
            final currentSeason =
                Map<String, dynamic>.from(storyProvider.selectedSeason);
            currentSeason['episodes'] = _episodes;

            // ✅ Preserve critical fields from API response
            currentSeason['is_locked'] = seasonDetails['is_locked'];
            currentSeason['watched'] = seasonDetails['watched'];
            currentSeason['content_type'] =
                seasonDetails['content_type'] ?? story['content_type'];
            currentSeason['book_title'] = seasonDetails['book_title'];
            currentSeason['book_author'] = seasonDetails['book_author'];
            currentSeason['nepali_description'] =
                seasonDetails['nepali_description'];

            // ✅ Preserve thumbnail and title from either source
            currentSeason['thumbnail'] =
                seasonDetails['thumbnail'] ?? story['thumbnail'];
            currentSeason['title'] = seasonDetails['title'] ?? story['title'];

            // ✅ CRITICAL: Include my_list field to prevent double-click issue
            if (seasonDetails.containsKey('my_list')) {
              currentSeason['my_list'] = seasonDetails['my_list'];
              DebugLogger.api(
                  '📋 Episode Screen: Updated selectedSeason my_list to: ${seasonDetails['my_list']}');
            }

            storyProvider.setSelectedSeason(currentSeason);

            DebugLogger.api(
                '🎬 Episode Screen: Updated selectedSeason with fresh API data');
          }

          _isLoading = false;
        });

        await _cacheSeasonDataToPrefs(seasonDetails);

        // ✅ Debug logging to verify data
        DebugLogger.api('🎬 Description: ${seasonDetails['description']}');
        DebugLogger.api('🎬 Cast: ${seasonDetails['cast']}');
        DebugLogger.api('🎬 Director: ${seasonDetails['director']}');
        DebugLogger.api('🎬 Genres: ${seasonDetails['genres']}');
      } else if (mounted) {
        DebugLogger.api(
            '🎬 Episode Screen: No season details, falling back to episodes only');
        // Fallback to original method if API doesn't exist yet
        await _fetchEpisodesOnly();
      }
    } catch (e) {
      DebugLogger.api('🎬 Episode Screen: Error fetching season details: $e');
      if (mounted) {
        DebugLogger.api('🎬 Episode Screen: Setting error state');
        setState(() {
          _errorMessage = 'Failed to load season details: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchEpisodesOnly() async {
    try {
      final storyProvider = Provider.of<Story>(context, listen: false);
      final story = storyProvider.selectedSeason;

      // Check if selectedSeason exists
      if (story.isEmpty) {
        DebugLogger.api(
            '🎬 Episode Screen: No selected season available in fallback');
        if (mounted) {
          setState(() {
            _errorMessage = 'No season selected';
            _isLoading = false;
          });
        }
        return;
      }

      final seasonId = story['id'];
      final isCreatorSeason = story['isCreatorSeason'] ?? false;
      final creatorId = story['creatorId'];

      // Ensure seasonId is valid
      if (seasonId == null) {
        DebugLogger.api('🎬 Episode Screen: Season ID is null in fallback');
        setState(() {
          _errorMessage = 'Invalid season ID';
          _isLoading = false;
        });
        return;
      }

      final int validSeasonId =
          seasonId is int ? seasonId : int.tryParse(seasonId.toString()) ?? 0;
      if (validSeasonId <= 0) {
        DebugLogger.api(
            '🎬 Episode Screen: Invalid season ID in fallback: $seasonId');
        setState(() {
          _errorMessage = 'Invalid season ID format';
          _isLoading = false;
        });
        return;
      }

      DebugLogger.api(
          '🎬 Episode Screen: Fetching episodes for season ID: $validSeasonId');

      // Fetch episodes for the season
      if (isCreatorSeason && creatorId != null) {
        final int validCreatorId = creatorId is int
            ? creatorId
            : int.tryParse(creatorId.toString()) ?? 0;
        if (validCreatorId <= 0) {
          throw 'Invalid creator ID';
        }
        // Get Map instead of List
        final Map<String, dynamic> data = await storyProvider
            .fetchCreatorSeasonEpisodes(validCreatorId, validSeasonId);

        if (mounted) {
          setState(() {
            _episodes = data['episodes'] ?? [];
            // Inject creator_id into detailedSeasonData if it exists
            if (_detailedSeasonData != null) {
              _detailedSeasonData!['creator_id'] = data['user_id'];
              DebugLogger.api(
                  '👤 Injected creator_id into detailedSeasonData: ${data["user_id"]}');
            }
            _isLoading = false;
          });

          await _cacheSeasonDataToPrefs({
            'episodes': _episodes,
            'creator_id': data['user_id'],
          });

          DebugLogger.api(
              '🎬 Episode Screen: Episodes loaded successfully (${_episodes.length} episodes)');
          DebugLogger.api('👤 Creator user_id: ${data["user_id"]}');
        }
      } else {
        final List<dynamic> episodes =
            await storyProvider.fetchSeasonEpisodes(validSeasonId);
        if (mounted) {
          setState(() {
            _episodes = episodes;
            _isLoading = false;
          });
          await _cacheSeasonDataToPrefs({
            'episodes': _episodes,
          });
        }
      }
    } catch (e) {
      DebugLogger.api('🎬 Episode Screen: Error fetching episodes: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load episodes: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = Provider.of<Story>(context, listen: false).selectedSeason;
    final title = story['title'] ?? 'Episodes';

    return Scaffold(
      appBar: header(
        context: context,
        titleText: title,
        // showBackButton: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const EpisodeDetailSkeleton()
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrailerSection(),
                    const SizedBox(height: 8),
                    LockSection(),
                    const SizedBox(height: 12),
                    SeasonDetails(detailedSeasonData: _detailedSeasonData),
                    const SizedBox(height: 12),
                    Consumer<Story>(
                      builder: (context, storyProvider, child) {
                        // Get fresh episode data from the provider instead of local state
                        final season = storyProvider.selectedSeason;
                        final providerEpisodes =
                            season.containsKey('episodes') &&
                                    season['episodes'] is List
                                ? season['episodes'] as List<dynamic>
                                : [];

                        // Use provider episodes if available, otherwise fallback to local state
                        final episodesToUse = providerEpisodes.isNotEmpty
                            ? providerEpisodes
                            : _episodes;

                        return EpisodesSection(
                            episodes: episodesToUse,
                            isLoading: _isLoading,
                            errorMessage: _errorMessage,
                            seasonData: _detailedSeasonData);
                      },
                    ),
                    const SizedBox(height: 12),
                    const BaakhaBannerAd(),
                    const SizedBox(height: 12),
                    SuggestedSeasonsSection(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  // Method to show share modal
  Future<void> _showShareModal(BuildContext context) async {
    // Get season data for sharing
    final story = Provider.of<Story>(context, listen: false).selectedSeason;
    final seasonId = story['id'];
    final seasonTitle = story['title'] ?? 'Season';

    // Generate share text for season with deep link
    String bs64str1 = base64Url.encode(utf8.encode(json.encode(seasonId)));
    final shareText =
        'Check out "$seasonTitle" season on Baakhapaa! Watch amazing episodes and earn rewards. ${Url.deepLink('/season/$bs64str1')}';

    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return _buildShareModal(context, shareText);
      },
    );
  }

  // Share modal widget (same as video_screen implementation)
  Widget _buildShareModal(BuildContext context, String shareText) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Limit max height
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.purple.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.share_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Share Season',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Consumer<Auth>(
              builder: (ctx, auth, _) => FutureBuilder(
                future: auth.fetchConversations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const GridSkeleton(crossAxisCount: 4, itemCount: 4);
                  }
                  final conversations = auth.conversations;
                  return Container(
                    height: 160, // Reduced from 200 to prevent overflow
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: conversations.length,
                      itemBuilder: (ctx, index) {
                        final conversation = conversations[index];
                        final userImage = conversation['user_image'] ?? '';
                        final name = conversation['name'] ?? '';
                        final username = conversation['username'];

                        return GestureDetector(
                          onTap: () {
                            final authProvider =
                                Provider.of<Auth>(context, listen: false);
                            authProvider
                                .sendMessages(
                              conversation['conversation_id'],
                              shareText,
                              'text',
                              null,
                              null,
                            )
                                .then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Shared Successfully!')),
                              );
                              Navigator.pop(context);
                            }).catchError((error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Failed to share. Please try again.')),
                              );
                            });
                          },
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: userImage.isNotEmpty
                                    ? CachedNetworkImageProvider(userImage)
                                    : null,
                                child: userImage.isEmpty
                                    ? Text(name.isEmpty ? username[0] : name[0])
                                    : null,
                              ),
                              SizedBox(height: 4),
                              Text(
                                name.isEmpty ? username : name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.share,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              title: Text('Share to Other Apps'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: shareText,
                    subject: "Join Skill Sikka and earn points!",
                    sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
                  ),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.qr_code,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              title: Text('Share using QR'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => ShareWithQrModal(
                    data: shareText,
                    subject: "Join Skill Sikka and earn points!",
                  ),
                );
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Method to show unlock dialog with API integration
  void _showUnlockDialog(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);

    // If guest, show login dialog and stop
    if (auth.isGuest) {
      GuestAuthHelper.showGuestLoginDialog(context, 'unlock seasons');
      return;
    }

    DebugLogger.api('🎬 Unlock Dialog - Starting unlock dialog');

    final story = Provider.of<Story>(context, listen: false).selectedSeason;
    final seasonId = story['id'];
    final seasonTitle = story['title'] ?? 'Season';

    // Get detailed season data for accurate coin_to_unlock value
    final episodeState = context.findAncestorStateOfType<_EpisodeScreenState>();
    final detailedData = episodeState?._detailedSeasonData;
    final seasonData = detailedData ?? story;

    // Debug which data source we're using
    DebugLogger.api(
        '🎬 Unlock Dialog - Using ${detailedData != null ? 'detailed API data' : 'original story data'}');

    // Extract coin_to_unlock with proper type handling
    final dynamic coinValue = seasonData['coin_to_unlock'];
    final int coinToUnlock = coinValue is int
        ? coinValue
        : (coinValue is String
            ? int.tryParse(coinValue) ?? 0
            : (coinValue?.toInt() ?? 0));

    // Debug logging to track coin extraction
    DebugLogger.api(
        '🎬 Unlock Dialog - Raw coin value: $coinValue (${coinValue.runtimeType})');
    DebugLogger.api(
        '🎬 Unlock Dialog - Extracted coin to unlock: $coinToUnlock');
    DebugLogger.api(
        '🎬 Unlock Dialog - Season data keys: ${seasonData.keys.toList()}');

    // Ensure seasonId is valid
    if (seasonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid season ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final int validSeasonId =
        seasonId is int ? seasonId : int.tryParse(seasonId.toString()) ?? 0;
    if (validSeasonId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid season ID format'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate coin requirement
    if (coinToUnlock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This season does not require coins to unlock'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Local state for benefit status
        UserBenefitUsage? storyBenefit;
        bool isCheckingBenefit = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fetch benefit status once
            if (isCheckingBenefit && auth.isSubscribed) {
              final subService = SubscriptionService(context: context);
              subService.getUserBenefitStatus().then((response) {
                if (mounted) {
                  setDialogState(() {
                    if (response.success && response.items.isNotEmpty) {
                      try {
                        // Benefit type 2 is 'Unlock stories'
                        storyBenefit = response.items.first.benefits.firstWhere(
                          (b) => b.benefitType.id == 2,
                        );
                      } catch (_) {
                        storyBenefit = null;
                      }
                    }
                    isCheckingBenefit = false;
                  });
                }
              }).catchError((e) {
                if (mounted) {
                  setDialogState(() {
                    isCheckingBenefit = false;
                  });
                }
              });
            } else if (!auth.isSubscribed) {
              isCheckingBenefit = false;
            }

            return Consumer2<Auth, Story>(
              builder: (context, auth, storyProvider, child) {
                final userCoins = auth.userAvailableCoins;
                final canAfford = userCoins >= coinToUnlock;

                // Check if benefit can be used
                final bool hasBenefit = storyBenefit != null &&
                    storyBenefit!.canUse &&
                    (storyBenefit!.usage.availableCount > 0 ||
                        storyBenefit!.usage.isUnlimited);

                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text(
                    'Unlock "$seasonTitle"',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This season requires $coinToUnlock points to unlock.',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            FontAwesomeIcons.coins,
                            size: 16,
                            color: canAfford ? Colors.amber : Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Your available points: $userCoins',
                            style: TextStyle(
                              fontSize: 14,
                              color: canAfford ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (hasBenefit) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(FontAwesomeIcons.crown,
                                  color: Colors.green, size: 16),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  storyBenefit!.usage.isUnlimited
                                      ? 'You have unlimited season unlocks!'
                                      : 'Your remaining benefit for Unlock Story is ${storyBenefit!.usage.remaining}. Would you like to use 1 to unlock this season? Your remaining benefit will be ${storyBenefit!.usage.remaining - 1 > 0 ? storyBenefit!.usage.remaining - 1 : 0}.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (isCheckingBenefit) ...[
                        SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Checking subscription benefits...',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                      if (!canAfford && !hasBenefit && !isCheckingBenefit) ...[
                        SizedBox(height: 12),
                        Text(
                          'You need ${coinToUnlock - userCoins} more points to unlock this season.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    if (hasBenefit)
                      ElevatedButton(
                        onPressed: () async {
                          // Capture provider refs before async operations
                          final authProvider =
                              Provider.of<Auth>(context, listen: false);
                          final storyProviderInstance =
                              Provider.of<Story>(context, listen: false);
                          final benefitId = storyBenefit!.id;

                          try {
                            DebugLogger.api(
                                '🎬 Benefit Unlock - Starting unlock operation');

                            // Show loading on top of dialog (don't pop first!)
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            final subService = SubscriptionService(
                              context: context,
                              authToken: authProvider.token,
                            );

                            // 1. Mark as watched/unlocked in backend
                            final url = Url.baakhapaaApi(
                                '/season/$validSeasonId/watched');
                            final response = await http.get(
                              Uri.parse(url),
                              headers:
                                  Url.baakhapaaAuthHeaders(authProvider.token),
                            );

                            if (response.statusCode != 200) {
                              throw 'Failed to unlock season with benefit';
                            }

                            // 2. Update benefit usage (V2 API)
                            await subService.updateUserBenefitUsage(
                              userBenefitUsageId: benefitId,
                              seasonId: validSeasonId,
                            );

                            // 3. Refresh user data
                            await authProvider.getUser();

                            // 4. Update selected season lock status
                            try {
                              final updatedStory = Map<String, dynamic>.from(
                                  storyProviderInstance.selectedSeason);
                              updatedStory['is_locked'] = false;
                              updatedStory['watched'] = true;
                              await storyProviderInstance
                                  .setSelectedSeason(updatedStory);
                            } catch (providerError) {
                              DebugLogger.api(
                                  '🎬 Benefit Unlock - Provider update error: $providerError');
                            }

                            if (!mounted) return;

                            // Close loading dialog
                            try {
                              Navigator.of(context).pop();
                            } catch (_) {}

                            // Close unlock dialog
                            try {
                              Navigator.of(context).pop();
                            } catch (_) {}

                            // Refresh and show success
                            _refreshSeasonWithId(validSeasonId, seasonTitle);
                            _showSuccessSnackBar(
                                'Season unlocked using your subscription benefit!');
                          } catch (e) {
                            DebugLogger.api('🎬 Benefit Unlock - Error: $e');
                            if (mounted) {
                              // Close loading dialog if open
                              try {
                                Navigator.of(context).pop();
                              } catch (_) {}
                              _showErrorSnackBar('Failed to unlock: $e');
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Unlock with Benefit'),
                      ),
                    if (!canAfford && !hasBenefit && !isCheckingBenefit)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context)
                              .pushNamed(SubscriptionScreen.routeName);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Get More Points'),
                      ),
                    if (canAfford)
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            DebugLogger.api(
                                '🎬 Unlock Dialog - Starting unlock operation');

                            // Show loading state
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            // Get provider references
                            final authProvider =
                                Provider.of<Auth>(context, listen: false);
                            final storyProviderInstance =
                                Provider.of<Story>(context, listen: false);

                            DebugLogger.api(
                                '🎬 Unlock Dialog - Calling unlock API');

                            // Call unlock API with error handling
                            await storyProviderInstance.unlockSeason(
                              authProvider.userId,
                              validSeasonId,
                              seasonTitle,
                              coinToUnlock,
                            );

                            DebugLogger.api(
                                '🎬 Unlock Dialog - Unlock API completed successfully');

                            // Refresh user data to update coin balance
                            DebugLogger.api(
                                '🎬 Unlock Dialog - Refreshing user data');
                            await authProvider.getUser();

                            // Update the selectedSeason to reflect unlock status
                            DebugLogger.api(
                                '🎬 Unlock Dialog - Updating selected season');
                            try {
                              final updatedStory = Map<String, dynamic>.from(
                                  storyProviderInstance.selectedSeason);
                              updatedStory['is_locked'] = false;
                              updatedStory['watched'] = true;
                              await storyProviderInstance
                                  .setSelectedSeason(updatedStory);
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Selected season updated successfully');
                            } catch (providerError) {
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Provider disposed during selectedSeason update: $providerError');
                              // This is expected if user navigated away - the unlock was still successful
                            }

                            // Check if still mounted before UI operations
                            if (!mounted) {
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Widget unmounted during operation, but operation completed');
                              return;
                            }

                            // Close loading dialog
                            try {
                              Navigator.of(context).pop();
                            } catch (navError) {
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Error closing loading dialog: $navError');
                            }

                            // Close unlock dialog
                            try {
                              Navigator.of(context).pop();
                            } catch (navError) {
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Error closing unlock dialog: $navError');
                            }

                            // Show success message
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Season "$seasonTitle" unlocked successfully!'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            } catch (snackError) {
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Error showing success message: $snackError');
                            }

                            // Refresh the episode screen data in the background
                            DebugLogger.api(
                                '🎬 Unlock Dialog - Starting background refresh');
                            try {
                              setState(() {
                                _isLoading = true;
                              });

                              // Store season ID before potential provider disposal
                              final currentSeasonId = validSeasonId;
                              final currentSeasonTitle = seasonTitle;

                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Refreshing with Season ID: $currentSeasonId');

                              // Force refresh season details to get updated unlock status
                              await _refreshSeasonWithId(
                                  currentSeasonId, currentSeasonTitle);

                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Background refresh completed');
                            } catch (refreshError) {
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Error during background refresh: $refreshError');
                            }
                          } catch (error) {
                            // Enhanced error logging
                            DebugLogger.api(
                                '🎬 Unlock Dialog - Error occurred: $error');
                            DebugLogger.api(
                                '🎬 Unlock Dialog - Error type: ${error.runtimeType}');
                            DebugLogger.api(
                                '🎬 Unlock Dialog - Error stack: ${StackTrace.current}');

                            // Check if still mounted before showing error
                            if (!mounted) {
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Widget unmounted, skipping error display');
                              return;
                            }

                            // Close loading dialog if open
                            try {
                              Navigator.of(context).pop();
                            } catch (e) {
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Loading dialog already closed: $e');
                            }

                            // Show appropriate error message based on error type
                            String errorMessage = 'Failed to unlock season';

                            if (error.toString().contains('disposed')) {
                              errorMessage =
                                  'Season unlocked successfully! (Completed in background)';
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Unlock completed but provider disposed (user likely navigated away)');
                              // Don't show this as an error - it's actually success
                              return;
                            } else if (error.toString().contains('network') ||
                                error.toString().contains('connection')) {
                              errorMessage =
                                  'Network error - please check your connection';
                            } else if (error
                                .toString()
                                .contains('insufficient')) {
                              errorMessage =
                                  'Insufficient coins to unlock this season';
                            } else {
                              errorMessage =
                                  'Failed to unlock season: ${error.toString()}';
                            }

                            DebugLogger.info(
                                'Failed to unlock season: ${error.toString()}');

                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            } catch (snackError) {
                              DebugLogger.api(
                                  '🎬 Unlock Dialog - Error showing error message: $snackError');
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Unlock for $coinToUnlock points',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class TrailerSection extends StatelessWidget {
  const TrailerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final story = Provider.of<Story>(context).selectedSeason;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get trailer URL or fallback to thumbnail
    final String trailerUrl = story['trailer_url']?.toString() ?? '';
    final String thumbnailUrl = story['thumbnail']?.toString() ?? '';

    // Use trailer if available, otherwise use thumbnail
    final String imageUrl = trailerUrl.isNotEmpty ? trailerUrl : thumbnailUrl;

    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, top: 0, bottom: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          // height: 243,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242424) : Colors.white54,
            // gradient: LinearGradient(
            //   begin: Alignment.topLeft,
            //   end: Alignment.bottomRight,
            //   colors: [
            //     isDark ? const Color(0xFF2A2A2A) : Colors.white,
            //     isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            //   ],
            // ),
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.8),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.black12,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade300,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey.shade600,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Image not available',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Continue watching progress bar
                  Consumer<Story>(
                    builder: (context, storyProvider, child) {
                      // Get detailed season data for continue_watching percentage
                      final episodeState = context
                          .findAncestorStateOfType<_EpisodeScreenState>();
                      final detailedData = episodeState?._detailedSeasonData;
                      final seasonData =
                          detailedData ?? storyProvider.selectedSeason;
                      final double continueWatching =
                          (seasonData['continue_watching'] ?? 0.0).toDouble();

                      if (continueWatching > 0) {
                        return Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 20,
                            margin: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Stack(
                              children: [
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: continueWatching / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFFFE88C),
                                          Color(0xFFFFD700)
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    '${continueWatching.toInt()}%',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LockSection extends StatefulWidget {
  const LockSection({super.key});

  @override
  State<LockSection> createState() => _LockSectionState();
}

class _LockSectionState extends State<LockSection> {
  bool _isToggling = false;

  Future<void> _toggleMyList() async {
    final story = Provider.of<Story>(context, listen: false).selectedSeason;
    final int seasonId = story['id'] ?? 0;

    if (seasonId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid season'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isToggling = true;
    });

    try {
      final storyProvider = Provider.of<Story>(context, listen: false);

      // Debug: Log initial state using the same logic as UI
      final episodeState =
          context.findAncestorStateOfType<_EpisodeScreenState>();
      final detailedData = episodeState?._detailedSeasonData;
      final seasonData = detailedData ?? story;
      final initialState = seasonData.containsKey('my_list')
          ? seasonData['my_list'] == true
          : storyProvider.isSeasonInMyList(seasonId);
      DebugLogger.api(
          '📋 Episode Screen: Initial My List state for season $seasonId: $initialState');
      DebugLogger.api(
          '📋 Episode Screen: Expected action: ${initialState ? "REMOVE" : "ADD"}');

      final success = await storyProvider.toggleMyListItem(seasonId);

      if (success) {
        // Update the detailed season data's my_list field to reflect the change
        final episodeState =
            context.findAncestorStateOfType<_EpisodeScreenState>();
        if (episodeState != null && episodeState._detailedSeasonData != null) {
          final newMyListStatus = storyProvider.isSeasonInMyList(seasonId);
          episodeState._detailedSeasonData!['my_list'] = newMyListStatus;

          // Debug: Log state changes
          DebugLogger.api(
              '📋 Episode Screen: Updated detailed season data my_list to: $newMyListStatus');

          // Trigger both parent and local rebuild to reflect the change in UI
          episodeState.setState(() {});
        }

        // Rebuild this widget to reflect the new My List status
        if (mounted) setState(() {});

        final finalState = storyProvider.isSeasonInMyList(seasonId);

        // Debug: Log final state
        DebugLogger.api(
            '📋 Episode Screen: Final My List state for season $seasonId: $finalState');

        // Success message based on the action that was performed (initial -> final)
        final actionPerformed = initialState ? 'Removed from' : 'Added to';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$actionPerformed My List successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update My List. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
      }
    }
  }

  void _playEpisode() {
    final auth = Provider.of<Auth>(context, listen: false);

    // If guest, show login dialog and stop
    if (auth.isGuest) {
      GuestAuthHelper.showGuestLoginDialog(context, 'watch episodes');
      return;
    }

    // Get episodes from the parent EpisodeScreen state
    final episodeState = context.findAncestorStateOfType<_EpisodeScreenState>();
    final episodes = episodeState?._episodes ?? [];
    final detailedData = episodeState?._detailedSeasonData;
    final story = Provider.of<Story>(context, listen: false).selectedSeason;
    final seasonData = detailedData ?? story;

    if (episodes.isNotEmpty) {
      Map<String, dynamic>? episodeToPlay;

      // Determine content type
      final isReadableContent =
          (seasonData['content_type'] ?? story['content_type'] ?? 'video') ==
              'readable';

      // Check if there's a last_episode_watched field
      final lastEpisodeWatchedId = seasonData['last_episode_watched'];

      if (isReadableContent) {
        // For readable content: find the first episode without a green tick (not watched)
        try {
          episodeToPlay = episodes.firstWhere(
            (episode) => episode['watched'] != true,
          ) as Map<String, dynamic>?;
          DebugLogger.info(
              '📖 Readable: Navigating to first unread chapter: ${episodeToPlay?['id']}');
        } catch (e) {
          // All episodes watched — replay the last one
          episodeToPlay = episodes.last as Map<String, dynamic>?;
          DebugLogger.info('📖 Readable: All chapters read, replaying last');
        }
      } else if (lastEpisodeWatchedId != null) {
        // Video content: resume the same episode (partial watch)
        try {
          episodeToPlay = episodes.firstWhere(
            (episode) => episode['id'] == lastEpisodeWatchedId,
          ) as Map<String, dynamic>?;
          DebugLogger.info(
              '📺 Resuming episode with ID: $lastEpisodeWatchedId');
        } catch (e) {
          DebugLogger.warning(
              '📺 Last watched episode $lastEpisodeWatchedId not found, playing first episode');
          episodeToPlay = episodes[0];
        }
      } else {
        // No last watched episode, play the first one
        episodeToPlay = episodes[0];
        DebugLogger.info('📺 No last watched episode, playing first episode');
      }

      if (episodeToPlay != null) {
        // Update selectedSeason to include episodes for video screen navigation
        final story = Provider.of<Story>(context, listen: false);
        final currentSeason = Map<String, dynamic>.from(story.selectedSeason);
        currentSeason['episodes'] = episodes;

        // ✅ Ensure critical fields are preserved
        if (seasonData['thumbnail'] != null) {
          currentSeason['thumbnail'] = seasonData['thumbnail'];
        }
        if (seasonData['title'] != null) {
          currentSeason['title'] = seasonData['title'];
        }
        if (seasonData['content_type'] != null) {
          currentSeason['content_type'] = seasonData['content_type'];
        }

        story.setSelectedSeason(currentSeason).then((_) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushNamed(
                  isReadableContent
                      ? ReadableEpisodeScreen.routeName
                      : VideoScreen.routeName,
                  arguments: episodeToPlay,
                );
              }
            });
          }
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No episodes available to play'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showReportSeasonDialog(Map<String, dynamic> seasonData) async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      await GuestAuthHelper.showGuestLoginDialog(context, 'report this story');
      return;
    }

    final int? seasonId = seasonData['id'] is int
        ? seasonData['id'] as int
        : int.tryParse(seasonData['id']?.toString() ?? '');
    if (seasonId == null || seasonId <= 0) {
      _showSeasonActionSnackBar('Invalid story for reporting.', Colors.red);
      return;
    }

    String selectedReason = 'Inappropriate content';
    final reasons = [
      'Spam',
      'Harassment or bullying',
      'Hate speech',
      'Inappropriate content',
      'Misinformation',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.flag_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Report Story'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you reporting ${seasonData['title'] ?? 'this story'}?',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...reasons.map(
                (reason) => RadioListTile<String>(
                  dense: true,
                  title: Text(reason, style: const TextStyle(fontSize: 13)),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (value) =>
                      setDialogState(() => selectedReason = value!),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await auth.reportContent(
                    type: 'season',
                    targetId: seasonId,
                    reason: selectedReason,
                  );
                  if (mounted) {
                    _showSeasonActionSnackBar(
                      'Report submitted. Thank you.',
                      Colors.green,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    _showSeasonActionSnackBar(
                      e.toString().replaceFirst('Exception: ', ''),
                      Colors.red,
                    );
                  }
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBlockCreatorDialog(String username) async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      await GuestAuthHelper.showGuestLoginDialog(context, 'block this creator');
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            Text('Block @$username'),
          ],
        ),
        content: Text(
          'Blocking @$username will remove this creator\'s stories from your feed and prevent access to their profile.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await auth.blockUser(username);
                if (mounted) {
                  _showSeasonActionSnackBar(
                    '@$username has been blocked.',
                    Colors.green,
                  );
                  Navigator.of(context).maybePop();
                }
              } catch (e) {
                if (mounted) {
                  _showSeasonActionSnackBar(
                    e.toString().replaceFirst('Exception: ', ''),
                    Colors.red,
                  );
                }
              }
            },
            child: const Text('Block Creator'),
          ),
        ],
      ),
    );
  }

  void _showSeasonActionSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Use listen: false to prevent auto-refresh - only rebuild when state changes internally
    final storyProvider = Provider.of<Story>(context, listen: false);
    final story = storyProvider.selectedSeason;
    final bool isDefaultLocked = story['is_locked'] ?? false;
    final bool isWatched = story['watched'] ?? false;
    // Season is locked if it's default locked AND user hasn't watched it yet
    final bool isLocked = isDefaultLocked && !isWatched;
    final int seasonId = story['id'] ?? 0;

    // Get detailed season data to check for last watched episode
    final episodeState = context.findAncestorStateOfType<_EpisodeScreenState>();
    final detailedData = episodeState?._detailedSeasonData;
    final seasonData = detailedData ?? story;
    final lastEpisodeWatchedId = seasonData['last_episode_watched'];

    // Debug logging for last watched episode
    DebugLogger.info('🎬 Last episode watched ID: $lastEpisodeWatchedId');

    // Determine button text and icon based on whether there's a last watched episode
    final bool hasLastWatched = lastEpisodeWatchedId != null;
    final bool isReadableContent =
        (seasonData['content_type'] ?? story['content_type'] ?? 'video') ==
            'readable';
    final String buttonText = isReadableContent
        ? (hasLastWatched ? 'Continue' : 'Read')
        : (hasLastWatched ? 'Resume' : 'Play');
    final IconData buttonIcon = isReadableContent
        ? Icons.menu_book
        : (hasLastWatched ? Icons.play_circle_fill : Icons.play_arrow);

    // Check My List status from both API data and provider state
    // If detailed season data has my_list field, use it; otherwise use provider state
    final bool isInMyList = seasonData.containsKey('my_list')
        ? seasonData['my_list'] == true
        : storyProvider.isSeasonInMyList(seasonId);
    final creatorUsername = seasonData['username']?.toString().trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compactActions = constraints.maxWidth < 390;
        final double actionHeight = compactActions ? 50 : 52;
        final double actionGroupWidth = compactActions ? 106 : 148;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
          child: SizedBox(
            height: actionHeight,
            child: Row(
              children: [
                Expanded(
                  flex: compactActions ? 34 : 30,
                  child: SizedBox(
                    height: actionHeight,
                    child: ElevatedButton.icon(
                      onPressed: _isToggling ? null : _toggleMyList,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(0, actionHeight),
                        backgroundColor: isInMyList
                            ? Colors.green.withValues(alpha: 0.2)
                            : AppColors.pillBg(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: compactActions ? 8 : 10,
                          vertical: 10,
                        ),
                        elevation: 0,
                      ),
                      icon: _isToggling
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.textPrimary(context),
                                ),
                              ),
                            )
                          : Icon(
                              isInMyList ? Icons.check : Icons.add,
                              size: 18,
                              color: isInMyList
                                  ? Colors.green
                                  : AppColors.textPrimary(context),
                            ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isInMyList ? 'In My List' : 'My List',
                          style: AppTextStyles.interSemiBold(
                            color: isInMyList
                                ? Colors.green
                                : AppColors.textPrimary(context),
                            fontSize: compactActions ? 13 : 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: compactActions ? 38 : 42,
                  child: SizedBox(
                    height: actionHeight,
                    child: isLocked
                        ? Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color.fromARGB(255, 105, 1, 10),
                                  Color.fromARGB(255, 248, 2, 2)
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                final episodeState =
                                    context.findAncestorStateOfType<
                                        _EpisodeScreenState>();
                                if (episodeState != null) {
                                  episodeState._showUnlockDialog(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size.fromHeight(actionHeight),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: compactActions ? 18 : 26,
                                  vertical: 5,
                                ),
                                elevation: 0,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/svgs/lock.svg',
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                      width: 18,
                                      height: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      compactActions ? 'Unlock' : 'unlock now',
                                      style: GoogleFonts.poppins(
                                        fontSize: compactActions ? 15 : 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0,
                                        color: const Color(0xFFFFFFFF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment(1.0, 0.0),
                                end: Alignment(-1.0, 0.0),
                                colors: [
                                  Color(0xFF0DFF00),
                                  Color(0xFF0D9900),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: ElevatedButton(
                              onPressed: _playEpisode,
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size.fromHeight(actionHeight),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: compactActions ? 18 : 28,
                                  vertical: 5,
                                ),
                                elevation: 0,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      buttonIcon,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      buttonText,
                                      style: GoogleFonts.poppins(
                                        fontSize: compactActions ? 15 : 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0,
                                        color: const Color(0xFFFFFFFF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: actionGroupWidth,
                  height: actionHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.pillBg(context),
                      border: Border.all(color: AppColors.borderColor(context)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(20),
                              ),
                              onTap: () async {
                                final episodeState =
                                    context.findAncestorStateOfType<
                                        _EpisodeScreenState>();
                                if (episodeState != null) {
                                  await episodeState._showShareModal(context);
                                }
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compactActions ? 0 : 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.share,
                                      size: 18,
                                      color: AppColors.textPrimary(context),
                                    ),
                                    if (!compactActions) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        'Share',
                                        style: AppTextStyles.interSemiBold(
                                          color: AppColors.textPrimary(context),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 22,
                          color: AppColors.borderColor(context),
                        ),
                        SizedBox(
                          width: compactActions ? 44 : 46,
                          child: PopupMenuButton<String>(
                            tooltip: 'More actions',
                            padding: EdgeInsets.zero,
                            offset: const Offset(-10, 40),
                            icon: Icon(
                              Icons.more_vert,
                              size: 18,
                              color: AppColors.textPrimary(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onSelected: (value) {
                              if (value == 'report_story') {
                                _showReportSeasonDialog(seasonData);
                              } else if (value == 'block_creator' &&
                                  creatorUsername != null &&
                                  creatorUsername.isNotEmpty) {
                                _showBlockCreatorDialog(creatorUsername);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                value: 'report_story',
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_outlined,
                                        color: Colors.orange),
                                    SizedBox(width: 10),
                                    Text('Report Story'),
                                  ],
                                ),
                              ),
                              if (creatorUsername != null &&
                                  creatorUsername.isNotEmpty)
                                const PopupMenuItem<String>(
                                  value: 'block_creator',
                                  child: Row(
                                    children: [
                                      Icon(Icons.block, color: Colors.red),
                                      SizedBox(width: 10),
                                      Text('Block Creator'),
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class SeasonDetails extends StatefulWidget {
  final Map<String, dynamic>? detailedSeasonData;

  const SeasonDetails({super.key, this.detailedSeasonData});

  @override
  State<SeasonDetails> createState() => _SeasonDetailsState();
}

class _SeasonDetailsState extends State<SeasonDetails> {
  // Getter to extract creatorId from detailedSeasonData or fallback
  int? get creatorId {
    final season = widget.detailedSeasonData;
    if (season == null) return null;

    // Check various common keys for creator/user ID
    final dynamic rawId = season['creator_id'] ??
        season['user_id'] ??
        (season['creator'] is Map ? season['creator']['id'] : null);

    if (rawId != null) {
      return rawId is int ? rawId : int.tryParse(rawId.toString());
    }

    return null;
  }

  bool _isExpanded = false;

  // Helper method to navigate to search screen with query
  void _navigateToSearch(String query) {
    Navigator.of(context).pushNamed(
      SearchScreen.routeName,
      arguments: query,
    );
  }

  // Helper method to build clickable metadata spans
  Widget _buildDescriptionWithMetadata(
      String description,
      String director,
      List<dynamic> cast,
      List<dynamic> writers,
      List<dynamic> genres,
      Color textColor,
      {int? maxLines}) {
    List<InlineSpan> spans = [];

    // Render description as plain text (no link)
    spans.add(
      TextSpan(
        text: description,
        style: TextStyle(
          color: textColor,
          fontSize: 13.5,
          height: 1.4,
          decoration: TextDecoration.none,
        ),
      ),
    );

    // Add metadata if available
    if (director.isNotEmpty ||
        cast.isNotEmpty ||
        writers.isNotEmpty ||
        genres.isNotEmpty) {
      spans.add(TextSpan(text: '\n\n'));

      // Director
      if (director.isNotEmpty) {
        spans.add(TextSpan(
          text: 'Director: ',
          style: TextStyle(
            color: textColor,
            fontSize: 13.5,
            height: 1.4,
          ),
        ));
        spans.add(TextSpan(
          text: director,
          style: TextStyle(
            color: textColor,
            fontSize: 13.5,
            height: 1.4,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _navigateToSearch(director),
        ));
        spans.add(TextSpan(text: '\n'));
      }

      // Cast
      if (cast.isNotEmpty) {
        spans.add(TextSpan(
          text: 'Cast: ',
          style: TextStyle(
            color: textColor,
            fontSize: 13.5,
            height: 1.4,
          ),
        ));
        final castList = cast.take(3).toList();
        for (int i = 0; i < castList.length; i++) {
          spans.add(TextSpan(
            text: castList[i].toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 13.5,
              height: 1.4,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _navigateToSearch(castList[i].toString()),
          ));
          if (i < castList.length - 1) {
            spans.add(TextSpan(text: ', '));
          }
        }
        if (cast.length > 3) {
          spans.add(TextSpan(text: ' and more'));
        }
        spans.add(TextSpan(text: '\n'));
      }

      // Writers
      if (writers.isNotEmpty) {
        spans.add(TextSpan(
          text: 'Writers: ',
          style: TextStyle(
            color: textColor,
            fontSize: 13.5,
            height: 1.4,
          ),
        ));
        final writersList = writers.take(2).toList();
        for (int i = 0; i < writersList.length; i++) {
          spans.add(TextSpan(
            text: writersList[i].toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 13.5,
              height: 1.4,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _navigateToSearch(writersList[i].toString()),
          ));
          if (i < writersList.length - 1) {
            spans.add(TextSpan(text: ', '));
          }
        }
        if (writers.length > 2) {
          spans.add(TextSpan(text: ' and more'));
        }
        spans.add(TextSpan(text: '\n'));
      }

      // Genres
      if (genres.isNotEmpty) {
        spans.add(TextSpan(
          text: 'Genres: ',
          style: TextStyle(
            color: textColor,
            fontSize: 13.5,
            height: 1.4,
          ),
        ));
        final genresList = genres.take(3).toList();
        for (int i = 0; i < genresList.length; i++) {
          spans.add(TextSpan(
            text: genresList[i].toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 13.5,
              height: 1.4,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _navigateToSearch(genresList[i].toString()),
          ));
          if (i < genresList.length - 1) {
            spans.add(TextSpan(text: ', '));
          }
        }
        if (genres.length > 3) {
          spans.add(TextSpan(text: ' and more'));
        }
      }
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _authProvider = Provider.of<Auth>(context, listen: false);
    final story = Provider.of<Story>(context).selectedSeason;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ CRITICAL FIX: Always prioritize detailed data
    final seasonData = widget.detailedSeasonData ?? story;

    // ✅ Add debug logging
    DebugLogger.api(
        '🎬 SeasonDetails Build - Has detailed data: ${widget.detailedSeasonData != null}');
    DebugLogger.api(
        '🎬 SeasonDetails - Description length: ${seasonData['description']?.toString().length ?? 0}');

    // Get dynamic data from the season
    final String description =
        seasonData['description']?.toString() ?? 'No description available.';
    final String maturityCode =
        'U/A: ${seasonData['maturity_code']?.toString()}';

    // ✅ Handle both List and dynamic types
    final List<dynamic> genres = seasonData['genres'] is List
        ? seasonData['genres'] as List<dynamic>
        : [];
    final List<dynamic> cast =
        seasonData['cast'] is List ? seasonData['cast'] as List<dynamic> : [];
    final List<dynamic> writers = seasonData['writers'] is List
        ? seasonData['writers'] as List<dynamic>
        : [];

    final String director = seasonData['director']?.toString() ?? '';
    final String createdAt =
        seasonData['created_at'] ?? seasonData['publish_date'] ?? '';

    // Debug logging
    DebugLogger.api(
        '🎬 SeasonDetails - Description: ${description.length > 50 ? description.substring(0, 50) + "..." : description}');
    DebugLogger.api('🎬 SeasonDetails - Cast count: ${cast.length}');
    DebugLogger.api('🎬 SeasonDetails - Genres count: ${genres.length}');

    // Format release date
    String releaseDate = 'Release date not available';
    if (createdAt.isNotEmpty) {
      try {
        final DateTime parsedDate = DateTime.parse(createdAt);
        final months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December'
        ];
        releaseDate =
            'Released at: ${months[parsedDate.month - 1]} ${parsedDate.day}, ${parsedDate.year}';
      } catch (e) {
        releaseDate = 'Released at: $createdAt';
      }
    }

    // Challenge info (if in challenge mode) - with safe extraction
    final dynamic rawChallengeId = seasonData['challenge_id'];
    final int? challengeId = rawChallengeId != null
        ? (rawChallengeId is int
            ? rawChallengeId
            : int.tryParse(rawChallengeId.toString()))
        : null;
    final String? challengeName = seasonData['challenge_title']?.toString();

    // Only show challenge info if both ID and name are valid
    final bool hasValidChallenge = challengeId != null &&
        challengeId > 0 &&
        challengeName != null &&
        challengeName.isNotEmpty;

    // Safely extract seasonId for rating widgets
    final dynamic rawSeasonId = seasonData['id'];
    final int? seasonId = rawSeasonId != null
        ? (rawSeasonId is int
            ? rawSeasonId
            : int.tryParse(rawSeasonId.toString()))
        : null;
    final String seasonTitle = seasonData['title']?.toString() ?? 'Untitled';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14, bottom: 0, left: 14, right: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF2A2A2A) : Colors.white,
            isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.8),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⭐ Rating + Chip + Reward
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rating + Age chip
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (seasonId != null)
                        InkWell(
                          onTap: () {
                            if (_authProvider.isGuest) {
                              GuestAuthHelper.showGuestLoginDialog(
                                  context, 'rating');
                              return;
                            }
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => RatingSheet(
                                ratingType: RatingType.season,
                                currentUserId: _authProvider.userId,
                                authToken: _authProvider.token,
                                ratingId: seasonId,
                                ratingTitle: seasonTitle,
                              ),
                            );
                          },
                          child: RatingSummery(
                              ratingId: seasonId,
                              authToken: _authProvider.token,
                              ratingTo: RatingTo.season,
                              starSize: 4),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.pillBg(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          maturityCode,
                          style: AppTextStyles.interMedium(
                              color: AppColors.textPrimary(context),
                              fontSize: 14),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  // Release Date
                  Text(
                    releaseDate,
                    style: AppTextStyles.inter(
                        color: AppColors.textSecondary(context), fontSize: 12),
                  ),
                  // Storyteller info (user_id and username)
                  // if (seasonData['user_id'] != null ||
                  //     (seasonData['username'] != null &&
                  //         seasonData['username'].toString().isNotEmpty)) ...[
                  //   const SizedBox(height: 4),
                  //   GestureDetector(
                  //     onTap: () {
                  //       final userId = seasonData['user_id'];
                  //       final username = seasonData['username'];
                  //       if (userId != null) {
                  //         Navigator.of(context).pushNamed(
                  //           CreatorStoryScreen.routeName,
                  //           arguments: [userId, username],
                  //         );
                  //       }
                  //     },
                  //     child: Text(
                  //       'Storyteller: ${seasonData['username'] ?? 'Unknown'}',
                  //       style: TextStyle(
                  //         color: AppColors.textPrimary(context),
                  //         fontSize: 13.5,
                  //         height: 1.4,
                  //         decoration: TextDecoration.underline,
                  //       ),
                  //     ),
                  //   ),
                  // ],

                  // // Challenge Info (always show if present, name is clickable)
                  // if ((challengeId != null &&
                  //         challengeId.toString().isNotEmpty) ||
                  //     (challengeName != null && challengeName.isNotEmpty)) ...[
                  //   const SizedBox(height: 4),
                  //   if (challengeId != null &&
                  //       challengeId.toString().isNotEmpty &&
                  //       challengeName != null &&
                  //       challengeName.isNotEmpty)
                  //     const SizedBox(width: 12),
                  //   if (challengeName != null && challengeName.isNotEmpty)
                  //     GestureDetector(
                  //       onTap: () {
                  //         Navigator.of(context).pushNamed(
                  //           ChallengeDetailScreen.routeName,
                  //           arguments: challengeId,
                  //         );
                  //       },
                  //       child: Text(
                  //         'Challenge Name: $challengeName',
                  //         style: const TextStyle(
                  //           color: Colors.white,
                  //           fontSize: 13.5,
                  //           height: 1.4,
                  //           decoration: TextDecoration.underline,
                  //         ),
                  //       ),
                  //     ),
                  // ],
                ],
              ),

              const Spacer(),

              // Reward badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color.fromARGB(255, 247, 216, 14),
                      Color.fromARGB(255, 255, 174, 0)
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Image(
                        image: AssetImage('assets/images/coins.png'),
                        width: 16,
                        height: 16),
                    const SizedBox(width: 5),
                    Text(
                      'Point Reward:\n${seasonData['total_reward_points'] ?? 0} Sikka',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Description with expand/collapse functionality (AnimatedSize)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _buildDescriptionWithMetadata(
              description,
              director,
              cast,
              writers,
              genres,
              AppColors.textPrimary(context),
              maxLines: _isExpanded ? null : 2,
            ),
          ),

          const SizedBox(height: 8),

          // Storyteller (always visible)
          if (seasonData['user_id'] != null &&
              seasonData['username'] != null &&
              seasonData['username'].toString().isNotEmpty)
            GestureDetector(
              onTap: () async {
                final auth = Provider.of<Auth>(context, listen: false);
                if (auth.isGuest) {
                  await GuestAuthHelper.showGuestLoginDialog(
                    context,
                    'view teachers profile',
                  );
                  return;
                }
                Navigator.of(context).pushNamed(
                  CreatorStoryScreen.routeName,
                  arguments: [seasonData['user_id'], seasonData['username']],
                );
              },
              child: Row(
                children: [
                  // User image with fallback and debug logging

                  Text(
                    'Teacher: ',
                    style: AppTextStyles.inter(
                      color: AppColors.textSecondary(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),

                  Builder(
                    builder: (context) {
                      final auth = Provider.of<Auth>(context);
                      final id = creatorId;

                      // Attempt to find creator in Auth.creators for the most updated thumbnail
                      final creator = auth.creators.firstWhere(
                        (c) => c['id'] == id,
                        orElse: () => null,
                      );

                      String? userImage;
                      if (creator != null &&
                          creator['images'] is List &&
                          (creator['images'] as List).isNotEmpty) {
                        final imgs = creator['images'] as List;
                        final imgData = imgs[0];
                        if (imgData is Map) {
                          // Try thumbnail first, then url
                          userImage = imgData['thumbnail'] ?? imgData['url'];
                        }
                      }

                      // Fallback to seasonData['user_image'] if not found in creators list
                      userImage ??= seasonData['user_image'];

                      const String fallbackImage =
                          "https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg";

                      DebugLogger.api('🖼️ EpisodeScreen: Creator image URL: '
                          '${userImage ?? "<null>"}');

                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.pillBg(context),
                        backgroundImage: CachedNetworkImageProvider(
                            userImage != null && userImage.isNotEmpty
                                ? userImage
                                : fallbackImage),
                        onBackgroundImageError: (exception, stackTrace) {
                          DebugLogger.warning(
                              'Failed to load creator image: $exception');
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 6),

                  Text(seasonData['username'],
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      )),
                ],
              ),
            ),

          // Challenge info (only visible if valid)
          if (hasValidChallenge) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                try {
                  Navigator.of(context).pushNamed(
                    ChallengeDetailScreen.routeName,
                    arguments: challengeId,
                  );
                } catch (e) {
                  DebugLogger.warning('Failed to navigate to challenge: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Unable to open challenge details'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  // Challenge image
                  if (seasonData['challenge_image_url'] != null &&
                      seasonData['challenge_image_url'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        seasonData['challenge_image_url'],
                        width: 20,
                        height: 20,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.emoji_events,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(width: 6),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Challenge: ',
                          style: AppTextStyles.inter(
                            color: AppColors.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                            text: '$challengeName',
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // See more/less button
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isExpanded ? 'see less' : 'see more',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(context),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UnlockRewardsTabs extends StatefulWidget {
  final Map<String, dynamic>? detailedSeasonData;

  const UnlockRewardsTabs({super.key, this.detailedSeasonData});

  @override
  State<UnlockRewardsTabs> createState() => _UnlockRewardsTabsState();
}

class _UnlockRewardsTabsState extends State<UnlockRewardsTabs> {
  // Colors / gradients used to match the screenshots
  static const LinearGradient _goldGradient = LinearGradient(
    colors: [
      Color.fromARGB(255, 145, 118, 52),
      Color.fromARGB(255, 238, 208, 131),
      Color.fromARGB(255, 226, 185, 83),
      Color.fromARGB(255, 207, 178, 108),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if season is unlocked to determine initial tab
    final story = Provider.of<Story>(context).selectedSeason;
    final bool isDefaultLocked = story['is_locked'] ?? false;
    final bool isWatched = story['watched'] ?? false;
    // Season is locked if it's default locked AND user hasn't watched it yet
    final bool isLocked = isDefaultLocked && !isWatched;
    final int initialIndex =
        isLocked ? 0 : 1; // 0 = Unlock tab, 1 = Rewards tab

    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? const Color(0xFF2A2A2A) : Colors.white,
              isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.8),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Top Tabs (pill)
            Container(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: Colors.transparent,
                  child: TabBar(
                    padding: EdgeInsets.only(left: 30, right: 30),
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: AppColors.actionButtonBg(context),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.textPrimary(context),
                    unselectedLabelColor: AppColors.textSecondary(context),
                    labelStyle: AppTextStyles.interExtraBold(fontSize: 16),
                    unselectedLabelStyle: AppTextStyles.interMedium(),
                    indicatorWeight: 4,
                    tabs: const [
                      Tab(
                        text: 'Unlock',
                        height: 36,
                      ),
                      Tab(text: 'Rewards', height: 36),
                    ],
                  ),
                ),
              ),
            ),

            Divider(
              color: Color(0x1FFFFFFF),
              thickness: 1,
              height: 1,
              indent: 12,
              endIndent: 12,
            ),
            const SizedBox(height: 12),

            // Tab Views
            SizedBox(
              height: 150,
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Unlock tab
                  _buildUnlockTab(),
                  // Rewards tab
                  _buildRewardsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockTab() {
    final story = Provider.of<Story>(context).selectedSeason;
    final episodeState = context.findAncestorStateOfType<_EpisodeScreenState>();
    final detailedData = episodeState?._detailedSeasonData;
    final seasonData = detailedData ?? story;
    final Map<String, dynamic> unlockDetails =
        seasonData['unlock_details'] ?? {};

    // Extract points required with proper type handling
    final dynamic coinValue = seasonData['coin_to_unlock'];
    final int pointsRequired = coinValue is int
        ? coinValue
        : (coinValue is String
            ? int.tryParse(coinValue) ?? 0
            : (coinValue?.toInt() ?? 0));

    // Debug logging for unlock tab
    DebugLogger.api(
        '🎬 UnlockTab - Raw coin value: $coinValue (${coinValue.runtimeType})');
    DebugLogger.api('🎬 UnlockTab - Points required: $pointsRequired');

    final List<dynamic> achievements = unlockDetails['achievements'] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Points required to unlock:',
            style: TextStyle(color: Color(0xFFB4B4B4)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (pointsRequired > 0)
                Container(
                  padding: const EdgeInsets.only(
                      left: 6, right: 6, top: 10, bottom: 10),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF990000),
                          Color(0xFFFF0000),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(28)),
                  child: Row(
                    children: [
                      Image(
                          image: AssetImage('assets/images/coins.png'),
                          width: 16,
                          height: 16),
                      SizedBox(width: 4),
                      Text(
                        '$pointsRequired',
                        style: AppTextStyles.interBold(
                            color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        ' points',
                        style: AppTextStyles.interSemiBold(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.only(
                      left: 6, right: 6, top: 10, bottom: 10),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0D9900),
                          Color(0xFF0DFF00),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(28)),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'FREE',
                        style: AppTextStyles.interBold(
                            color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (achievements.isNotEmpty) ...[
            const Text('Badges required to unlock:',
                style: TextStyle(color: Color(0xFFB4B4B4))),
            const SizedBox(height: 6),
            SizedBox(
              height: 65,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final achievement = achievements[index];
                  final String title =
                      achievement['title']?.toString() ?? 'Badge';
                  final String imageUrl = achievement['url']?.toString() ?? '';
                  final List<dynamic> progress = achievement['progress'] ?? [];
                  final double progressValue = progress.isNotEmpty ? 1.0 : 0.0;
                  final bool isEarned = progress.isNotEmpty;

                  return GestureDetector(
                    onTap: () {
                      _showAchievementModal(context, achievement);
                    },
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 92,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: isEarned
                                    ? _goldGradient
                                    : LinearGradient(
                                        colors: [
                                          Colors.grey.shade600,
                                          Colors.grey.shade800
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isEarned
                                    ? [
                                        BoxShadow(
                                          color: Colors.amber
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                                image: imageUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(imageUrl),
                                        fit: BoxFit.cover,
                                        colorFilter: isEarned
                                            ? null
                                            : ColorFilter.mode(
                                                Colors.grey
                                                    .withValues(alpha: 0.6),
                                                BlendMode.saturation,
                                              ),
                                      )
                                    : null,
                              ),
                              child: imageUrl.isEmpty
                                  ? Center(
                                      child: Text(
                                        title.length > 10
                                            ? title.substring(0, 10)
                                            : title,
                                        style: TextStyle(
                                          color: isEarned
                                              ? Colors.black
                                                  .withValues(alpha: 0.8)
                                              : Colors.white
                                                  .withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : null,
                            ),
                            // Achievement status indicator
                            if (isEarned)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 92,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progressValue,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isEarned
                                    ? const Color(0xFFCFB26C)
                                    : Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          Builder(
            builder: (context) {
              // Collect all products from all achievements
              List<dynamic> allProducts = [];
              for (var achievement in achievements) {
                if (achievement['products'] != null) {
                  allProducts.addAll(achievement['products']);
                }
              }

              if (allProducts.isNotEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    const Text('Products required to unlock:',
                        style: TextStyle(color: Color(0xFFB4B4B4))),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 55,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: allProducts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final product = allProducts[index];
                          final String imageUrl =
                              'https://student.baakhapaa.com/storage/' +
                                  product['image_url'];
                          final int productId = product['id'] ?? 0;
                          final bool isPurchased =
                              product['product_purchased'] ?? false;

                          return GestureDetector(
                            onTap: () {
                              if (productId > 0) {
                                Navigator.of(context).pushNamed(
                                  '/single-product-screen',
                                  arguments: productId,
                                );
                              }
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 55,
                                  height: 55,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isPurchased
                                          ? Colors.green.withValues(alpha: 0.5)
                                          : Colors.white10,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isPurchased
                                            ? Colors.green
                                                .withValues(alpha: 0.2)
                                            : Colors.black
                                                .withValues(alpha: 0.2),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[800],
                                                child: Icon(Icons.card_giftcard,
                                                    color: Colors.white,
                                                    size: 24),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: Colors.grey[800],
                                            child: Icon(Icons.card_giftcard,
                                                color: Colors.white, size: 24),
                                          ),
                                  ),
                                ),
                                if (isPurchased)
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.3),
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final auth = Provider.of<Auth>(context, listen: false);
              if (auth.isGuest) {
                GuestAuthHelper.showGuestLoginDialog(context, 'unlock seasons');
                return;
              }
              if (auth.isSubscribed) {
                // If subscribed, show confirmation dialog with benefit details
                try {
                  // Show loading while fetching benefit status
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  final subService = SubscriptionService(context: context);
                  final response = await subService.getUserBenefitStatus();

                  UserBenefitUsage? storyBenefit;
                  if (response.success && response.items.isNotEmpty) {
                    try {
                      // Benefit type 2 is 'Unlock stories'
                      storyBenefit = response.items.first.benefits.firstWhere(
                        (b) => b.benefitType.id == 2,
                      );
                    } catch (_) {}
                  }

                  // Close loading dialog
                  if (mounted) {
                    Navigator.of(context).pop();
                  }

                  if (storyBenefit != null &&
                      storyBenefit.canUse &&
                      (storyBenefit.usage.availableCount > 0 ||
                          storyBenefit.usage.isUnlimited)) {
                    // Show confirmation dialog
                    if (mounted) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Row(
                              children: [
                                Icon(FontAwesomeIcons.crown,
                                    color: Colors.amber, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Unlock with Benefit',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You are about to unlock this season.',
                                  style: TextStyle(fontSize: 15),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.green
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(FontAwesomeIcons.gift,
                                              color: Colors.green, size: 16),
                                          SizedBox(width: 10),
                                          Text(
                                            'Benefit Details',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        storyBenefit!.usage.isUnlimited
                                            ? '• Unlimited season unlocks available'
                                            : '• Current remaining: ${storyBenefit.usage.remaining}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      if (!storyBenefit.usage.isUnlimited)
                                        Text(
                                          '• After unlock: ${storyBenefit.usage.remaining - 1}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Unlock Now'),
                              ),
                            ],
                          );
                        },
                      );

                      // If user confirmed, proceed with unlock
                      if (confirmed == true) {
                        try {
                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          // Get season info
                          final story =
                              Provider.of<Story>(context, listen: false)
                                  .selectedSeason;
                          final seasonId = story['id'];
                          final seasonTitle = story['title'] ?? 'Season';

                          final int validSeasonId = seasonId is int
                              ? seasonId
                              : int.tryParse(seasonId.toString()) ?? 0;

                          if (validSeasonId <= 0) throw 'Invalid season ID';

                          // 1. Mark as watched/unlocked in backend
                          final url = Url.baakhapaaApi(
                              '/season/$validSeasonId/watched');
                          final unlockResponse = await http.get(
                            Uri.parse(url),
                            headers: Url.baakhapaaAuthHeaders(auth.token),
                          );

                          if (unlockResponse.statusCode != 200) {
                            throw 'Failed to unlock season with benefit';
                          }

                          // 2. Update benefit usage (V2 API)
                          await subService.updateUserBenefitUsage(
                            userBenefitUsageId: storyBenefit.id,
                            seasonId: validSeasonId,
                          );

                          // 3. Refresh and Close
                          if (mounted) {
                            Navigator.of(context).pop(); // Close loader
                            final episodeState = context
                                .findAncestorStateOfType<_EpisodeScreenState>();
                            if (episodeState != null) {
                              episodeState._refreshSeasonWithId(
                                  validSeasonId, seasonTitle);
                              episodeState._showSuccessSnackBar(
                                  'Season unlocked using your subscription benefit!');
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop(); // Close loader
                            final episodeState = context
                                .findAncestorStateOfType<_EpisodeScreenState>();
                            if (episodeState != null) {
                              episodeState
                                  ._showErrorSnackBar('Failed to unlock: $e');
                            }
                          }
                        }
                      }
                    }
                  } else {
                    // No benefit available or not found, navigate to subscription
                    if (mounted) {
                      Navigator.of(context)
                          .pushNamed(SubscriptionScreen.routeName);
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    try {
                      Navigator.of(context).pop(); // Close loader if open
                    } catch (_) {}
                    final episodeState =
                        context.findAncestorStateOfType<_EpisodeScreenState>();
                    if (episodeState != null) {
                      episodeState
                          ._showErrorSnackBar('Failed to check benefits: $e');
                    }
                  }
                }
              } else {
                // Navigate to subscription screen
                Navigator.of(context).pushNamed(SubscriptionScreen.routeName);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: _goldGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/svgs/Crown.svg',
                    width: 20,
                    height: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Unlock with PREMIUM',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsTab() {
    final story = Provider.of<Story>(context).selectedSeason;
    final episodeState = context.findAncestorStateOfType<_EpisodeScreenState>();
    final detailedData = episodeState?._detailedSeasonData;
    final seasonData = detailedData ?? story;
    final Map<String, dynamic> rewardDetails =
        seasonData['reward_details'] ?? {};

    // Extract reward data from the new structure
    final int pointReward = rewardDetails['reward_points'] ?? 0;
    final List<dynamic> products = rewardDetails['product'] ?? [];
    final List<dynamic> achievements = rewardDetails['achievement'] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points Reward Section
          const Text(
            'Points Reward:',
            style: TextStyle(color: Color(0xFFB4B4B4)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFCB0C),
                        Color(0xFFDC9903),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(28)),
                child: Row(
                  children: [
                    const Image(
                        image: AssetImage('assets/images/coins.png'),
                        width: 16,
                        height: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$pointReward',
                      style: AppTextStyles.interBold(
                          color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      ' points',
                      style: AppTextStyles.interSemiBold(
                          color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Badge Rewards Section
          if (achievements.isNotEmpty) ...[
            const Text('Badge Rewards:',
                style: TextStyle(color: Color(0xFFB4B4B4))),
            const SizedBox(height: 8),
            SizedBox(
              height: 65,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final achievement = achievements[index];
                  final String title =
                      achievement['title']?.toString() ?? 'Achievement';
                  final String imageUrl =
                      achievement['image_url']?.toString() ?? '';
                  final bool isClaimed = achievement['is_claimed'] ?? false;
                  final List<dynamic> progress = achievement['progress'] ?? [];
                  final double progressValue =
                      isClaimed ? 1.0 : (progress.isNotEmpty ? 0.5 : 0.0);

                  return GestureDetector(
                    onTap: () {
                      _showAchievementModal(context, achievement);
                    },
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 92,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: isClaimed
                                    ? _goldGradient
                                    : LinearGradient(
                                        colors: [
                                          Colors.grey.shade600,
                                          Colors.grey.shade800
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isClaimed
                                    ? [
                                        BoxShadow(
                                          color: Colors.amber
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                                image: imageUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(imageUrl),
                                        fit: BoxFit.cover,
                                        colorFilter: isClaimed
                                            ? null
                                            : ColorFilter.mode(
                                                Colors.grey
                                                    .withValues(alpha: 0.6),
                                                BlendMode.saturation,
                                              ),
                                      )
                                    : null,
                              ),
                              child: imageUrl.isEmpty
                                  ? Center(
                                      child: Text(
                                        title.length > 10
                                            ? title.substring(0, 10)
                                            : title,
                                        style: TextStyle(
                                          color: isClaimed
                                              ? Colors.black
                                                  .withValues(alpha: 0.8)
                                              : Colors.white
                                                  .withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : null,
                            ),
                            if (isClaimed)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 92,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progressValue,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isClaimed
                                    ? const Color(0xFFCFB26C)
                                    : Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Gift Rewards Section
          if (products.isNotEmpty) ...[
            const Text('Gift Rewards:',
                style: TextStyle(color: Color(0xFFB4B4B4))),
            const SizedBox(height: 8),
            SizedBox(
              height: 55,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final String imageUrl =
                      product['image_url']?.toString() ?? '';
                  final int productId = product['id'] ?? 0;

                  return GestureDetector(
                    onTap: () {
                      if (productId > 0) {
                        Navigator.of(context).pushNamed(
                          '/single-product-screen',
                          arguments: productId,
                        );
                      }
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl.startsWith('storage/')
                                        ? 'https://student.baakhapaa.com/storage/$imageUrl'
                                        : imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[800],
                                        child: Icon(Icons.card_giftcard,
                                            color: Colors.white, size: 24),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey[800],
                                    child: Icon(Icons.card_giftcard,
                                        color: Colors.white, size: 24),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final auth = Provider.of<Auth>(context, listen: false);
              if (auth.isSubscribed) {
                // If subscribed, show confirmation dialog with benefit details
                try {
                  // Show loading while fetching benefit status
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  final subService = SubscriptionService(context: context);
                  final response = await subService.getUserBenefitStatus();

                  UserBenefitUsage? storyBenefit;
                  if (response.success && response.items.isNotEmpty) {
                    try {
                      // Benefit type 2 is 'Unlock stories'
                      storyBenefit = response.items.first.benefits.firstWhere(
                        (b) => b.benefitType.id == 2,
                      );
                    } catch (_) {}
                  }

                  // Close loading dialog
                  if (mounted) {
                    Navigator.of(context).pop();
                  }

                  if (storyBenefit != null &&
                      storyBenefit.canUse &&
                      (storyBenefit.usage.availableCount > 0 ||
                          storyBenefit.usage.isUnlimited)) {
                    // Show confirmation dialog
                    if (mounted) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Row(
                              children: [
                                Icon(FontAwesomeIcons.crown,
                                    color: Colors.amber, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Unlock with Benefit',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You are about to unlock this season.',
                                  style: TextStyle(fontSize: 15),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.green
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(FontAwesomeIcons.gift,
                                              color: Colors.green, size: 16),
                                          SizedBox(width: 10),
                                          Text(
                                            'Benefit Details',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        storyBenefit!.usage.isUnlimited
                                            ? '• Unlimited season unlocks available'
                                            : '• Current remaining: ${storyBenefit.usage.remaining}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      if (!storyBenefit.usage.isUnlimited)
                                        Text(
                                          '• After unlock: ${storyBenefit.usage.remaining - 1}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Unlock Now'),
                              ),
                            ],
                          );
                        },
                      );

                      // If user confirmed, proceed with unlock
                      if (confirmed == true) {
                        try {
                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          // Get season info
                          final story =
                              Provider.of<Story>(context, listen: false)
                                  .selectedSeason;
                          final seasonId = story['id'];
                          final seasonTitle = story['title'] ?? 'Season';

                          final int validSeasonId = seasonId is int
                              ? seasonId
                              : int.tryParse(seasonId.toString()) ?? 0;

                          if (validSeasonId <= 0) throw 'Invalid season ID';

                          // 1. Mark as watched/unlocked in backend
                          final url = Url.baakhapaaApi(
                              '/season/$validSeasonId/watched');
                          final unlockResponse = await http.get(
                            Uri.parse(url),
                            headers: Url.baakhapaaAuthHeaders(auth.token),
                          );

                          if (unlockResponse.statusCode != 200) {
                            throw 'Failed to unlock season with benefit';
                          }

                          // 2. Update benefit usage (V2 API)
                          await subService.updateUserBenefitUsage(
                            userBenefitUsageId: storyBenefit.id,
                            seasonId: validSeasonId,
                          );

                          // 3. Refresh and Close
                          if (mounted) {
                            Navigator.of(context).pop(); // Close loader
                            final episodeState = context
                                .findAncestorStateOfType<_EpisodeScreenState>();
                            if (episodeState != null) {
                              episodeState._refreshSeasonWithId(
                                  validSeasonId, seasonTitle);
                              episodeState._showSuccessSnackBar(
                                  'Season unlocked using your subscription benefit!');
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop(); // Close loader
                            final episodeState = context
                                .findAncestorStateOfType<_EpisodeScreenState>();
                            if (episodeState != null) {
                              episodeState
                                  ._showErrorSnackBar('Failed to unlock: $e');
                            }
                          }
                        }
                      }
                    }
                  } else {
                    // No benefit available or not found, navigate to subscription
                    if (mounted) {
                      Navigator.of(context)
                          .pushNamed(SubscriptionScreen.routeName);
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    try {
                      Navigator.of(context).pop(); // Close loader if open
                    } catch (_) {}
                    final episodeState =
                        context.findAncestorStateOfType<_EpisodeScreenState>();
                    if (episodeState != null) {
                      episodeState
                          ._showErrorSnackBar('Failed to check benefits: $e');
                    }
                  }
                }
              } else {
                // Guest check
                if (auth.isGuest) {
                  await GuestAuthHelper.showGuestLoginDialog(
                    context,
                    'view subscription',
                  );
                  return;
                }

                // Navigate to subscription screen
                Navigator.of(context).pushNamed(SubscriptionScreen.routeName);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: _goldGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/svgs/Crown.svg',
                    width: 20,
                    height: 20,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Unlock with PREMIUM',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to show achievement details modal
  void _showAchievementModal(
      BuildContext context, Map<String, dynamic> achievement) {
    final String title = achievement['title']?.toString() ?? 'Achievement';
    final String description =
        achievement['description'] ?? 'No description available.';
    final String imageUrl = achievement['url']?.toString() ?? '';
    final List<dynamic> progress = achievement['progress'] ?? [];
    final bool isEarned = achievement['is_claimed'] ?? false;
    final String category =
        achievement['achievement_category']?.toString() ?? 'General';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: 400,
            ),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF2A2A2A)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row
                Row(
                  children: [
                    // Achievement icon/image
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isEarned ? Colors.amber : Colors.grey,
                        borderRadius: BorderRadius.circular(8),
                        image: imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageUrl.isEmpty
                          ? Icon(
                              isEarned ? Icons.emoji_events : Icons.lock,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isEarned ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isEarned ? 'Claimed' : 'Not Claimed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(context),
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Progress section
                        if (progress.isNotEmpty) ...[
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            height: 80,
                            child: ListView.builder(
                              shrinkWrap: true,
                              scrollDirection: Axis.horizontal,
                              itemCount: progress.length,
                              itemBuilder: (context, index) {
                                final progressItem = progress[index];
                                final progressPercentage =
                                    progressItem['percentage']?.toDouble() ??
                                        0.0;

                                return Container(
                                  width: 60,
                                  margin: EdgeInsets.only(right: 8),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: progressPercentage >= 100
                                              ? Colors.green
                                              : Colors.grey.shade300,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${progressPercentage.toInt()}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: progressPercentage >= 100
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        progressItem['title'] ??
                                            'Progress ${index + 1}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              AppColors.textSecondary(context),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Close button
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class EpisodesSection extends StatelessWidget {
  final List<dynamic> episodes;
  final bool isLoading;
  final String errorMessage;
  final Map<String, dynamic>? seasonData;

  const EpisodesSection({
    super.key,
    required this.episodes,
    required this.isLoading,
    required this.errorMessage,
    this.seasonData,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final story = Provider.of<Story>(context, listen: false).selectedSeason;
    final _isReadable =
        (seasonData?['content_type'] ?? story['content_type']) == 'readable';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF2A2A2A) : Colors.white,
            isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.8),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isReadable
                            ? [Color(0xFF7B2FF7), Color(0xFF9B59B6)]
                            : [Color(0xFF2964FA), Color(0xFF2E45F7)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(8),
                  child: Icon(_isReadable ? Icons.menu_book : Icons.play_circle,
                      color: const Color.fromARGB(255, 255, 255, 255),
                      size: 24),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isReadable ? 'Chapters' : 'Chapters',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context))),
                  Builder(
                    builder: (context) {
                      // Get genres from season data
                      final story = Provider.of<Story>(context, listen: false)
                          .selectedSeason;
                      final seasonData = this.seasonData ?? story;
                      final List<dynamic> genres = seasonData['genres'] is List
                          ? seasonData['genres'] as List<dynamic>
                          : [];

                      String genreText = _isReadable
                          ? 'Read insightful chapters'
                          : 'Watch amazing lessons';
                      if (genres.isNotEmpty) {
                        genreText = genres.take(3).join(' • ');
                        if (genres.length > 3) genreText += ' & more';
                      }

                      return Text(
                        genreText,
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontWeight: FontWeight.w500,
                            fontSize: 10),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content based on state
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: ListSkeleton(itemCount: 3),
            )
          else if (errorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red[400]),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (episodes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No episodes available',
                  style: TextStyle(color: AppColors.textSecondary(context)),
                ),
              ),
            )
          else
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: episodes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 16 / 11,
              ),
              itemBuilder: (context, index) {
                final episode = episodes[index];

                return Consumer<Story>(
                  builder: (context, storyProvider, child) {
                    // Get season thumbnail from seasonData or from the story provider
                    final story = storyProvider.selectedSeason;
                    final seasonThumbnail =
                        seasonData?['thumbnail'] ?? story['thumbnail'] ?? '';

                    return EpisodeThumbnailCard(
                      imageUrl: seasonThumbnail.isNotEmpty
                          ? seasonThumbnail
                          : 'https://via.placeholder.com/600x360?text=Episode+${index + 1}',
                      label:
                          _isReadable ? 'CH ${index + 1}' : 'EP ${index + 1}',
                      isReadable: _isReadable,
                      episode: episode,
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class EpisodeThumbnailCard extends StatelessWidget {
  final String imageUrl;
  final String label;
  final Map<String, dynamic> episode;
  final bool isReadable;

  const EpisodeThumbnailCard({
    super.key,
    required this.imageUrl,
    required this.label,
    required this.episode,
    this.isReadable = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final story = Provider.of<Story>(context).selectedSeason;
    final bool isDefaultLocked = story['is_locked'] ?? false;
    final bool isWatched = story['watched'] ?? false;
    // Season is locked if it's default locked AND user hasn't watched it yet
    final bool isLocked = isDefaultLocked && !isWatched;

    // Prioritize episode thumbnail over season thumbnail
    final String episodeThumbnail = episode['thumbnail']?.toString() ?? '';
    final String seasonThumbnail = imageUrl;
    final String thumbnailToUse =
        episodeThumbnail.isNotEmpty ? episodeThumbnail : seasonThumbnail;

    return GestureDetector(
      onTap: () {
        final auth = Provider.of<Auth>(context, listen: false);

        // If guest, show login dialog and stop
        if (auth.isGuest) {
          GuestAuthHelper.showGuestLoginDialog(context, 'watch lessons');
          return;
        }

        if (isLocked) {
          // Show unlock dialog if season is locked
          final episodeState =
              context.findAncestorStateOfType<_EpisodeScreenState>();
          if (episodeState != null) {
            episodeState._showUnlockDialog(context);
          }
        } else {
          // Update selectedSeason to include episodes for video screen navigation
          final episodeState =
              context.findAncestorStateOfType<_EpisodeScreenState>();
          final episodes = episodeState?._episodes ?? [];

          final story = Provider.of<Story>(context, listen: false);
          final currentSeason = Map<String, dynamic>.from(story.selectedSeason);
          currentSeason['episodes'] = episodes;

          // ✅ Preserve thumbnail and title
          final seasonStory = story.selectedSeason;
          if (seasonStory['thumbnail'] != null) {
            currentSeason['thumbnail'] = seasonStory['thumbnail'];
          }
          if (seasonStory['title'] != null) {
            currentSeason['title'] = seasonStory['title'];
          }

          story.setSelectedSeason(currentSeason).then((_) {
            // Navigate to video or readable screen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (isReadable) {
                Navigator.of(context).pushNamed(ReadableEpisodeScreen.routeName,
                    arguments: episode);
              } else {
                Navigator.of(context)
                    .pushNamed(VideoScreen.routeName, arguments: episode);
              }
            });
          });
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark ? const Color(0xFF1A1A1A) : Colors.white,
                isDark ? const Color(0xFF0F0F10) : Colors.grey.shade100,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : Colors.grey.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              Positioned.fill(
                child: Image.network(
                  thumbnailToUse,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade300,
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 30,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 20% Black overlay on top of thumbnail
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),

              // Gradient overlay for better text visibility at bottom
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),

              // EP badge (blue) top-left
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0.8, -0.6), // 133.36 degrees
                      end: Alignment(-0.8, 0.6),
                      colors: [Color(0xFF2964FA), Color(0xFF2E45F7)],
                      stops: [0.1437, 0.8862],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Color(0xFF0064A7),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF0064A7),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(label,
                      style: AppTextStyles.interBold(
                          color: Colors.white, fontSize: 12)),
                ),
              ),

              // Reading time badge for readable chapters
              if (isReadable && episode['reading_time_minutes'] != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule,
                            color: Colors.white70, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          '~${episode['reading_time_minutes']} min',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Progress bar (show only if completion_percent > 0) - Full width at bottom
              if ((episode['completion_percent'] ?? 0) > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ((episode['completion_percent'] as num? ?? 0)
                              .toDouble() /
                          100.0),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF00C851), Color(0xFF007E33)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Watch status indicator (top-right)
              Positioned(
                right: 10,
                top: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: episode['watched'] == true
                        ? LinearGradient(
                            begin: Alignment(1.0, 0.0),
                            end: Alignment(-1.0, 0.0),
                            colors: [Color(0xFF0DFF00), Color(0xFF0D9900)],
                          )
                        : null,
                    color:
                        episode['watched'] != true ? Color(0x993C3C43) : null,
                    shape: BoxShape.circle,
                  ),
                  child: episode['watched'] == true
                      ? Icon(
                          Icons.check,
                          color: Colors.black,
                          size: 14,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SuggestedSeasonsSection extends StatefulWidget {
  const SuggestedSeasonsSection({super.key});

  @override
  State<SuggestedSeasonsSection> createState() =>
      _SuggestedSeasonsSectionState();
}

class _SuggestedSeasonsSectionState extends State<SuggestedSeasonsSection> {
  List<dynamic> _relatedSeasons = [];
  bool _isLoadingRelated = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _fetchRelatedSeasons();
  }

  Future<void> _fetchRelatedSeasons() async {
    if (_hasInitialized) return;

    setState(() {
      _isLoadingRelated = true;
    });

    try {
      // Get detailed season data from parent if available
      final episodeState =
          context.findAncestorStateOfType<_EpisodeScreenState>();
      final detailedData = episodeState?._detailedSeasonData;

      if (detailedData != null) {
        DebugLogger.api(
            '🎬 SuggestedSeasonsSection: Using existing detailed data');
        setState(() {
          _relatedSeasons = detailedData['related_seasons'] ?? [];
          _isLoadingRelated = false;
          _hasInitialized = true;
        });
        return;
      }

      final story = Provider.of<Story>(context, listen: false).selectedSeason;
      final seasonId = story['id'] as int;

      DebugLogger.api(
          '🎬 SuggestedSeasonsSection: Fetching related seasons for ID: $seasonId');

      // Fetch related seasons data from season details API
      final seasonDetails = await Provider.of<Story>(context, listen: false)
          .fetchSeasonDetails(seasonId);

      if (mounted && seasonDetails != null) {
        setState(() {
          _relatedSeasons = seasonDetails['related_seasons'] ?? [];
          _isLoadingRelated = false;
          _hasInitialized = true;
        });
        DebugLogger.api(
            '🎬 SuggestedSeasonsSection: Found ${_relatedSeasons.length} related seasons');
      }
    } catch (e) {
      DebugLogger.api(
          '🎬 SuggestedSeasonsSection: Error fetching related seasons: $e');
      if (mounted) {
        setState(() {
          _isLoadingRelated = false;
          _hasInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoadingRelated) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        padding: const EdgeInsets.all(15),
        child: const ShimmerLoading(
          child: Column(
            children: [
              SkeletonBox(width: double.infinity, height: 60, borderRadius: 12),
              SizedBox(height: 8),
              SkeletonBox(width: double.infinity, height: 60, borderRadius: 12),
            ],
          ),
        ),
      );
    }

    // Hide if no related seasons
    if (_relatedSeasons.isEmpty) {
      return SizedBox.shrink();
    }

    return _buildUnifiedSeasonCategory(
      title: 'Related Seasons',
      seasons: _relatedSeasons,
      isWatchTitle: true,
      showDifficulty: false,
    );
  }

  // Unified season category widget (same as story_screen)
  Widget _buildUnifiedSeasonCategory({
    required String title,
    required List<dynamic> seasons,
    required bool isWatchTitle,
    required bool showDifficulty,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF2A2A2A)
                  : Colors.white,
              Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF1E1E1E)
                  : Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 0,
              offset: Offset(0, 8),
            ),
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.8),
              blurRadius: 1,
              spreadRadius: 0,
              offset: Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title
            Row(
              children: [
                Text(
                  isWatchTitle ? 'Watch $title' : title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal scrolling seasons list
            Container(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: seasons.length,
                itemBuilder: (context, index) {
                  final season = seasons[index];

                  // Calculate width to show 3 items with last one 80% visible
                  double screenWidth = MediaQuery.of(context).size.width;
                  double cardWidth;
                  // Available width = screen width - container padding and margins
                  double availableWidth = screenWidth - 44;

                  if (index < 3) {
                    // First 3 cards - equal width
                    cardWidth = availableWidth / 3;
                  } else if (index == 3) {
                    // 4th card - 80% visible to indicate scrolling
                    cardWidth = (availableWidth / 3) * 1;
                  } else {
                    // Rest of the cards - normal width
                    cardWidth = availableWidth / 3;
                  }

                  return Container(
                    width: cardWidth,
                    margin: EdgeInsets.only(
                      right: index == seasons.length - 1 ? 0 : 8.0,
                    ),
                    child: _buildUnifiedSeasonCard(season, showDifficulty),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Unified season card widget (same as story_screen)
  Widget _buildUnifiedSeasonCard(dynamic seasonData, bool showDifficulty) {
    // Safely cast to Map<String, dynamic>
    final Map<String, dynamic> season = seasonData is Map<String, dynamic>
        ? seasonData
        : Map<String, dynamic>.from(seasonData as Map);

    final String? thumbnail = season['thumbnail'];
    final int seasonId = season['id'] ?? 0;
    final dynamic rawRewards = season['rewards'];
    final Map<String, dynamic>? rewards = rawRewards != null
        ? (rawRewards is Map<String, dynamic>
            ? rawRewards
            : Map<String, dynamic>.from(rawRewards as Map))
        : null;
    final String difficulty = season['difficulty']?.toString() ?? 'low';
    final double completionPercentage =
        season['completion_percentage']?.toDouble() ?? 0.0;

    // Check if season is unlocked using helper function
    final bool _hasUnlocked = isSeasonUnlocked(season);

    return InkWell(
      onTap: () async {
        try {
          // Always navigate to episode screen - let users see unlock requirements for locked seasons
          final story = context.read<Story>();
          await story.setSelectedSeason({
            'id': seasonId,
            'thumbnail': thumbnail,
            'isCreatorSeason': false,
            ...season,
          });

          // Replace current episode screen with fade transition
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  EpisodeScreen(),
              transitionDuration: Duration(milliseconds: 300),
              reverseTransitionDuration: Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            ),
          );
        } catch (e) {
          final seasonType =
              showDifficulty ? 'difficult season' : 'suggested season';
          DebugLogger.info('Error navigating to $seasonType: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open season'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
            // Add difficulty-based glow only for difficult seasons
            if (showDifficulty) ...[
              BoxShadow(
                color: _getDifficultyColor(difficulty).withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 0,
                offset: Offset(0, 0),
              ),
            ],
          ],
          border: showDifficulty
              ? Border.all(
                  color: _getDifficultyColor(difficulty).withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Thumbnail Image
              Positioned.fill(
                child: thumbnail != null && thumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: Icon(
                            Icons.movie,
                            color: Colors.grey[400],
                            size: 30,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.movie,
                          color: Colors.grey[400],
                          size: 30,
                        ),
                      ),
              ),

              // Gradient overlay for the specified filter effect
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),

              // Play icon for continue watching items
              if (completionPercentage > 0)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color(0xFFFFE88C),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        color: Color(0xFFFFE88C),
                        size: 14,
                      ),
                    ),
                  ),
                ),

              // Gradient overlay and content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Difficulty level display (only for difficult seasons)
                      if (showDifficulty) ...[
                        Flexible(
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 1500),
                            curve: Curves.easeInOut,
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _getDifficultyGradient(difficulty),
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: [0.0, 0.6, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _getDifficultyColor(difficulty)
                                      .withValues(
                                    alpha: difficulty.toLowerCase() == 'high'
                                        ? 0.6
                                        : 0.4,
                                  ),
                                  blurRadius: difficulty.toLowerCase() == 'high'
                                      ? 8
                                      : 6,
                                  spreadRadius:
                                      difficulty.toLowerCase() == 'high'
                                          ? 1
                                          : 0,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getDifficultyIcon(difficulty),
                                  size: 8,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    difficulty.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Rewards section - Full width
                      if (rewards != null) ...[
                        Container(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Product reward
                              if (rewards['product'] != null &&
                                  rewards['product'] > 0) ...[
                                Flexible(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FaIcon(
                                        FontAwesomeIcons.gift,
                                        color: Color(0xFFF96544),
                                        size: 10,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${rewards['product']}',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Reward points
                              if (rewards['reward_points'] != null &&
                                  rewards['reward_points'] > 0) ...[
                                Flexible(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Image.asset(
                                            'assets/images/coins.png',
                                            width: 9,
                                            height: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${rewards['reward_points']}',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Achievement
                              if (rewards['achievement'] != null &&
                                  rewards['achievement'] > 0) ...[
                                Flexible(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/svgs/star-badge-solid.svg',
                                        width: 9,
                                        height: 9,
                                        colorFilter: ColorFilter.mode(
                                          Color(0xFFA7DCFF),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${rewards['achievement']}',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Completion percentage for continue watching items
                      if (completionPercentage > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: completionPercentage / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(0xFFFFE88C),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Lock indicator (enhanced visibility)
              // Show lock when season is not unlocked (same logic as StoryCard)
              if (!_hasUnlocked)
                Positioned(
                  top: 8,
                  left: 8,
                  child: SvgPicture.asset(
                    'assets/svgs/lock.svg',
                    width: 10.5,
                    height: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for difficulty styling
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF5722);
      case 'medium':
        return const Color(0xFFFFC107);
      case 'low':
      default:
        return const Color(0xFF4CAF50);
    }
  }

  List<Color> _getDifficultyGradient(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'high':
        return [
          const Color(0xFFFF5722),
          const Color(0xFFFF8A65),
          const Color(0xFFFFAB91)
        ];
      case 'medium':
        return [
          const Color(0xFFFFC107),
          const Color(0xFFFFD54F),
          const Color(0xFFFFE082)
        ];
      case 'low':
      default:
        return [
          const Color(0xFF4CAF50),
          const Color(0xFF81C784),
          const Color(0xFFA5D6A7)
        ];
    }
  }

  IconData _getDifficultyIcon(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'high':
        return Icons.local_fire_department;
      case 'medium':
        return Icons.flash_on;
      case 'low':
      default:
        return Icons.eco;
    }
  }
}
