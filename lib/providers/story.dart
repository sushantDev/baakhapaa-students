import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_mode.dart';
import '../models/url.dart';
import '../utils/debug_logger.dart';
import '../utils/suggested_seasons_cache.dart';
import '../models/season_analytics.dart';

class Story with ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  late List<dynamic> _seasons = [];
  late List<Map<String, dynamic>> _featuredSeasons = [];
  late List<dynamic> _creatorSeasons = [];
  late List<dynamic> _sliders = [];
  late List<dynamic> _storySlider = [];
  late List<Map<String, dynamic>> _suggestedSeasons = [];
  late List<Map<String, dynamic>> _difficultSeasons = [];
  late List<dynamic> _myListItems = [];
  late List<dynamic> _continueWatchingItems = [];
  late List<dynamic> _premiumCreatorSeasons = [];
  late List<dynamic> _readableSeasons = [];
  late List<dynamic> _episodePages = [];
  bool _isLoadingPages = false;
  bool _isLoadingContinueWatching = false;
  Map<String, dynamic> _readingStreak = {};
  DateTime? _streakLastFetched;
  bool _isStreakFetching = false;
  List<Map<String, dynamic>> _readingHistory = [];

  Map<String, dynamic> get readingStreak => _readingStreak;
  List<Map<String, dynamic>> get readingHistory => _readingHistory;

  List<dynamic> _bookRequests = [];
  List<dynamic> get bookRequests => _bookRequests;

  late List<dynamic> _storyPopups = [];
  List<dynamic> get storyPopups {
    return _storyPopups;
  }

  // Season Analytics
  SeasonAnalytics? _seasonAnalytics;
  SeasonAnalytics? get seasonAnalytics => _seasonAnalytics;

  late Map<String, dynamic> _episode = {};
  late Map<String, dynamic> _selectedSeason = {};
  late String authToken;
  late String _episodeSeasonPurchased;

  // Game mode tracking
  GameMode _selectedGameMode = GameMode.quiz;
  GameMode get selectedGameMode => _selectedGameMode;
  set selectedGameMode(GameMode mode) {
    _selectedGameMode = mode;
    notifyListeners();
  }

  /// Set game mode without notifying listeners (safe to call during build)
  void setGameModeSilently(GameMode mode) {
    _selectedGameMode = mode;
  }

  late List<dynamic> _episodeComments = [];
  final ValueNotifier<List<dynamic>> _popupsNotifier =
      ValueNotifier<List<dynamic>>([]);

  Story(
    this.authToken,
    this._seasons, {
    Map<String, dynamic>? selectedSeason,
    Map<String, dynamic>? episode,
    List<Map<String, dynamic>>? featuredSeasons,
    List<Map<String, dynamic>>? suggestedSeasons,
    List<Map<String, dynamic>>? difficultSeasons,
    List<dynamic>? myListItems,
    List<dynamic>? continueWatchingItems,
    List<dynamic>? premiumCreatorSeasons,
    List<dynamic>? creatorSeasons,
    List<dynamic>? readableSeasons,
    Map<String, dynamic>? readingStreak,
  }) {
    // Preserve critical state from previous provider instance
    _selectedSeason = selectedSeason ?? {};
    _episode = episode ?? {};
    _featuredSeasons = featuredSeasons ?? [];
    _suggestedSeasons = suggestedSeasons ?? SuggestedSeasonsCache().getCache();
    _difficultSeasons = difficultSeasons ?? [];
    _myListItems = myListItems ?? [];
    _continueWatchingItems = continueWatchingItems ?? [];
    _premiumCreatorSeasons = premiumCreatorSeasons ?? [];
    _creatorSeasons = creatorSeasons ?? [];
    _readableSeasons = readableSeasons ?? [];
    _episodePages = [];
    _isLoadingPages = false;

    // Preserve streak from previous provider instance
    if (readingStreak != null && readingStreak.isNotEmpty) {
      _readingStreak = readingStreak;
    } else {
      // Load from local storage on first init
      _loadStreakFromLocal();
    }

    // Initialize other lists
    _sliders = [];
    _storySlider = [];
    _storyPopups = [];
    _episodeComments = [];
    _episodeSeasonPurchased = '';
  }

  /// Load streak data from SharedPreferences
  Future<void> _loadStreakFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final streakJson = prefs.getString('cached_reading_streak');
      if (streakJson != null) {
        final data = json.decode(streakJson);
        if (data is Map && data.isNotEmpty) {
          _readingStreak = Map<String, dynamic>.from(data);
          notifyListeners();
        }
      }
    } catch (e) {
      DebugLogger.error('đĽ Error loading cached streak: $e');
    }
  }

  /// Save streak data to SharedPreferences
  Future<void> _saveStreakToLocal() async {
    try {
      if (_readingStreak.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'cached_reading_streak', json.encode(_readingStreak));
      }
    } catch (e) {
      DebugLogger.error('đĽ Error saving streak to cache: $e');
    }
  }

  List<dynamic> get seasons {
    return _seasons;
  }

  List<Map<String, dynamic>> get featuredSeasons {
    return _featuredSeasons;
  }

  List<Map<String, dynamic>> get suggestedSeasons {
    return _suggestedSeasons;
  }

  List<Map<String, dynamic>> get difficultSeasons {
    return _difficultSeasons;
  }

  List<dynamic> get myListItems {
    return _myListItems;
  }

  List<dynamic> get continueWatchingItems {
    return _continueWatchingItems;
  }

  List<dynamic> get premiumCreatorSeasons {
    return _premiumCreatorSeasons;
  }

  List<dynamic> get readableSeasons {
    return _readableSeasons;
  }

  List<dynamic> get episodePages {
    return _episodePages;
  }

  bool get isLoadingPages => _isLoadingPages;
  bool get isLoadingContinueWatching => _isLoadingContinueWatching;

  List<dynamic> get creatorSeasons {
    return _creatorSeasons;
  }

  List<dynamic> get sliders {
    return _sliders;
  }

  List<dynamic> get storySlider => _storySlider;
  bool get isEpisodeSeasonPurchased {
    if (_episodeSeasonPurchased == 'HAS_NOT_PURCHASED_SEASON') {
      return false;
    } else {
      return true;
    }
  }

  Map<String, dynamic> get episode {
    return _episode;
  }

  List<dynamic> get episodeComments {
    return _episodeComments;
  }

  List<dynamic> get episodePopups {
    return _popupsNotifier.value;
  }

  Map<String, dynamic> get selectedSeason {
    return _selectedSeason;
  }

  int get seasonsCount {
    return _seasons.length;
  }

  int get creatorSeasonsCount {
    return _creatorSeasons.length;
  }

  bool get watchedEpisode {
    return _episode['watched'] == true;
  }

  Future<void> fetchAllSeasons() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/v3/seasons')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        _seasons = List<Map<String, dynamic>>.from(
          responseData['data']['items'],
        );
        DebugLogger.api(
          'Story Provider: Loaded ${_seasons.length} seasons with user-specific data',
        );
        notifyListeners();
      } else {
        throw ('Failed to fetch seasons');
      }
    } catch (e) {
      DebugLogger.error('Error fetching seasons: $e');
      throw e;
    }
  }

  Future<void> fetchFeaturedSeasons() async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/seasons/featured-seasons')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(Duration(seconds: 15));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        final dataField = responseData['data'];

        // Handle different possible structures
        List<dynamic> rawItems = [];
        if (dataField is List) {
          rawItems = dataField;
        } else if (dataField is Map<String, dynamic>) {
          if (dataField.containsKey('items')) {
            rawItems = dataField['items'] ?? [];
          } else if (dataField.containsKey('seasons')) {
            rawItems = dataField['seasons'] ?? [];
          } else {
            // Try to find any array field in the data
            final arrayFields = dataField.entries.where(
              (entry) => entry.value is List,
            );
            if (arrayFields.isNotEmpty) {
              rawItems = arrayFields.first.value;
            }
          }
        }

        // Filter out null items and ensure each season has required fields
        _featuredSeasons = rawItems
            .where((season) => season != null)
            .map<Map<String, dynamic>>((season) {
          final Map<String, dynamic> safeSeason = Map<String, dynamic>.from(
            season,
          );
          // Ensure critical fields have default values if null
          if (safeSeason['title'] == null)
            safeSeason['title'] = 'Untitled Season';
          if (safeSeason['thumbnail'] == null) safeSeason['thumbnail'] = '';
          if (safeSeason['images'] == null) safeSeason['images'] = [];

          // Normalize user and challenge fields
          return _normalizeSeasonData(safeSeason);
        }).toList();

        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (e) {
      DebugLogger.api('Error fetching featured seasons: $e');
      _featuredSeasons = [];
      notifyListeners();
    }
  }

  Future<void> fetchSuggestedSeasons() async {
    try {
      final String apiUrl = Url.baakhapaaApi('/seasons/suggested-seasons');
      final Map<String, String> headers = Url.baakhapaaAuthHeaders(authToken);

      var response = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['data'] != null &&
            responseData['data']['items'] != null) {
          List<dynamic> categories = responseData['data']['items'];

          // Update cache with new data
          List<Map<String, dynamic>> typedCategories =
              categories.cast<Map<String, dynamic>>();
          SuggestedSeasonsCache().updateCache(typedCategories);

          // Also update local variable
          _suggestedSeasons = typedCategories;
          notifyListeners();
        }
      } else {
        DebugLogger.error(
            'Suggested seasons API Error: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.error('Error fetching suggested seasons: $e');
    }
  }

  Future<void> fetchDifficultSeasons() async {
    try {
      final String apiUrl = Url.baakhapaaApi('/seasons/difficult-seasons');
      final Map<String, String> headers = Url.baakhapaaAuthHeaders(authToken);

      var response = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['data'] != null &&
            responseData['data']['items'] != null) {
          List<dynamic> categories = responseData['data']['items'];

          // Update local variable
          _difficultSeasons = categories.cast<Map<String, dynamic>>();
          notifyListeners();
        }
      } else {
        DebugLogger.error(
            'Difficult seasons API Error: ${response.statusCode}');
      }
    } catch (e) {
      DebugLogger.error('Error fetching difficult seasons: $e');
    }
  }

  Future<void> setSelectedSeason(Map<String, dynamic> season) async {
    _selectedSeason = season;

    // Ensure my_list status is set from _myListItems if not already present
    if (!_selectedSeason.containsKey('my_list') && _myListItems.isNotEmpty) {
      final seasonId = _selectedSeason['id'];
      final inList = _myListItems.any((item) {
        final s = item['season'];
        return s != null && s['id'] == seasonId;
      });
      _selectedSeason['my_list'] = inList;
    }

    notifyListeners();
  }

  // New method to fetch episodes for a specific season
  Future<List<dynamic>> fetchSeasonEpisodes(int seasonId) async {
    try {
      DebugLogger.api('đŹ Fetching episodes for season ID: $seasonId');
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/season/$seasonId/episodes')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      DebugLogger.api(
          'đŹ Episode API Response Status: ${response.statusCode}');
      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      DebugLogger.api('đŹ Episode API Response: ${responseData.toString()}');

      if (responseData['success'] == true) {
        final episodes = responseData['data']['episodes'] ?? [];
        DebugLogger.info('đŹ Found ${episodes.length} episodes');

        // Store episodes in the selected season for navigation purposes
        if (_selectedSeason['id'] == seasonId) {
          _selectedSeason['episodes'] = episodes;
          DebugLogger.info(
            'đŹ Updated selected season with ${episodes.length} episodes',
          );
          notifyListeners();
        }

        return episodes;
      } else {
        throw ('Error fetching episodes');
      }
    } catch (error) {
      DebugLogger.api('đŹ Error fetching episodes: $error');
      throw error;
    }
  }

  // New method to fetch episodes for a creator's specific season
  Future<Map<String, dynamic>> fetchCreatorSeasonEpisodes(
    int creatorId,
    int seasonId,
  ) async {
    try {
      DebugLogger.api(
        'đŹ Fetching creator episodes for creator ID: $creatorId, season ID: $seasonId',
      );
      final response = await http.get(
        Uri.parse(
          Url.baakhapaaApi('/creator/$creatorId/season/$seasonId/episodes'),
        ),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        final data = responseData['data'] ?? {};
        final episodes = data['episodes'] ?? [];
        final userId = data['user_id'];
        final seasonIdFromApi = data['season_id'];
        DebugLogger.info(
            'đŹ Found [33m${episodes.length}[0m creator episodes');
        DebugLogger.api('đ¤ Creator user_id: $userId');

        // Store episodes and creator_id in the selected season for navigation purposes
        if (_selectedSeason['id'] == seasonIdFromApi) {
          _selectedSeason['episodes'] = episodes;
          _selectedSeason['creator_id'] = userId; // â ADD THIS!
          notifyListeners();
        }

        // â Return full data structure
        return {
          'user_id': userId,
          'season_id': seasonIdFromApi,
          'episodes': episodes,
        };
      } else {
        throw ('Error fetching creator episodes');
      }
    } catch (error) {
      DebugLogger.error('đŹ Error fetching creator episodes: $error');
      throw error;
    }
  }

  // Future<void> fetchCreatorSeasons(int creatorId) async {
  //   try {
  //     DebugLogger.info(
  //         'đş Fetching creator seasons for creator ID: $creatorId');
  //     final url = Url.baakhapaaApi('/v3/seasons/$creatorId');
  //     DebugLogger.info('đ API URL: $url');

  //     final response = await http.get(
  //       Uri.parse(url),
  //       headers: Url.baakhapaaAuthHeaders(authToken),
  //     );

  //     DebugLogger.info(
  //         'đĄ Creator seasons API response status: ${response.statusCode}');
  //     DebugLogger.info('đŚ Raw response body length: ${response.body.length}');

  //     var responseData = json.decode(utf8.decode((response.bodyBytes)));
  //     DebugLogger.info('â Creator seasons success: ${responseData['success']}');
  //     DebugLogger.info('đ Full response keys: ${responseData.keys.toList()}');

  //     final preview = responseData.toString();
  //     DebugLogger.info(
  //         'đ Response preview: ${preview.length > 200 ? preview.substring(0, 200) : preview}...');

  //     if (responseData['success'] == true) {
  //       final dataField = responseData['data'];
  //       DebugLogger.info('đ Data field type: ${dataField.runtimeType}');

  //       // Handle different possible structures
  //       List<dynamic> rawItems = [];
  //       if (dataField is List) {
  //         DebugLogger.info('đ Data is a List directly');
  //         rawItems = dataField;
  //       } else if (dataField is Map<String, dynamic>) {
  //         DebugLogger.info(
  //             'đ Data is a Map with keys: ${dataField.keys.toList()}');
  //         if (dataField.containsKey('items')) {
  //           rawItems = dataField['items'] ?? [];
  //           DebugLogger.info(
  //               'đ Found items field with ${rawItems.length} items');
  //         } else if (dataField.containsKey('seasons')) {
  //           rawItems = dataField['seasons'] ?? [];
  //           DebugLogger.info(
  //               'đ Found seasons field with ${rawItems.length} items');
  //         } else {
  //           // Try to find any array field in the data
  //           final arrayFields = dataField.entries.where(
  //             (entry) => entry.value is List,
  //           );
  //           if (arrayFields.isNotEmpty) {
  //             rawItems = arrayFields.first.value;
  //             DebugLogger.info(
  //                 'đ Found array field "${arrayFields.first.key}" with ${rawItems.length} items');
  //           }
  //         }
  //       }

  //       DebugLogger.info(
  //           'đ Raw items count before filtering: ${rawItems.length}');

  //       // Filter out null items and ensure each season has required fields
  //       _creatorSeasons = rawItems.where((season) => season != null).map((
  //         season,
  //       ) {
  //         final Map<String, dynamic> safeSeason = Map<String, dynamic>.from(
  //           season,
  //         );
  //         // Ensure critical fields have default values if null
  //         if (safeSeason['title'] == null)
  //           safeSeason['title'] = 'Untitled Season';
  //         if (safeSeason['thumbnail'] == null) safeSeason['thumbnail'] = '';
  //         if (safeSeason['images'] == null) safeSeason['images'] = [];
  //         return safeSeason;
  //       }).toList();

  //       DebugLogger.info(
  //           'â¨ Creator seasons SET to: ${_creatorSeasons.length} items');
  //       DebugLogger.info('đ Calling notifyListeners() for creator seasons');
  //       try {
  //         notifyListeners();
  //         DebugLogger.info('â notifyListeners() completed for creator seasons');
  //       } catch (e) {
  //         DebugLogger.info(
  //             'â ď¸ notifyListeners() called after disposal (widget navigated away)');
  //       }
  //     } else {
  //       DebugLogger.error('â API returned success=false');
  //       _creatorSeasons = [];
  //       try {
  //         notifyListeners();
  //       } catch (e) {
  //         DebugLogger.info('â ď¸ notifyListeners() called after disposal');
  //       }
  //       throw ('Error');
  //     }
  //   } catch (error) {
  //     DebugLogger.error('đĽ Error in fetchCreatorSeasons: $error');
  //     if (!error.toString().contains('was used after being disposed')) {
  //       DebugLogger.error('Stack trace: ${StackTrace.current}');
  //     }
  //     _creatorSeasons = [];
  //     try {
  //       notifyListeners();
  //     } catch (e) {
  //       DebugLogger.info('â ď¸ notifyListeners() called after disposal');
  //     }
  //     rethrow;
  //   }
  // }

  Future<List<dynamic>> fetchCreatorSeasons(int creatorId,
      {bool returnList = false}) async {
    try {
      DebugLogger.info(
          'đş Fetching creator seasons for creator ID: $creatorId');
      final url = Url.baakhapaaApi('/v3/seasons/$creatorId');
      DebugLogger.info('đş API URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      DebugLogger.info('đş Response status: ${response.statusCode}');

      // Handle rate limiting
      if (response.statusCode == 429) {
        DebugLogger.error('đş Rate limited for creator $creatorId');
        throw Exception('429');
      }

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      DebugLogger.info('đş Response success: ${responseData['success']}');

      if (responseData['success'] == true) {
        final dataField = responseData['data'];
        DebugLogger.info('đş Data field type: ${dataField.runtimeType}');

        // Normalize to list regardless of backend shape
        List<dynamic> rawItems = [];
        if (dataField is List) {
          rawItems = dataField;
          DebugLogger.info('đş Data is List with ${rawItems.length} items');
        } else if (dataField is Map<String, dynamic>) {
          DebugLogger.info(
              'đş Data is Map with keys: ${dataField.keys.toList()}');
          if (dataField.containsKey('items')) {
            rawItems = dataField['items'] ?? [];
            DebugLogger.info(
                'đş Extracted ${rawItems.length} items from data.items');
          } else if (dataField.containsKey('seasons')) {
            rawItems = dataField['seasons'] ?? [];
            DebugLogger.info(
                'đş Extracted ${rawItems.length} items from data.seasons');
          } else {
            // fallback: first list field if any
            final arrayFields = dataField.entries.where((e) => e.value is List);
            if (arrayFields.isNotEmpty) {
              rawItems = arrayFields.first.value;
              DebugLogger.info(
                  'đş Fallback: extracted ${rawItems.length} from ${arrayFields.first.key}');
            }
          }
        }

        final list = rawItems
            .where((e) => e != null)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        DebugLogger.info(
            'đş Final list size after filtering: ${list.length}');
        DebugLogger.info('đş Returning list for creator $creatorId');

        if (!returnList) {
          // update provider state (unchanged behavior)
          _creatorSeasons = list;
          notifyListeners();
        }

        // Return the list so callers can use it directly (no global overwrite)
        return list;
      } else {
        // API returned success=false
        if (!returnList) {
          _creatorSeasons = [];
          notifyListeners();
        }
        return [];
      }
    } catch (e, st) {
      DebugLogger.error('fetchCreatorSeasons error: $e\n$st');
      if (!returnList) {
        _creatorSeasons = [];
        try {
          notifyListeners();
        } catch (_) {}
      }
      return [];
    }
  }

  Future<void> fetchEpisode(int episodeId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/v2/episode/$episodeId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        _episode = responseData['data'];
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> fetchEpisodePopups(int episodeId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/episode/$episodeId/popups')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        // Add null safety for items array
        final items = responseData['data']?['items'];
        _popupsNotifier.value = items is List ? items : [];
      } else {
        _popupsNotifier.value = [];
      }
    } catch (error) {
      DebugLogger.error('Error fetching episode popups: $error');
      _popupsNotifier.value = [];
      // Don't rethrow to prevent app crash
    }
  }

  Future<void> unlockSeason(
    int userId,
    int seasonId,
    String seasonTitle,
    int seasonCoinToUnlock,
  ) async {
    try {
      final paymentResponse = await http.post(
        Uri.parse(Url.baakhapaaApi('/coin-transaction')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode({
          'user_id': userId,
          'status': 'debited',
          'coin': seasonCoinToUnlock,
          'remarks': 'Season "$seasonTitle" unlock',
        }),
      );
      var responseData = json.decode(paymentResponse.body);
      if (responseData['code'] >= 400) {
        throw responseData['message'];
      }
      if (responseData['success'] == true) {
        await http.get(
          Uri.parse(Url.baakhapaaApi('/season/$seasonId/watched')),
          headers: Url.baakhapaaAuthHeaders(authToken),
        );

        // Update local lists so returning to story_screen shows unlocked state
        final sid = seasonId.toString();
        for (int i = 0; i < _readableSeasons.length; i++) {
          if (_readableSeasons[i]['id'].toString() == sid) {
            _readableSeasons[i] =
                Map<String, dynamic>.from(_readableSeasons[i]);
            _readableSeasons[i]['watched'] = true;
            break;
          }
        }
        for (int i = 0; i < _featuredSeasons.length; i++) {
          if (_featuredSeasons[i]['id'].toString() == sid) {
            _featuredSeasons[i] =
                Map<String, dynamic>.from(_featuredSeasons[i]);
            _featuredSeasons[i]['watched'] = true;
            break;
          }
        }
        for (int i = 0; i < _suggestedSeasons.length; i++) {
          if (_suggestedSeasons[i]['id'].toString() == sid) {
            _suggestedSeasons[i] =
                Map<String, dynamic>.from(_suggestedSeasons[i]);
            _suggestedSeasons[i]['watched'] = true;
            break;
          }
        }
        // Update nested seasons inside each difficult-seasons category
        for (int i = 0; i < _difficultSeasons.length; i++) {
          final List<dynamic> catSeasons =
              (_difficultSeasons[i]['seasons'] as List?) ?? [];
          bool found = false;
          for (int j = 0; j < catSeasons.length; j++) {
            if (catSeasons[j]['id'].toString() == sid) {
              final updated = Map<String, dynamic>.from(catSeasons[j] as Map);
              updated['watched'] = true;
              catSeasons[j] = updated;
              found = true;
              break;
            }
          }
          if (found) {
            // Replace category map so listeners see a new reference
            final updatedCat = Map<String, dynamic>.from(_difficultSeasons[i]);
            updatedCat['seasons'] = catSeasons;
            _difficultSeasons[i] = updatedCat;
            break;
          }
        }

        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> episodeWatched(
    int userId,
    int episodeId,
    String episodeTitle,
    int episodeRewardCoin,
    int episodeCoinsUsers,
    int fallBackPoints,
  ) async {
    try {
      if (episodeCoinsUsers == 0) {
        // for baakhapaa episodes reward process
        await http.post(
          Uri.parse(Url.baakhapaaApi('/coin-transaction')),
          headers: Url.baakhapaaAuthHeaders(authToken),
          body: json.encode({
            'user_id': userId,
            'status': 'credited',
            'coin': fallBackPoints,
            'remarks':
                'Episode "$episodeTitle" has been completed. You have received fallback points because the creator\'s allocated points have already been used.',
          }),
        );
      } else {
        // for creators episodes reward process
        if (episodeCoinsUsers > 0) {
          await http
              .get(
            Uri.parse(
              Url.baakhapaaApi('/episode/$episodeId/deduct-coins-users'),
            ),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
              .then((_) async {
            await http.post(
              Uri.parse(Url.baakhapaaApi('/coin-transaction')),
              headers: Url.baakhapaaAuthHeaders(authToken),
              body: json.encode({
                'user_id': userId,
                'status': 'credited',
                'coin': episodeRewardCoin,
                'remarks': 'Episode "$episodeTitle" completed',
              }),
            );
          });
        }
      }
      await http.get(
        Uri.parse(Url.baakhapaaApi(
            '/episode/$episodeId/watched?game_mode=${_selectedGameMode.toApiString()}')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );
    } catch (error) {
      throw error;
    }
  }

  Future<bool> hasCompletedEpisodeQuiz(int episodeId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/episode/$episodeId/watched')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );
      final responseData = json.decode(utf8.decode(response.bodyBytes));
      final message = (responseData['message'] ?? '').toString().toLowerCase();
      final code = responseData['code']?.toString();
      final completed = responseData['success'] == true &&
          (message.contains('completed') ||
              message.contains('congratulations') ||
              code == '0');

      if (completed) {
        _episode['watched'] = true;
        updateEpisodeWatchedStatusLocally(episodeId);
      }

      return completed;
    } catch (error) {
      DebugLogger.error('Error checking episode watched status: $error');
      return false;
    }
  }

  /// Updates the watched status of an episode locally in the selectedSeason's episodes list
  /// This provides immediate UI feedback before the next API refresh
  void updateEpisodeWatchedStatusLocally(int episodeId) {
    try {
      // Update in selectedSeason's episodes list
      if (_selectedSeason['episodes'] != null) {
        final episodes = _selectedSeason['episodes'] as List<dynamic>;
        for (int i = 0; i < episodes.length; i++) {
          if (episodes[i]['id'] == episodeId) {
            episodes[i]['watched'] = true;
            DebugLogger.success(
              'đş Story Provider: Updated episode $episodeId watched status to true in selectedSeason',
            );
            break;
          }
        }
      }

      // Update the current episode if it matches
      if (_episode['id'] == episodeId) {
        _episode['watched'] = true;
        DebugLogger.success(
          'đş Story Provider: Updated current episode $episodeId watched status to true',
        );
      }

      // Notify listeners to trigger UI update
      notifyListeners();
    } catch (error) {
      DebugLogger.error(
        'â Story Provider: Failed to update episode watched status locally: $error',
      );
    }
  }

  Future<void> episodeSeasonPurchased(int episodeId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/episode/$episodeId/purchased')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        _episodeSeasonPurchased = responseData['message'];
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> getEpisodeComments(int episodeId) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/episode/$episodeId/comments')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        _episodeComments = responseData['data']['values'];
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> storeEpisodeComments(
    int episodeId,
    String body,
    int parentCommentId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/episode/comment')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode({
          'episode_id': episodeId,
          'body': body,
          'parent_comment_id': parentCommentId != 0 ? parentCommentId : null,
        }),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        // Refresh comments from server to get the latest list
        await getEpisodeComments(episodeId);
        DebugLogger.success('đŹ Comment posted and list refreshed');
      } else {
        throw Exception(responseData['message'] ?? 'Failed to post comment');
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> updateEpisodeProgress(
    int episodeId,
    int progressSeconds,
    int durationSeconds,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/episode-progress')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode({
          'episode_id': episodeId,
          'progress_seconds': progressSeconds,
          'duration_seconds': durationSeconds,
        }),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        DebugLogger.info(
          'đ Episode progress updated: ${progressSeconds}s/${durationSeconds}s for episode $episodeId',
        );
      } else {
        DebugLogger.error(
          'â Failed to update episode progress: ${responseData['message']}',
        );
      }
    } catch (error) {
      DebugLogger.error('â Error updating episode progress: $error');
    }
  }

  // Method to update episode progress locally for immediate UI feedback
  void updateEpisodeProgressLocally(
    int episodeId,
    int progressSeconds,
    int durationSeconds,
  ) {
    try {
      // Calculate completion percentage
      double completionPercent = 0.0;
      if (durationSeconds > 0) {
        completionPercent = (progressSeconds / durationSeconds) * 100;
        // Cap at 99% to avoid showing 100% for incomplete videos
        if (completionPercent > 99) completionPercent = 99.0;
      }

      DebugLogger.info(
        'đ Updating local episode progress: Episode $episodeId -> ${completionPercent.toStringAsFixed(1)}% (${progressSeconds}s/${durationSeconds}s)',
      );

      // Update in selected season if it contains episodes
      if (_selectedSeason.containsKey('episodes') &&
          _selectedSeason['episodes'] is List) {
        final episodes = _selectedSeason['episodes'] as List<dynamic>;
        for (var episode in episodes) {
          if (episode is Map<String, dynamic> && episode['id'] == episodeId) {
            episode['completion_percent'] = completionPercent;
            DebugLogger.success(
              'đ Updated episode ${episodeId} completion_percent to ${completionPercent.toStringAsFixed(1)}%',
            );
            break;
          }
        }
      }

      // Also update in the current episode if it matches
      if (_episode.isNotEmpty && _episode['id'] == episodeId) {
        _episode['completion_percent'] = completionPercent;
        DebugLogger.success('đ Updated current episode completion_percent');
      }

      // Notify listeners to trigger UI updates
      notifyListeners();
    } catch (error) {
      DebugLogger.error('â Error updating local episode progress: $error');
    }
  }

  Future<void> fetchStorySlider() async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/story-slider')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(Duration(seconds: 15));

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        _sliders = responseData['data']['items'];
        notifyListeners();
      } else {
        DebugLogger.error(
            'Error fetching story slider: ${responseData['message']}');
      }
    } catch (error) {
      DebugLogger.error('Error fetching story slider: $error');
      // Don't rethrow â caller should not crash for non-critical slider data
    }
  }

  Future<void> fetchStoryPopup() async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/story-popup')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(Duration(seconds: 15));

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        _storyPopups = responseData['data']['items'];
        notifyListeners();
      } else {
        DebugLogger.error(
            'Error fetching story popup: ${responseData['message']}');
      }
    } catch (error) {
      DebugLogger.error('Error fetching story popup: $error');
      // Don't rethrow â popups are non-critical
    }
  }

  Future<void> fetchMyList() async {
    try {
      DebugLogger.api(
        'đ STARTING fetchMyList - authToken length: ${authToken.length}',
      );

      final String apiUrl = Url.baakhapaaApi('/my-list/show');
      DebugLogger.api('đ API URL: $apiUrl');

      final Map<String, String> headers = Url.baakhapaaAuthHeaders(authToken);

      var response = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true &&
            responseData['data'] != null &&
            responseData['data']['items'] != null) {
          _myListItems = responseData['data']['items'];
          DebugLogger.api('đ Loaded ${_myListItems.length} my list items');
          notifyListeners();
        } else {
          DebugLogger.api(
            'đ My List API Error: ${responseData['message'] ?? 'Unknown error'}',
          );
          _myListItems = [];
          notifyListeners();
        }
      } else {
        DebugLogger.api(
          'đ My List API Error: ${response.statusCode} - ${response.body}',
        );
        _myListItems = [];
        notifyListeners();
      }
    } catch (e) {
      DebugLogger.api('đ Error fetching my list: $e');
      _myListItems = [];
      notifyListeners();
    }
  }

  // Add or remove item from My List
  Future<bool> toggleMyListItem(int seasonId) async {
    try {
      DebugLogger.api('đ STARTING toggleMyListItem - Season ID: $seasonId');

      // Check if item is already in My List - prioritize selected season data
      bool isInMyList = false;
      bool usedSelectedSeasonData = false;

      // First, check if this is the selected season and has my_list field (most accurate)
      if (_selectedSeason.isNotEmpty && _selectedSeason['id'] == seasonId) {
        if (_selectedSeason.containsKey('my_list')) {
          isInMyList = _selectedSeason['my_list'] == true;
          usedSelectedSeasonData = true;
          DebugLogger.api(
            'đ Provider: Using selectedSeason my_list field: $isInMyList',
          );
        }
      }

      // Only fall back to _myListItems array if we haven't already used selected season data
      if (!usedSelectedSeasonData) {
        if (_selectedSeason.isNotEmpty && _selectedSeason['id'] == seasonId) {
          // For selected season without my_list field, use _myListItems array
          isInMyList = _myListItems.any((item) {
            final season = item['season'];
            return season != null && season['id'] == seasonId;
          });
          DebugLogger.api(
            'đ Provider: Using _myListItems array check: $isInMyList',
          );
        } else {
          // For non-selected seasons, always use _myListItems array
          isInMyList = _myListItems.any((item) {
            final season = item['season'];
            return season != null && season['id'] == seasonId;
          });
          DebugLogger.api(
            'đ Provider: Using _myListItems for non-selected season: $isInMyList',
          );
        }
      }

      // If we still have no data from selectedSeason and _myListItems is empty,
      // make sure to fetch My List data first
      if (!usedSelectedSeasonData && _myListItems.isEmpty) {
        DebugLogger.api(
          'đ Provider: My List items empty, ensuring fresh data',
        );
        await fetchMyList();

        // Re-check with fresh data
        isInMyList = _myListItems.any((item) {
          final season = item['season'];
          return season != null && season['id'] == seasonId;
        });
        DebugLogger.api(
          'đ Provider: Re-checked with fresh My List data: $isInMyList',
        );
      }

      DebugLogger.api(
        'đ Provider: Determined My List status for season $seasonId: $isInMyList',
      );

      String apiUrl;
      Map<String, dynamic>? requestBody;
      http.Response response;

      final Map<String, String> headers = {
        ...Url.baakhapaaAuthHeaders(authToken),
        'Content-Type': 'application/json',
      };

      if (isInMyList) {
        // Remove from My List using DELETE API pattern
        apiUrl = Url.baakhapaaApi('/my-list/$seasonId');
        DebugLogger.api(
          'đ Provider: REMOVING season $seasonId from My List using DELETE $apiUrl',
        );

        response = await http.delete(Uri.parse(apiUrl), headers: headers);
      } else {
        // Add to My List using POST
        apiUrl = Url.baakhapaaApi('/my-list/store');
        requestBody = {'season_id': seasonId};
        DebugLogger.api(
          'đ Provider: ADDING season $seasonId to My List using POST $apiUrl',
        );

        response = await http.post(
          Uri.parse(apiUrl),
          headers: headers,
          body: json.encode(requestBody),
        );
      }

      DebugLogger.api(
        'đ My List Toggle API Response Status: ${response.statusCode}',
      );
      DebugLogger.api(
          'đ My List Toggle API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          DebugLogger.api('đ My List item toggled successfully');

          // Update the selected season's my_list field if it's the same season
          if (_selectedSeason.isNotEmpty && _selectedSeason['id'] == seasonId) {
            _selectedSeason['my_list'] = !isInMyList; // Toggle the value
            DebugLogger.api(
              'đ Updated selectedSeason my_list field to: ${_selectedSeason['my_list']}',
            );
          }

          // Refresh My List to get updated data
          await fetchMyList();

          return true;
        } else {
          DebugLogger.api(
            'đ My List Toggle API Error: ${responseData['message']}',
          );
          return false;
        }
      } else {
        DebugLogger.api(
          'đ My List Toggle API Error: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      DebugLogger.api('đ Error toggling my list item: $e');
      return false;
    }
  }

  // Check if a season is in My List
  bool isSeasonInMyList(int seasonId) {
    // Prioritize selectedSeason data if available (most accurate)
    if (_selectedSeason.isNotEmpty && _selectedSeason['id'] == seasonId) {
      if (_selectedSeason.containsKey('my_list')) {
        return _selectedSeason['my_list'] == true;
      }
    }

    // Fall back to checking _myListItems array
    return _myListItems.any((item) {
      final season = item['season'];
      return season != null && season['id'] == seasonId;
    });
  }

  /// Helper method to normalize season data
  /// Ensures user_image, username, challenge_image_url are properly mapped
  Map<String, dynamic> _normalizeSeasonData(Map<String, dynamic> seasonData) {
    final normalized = Map<String, dynamic>.from(seasonData);

    // Map user/creator fields - check both nested 'creator' object and root level
    if (seasonData['creator'] != null && seasonData['creator'] is Map) {
      final creator = seasonData['creator'] as Map<String, dynamic>;

      // Map creator image to user_image if not already present
      if (normalized['user_image'] == null ||
          normalized['user_image'].toString().isEmpty) {
        // First try to get image from creator's images array (like creators_screen.dart)
        if (creator['images'] != null &&
            creator['images'] is List &&
            (creator['images'] as List).isNotEmpty) {
          final firstImage = (creator['images'] as List).first;
          if (firstImage is Map) {
            final t = firstImage['thumbnail'] ?? firstImage['url'];
            if (t != null && t.toString().isNotEmpty) {
              normalized['user_image'] = t;
            }
          }
        } else {
          // Fallback to other creator fields
          normalized['user_image'] = creator['image'] ??
              creator['thumbnail'] ??
              creator['user_image'] ??
              '';
        }
      }

      // Map creator username to username if not already present
      if (normalized['username'] == null ||
          normalized['username'].toString().isEmpty) {
        normalized['username'] = creator['username'] ?? creator['name'] ?? '';
      }

      // Map creator ID
      if (normalized['user_id'] == null) {
        normalized['user_id'] = creator['id'] ?? creator['user_id'];
      }
    } else {
      // If no nested creator object, DON'T use season-level fields
      // Only check if there's a user_images array at root level for the creator
      if (normalized['user_image'] == null ||
          normalized['user_image'].toString().isEmpty) {
        // This is a fallback - normally creator data should be in a nested object
        DebugLogger.warning(
            'â ď¸ Season data missing creator object, cannot extract creator image');
      }
    }

    // Map challenge fields
    if (seasonData['challenge'] != null && seasonData['challenge'] is Map) {
      final challenge = seasonData['challenge'] as Map<String, dynamic>;

      // Map challenge image
      if (normalized['challenge_image_url'] == null ||
          normalized['challenge_image_url'].toString().isEmpty) {
        normalized['challenge_image_url'] = challenge['image_url'] ??
            challenge['thumbnail'] ??
            challenge['image'] ??
            '';
      }

      // Map challenge title
      if (normalized['challenge_title'] == null ||
          normalized['challenge_title'].toString().isEmpty) {
        normalized['challenge_title'] =
            challenge['title'] ?? challenge['name'] ?? '';
      }

      // Map challenge ID
      if (normalized['challenge_id'] == null) {
        normalized['challenge_id'] =
            challenge['id'] ?? challenge['challenge_id'];
      }
    }

    return normalized;
  }

  Future<Map<String, dynamic>?> fetchSeasonDetails(int seasonId) async {
    try {
      DebugLogger.api(
          'đŹ STARTING fetchSeasonDetails - Season ID: $seasonId');

      final String apiUrl = Url.baakhapaaApi('/season-details/$seasonId');
      DebugLogger.api('đŹ API URL: $apiUrl');

      final Map<String, String> headers = Url.baakhapaaAuthHeaders(authToken);

      var response = await http.get(Uri.parse(apiUrl), headers: headers);
      DebugLogger.api('đŹ API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);
        DebugLogger.api('đŹ Season Details API Response: $responseData');

        if (responseData['success'] == true && responseData['data'] != null) {
          // Normalize the season data to ensure proper field mapping
          final normalizedData = _normalizeSeasonData(responseData['data']);
          DebugLogger.api(
              'đŹ Normalized season data - user_image: ${normalizedData['user_image']}, username: ${normalizedData['username']}, challenge_image_url: ${normalizedData['challenge_image_url']}');
          return normalizedData;
        } else {
          DebugLogger.api(
            'đŹ Season Details API Error: ${responseData['message'] ?? 'Unknown error'}',
          );
          return null;
        }
      } else {
        DebugLogger.api(
          'đŹ Season Details API Error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      DebugLogger.api('đŹ Error fetching season details: $e');
      return null;
    }
  }

  // Add this method to your Story provider class

  Future<void> fetchContinueWatching() async {
    _isLoadingContinueWatching = true;
    notifyListeners();

    try {
      DebugLogger.api(
        'âŻď¸ STARTING fetchContinueWatching - authToken length: ${authToken.length}',
      );

      final String apiUrl = Url.baakhapaaApi('/continue-watching?limit=10');
      DebugLogger.api('âŻď¸ API URL: $apiUrl');

      final Map<String, String> headers = Url.baakhapaaAuthHeaders(authToken);

      var response = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true &&
            responseData['data'] != null &&
            responseData['data']['items'] != null) {
          // â NORMALIZE: Transform reward keys from backend format to UI format
          _continueWatchingItems = List<dynamic>.from(
            (responseData['data']['items'] as List).map((item) {
              final rewardDetails = item['reward_details'] ?? {};

              // Normalize season data if it exists
              final season = item['season'] != null
                  ? _normalizeSeasonData(
                      Map<String, dynamic>.from(item['season']))
                  : item['season'];

              return {
                ...item,
                'season': season,
                'reward_details': {
                  // Backend key â UI key
                  'product': rewardDetails['product_reward'] != null ? 1 : 0,
                  'achievement':
                      rewardDetails['achievement_reward'] != null ? 1 : 0,
                  'reward_points': rewardDetails['point_reward'] ?? 0,
                },
              };
            }).toList(),
          );

          DebugLogger.api(
            'âŻď¸ Loaded ${_continueWatchingItems.length} continue watching items',
          );

          // Debug: Log first item
          if (_continueWatchingItems.isNotEmpty) {
            DebugLogger.api(
              'âŻď¸ First item: ${_continueWatchingItems.first['season']['title']}, '
              'Completion: ${_continueWatchingItems.first['completion_percentage']}%',
            );
          }

          _isLoadingContinueWatching = false;
          notifyListeners();
        } else {
          DebugLogger.api(
            'âŻď¸ Continue Watching API Error: ${responseData['message'] ?? 'Unknown error'}',
          );
          _continueWatchingItems = [];
          _isLoadingContinueWatching = false;
          notifyListeners();
        }
      } else {
        DebugLogger.api(
          'âŻď¸ Continue Watching API Error: ${response.statusCode} - ${response.body}',
        );
        _continueWatchingItems = [];
        _isLoadingContinueWatching = false;
        notifyListeners();
      }
    } catch (e) {
      DebugLogger.api('âŻď¸ Error fetching continue watching: $e');
      _continueWatchingItems = [];
      _isLoadingContinueWatching = false;
      notifyListeners();
    }
  }

  Future<void> fetchPremiumCreatorSeasons() async {
    try {
      DebugLogger.api(
        'đ STARTING fetchPremiumCreatorSeasons - authToken length: ${authToken.length}',
      );

      final String apiUrl =
          Url.baakhapaaApi('/seasons/premium-creator-seasons');
      DebugLogger.api('đ API URL: $apiUrl');

      final Map<String, String> headers = Url.baakhapaaAuthHeaders(authToken);

      var response = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true &&
            responseData['data'] != null &&
            responseData['data']['items'] != null) {
          _premiumCreatorSeasons = List<dynamic>.from(
            (responseData['data']['items'] as List).map((item) {
              final Map<String, dynamic> season =
                  Map<String, dynamic>.from(item);
              // Ensure keys expected by unified widget exist
              season['rewards'] = season['rewards'] ?? {'reward_points': 0};
              season['watched'] = season['watched'] ?? false;
              return season;
            }).toList(),
          );

          DebugLogger.api(
            'đ Loaded ${_premiumCreatorSeasons.length} premium creator seasons',
          );

          notifyListeners();
        } else {
          DebugLogger.api(
            'đ Premium Creator Seasons API Error: ${responseData['message'] ?? 'Unknown error'}',
          );
          _premiumCreatorSeasons = [];
          notifyListeners();
        }
      } else {
        DebugLogger.api(
          'đ Premium Creator Seasons API Error: ${response.statusCode} - ${response.body}',
        );
        _premiumCreatorSeasons = [];
        notifyListeners();
      }
    } catch (e) {
      DebugLogger.api('đ Error fetching premium creator seasons: $e');
      _premiumCreatorSeasons = [];
      notifyListeners();
    }
  }

  /// Fetch readable (book summary) seasons
  Future<void> fetchReadableSeasons() async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/v3/seasons?content_type=readable')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(Duration(seconds: 15));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        final dataField = responseData['data'];
        List<dynamic> rawItems = [];
        if (dataField is List) {
          rawItems = dataField;
        } else if (dataField is Map<String, dynamic>) {
          if (dataField.containsKey('items')) {
            rawItems = dataField['items'] ?? [];
          } else if (dataField.containsKey('seasons')) {
            rawItems = dataField['seasons'] ?? [];
          } else {
            final arrayFields =
                dataField.entries.where((entry) => entry.value is List);
            if (arrayFields.isNotEmpty) {
              rawItems = arrayFields.first.value;
            }
          }
        }

        _readableSeasons = rawItems
            .where((season) => season != null)
            .map<Map<String, dynamic>>((season) {
          final Map<String, dynamic> safeSeason =
              Map<String, dynamic>.from(season);
          safeSeason['content_type'] = 'readable';
          // Map image_url to thumbnail so season cards show the cover
          if ((safeSeason['thumbnail'] == null ||
                  safeSeason['thumbnail'].toString().isEmpty) &&
              safeSeason['image_url'] != null &&
              safeSeason['image_url'].toString().isNotEmpty) {
            safeSeason['thumbnail'] = safeSeason['image_url'];
          }
          return _normalizeSeasonData(safeSeason);
        }).toList();

        // Shuffle so the same books don't appear in the same order every time
        _readableSeasons.shuffle();

        DebugLogger.api(
            'đ Loaded ${_readableSeasons.length} readable seasons');
        notifyListeners();
      }
    } catch (e) {
      DebugLogger.error('đ Error fetching readable seasons: $e');
      _readableSeasons = [];
      notifyListeners();
    }
  }

  /// Fetch pages for a readable episode (chapter)
  Future<List<dynamic>> fetchEpisodePages(int episodeId) async {
    _isLoadingPages = true;
    notifyListeners();
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/episode/$episodeId/pages')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(Duration(seconds: 15));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        final dataField = responseData['data'];
        List<dynamic> pages = [];
        if (dataField is List) {
          pages = dataField;
        } else if (dataField is Map<String, dynamic>) {
          pages = dataField['items'] ?? dataField['pages'] ?? [];
        }
        _episodePages = pages;
        DebugLogger.api(
            'đ Loaded ${_episodePages.length} pages for episode $episodeId');
      } else {
        _episodePages = [];
      }
    } catch (e) {
      DebugLogger.error('đ Error fetching episode pages: $e');
      _episodePages = [];
    } finally {
      _isLoadingPages = false;
      notifyListeners();
    }
    return _episodePages;
  }

  Future<void> fetchReadingStreak({bool force = false}) async {
    // Prevent concurrent fetches
    if (_isStreakFetching) return;
    // Only fetch once per day unless forced
    if (!force && _streakLastFetched != null) {
      final now = DateTime.now();
      if (now.year == _streakLastFetched!.year &&
          now.month == _streakLastFetched!.month &&
          now.day == _streakLastFetched!.day) {
        return;
      }
    }
    _isStreakFetching = true;
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/reading/streak')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        _readingStreak = Map<String, dynamic>.from(responseData['data'] ?? {});
        _streakLastFetched = DateTime.now();
        _saveStreakToLocal();
        notifyListeners();
      }
    } catch (e) {
      DebugLogger.error('đĽ Error fetching reading streak: $e');
    } finally {
      _isStreakFetching = false;
    }
  }

  Future<void> fetchReadingHistory({int days = 30}) async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/reading/history?days=$days')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        final historyData = responseData['data']?['history'] ?? [];
        _readingHistory = List<Map<String, dynamic>>.from(
          (historyData as List).map((e) => Map<String, dynamic>.from(e)),
        );
        notifyListeners();
      }
    } catch (e) {
      DebugLogger.error('đĽ Error fetching reading history: $e');
    }
  }

  Future<Map<String, dynamic>> recordChapterComplete(int episodeId) async {
    try {
      final response = await http
          .post(
            Uri.parse(Url.baakhapaaApi('/reading/chapter-complete/$episodeId')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 10));

      DebugLogger.auth(
          'recordChapterComplete status=${response.statusCode} episodeId=$episodeId');
      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        final data = Map<String, dynamic>.from(responseData['data'] ?? {});
        DebugLogger.auth('recordChapterComplete data=$data');
        _readingStreak = data;
        _saveStreakToLocal();
        notifyListeners();
        return data;
      } else {
        DebugLogger.error('recordChapterComplete success!=true: $responseData');
      }
    } catch (e) {
      DebugLogger.error('đĽ Error recording chapter complete: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> recordVideoComplete(int episodeId) async {
    try {
      final response = await http
          .post(
            Uri.parse(Url.baakhapaaApi('/reading/video-complete/$episodeId')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 10));

      DebugLogger.auth(
          'recordVideoComplete status=${response.statusCode} episodeId=$episodeId');
      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        final data = Map<String, dynamic>.from(responseData['data'] ?? {});
        DebugLogger.auth('recordVideoComplete data=$data');
        _readingStreak = data;
        _saveStreakToLocal();
        notifyListeners();
        return data;
      } else {
        DebugLogger.error('recordVideoComplete success!=true: $responseData');
      }
    } catch (e) {
      DebugLogger.error('đĽ Error recording video complete: $e');
    }
    return {};
  }

  /// Recover a broken streak by spending 100 coins
  Future<Map<String, dynamic>> recoverStreak() async {
    try {
      final response = await http
          .post(
            Uri.parse(Url.baakhapaaApi('/reading/recover')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 10));

      DebugLogger.auth('recoverStreak status=${response.statusCode}');
      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        final data = Map<String, dynamic>.from(responseData['data'] ?? {});
        DebugLogger.auth('recoverStreak data=$data');
        // Update streak from the nested 'streak' object
        if (data['streak'] != null) {
          _readingStreak = Map<String, dynamic>.from(data['streak']);
          _saveStreakToLocal();
        }
        notifyListeners();
        return data;
      } else {
        DebugLogger.error('recoverStreak failed: ${responseData['message']}');
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to recover streak',
        };
      }
    } catch (e) {
      DebugLogger.error('đĽ Error recovering streak: $e');
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  Future<void> fetchBookRequests() async {
    try {
      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi('/book-requests')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 15));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        _bookRequests = responseData['data']?['requests'] ?? [];
        notifyListeners();
      }
    } catch (e) {
      DebugLogger.error('đ Error fetching book requests: $e');
    }
  }

  Future<bool> submitBookRequest({
    required String title,
    String? author,
    String? genre,
    String? reason,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(Url.baakhapaaApi('/book-requests')),
            headers: {
              ...Url.baakhapaaAuthHeaders(authToken),
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'title': title,
              if (author != null) 'author': author,
              if (genre != null) 'genre': genre,
              if (reason != null) 'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      return responseData['success'] == true;
    } catch (e) {
      DebugLogger.error('đ Error submitting book request: $e');
      return false;
    }
  }

  Future<bool> upvoteBookRequest(int requestId) async {
    try {
      final response = await http
          .post(
            Uri.parse(Url.baakhapaaApi('/book-requests/$requestId/upvote')),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 10));

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (responseData['success'] == true) {
        await fetchBookRequests();
        return true;
      }
    } catch (e) {
      DebugLogger.error('đ Error upvoting book request: $e');
    }
    return false;
  }

  Future<void> fetchSeasonAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/season-analytics')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        _seasonAnalytics = SeasonAnalytics.fromJson(responseData['data']);
        notifyListeners();
      } else {
        throw (responseData['message'] ?? 'Error fetching season analytics');
      }
    } catch (error) {
      DebugLogger.error('đĽ Error in fetchSeasonAnalytics: $error');
      rethrow;
    }
  }

  // Buy extra life for the current episode
  Future<Map<String, dynamic>> buyExtraLife(int episodeId) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/episode/$episodeId/buy-extra-life')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        // Update episode locally with new extra life data
        if (_episode['id'] == episodeId) {
          _episode['extra_lives_bought'] =
              responseData['data']['extra_lives_bought'];
          _episode['extra_lives_remaining'] =
              responseData['data']['extra_lives_remaining'];
          _episode['lives'] = responseData['data']['lives'];
          notifyListeners();
        }

        DebugLogger.success('â Extra life purchased successfully');
        return responseData;
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to purchase extra life');
      }
    } catch (error) {
      DebugLogger.error('â Error purchasing extra life: $error');
      throw error;
    }
  }

  // Buy duration skip for the current episode
  Future<Map<String, dynamic>> buyDurationSkip(int episodeId) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/episode/$episodeId/buy-duration-skip')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        // Update episode locally with new duration skip data
        if (_episode['id'] == episodeId) {
          _episode['duration_skips_bought'] =
              responseData['data']['duration_skips_bought'];
          _episode['duration_skips_remaining'] =
              responseData['data']['duration_skips_remaining'];
          notifyListeners();
        }

        DebugLogger.success('â Duration skip purchased successfully');
        return responseData;
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to purchase duration skip');
      }
    } catch (error) {
      DebugLogger.error('â Error purchasing duration skip: $error');
      throw error;
    }
  }

  Future<Map<String, dynamic>> useDurationSkip(int episodeId) async {
    try {
      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/episode/$episodeId/use-duration-skip')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        // Update episode locally with new duration skip data
        if (_episode['id'] == episodeId) {
          _episode['duration_skips_bought'] =
              responseData['data']['duration_skips_bought'];
          _episode['duration_skips_remaining'] =
              responseData['data']['duration_skips_remaining'];
          notifyListeners();
        }

        DebugLogger.success('â Duration skip used successfully');
        return responseData;
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to use duration skip');
      }
    } catch (error) {
      DebugLogger.error('â Error using duration skip: $error');
      throw error;
    }
  }

  /// Reset episode attempt - clears purchased lives/skips for fresh retry
  /// Called when user fails quiz or clicks "Try Again"
  Future<Map<String, dynamic>> resetEpisodeAttempt(int episodeId) async {
    try {
      DebugLogger.info(
          'đ Resetting episode attempt for episode ID: $episodeId');

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/episode/$episodeId/reset-attempt')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        // Update episode locally to reset purchased lives/skips AND watched status
        if (_episode['id'] == episodeId) {
          _episode['extra_lives_bought'] = 0;
          _episode['extra_lives_remaining'] = _episode['extra_lives'] ?? 0;
          _episode['duration_skips_bought'] = 0;
          _episode['duration_skips_remaining'] =
              _episode['max_duration_skips'] ?? 0;
          _episode['watched'] =
              false; // â CRITICAL: Clear watched status for fresh retry

          DebugLogger.success(
              'â Episode attempt reset locally (including watched status)');
          notifyListeners();
        }

        DebugLogger.success('â Episode attempt reset successfully on server');
        return responseData;
      } else {
        throw Exception(
          responseData['message'] ?? 'Failed to reset episode attempt',
        );
      }
    } catch (error) {
      DebugLogger.error('â Error resetting episode attempt: $error');
      throw error;
    }
  }

  // â Buy achievement using coins
  Future<Map<String, dynamic>> buyAchievement(int achievementId) async {
    try {
      DebugLogger.info('đ Story: Buying achievement $achievementId...');

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/buy-achievement/$achievementId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true || response.statusCode == 200) {
        DebugLogger.success(
            'â Achievement purchased! Level: ${responseData['data']['level']}, Cost: ${responseData['data']['actual_cost']}');
        return responseData['data'] ?? responseData;
      } else {
        final errorMsg =
            responseData['message'] ?? 'Failed to purchase achievement';
        DebugLogger.error('â Achievement purchase failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (error) {
      DebugLogger.error('â Error buying achievement: $error');
      throw error;
    }
  }

  // â Get user achievements
  Future<List<dynamic>> getUserAchievements() async {
    try {
      DebugLogger.info('đ Story: Fetching user achievements...');

      // Use the full userAchievements endpoint that returns all achievements with status
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('user-achievements')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true && responseData['data'] != null) {
        DebugLogger.success(
            'â Achievements fetched: ${responseData['data'].length}');
        return responseData['data'];
      } else {
        throw Exception(
            responseData['message'] ?? 'Failed to fetch achievements');
      }
    } catch (error) {
      DebugLogger.error('â Error fetching achievements: $error');
      throw error;
    }
  }
}
