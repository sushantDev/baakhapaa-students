import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/url.dart';
import '../models/short_topic.dart';
import '../models/shorts_analytics.dart';
import '../utils/debug_logger.dart';

class Shorts with ChangeNotifier {
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

  List<dynamic> _shorts = [];
  List<dynamic> _creatorShorts = [];
  List<dynamic> _challengeShorts = [];
  String authToken;
  List<dynamic> _shortsTopic = [];
  List<dynamic> _questions = [];
  Map _singleShorts = {};
  bool _filtered = false;
  int _newlyCreatedShortsId = 0;
  ShortsAnalytics? _shortsAnalytics;

  // Added pagination state variables
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  String _currentEndpoint = '/v2/shorts';
  Map<String, dynamic> _currentFilters = {};

  Shorts(this.authToken, this._shorts);

  // Update token without resetting pagination state
  void updateToken(String token) {
    if (authToken != token) {
      DebugLogger.info(
          '🔑 Shorts Provider: Token updated (pagination preserved - page: $_currentPage/$_totalPages)');
      authToken = token;
    }
  }

  // Factory constructor that preserves pagination state from previous instance
  Shorts.fromPrevious(String token, Shorts? previous) : authToken = token {
    if (previous != null) {
      _shorts = previous._shorts;
      _creatorShorts = previous._creatorShorts;
      _challengeShorts = previous._challengeShorts;
      _shortsTopic = previous._shortsTopic;
      _questions = previous._questions;
      _singleShorts = previous._singleShorts;
      _filtered = previous._filtered;
      _newlyCreatedShortsId = previous._newlyCreatedShortsId;
      _shortsAnalytics = previous._shortsAnalytics;
      // IMPORTANT: Preserve pagination state
      _currentPage = previous._currentPage;
      _totalPages = previous._totalPages;
      _isLoadingMore =
          false; // Never preserve loading flag — old instance's async op is orphaned
      _currentEndpoint = previous._currentEndpoint;
      _currentFilters = previous._currentFilters;
      DebugLogger.info(
          '🔄 Shorts Provider: Created from previous - preserving pagination: page $_currentPage/$_totalPages');
    }
  }

  List<dynamic> get shorts {
    return _shorts;
  }

  // Add getters for pagination state
  bool get hasMorePages {
    final result = _currentPage < _totalPages;
    DebugLogger.info(
        '🔢 Shorts Provider: hasMorePages check - page: $_currentPage, total: $_totalPages, result: $result');
    return result;
  }

  bool get isLoadingMore => _isLoadingMore;

  List<dynamic> get creatorShorts {
    return _creatorShorts;
  }

  int get newlyCreatedShortsId {
    return _newlyCreatedShortsId;
  }

  List<dynamic> get challengeShorts {
    return _challengeShorts;
  }

  int get creatorShortsCount {
    return _creatorShorts.length;
  }

  List<dynamic> get shortsTopic {
    return _shortsTopic;
  }

  List<dynamic> get questions {
    return _questions;
  }

  Map get singleShorts {
    return _singleShorts;
  }

  bool get filtered {
    return _filtered;
  }

  ShortsAnalytics? get shortsAnalytics {
    return _shortsAnalytics;
  }

  // Helper method to deduplicate shorts list
  void _deduplicateShorts() {
    final Map<int, dynamic> uniqueShorts = {};
    for (var short in _shorts) {
      if (short['id'] != null) {
        uniqueShorts[short['id']] = short;
      }
    }
    _shorts = uniqueShorts.values.toList();
    DebugLogger.info(
        '🧹 Shorts Provider: Deduplicated shorts list, now has ${_shorts.length} unique videos');
  }

  // Reset pagination state when starting a new fetch
  void _resetPagination() {
    DebugLogger.info(
        '🔄 Shorts Provider: _resetPagination() called - resetting page to 1, totalPages to 1');
    _currentPage = 1;
    _totalPages = 1;
    _shorts = [];
  }

  Future<void> fetchShorts() async {
    _resetPagination();
    _currentEndpoint = '/v2/shorts';
    _currentFilters = {};
    DebugLogger.info(
        '🚀 Shorts Provider: fetchShorts() starting - endpoint: $_currentEndpoint');
    await _fetchShortsPage(_currentPage);
    _deduplicateShorts(); // Clean up any duplicates
    DebugLogger.info(
        '✅ Shorts Provider: fetchShorts() complete - page: $_currentPage/$_totalPages, hasMore: $hasMorePages, items: ${_shorts.length}');
  }

  Future<void> fetchShortsChallenges() async {
    _resetPagination();
    _currentEndpoint = '/v2/shorts-challenge';
    _currentFilters = {};
    await _fetchShortsPage(_currentPage);
    _deduplicateShorts(); // Clean up any duplicates
  }

  // New method to fetch more shorts
  Future<void> loadMoreShorts() async {
    DebugLogger.info(
        '🔄 Shorts Provider: loadMoreShorts called - isLoading: $_isLoadingMore, hasMore: $hasMorePages');
    DebugLogger.info(
        '📊 Shorts Provider: Current state - page: $_currentPage/$_totalPages, items: ${_shorts.length}');

    if (_isLoadingMore || !hasMorePages) {
      DebugLogger.info(
          '🚫 Shorts Provider: Skipping load - isLoading: $_isLoadingMore, hasMore: $hasMorePages');
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      DebugLogger.info(
          '📥 Shorts Provider: Fetching page ${_currentPage + 1}...');
      await _fetchShortsPage(_currentPage + 1);
      _deduplicateShorts(); // Clean up any duplicates after loading more
      DebugLogger.info(
          '✅ Shorts Provider: Successfully loaded page $_currentPage, total items: ${_shorts.length}');
    } catch (error) {
      DebugLogger.error('❌ Shorts Provider: Error loading more shorts: $error');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Internal method to fetch a specific page
  Future<void> _fetchShortsPage(int page) async {
    try {
      final String endpoint = _currentEndpoint;
      final String url = endpoint + '?page=$page';

      final response = await http
          .get(
            Uri.parse(Url.baakhapaaApi(url)),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        final pagination = responseData['data']['pagination'];
        final List<dynamic> newShorts = responseData['data']['items'];

        _currentPage = pagination['current_page'];
        _totalPages = pagination['total_pages'];

        DebugLogger.info(
            '📡 Shorts Provider: API Response - page: $_currentPage/$_totalPages, new items: ${newShorts.length}, existing: ${_shorts.length}');

        if (page == 1) {
          _shorts = newShorts;
          if (_shorts.isNotEmpty) {
            DebugLogger.info('DEBUG: First short structure: ${_shorts.first}');
            DebugLogger.info(
                'DEBUG: user_id present? ${_shorts.first.containsKey('user_id')}');
            DebugLogger.info(
                'DEBUG: user_id value: ${_shorts.first['user_id']}');
          }
        } else {
          // Deduplicate before adding new shorts
          final Set<int> existingIds =
              _shorts.map((s) => s['id'] as int).toSet();
          final List<dynamic> deduplicatedShorts = newShorts
              .where((newShort) => !existingIds.contains(newShort['id']))
              .toList();

          DebugLogger.info(
              '📊 Shorts Provider: Adding ${deduplicatedShorts.length} new shorts (${newShorts.length - deduplicatedShorts.length} duplicates filtered)');
          _shorts.addAll(deduplicatedShorts);
        }

        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error fetching shorts page: $error');
    }
  }

  // Update all filter methods to work with pagination
  Future<void> fetchMostLikedShorts() async {
    _resetPagination();
    _currentEndpoint = '/v2/shorts/most-liked';
    _currentFilters = {};
    await _fetchShortsPage(_currentPage);
    _deduplicateShorts(); // Clean up any duplicates
  }

  Future<void> fetchMostPointsShorts() async {
    _resetPagination();
    _currentEndpoint = '/v2/shorts/most-points';
    _currentFilters = {};
    await _fetchShortsPage(_currentPage);
    _deduplicateShorts(); // Clean up any duplicates
  }

  Future<void> fetchLatestShorts() async {
    _resetPagination();
    _currentEndpoint = '/v2/shorts/latest';
    _currentFilters = {};
    await _fetchShortsPage(_currentPage);
    _deduplicateShorts(); // Clean up any duplicates
  }

  Future<void> fetchOldestShorts() async {
    _resetPagination();
    _currentEndpoint = '/v2/shorts/oldest';
    _currentFilters = {};
    await _fetchShortsPage(_currentPage);
    _deduplicateShorts(); // Clean up any duplicates
  }

  Future<void> fetchRandomShorts() async {
    _resetPagination();
    _currentEndpoint = '/v2/shorts/random';
    _currentFilters = {};
    await _fetchShortsPage(_currentPage);
    _deduplicateShorts(); // Clean up any duplicates
  }

  // Update filter method to work with pagination
  Future<void> filterShorts(List<ShortTopic> shortTopics) async {
    _resetPagination();
    _currentEndpoint = '/v2/shorts/filter';
    _currentFilters = {'shortTopics': shortTopics};

    try {
      final response = await http
          .post(
            Uri.parse(
              Url.baakhapaaApi('/shorts/filter?page=$_currentPage'),
            ),
            headers: Url.baakhapaaAuthHeaders(authToken),
            body: json.encode(shortTopics),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        final pagination = responseData['data']['pagination'];

        _shorts = responseData['data']['items'];
        _filtered = true;

        _currentPage = pagination['current_page'];
        _totalPages = pagination['total_pages'];

        _deduplicateShorts(); // Clean up any duplicates in filtered results

        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error filtering shorts: $error');
    }
  }

  // New method to load more filtered shorts
  Future<void> loadMoreFilteredShorts() async {
    if (_isLoadingMore || !hasMorePages) return;

    _isLoadingMore = true;
    notifyListeners();

    final nextPage = _currentPage + 1;

    try {
      if (_currentEndpoint == '/v2/shorts/filter') {
        final response = await http.post(
          Uri.parse(
            Url.baakhapaaApi('/shorts/filter?page=$nextPage'),
          ),
          headers: Url.baakhapaaAuthHeaders(authToken),
          body: json.encode(_currentFilters['shortTopics']),
        );

        var responseData = json.decode(utf8.decode((response.bodyBytes)));
        if (responseData['success']) {
          final pagination = responseData['data']['pagination'];
          final List<dynamic> newShorts = responseData['data']['items'];

          _currentPage = pagination['current_page'];
          _totalPages = pagination['total_pages'];

          // Deduplicate before adding new filtered shorts
          final Set<int> existingIds =
              _shorts.map((s) => s['id'] as int).toSet();
          final List<dynamic> deduplicatedShorts = newShorts
              .where((newShort) => !existingIds.contains(newShort['id']))
              .toList();

          DebugLogger.info(
              '📊 Filtered Shorts: Adding ${deduplicatedShorts.length} new shorts (${newShorts.length - deduplicatedShorts.length} duplicates filtered)');
          _shorts.addAll(deduplicatedShorts);
          notifyListeners();
        } else {
          throw ('Error');
        }
      } else {
        await _fetchShortsPage(nextPage);
        _deduplicateShorts(); // Clean up any duplicates after loading more filtered shorts
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> clearFilter() async {
    try {
      _filtered = false;
      await fetchShorts();
    } catch (error) {
      DebugLogger.error('Error clearing filter: $error');
    }
  }

  Future<void> fetchSingleShorts(dynamic shortsId) async {
    try {
      // Handle both int and string IDs
      final String idString = shortsId.toString();

      final response = await http
          .get(
            Uri.parse(
              Url.baakhapaaApi('/shorts/$idString'),
            ),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _singleShorts = responseData['data'];
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error fetching single shorts: $error');
    }
  }

  Future<void> fetchShortsTopic() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              Url.baakhapaaApi('/shorts-topics'),
            ),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _shortsTopic = responseData['data']['items'];
        notifyListeners();
      } else {
        throw (responseData['message'] ?? 'Error fetching shorts topics');
      }
    } catch (error) {
      DebugLogger.error('Error fetching shorts topics: $error');
    }
  }

  Future<void> watched(int shortsId) async {
    try {
      final response = await http.get(
        Uri.parse(
          Url.baakhapaaApi('/shorts-view/$shortsId'),
        ),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> liked(int shortsId) async {
    try {
      final response = await http.get(
        Uri.parse(
          Url.baakhapaaApi('/shorts-like/$shortsId'),
        ),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        // Update the liked status in both regular shorts and challenge shorts
        _updateLikeStatusInLists(shortsId, true);
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> unliked(int shortsId) async {
    try {
      final response = await http.get(
        Uri.parse(
          Url.baakhapaaApi('/shorts-unlike/$shortsId'),
        ),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        // Update the liked status in both regular shorts and challenge shorts
        _updateLikeStatusInLists(shortsId, false);
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      throw error;
    }
  }

  // Helper method to update like status across all lists.
  // NOTE: Only sets the 'liked' boolean flag. The 'likes' count is already
  // updated by the optimistic UI callback (ShortsScreen.likeAndUnlike) before
  // the API call even fires. Incrementing here again would cause +2 bug.
  void _updateLikeStatusInLists(int shortsId, bool isLiked) {
    // Update in regular shorts
    for (int i = 0; i < _shorts.length; i++) {
      if (_shorts[i]['id'] == shortsId) {
        _shorts[i]['liked'] = isLiked;
        break;
      }
    }

    // Update in challenge shorts
    for (int i = 0; i < _challengeShorts.length; i++) {
      if (_challengeShorts[i]['id'] == shortsId) {
        _challengeShorts[i]['liked'] = isLiked;
        break;
      }
    }

    // Update in creator shorts as well
    for (int i = 0; i < _creatorShorts.length; i++) {
      if (_creatorShorts[i]['id'] == shortsId) {
        _creatorShorts[i]['liked'] = isLiked;
        break;
      }
    }
  }

  Future<void> fetchShortsQuestions(int shortsId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              Url.baakhapaaApi('/shorts/$shortsId/questions'),
            ),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _questions = responseData['data']['items'];
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error fetching shorts questions: $error');
    }
  }

  Future<void> shortsWatched(int userId, int shortsId, String shortsTitle,
      int shortsRewardCoin, int shortsCoinsUsers, int fallBackPoints) async {
    try {
      if (shortsCoinsUsers == 0) {
        // for baakhapaa episodes reward process
        final paymentResponse = await http.post(
          Uri.parse(
            Url.baakhapaaApi('/coin-transaction'),
          ),
          headers: Url.baakhapaaAuthHeaders(authToken),
          body: json.encode({
            'user_id': userId,
            'status': 'credited',
            'coin': fallBackPoints,
            'remarks':
                'Shorts "$shortsTitle" has been completed. You have received fallback points because the creator\'s allocated points have already been used.',
          }),
        );
        var responseData = json.decode(paymentResponse.body);
        if (responseData['code'] >= 400) {
          throw responseData['message'];
        }
        if (responseData['success']) {
          await http.get(
            Uri.parse(
              Url.baakhapaaApi('/shorts-view/$shortsId'),
            ),
            headers: Url.baakhapaaAuthHeaders(authToken),
          );
          notifyListeners();
        }
      } else {
        // for creators shorts reward process
        if (shortsCoinsUsers > 0) {
          await http
              .get(
            Uri.parse(
              Url.baakhapaaApi('/shorts/$shortsId/deduct-coins-users'),
            ),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
              .then((_) async {
            await http.post(
              Uri.parse(
                Url.baakhapaaApi('/coin-transaction'),
              ),
              headers: Url.baakhapaaAuthHeaders(authToken),
              body: json.encode({
                'user_id': userId,
                'status': 'credited',
                'coin': shortsRewardCoin,
                'remarks': 'Shorts "$shortsTitle" completed',
              }),
            );
          });
        }
        await http.get(
          Uri.parse(
            Url.baakhapaaApi('/shorts-view/$shortsId'),
          ),
          headers: Url.baakhapaaAuthHeaders(authToken),
        );
        // Mark quiz as completed across all lists
        _markQuizAsCompleted(shortsId);
        notifyListeners();
      }
    } catch (error) {
      throw error;
    }
  }

  // Helper method to mark quiz as completed across all lists
  void _markQuizAsCompleted(int shortsId) {
    // Update in regular shorts
    for (int i = 0; i < _shorts.length; i++) {
      if (_shorts[i]['id'] == shortsId) {
        _shorts[i]['viewed'] = true;
        // Also set coins_users to 0 since quiz is completed
        _shorts[i]['coins_users'] = 0;
        break;
      }
    }

    // Update in challenge shorts
    for (int i = 0; i < _challengeShorts.length; i++) {
      if (_challengeShorts[i]['id'] == shortsId) {
        _challengeShorts[i]['viewed'] = true;
        // Also set coins_users to 0 since quiz is completed
        _challengeShorts[i]['coins_users'] = 0;
        break;
      }
    }

    // Update in creator shorts as well
    for (int i = 0; i < _creatorShorts.length; i++) {
      if (_creatorShorts[i]['id'] == shortsId) {
        _creatorShorts[i]['viewed'] = true;
        // Also set coins_users to 0 since quiz is completed
        _creatorShorts[i]['coins_users'] = 0;
        break;
      }
    }
  }

  Future<List<dynamic>> fetchCreatorShorts(int creatorId,
      {bool returnList = false}) async {
    try {
      DebugLogger.info('🎬 Fetching creator shorts for creator ID: $creatorId');
      final url = Url.baakhapaaApi('/shorts/$creatorId/list');
      DebugLogger.info('🎬 API URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      DebugLogger.info('🎬 Response status: ${response.statusCode}');

      // Handle rate limiting
      if (response.statusCode == 429) {
        DebugLogger.error('🎬 Rate limited for creator $creatorId');
        throw Exception('429');
      }

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      DebugLogger.info('🎬 Response success: ${responseData['success']}');

      if (responseData['success'] == true) {
        final dataField = responseData['data'];
        DebugLogger.info('🎬 Data field type: ${dataField?.runtimeType}');

        final items = responseData['data'] != null
            ? (responseData['data']['items'] ?? [])
            : [];
        DebugLogger.info(
            '🎬 Extracted ${items is List ? items.length : 0} items from data.items');

        final list = items is List ? List<dynamic>.from(items) : <dynamic>[];

        DebugLogger.info('🎬 Final list size: ${list.length}');
        DebugLogger.info('🎬 Returning list for creator $creatorId');

        if (!returnList) {
          // update provider state (unchanged behavior)
          _creatorShorts = list;
          notifyListeners();
        }

        // Return the list so callers can use it directly
        return list;
      } else {
        if (!returnList) {
          _creatorShorts = [];
          notifyListeners();
        }
        return [];
      }
    } catch (e, st) {
      DebugLogger.error('fetchCreatorShorts error: $e\n$st');
      if (!returnList) {
        _creatorShorts = [];
        try {
          notifyListeners();
        } catch (_) {}
      }
      return [];
    }
  }

  // Future<void> fetchCreatorShorts(int creatorId) async {
  //   try {
  //     DebugLogger.info('🎬 Fetching creator shorts for creator ID: $creatorId');
  //     final url = Url.baakhapaaApi('/shorts/$creatorId/list');
  //     DebugLogger.info('🌐 API URL: $url');

  //     final response = await http.get(
  //       Uri.parse(url),
  //       headers: Url.baakhapaaAuthHeaders(authToken),
  //     );

  //     DebugLogger.info(
  //         '📡 Creator shorts API response status: ${response.statusCode}');
  //     DebugLogger.info('📦 Raw response body length: ${response.body.length}');

  //     var responseData = json.decode(utf8.decode((response.bodyBytes)));
  //     DebugLogger.info('✅ Creator shorts success: ${responseData['success']}');
  //     DebugLogger.info(
  //         '📊 Full response data keys: ${responseData.keys.toList()}');

  //     if (responseData['data'] != null) {
  //       DebugLogger.info('📊 Data keys: ${responseData['data'].keys.toList()}');
  //       DebugLogger.info(
  //           '📊 Items type: ${responseData['data']['items'].runtimeType}');
  //       if (responseData['data']['items'] is List) {
  //         DebugLogger.info(
  //             '📊 Raw items count from API: ${(responseData['data']['items'] as List).length}');
  //       }
  //     }

  //     if (responseData['success']) {
  //       final items = responseData['data']['items'] ?? [];
  //       _creatorShorts = items is List ? items : [];
  //       DebugLogger.info(
  //           '✨ Creator shorts SET to: ${_creatorShorts.length} items');
  //       DebugLogger.info('🔔 Calling notifyListeners() for creator shorts');
  //       try {
  //         notifyListeners();
  //         DebugLogger.info('✅ notifyListeners() completed for creator shorts');
  //       } catch (e) {
  //         DebugLogger.info(
  //             '⚠️ notifyListeners() called after disposal (widget navigated away)');
  //       }
  //     } else {
  //       DebugLogger.error('❌ API returned success=false for creator shorts');
  //       _creatorShorts = [];
  //       try {
  //         notifyListeners();
  //       } catch (e) {
  //         DebugLogger.info('⚠️ notifyListeners() called after disposal');
  //       }
  //       throw ('Error');
  //     }
  //   } catch (error) {
  //     DebugLogger.error('💥 Error in fetchCreatorShorts: $error');
  //     if (!error.toString().contains('was used after being disposed')) {
  //       DebugLogger.error('Stack trace: ${StackTrace.current}');
  //     }
  //     _creatorShorts = [];
  //     try {
  //       notifyListeners();
  //     } catch (e) {
  //       DebugLogger.info('⚠️ notifyListeners() called after disposal');
  //     }
  //     rethrow;
  //   }
  // }

  Future<void> fetchChallengeShorts(int challengeId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              Url.baakhapaaApi('/shorts/$challengeId/challenge'),
            ),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _challengeShorts = responseData['data']['items'];
        notifyListeners();
      } else {
        throw ('Error');
      }
    } catch (error) {
      DebugLogger.error('Error fetching challenge shorts: $error');
    }
  }

  Future<void> uploadShorts(Map<String, dynamic> shortsData, File video) async {
    try {
      // ✅ Use collaborative endpoint ONLY for invitation-first flow (collaboration_id present).
      //    Inline new-collaborator invites (collaborator_ids[]) are sent to the
      //    standard /shorts/create endpoint — the backend handles invitation creation there.
      final bool hasCollaboration = shortsData['collaboration_id'] != null;
      final bool hasNewCollaborators = shortsData['collaborators'] != null &&
          (shortsData['collaborators'] as List).isNotEmpty;
      final endpoint =
          hasCollaboration ? '/shorts/create-collaborative' : '/shorts/create';

      final url = Uri.parse(Url.baakhapaaApi(endpoint));

      if (hasCollaboration) {
        DebugLogger.info(
            '🤝 Using collaborative endpoint: $endpoint for collaboration #${shortsData['collaboration_id']}');
      } else if (hasNewCollaborators) {
        DebugLogger.info(
            '🤝 Using collaborative endpoint: $endpoint for ${(shortsData['collaborators'] as List).length} new collaborator invite(s)');
      }

      var request = http.MultipartRequest('POST', url);

      request.files.add(await http.MultipartFile.fromPath('video', video.path));
      request.fields['title'] = shortsData['title'].toString();
      request.fields['description'] = shortsData['description'].toString();
      request.fields['shorts_topic_id'] =
          shortsData['shorts_topic_id'].toString();
      request.fields['coins'] = shortsData['coins'].toString();
      request.fields['coins_users'] = shortsData['coins_users'].toString();
      request.fields['lives'] = shortsData['lives'].toString();

      // ✅ CRITICAL: Include challenge_id if present
      if (shortsData['challenge_id'] != null) {
        request.fields['challenge_id'] = shortsData['challenge_id'].toString();
        DebugLogger.info(
            '🎯 Sending challenge_id to API: ${shortsData['challenge_id']}');
      }

      // Affiliate and linking fields
      if (shortsData['affiliate_product_ids'] != null &&
          (shortsData['affiliate_product_ids'] as List).isNotEmpty) {
        final ids = shortsData['affiliate_product_ids'] as List;
        for (int i = 0; i < ids.length; i++) {
          request.fields['affiliate_product_ids[$i]'] = ids[i].toString();
        }
      }
      if (shortsData['product_ids'] != null &&
          (shortsData['product_ids'] as List).isNotEmpty) {
        final ids = shortsData['product_ids'] as List;
        for (int i = 0; i < ids.length; i++) {
          request.fields['product_ids[$i]'] = ids[i].toString();
        }
      }
      if (shortsData['season_id'] != null) {
        request.fields['season_id'] = shortsData['season_id'].toString();
        DebugLogger.info(
            'ShortsProvider: season_id set: ${shortsData['season_id']}');
      }
      if (shortsData['related_shorts_ids'] != null &&
          (shortsData['related_shorts_ids'] as List).isNotEmpty) {
        final ids = shortsData['related_shorts_ids'] as List;
        for (int i = 0; i < ids.length; i++) {
          request.fields['related_shorts_ids[$i]'] = ids[i].toString();
        }
        DebugLogger.info(
            'ShortsProvider: related_shorts_ids count: ${ids.length}');
      }
      if (shortsData['related_episode_ids'] != null &&
          (shortsData['related_episode_ids'] as List).isNotEmpty) {
        final ids = shortsData['related_episode_ids'] as List;
        for (int i = 0; i < ids.length; i++) {
          request.fields['related_episode_ids[$i]'] = ids[i].toString();
        }
        DebugLogger.info(
            'ShortsProvider: related_episode_ids count: ${ids.length} (IDs: $ids)');
      }

      // ✅ COLLABORATION: Include collaborators as invited_collaborators[] (matches backend validation)
      if (shortsData['collaborators'] != null &&
          (shortsData['collaborators'] as List).isNotEmpty) {
        final collaborators = shortsData['collaborators'] as List;
        DebugLogger.info(
            '🤝 ShortsProvider: Processing ${collaborators.length} collaborators');
        for (int i = 0; i < collaborators.length; i++) {
          final collaborator = collaborators[i];
          // Send as invited_collaborators[i][field] — matches backend StoreShortsRequest validation
          request.fields['invited_collaborators[$i][user_id]'] =
              collaborator['user_id'].toString();
          DebugLogger.info(
              '🤝 Collaborator[$i]: user_id=${collaborator['user_id']}, username=${collaborator['username']}');
          // Send offer details inline (backend reads from invited_collaborators array)
          request.fields['invited_collaborators[$i][offer_type]'] =
              collaborator['offer_type']?.toString() ?? 'none';
          DebugLogger.info(
              '🤝 Collaborator[$i]: offer_type=${collaborator['offer_type'] ?? 'none'}');
          if (collaborator['offer_amount'] != null &&
              collaborator['offer_amount'] > 0) {
            request.fields['invited_collaborators[$i][offer_amount]'] =
                collaborator['offer_amount'].toString();
            DebugLogger.info(
                '🤝 Collaborator[$i]: offer_amount=${collaborator['offer_amount']}');
          }
          if (collaborator['message'] != null &&
              (collaborator['message'] as String).isNotEmpty) {
            request.fields['invited_collaborators[$i][message]'] =
                collaborator['message'];
            DebugLogger.info(
                '🤝 Collaborator[$i]: message="${collaborator['message']}"');
          }
        }
        DebugLogger.info(
            '🤝 ✅ All ${collaborators.length} collaborators added to request fields as invited_collaborators[]');
      }

      // ✅ COLLABORATION: If collaboration_id is present (invitation-first flow)
      if (shortsData['collaboration_id'] != null) {
        request.fields['collaboration_id'] =
            shortsData['collaboration_id'].toString();
        DebugLogger.info(
            '🤝 ShortsProvider: Uploading as part of collaboration #${shortsData['collaboration_id']}');
      }

      request.headers.addAll(Url.baakhapaaAuthHeadersWithFiles(authToken));

      // ─── PRE-FLIGHT DEBUG DUMP ────────────────────────────────────────────
      DebugLogger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      DebugLogger.info('📤 SHORTS UPLOAD — PRE-FLIGHT SUMMARY');
      DebugLogger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      DebugLogger.info('🌐 Endpoint  : ${url.toString()}');
      DebugLogger.info(
          '🔑 Auth token: ${authToken.isNotEmpty ? '${authToken.substring(0, authToken.length.clamp(0, 10))}… (length=${authToken.length})' : '⚠️  EMPTY TOKEN'}');
      DebugLogger.info(
          '📁 Video file: ${video.path} (exists=${video.existsSync()}, size=${video.existsSync() ? video.lengthSync() : 'N/A'} bytes)');
      DebugLogger.info('── Request fields ──────────────────────────────────');
      request.fields.forEach((key, value) {
        DebugLogger.info('   $key = $value');
      });
      DebugLogger.info('── Multipart files ─────────────────────────────────');
      for (final f in request.files) {
        DebugLogger.info(
            '   field="${f.field}"  filename="${f.filename}"  length=${f.length}');
      }
      DebugLogger.info('── Headers being sent ──────────────────────────────');
      request.headers.forEach((key, value) {
        DebugLogger.info('   $key: $value');
      });
      DebugLogger.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // ─────────────────────────────────────────────────────────────────────

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final responseData = json.decode(responseBody);

        // Log full response so we can see the structure from the collaborative endpoint
        DebugLogger.info('📥 Backend raw response: $responseData');

        // The collaborative endpoint may return the ID under a different key.
        // Try all known locations defensively.
        final data = responseData['data'];

        // Backend returns {value: false} when coin check fails (insufficient coins)
        if (data is Map && data['value'] == false) {
          throw 'Insufficient coins to create this short. Please check your balance.';
        }

        _newlyCreatedShortsId = 0;
        if (data is Map) {
          final raw = data['value'] ??
              data['id'] ??
              data['short_id'] ??
              data['shorts_id'] ??
              (data['short'] is Map ? data['short']['id'] : null) ??
              (data['shorts'] is Map ? data['shorts']['id'] : null);
          if (raw is int) {
            _newlyCreatedShortsId = raw;
          } else if (raw is String) {
            _newlyCreatedShortsId = int.tryParse(raw) ?? 0;
          }
        }

        DebugLogger.success(
            '✅ Shorts created successfully! ID: $_newlyCreatedShortsId');

        // Log backend response for collaboration debugging
        if (shortsData['collaborators'] != null &&
            (shortsData['collaborators'] as List).isNotEmpty) {
          DebugLogger.info('🤝 Backend Response: ${responseData.toString()}');
          if (responseData['data']['collaboration'] != null) {
            DebugLogger.success(
                '✅ Collaboration data in response: ${responseData['data']['collaboration']}');
          } else {
            DebugLogger.warning(
                '⚠️ No collaboration data in backend response - invitations may not be created!');
          }
        }

        notifyListeners();
      } else {
        String errorMessage = await utf8.decodeStream(response.stream);
        DebugLogger.error(
            '❌ uploadShorts HTTP ${response.statusCode} from $url → $errorMessage');

        // Extract user-friendly message from backend JSON error response
        String friendlyMessage = 'Something went wrong. Please try again.';
        try {
          final errorJson = json.decode(errorMessage);
          if (errorJson is Map) {
            // Use 'message' field but strip SQL/technical details
            final msg = errorJson['message']?.toString() ?? '';
            if (msg.contains('SQLSTATE') ||
                msg.contains('Exception') ||
                msg.contains('Connection:')) {
              friendlyMessage =
                  'A server error occurred. Please try again later.';
            } else if (msg.isNotEmpty) {
              friendlyMessage = msg;
            }
          }
        } catch (_) {
          // errorMessage wasn't valid JSON — keep friendlyMessage as-is
        }

        throw friendlyMessage;
      }
    } catch (error) {
      throw error;
    }
  }

  Future<Map<String, dynamic>> addQuestion(
      Map<String, dynamic> questionData) async {
    try {
      final response = await http.post(
        Uri.parse(
          Url.baakhapaaApi('/shorts/question/create'),
        ),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode({
          'type': questionData['type'],
          'question': questionData['question'],
          'time': questionData['time'],
          'shorts_id': questionData['shorts_id'],
          'answers': questionData['answers'],
        }),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        final newQuestion = responseData['data']['item'];
        notifyListeners();
        return newQuestion;
      } else {
        DebugLogger.api(responseData['message']);
        throw responseData['message'] ?? 'Failed to add question';
      }
    } catch (error) {
      throw error.toString();
    }
  }

  Future<Map<String, dynamic>> updateQuestion(
      Map<String, dynamic> questionData, int questionId) async {
    try {
      final response = await http.put(
        Uri.parse(
          Url.baakhapaaApi('/shorts/question/$questionId'),
        ),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode({
          'type': questionData['type'],
          'question': questionData['question'],
          'time': questionData['time'],
          'shorts_id': questionData['shorts_id'],
          'answers': questionData['answers'],
        }),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        final updatedQuestion = responseData['data'];
        final index = _questions.indexWhere((q) => q['id'] == questionId);
        if (index != -1) {
          _questions[index] = updatedQuestion;
        }
        notifyListeners();
        return updatedQuestion;
      } else {
        throw responseData['message'] ?? 'Failed to update question';
      }
    } catch (error) {
      throw error.toString();
    }
  }

  Future<void> deleteQuestion(int questionId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          Url.baakhapaaApi('/shorts/question/$questionId'),
        ),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _questions.removeWhere((question) => question['id'] == questionId);
        notifyListeners();
      } else {
        throw responseData['message'] ?? 'Failed to delete question';
      }
    } catch (error) {
      throw error.toString();
    }
  }

  Future<void> deleteShorts(int shortsId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          Url.baakhapaaApi('/shorts/$shortsId'),
        ),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _creatorShorts.removeWhere((shorts) => shorts['id'] == shortsId);
        notifyListeners();
      } else {
        throw responseData['message'] ?? 'Failed to delete shorts';
      }
    } catch (error) {
      DebugLogger.error('Error deleting shorts: $error');
      throw error;
    }
  }

  Future<void> fetchShortsAnalytics() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              Url.baakhapaaApi('/shorts-analytics'),
            ),
            headers: Url.baakhapaaAuthHeaders(authToken),
          )
          .timeout(const Duration(seconds: 15));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success']) {
        _shortsAnalytics = ShortsAnalytics.fromJson(responseData['data']);
        notifyListeners();
      } else {
        throw (responseData['message'] ?? 'Error fetching shorts analytics');
      }
    } catch (error) {
      DebugLogger.error('💥 Error in fetchShortsAnalytics: $error');
    }
  }
}
