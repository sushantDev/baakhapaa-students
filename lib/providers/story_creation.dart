import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/url.dart';
import '../utils/debug_logger.dart';

class StoryCreation with ChangeNotifier {
  String authToken;

  // Metadata
  List<dynamic> _headings = [];
  List<dynamic> _genres = [];
  List<dynamic> _maturities = [];
  List<dynamic> _achievements = [];
  List<dynamic> _products = [];
  List<dynamic> _seasons = [];

  // Created content IDs
  int _newlyCreatedSeasonId = 0;
  int _newlyCreatedEpisodeId = 0;

  StoryCreation(this.authToken);

  // Getters
  List<dynamic> get headings => _headings;
  List<dynamic> get genres => _genres;
  List<dynamic> get maturities => _maturities;
  List<dynamic> get achievements => _achievements;
  List<dynamic> get products => _products;
  List<dynamic> get seasons => _seasons;
  int get newlyCreatedSeasonId => _newlyCreatedSeasonId;
  int get newlyCreatedEpisodeId => _newlyCreatedEpisodeId;

  /// Fetch season creation metadata
  Future<void> fetchSeasonMetadata() async {
    try {
      DebugLogger.info('📊 Fetching season metadata...');

      // Fetch all metadata in parallel
      final results = await Future.wait([
        http.get(
          Uri.parse(Url.baakhapaaApi('/metadata/headings')),
          headers: Url.baakhapaaAuthHeaders(authToken),
        ),
        http.get(
          Uri.parse(Url.baakhapaaApi('/metadata/genres')),
          headers: Url.baakhapaaAuthHeaders(authToken),
        ),
        http.get(
          Uri.parse(Url.baakhapaaApi('/metadata/maturities')),
          headers: Url.baakhapaaAuthHeaders(authToken),
        ),
        http.get(
          Uri.parse(Url.baakhapaaApi('/metadata/achievements')),
          headers: Url.baakhapaaAuthHeaders(authToken),
        ),
      ]);

      // Parse responses
      final headingsData = json.decode(utf8.decode(results[0].bodyBytes));
      final genresData = json.decode(utf8.decode(results[1].bodyBytes));
      final maturitiesData = json.decode(utf8.decode(results[2].bodyBytes));
      final achievementsData = json.decode(utf8.decode(results[3].bodyBytes));

      // Debug: Log response structures
      DebugLogger.info(
          '📋 Headings response: ${headingsData.runtimeType} - Keys: ${headingsData.keys}');
      DebugLogger.info(
          '📋 Genres response: ${genresData.runtimeType} - Keys: ${genresData.keys}');
      DebugLogger.info(
          '📋 Maturities response: ${maturitiesData.runtimeType} - Keys: ${maturitiesData.keys}');
      DebugLogger.info(
          '📋 Achievements response: ${achievementsData.runtimeType} - Keys: ${achievementsData.keys}');

      // Extract data from responses - handle multiple possible structures
      _headings = _extractListFromResponse(headingsData, 'headings');
      _genres = _extractListFromResponse(genresData, 'genres');
      _maturities = _extractListFromResponse(maturitiesData, 'maturities');
      _achievements =
          _extractListFromResponse(achievementsData, 'achievements');

      DebugLogger.success(
        '✅ Season metadata loaded: ${_headings.length} headings, '
        '${_genres.length} genres, ${_maturities.length} maturities, '
        '${_achievements.length} achievements',
      );
      notifyListeners();
    } catch (error) {
      DebugLogger.error('❌ Error fetching season metadata: $error');
      throw error;
    }
  }

  /// Helper method to extract list from various response structures
  List<dynamic> _extractListFromResponse(
      Map<String, dynamic> response, String key) {
    // Try different possible structures
    dynamic result;

    // Pattern 1: response['data']['items'] (common pagination pattern)
    if (response['data'] != null && response['data'] is Map) {
      final dataMap = response['data'] as Map<String, dynamic>;
      result = dataMap['items'];

      // Pattern 1b: response['data'][key] (e.g., {data: {headings: [...]}})
      if (result == null) {
        result = dataMap[key];
      }
    }

    // Pattern 2: response[key] (e.g., {headings: [...]})
    if (result == null && response[key] != null) {
      result = response[key];
    }

    // Pattern 3: response['data'] is already the list (e.g., {data: [...]})
    if (result == null &&
        response['data'] != null &&
        response['data'] is List) {
      result = response['data'];
    }

    // Pattern 4: response['items'] at root level
    if (result == null &&
        response['items'] != null &&
        response['items'] is List) {
      result = response['items'];
    }

    // Pattern 5: If nothing found, try to find any list in data object
    if (result == null && response['data'] != null && response['data'] is Map) {
      final dataMap = response['data'] as Map<String, dynamic>;
      for (var value in dataMap.values) {
        if (value is List) {
          result = value;
          break;
        }
      }
    }

    // If result is a Map (like pagination structure), look for items/results/data
    if (result != null && result is Map) {
      result =
          result['items'] ?? result['results'] ?? result['data'] ?? result[key];
    }

    // Ensure we return a List
    if (result is List) {
      DebugLogger.info('✓ Extracted ${result.length} items for $key');
      return result;
    }

    DebugLogger.warning(
        '⚠️ Could not extract list for $key, returning empty list');
    return [];
  }

  /// Fetch episode creation metadata
  Future<void> fetchEpisodeMetadata() async {
    try {
      DebugLogger.info('📊 Fetching episode metadata...');

      // Fetch products and seasons in parallel
      final results = await Future.wait([
        http.get(
          Uri.parse(Url.baakhapaaApi('/metadata/products')),
          headers: Url.baakhapaaAuthHeaders(authToken),
        ),
        http.get(
          Uri.parse(Url.baakhapaaApi('/metadata/seasons')),
          headers: Url.baakhapaaAuthHeaders(authToken),
        ),
      ]);

      // Parse responses
      final productsData = json.decode(utf8.decode(results[0].bodyBytes));
      final seasonsData = json.decode(utf8.decode(results[1].bodyBytes));

      // Debug: Log response structures
      DebugLogger.info(
          '📋 Products response: ${productsData.runtimeType} - Keys: ${productsData.keys}');
      DebugLogger.info(
          '📋 Seasons response: ${seasonsData.runtimeType} - Keys: ${seasonsData.keys}');

      // Extract data from responses using helper method
      _products = _extractListFromResponse(productsData, 'products');
      _seasons = _extractListFromResponse(seasonsData, 'seasons');

      DebugLogger.success(
        '✅ Episode metadata loaded: ${_products.length} products, ${_seasons.length} seasons',
      );
      notifyListeners();
    } catch (error) {
      DebugLogger.error('❌ Error fetching episode metadata: $error');
      throw error;
    }
  }

  /// Fetch user's created seasons
  Future<List<dynamic>> fetchMySeasons() async {
    try {
      DebugLogger.info('📚 Fetching my seasons...');

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/metadata/my-seasons')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      // Debug: Log response structure
      DebugLogger.info(
          '📋 My Seasons response: ${responseData.runtimeType} - Keys: ${responseData.keys}');

      // Log the data structure for debugging
      if (responseData['data'] != null) {
        DebugLogger.info('📋 Data keys: ${(responseData['data'] as Map).keys}');
      }

      // Extract seasons list using helper method
      // The API returns {data: {items: [...]}}
      final seasonsList = _extractListFromResponse(responseData, 'seasons');

      // Add is_challenge field with default value if missing
      final seasonsWithChallenge = seasonsList.map((season) {
        // Add is_challenge field to season if not present
        if (!season.containsKey('is_challenge') ||
            season['is_challenge'] == null) {
          season['is_challenge'] = false;
        }

        // Add is_challenge field to episodes if not present
        if (season['episodes'] != null && season['episodes'] is List) {
          season['episodes'] = (season['episodes'] as List).map((episode) {
            if (!episode.containsKey('is_challenge') ||
                episode['is_challenge'] == null) {
              episode['is_challenge'] = false;
            }
            return episode;
          }).toList();
        }

        return season;
      }).toList();

      DebugLogger.success('✅ Loaded ${seasonsWithChallenge.length} seasons');
      return seasonsWithChallenge;
    } catch (error) {
      DebugLogger.error('❌ Error fetching my seasons: $error');
      throw error;
    }
  }

  /// Create a new season
  Future<Map<String, dynamic>> createSeason({
    required String title,
    required String description,
    String? trailerUrl,
    File? videoFile,
    required List<int> headings,
    required List<int> genres,
    required List<int> maturities,
    required String director,
    String? subDirector,
    List<String>? writers,
    List<String>? casts,
    required bool isJumpAvailable,
    int? coinToJump,
    required bool isLocked,
    int? coinToUnlock,
    required String publishDate,
    List<int>? achievements,
    File? imageFile,
    // Challenge parameters
    bool? isChallenge,
    int? challengeId,
    int? storyTopicId,
    int? noOfMcq,
    int? challengePoints,
    int? challengeLives,
    List<int>? shortsIds,
    // Collaboration parameter
    int? collaborationId,
    // Collaborators parameter
    List<Map<String, dynamic>>? collaborators,
  }) async {
    try {
      DebugLogger.info('🎬 Creating season: $title');

      // ✅ Use collaborative endpoint if collaboration_id is present
      final bool hasCollaboration = collaborationId != null;
      final endpoint = hasCollaboration
          ? '/seasons/create-collaborative'
          : '/seasons/create';

      final url = Uri.parse(Url.baakhapaaApi(endpoint));

      if (hasCollaboration) {
        DebugLogger.info(
            '🤝 Using collaborative endpoint: $endpoint for collaboration #$collaborationId');
      }

      var request = http.MultipartRequest('POST', url);

      // Add authentication headers
      request.headers.addAll(Url.baakhapaaAuthHeadersWithFiles(authToken));

      // Add text fields
      request.fields['title'] = title;
      request.fields['description'] = description;

      // Debug logging
      DebugLogger.info(
          '📝 Creating Season - Title: "$title", Description: "$description"');
      DebugLogger.info(
          '🎯 Challenge Mode: $isChallenge, Challenge ID: $challengeId');
      request.fields['director'] = director;
      request.fields['is_jump_available'] = isJumpAvailable ? '1' : '0';
      request.fields['is_locked'] = isLocked ? '1' : '0';
      request.fields['publish_date'] = publishDate;

      // Add arrays as JSON
      request.fields['headings'] = jsonEncode(headings);
      request.fields['genres'] = jsonEncode(genres);
      request.fields['maturities'] = jsonEncode(maturities);

      // Optional fields
      if (subDirector != null && subDirector.isNotEmpty) {
        request.fields['sub_director'] = subDirector;
      }
      if (writers != null && writers.isNotEmpty) {
        request.fields['writers'] = jsonEncode(writers);
      }
      if (casts != null && casts.isNotEmpty) {
        request.fields['casts'] = jsonEncode(casts);
      }
      if (coinToJump != null) {
        request.fields['coin_to_jump'] = coinToJump.toString();
      }
      if (coinToUnlock != null) {
        request.fields['coin_to_unlock'] = coinToUnlock.toString();
      }
      if (achievements != null && achievements.isNotEmpty) {
        request.fields['achievements'] = jsonEncode(achievements);
      }

      // Challenge fields
      if (isChallenge == true) {
        request.fields['is_challenge'] = 'true';
        DebugLogger.info('🏆 Creating CHALLENGE season with:');
        if (challengeId != null) {
          request.fields['challenge_id'] = challengeId.toString();
          DebugLogger.info('   - Challenge ID: $challengeId');
        }
        if (storyTopicId != null) {
          request.fields['story_topic_id'] = storyTopicId.toString();
          DebugLogger.info('   - Story Topic ID: $storyTopicId');
        }
        if (noOfMcq != null) {
          request.fields['no_of_mcq'] = noOfMcq.toString();
          DebugLogger.info('   - Number of MCQs: $noOfMcq');
        }
        if (challengePoints != null) {
          request.fields['points'] = challengePoints.toString();
          DebugLogger.info('   - Points: $challengePoints');
        }
        if (challengeLives != null) {
          request.fields['lives'] = challengeLives.toString();
          DebugLogger.info('   - Lives: $challengeLives');
        }
      }

      // Collaboration field
      if (collaborationId != null) {
        request.fields['collaboration_id'] = collaborationId.toString();
        DebugLogger.info(
            '🤝 Creating collaborative season with collaboration ID: $collaborationId');
      }

      // Collaborators field - send as invited_collaborators array
      // Backend expects: invited_collaborators[i][user_id], [offer_type], [offer_amount], [message]
      if (collaborators != null && collaborators.isNotEmpty) {
        for (int i = 0; i < collaborators.length; i++) {
          final collaborator = collaborators[i];
          request.fields['invited_collaborators[$i][user_id]'] =
              collaborator['user_id'].toString();
          request.fields['invited_collaborators[$i][offer_type]'] =
              collaborator['offer_type']?.toString() ?? 'none';
          if (collaborator['offer_amount'] != null &&
              collaborator['offer_amount'] > 0) {
            request.fields['invited_collaborators[$i][offer_amount]'] =
                collaborator['offer_amount'].toString();
          }
          if (collaborator['message'] != null &&
              (collaborator['message'] as String).isNotEmpty) {
            request.fields['invited_collaborators[$i][message]'] =
                collaborator['message'];
          }
        }
        DebugLogger.info(
            '🤝 Including ${collaborators.length} collaborators in season creation');
      }

      // Add trailer video
      if (trailerUrl != null && trailerUrl.isNotEmpty) {
        request.fields['trailer_url'] = trailerUrl;
        request.fields['trailer_source'] = 'youtube';
      } else if (videoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('video', videoFile.path),
        );
        request.fields['trailer_source'] = 'upload';
      }

      // Add image
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      // Debug: Log all data being sent
      DebugLogger.info('📤 === SEASON CREATION REQUEST DATA ===');
      DebugLogger.info('📍 URL: ${url.toString()}');
      DebugLogger.info('📋 Fields:');
      request.fields.forEach((key, value) {
        if (key == 'description' && value.length > 100) {
          DebugLogger.info(
              '  - $key: ${value.substring(0, 100)}... (${value.length} chars)');
        } else {
          DebugLogger.info('  - $key: $value');
        }
      });
      DebugLogger.info('📎 Files:');
      for (var file in request.files) {
        DebugLogger.info(
            '  - ${file.field}: ${file.filename} (${file.length} bytes)');
      }
      DebugLogger.info('📤 =====================================');

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      // Debug: Log response
      DebugLogger.info('📥 Response Status: ${response.statusCode}');
      DebugLogger.info('📥 Response Body: $responseBody');

      final responseData = json.decode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle nested response structure: data.season.id or season.id
        final seasonData =
            responseData['data']?['season'] ?? responseData['season'];
        if (seasonData != null && seasonData['id'] != null) {
          _newlyCreatedSeasonId = seasonData['id'];
          DebugLogger.success(
              '✅ Season created successfully: ID $_newlyCreatedSeasonId');
          DebugLogger.success('✅ Full Response: ${jsonEncode(responseData)}');
          notifyListeners();
          return responseData;
        } else {
          DebugLogger.error('❌ Season data or ID not found in response');
          throw Exception('Season created but ID not found in response');
        }
      } else {
        DebugLogger.error(
            '❌ Failed to create season - Status: ${response.statusCode}');
        DebugLogger.error('❌ Error Response: $responseBody');
        DebugLogger.error(
            '❌ Failed to create season: ${responseData['error'] ?? responseData['message']}');
        throw Exception(responseData['error'] ??
            responseData['message'] ??
            'Failed to create season');
      }
    } catch (error) {
      DebugLogger.error('❌ Error creating season: $error');
      DebugLogger.error('❌ Error Type: ${error.runtimeType}');
      if (error is Exception) {
        DebugLogger.error('❌ Exception details: ${error.toString()}');
      }
      throw error;
    }
  }

  /// Update an existing season
  Future<Map<String, dynamic>> updateSeason({
    required int seasonId,
    required String title,
    required String description,
    String? trailerUrl,
    File? videoFile,
    required List<int> headings,
    required List<int> genres,
    required List<int> maturities,
    required String director,
    String? subDirector,
    List<String>? writers,
    List<String>? casts,
    required bool isJumpAvailable,
    int? coinToJump,
    required bool isLocked,
    int? coinToUnlock,
    required String publishDate,
    List<int>? achievements,
    File? imageFile,
    List<int>? shortsIds,
    // Collaboration parameter
    int? collaborationId,
    // Collaborators parameter
    List<Map<String, dynamic>>? collaborators,
  }) async {
    try {
      DebugLogger.info('✏️ Updating season: $seasonId - $title');

      final url = Uri.parse(Url.baakhapaaApi('/seasons/$seasonId'));
      // Use POST with _method=PUT for Laravel multipart/form-data compatibility
      var request = http.MultipartRequest('POST', url);

      // Add authentication headers
      request.headers.addAll(Url.baakhapaaAuthHeadersWithFiles(authToken));

      // Add _method field for Laravel
      request.fields['_method'] = 'PUT';

      // Add text fields (same as create)
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['director'] = director;
      request.fields['is_jump_available'] = isJumpAvailable ? '1' : '0';
      request.fields['is_locked'] = isLocked ? '1' : '0';
      request.fields['publish_date'] = publishDate;

      // Add arrays as JSON
      request.fields['headings'] = jsonEncode(headings);
      request.fields['genres'] = jsonEncode(genres);
      request.fields['maturities'] = jsonEncode(maturities);

      // Optional fields
      if (subDirector != null && subDirector.isNotEmpty) {
        request.fields['sub_director'] = subDirector;
      }
      if (writers != null && writers.isNotEmpty) {
        request.fields['writers'] = jsonEncode(writers);
      }
      if (casts != null && casts.isNotEmpty) {
        request.fields['casts'] = jsonEncode(casts);
      }
      if (coinToJump != null) {
        request.fields['coin_to_jump'] = coinToJump.toString();
      }
      if (coinToUnlock != null) {
        request.fields['coin_to_unlock'] = coinToUnlock.toString();
      }
      if (achievements != null && achievements.isNotEmpty) {
        request.fields['achievements'] = jsonEncode(achievements);
      }

      // Add related shorts
      if (shortsIds != null && shortsIds.isNotEmpty) {
        for (int i = 0; i < shortsIds.length; i++) {
          request.fields['shorts_ids[$i]'] = shortsIds[i].toString();
        }
        DebugLogger.info(
            '🔗 Linked ${shortsIds.length} shorts to updated season');
      }

      // Collaboration field
      if (collaborationId != null) {
        request.fields['collaboration_id'] = collaborationId.toString();
        DebugLogger.info(
            '🤝 Updating season with collaboration ID: $collaborationId');
      }

      // Collaborators field - send as invited_collaborators array
      // Backend expects: invited_collaborators[i][user_id], [offer_type], [offer_amount], [message]
      if (collaborators != null && collaborators.isNotEmpty) {
        for (int i = 0; i < collaborators.length; i++) {
          final collaborator = collaborators[i];
          request.fields['invited_collaborators[$i][user_id]'] =
              collaborator['user_id'].toString();
          request.fields['invited_collaborators[$i][offer_type]'] =
              collaborator['offer_type']?.toString() ?? 'none';
          if (collaborator['offer_amount'] != null &&
              collaborator['offer_amount'] > 0) {
            request.fields['invited_collaborators[$i][offer_amount]'] =
                collaborator['offer_amount'].toString();
          }
          if (collaborator['message'] != null &&
              (collaborator['message'] as String).isNotEmpty) {
            request.fields['invited_collaborators[$i][message]'] =
                collaborator['message'];
          }
        }
        DebugLogger.info(
            '🤝 Including ${collaborators.length} collaborators in season update');
      }

      // Add trailer video
      if (trailerUrl != null && trailerUrl.isNotEmpty) {
        request.fields['trailer_url'] = trailerUrl;
        request.fields['trailer_source'] = 'youtube';
      } else if (videoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('video', videoFile.path),
        );
        request.fields['trailer_source'] = 'upload';
      }

      // Add image
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      DebugLogger.info('📥 Update Response Status: ${response.statusCode}');
      DebugLogger.info('📥 Update Response Body: $responseBody');

      final responseData = json.decode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        DebugLogger.success('✅ Season updated successfully: ID $seasonId');
        notifyListeners();
        return responseData;
      } else {
        DebugLogger.error(
            '❌ Failed to update season - Status: ${response.statusCode}');
        throw Exception(responseData['error'] ??
            responseData['message'] ??
            'Failed to update season');
      }
    } catch (error) {
      DebugLogger.error('❌ Error updating season: $error');
      throw error;
    }
  }

  /// Get full season details by ID
  Future<Map<String, dynamic>> getSeasonDetails(int seasonId) async {
    try {
      DebugLogger.info('📖 Fetching season details: $seasonId');

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/seasons/$seasonId/show')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      DebugLogger.info(
          '📦 Season details response: ${json.encode(responseData)}');

      if (response.statusCode == 200) {
        DebugLogger.success('✅ Season details fetched successfully');

        // Extract season data - handle different response structures
        if (responseData['data'] != null) {
          // Check if data contains items array or is the season object itself
          if (responseData['data'] is Map) {
            return responseData['data'] as Map<String, dynamic>;
          } else if (responseData['data']['items'] != null &&
              responseData['data']['items'] is List &&
              (responseData['data']['items'] as List).isNotEmpty) {
            return responseData['data']['items'][0] as Map<String, dynamic>;
          }
        }

        throw Exception('Season data not found in response');
      } else {
        DebugLogger.error(
            '❌ Failed to fetch season details - Status: ${response.statusCode}');
        throw Exception(
            responseData['message'] ?? 'Failed to fetch season details');
      }
    } catch (error) {
      DebugLogger.error('❌ Error fetching season details: $error');
      throw error;
    }
  }

  /// Delete a season
  Future<void> deleteSeason(int seasonId) async {
    try {
      DebugLogger.info('🗑️ Deleting season: $seasonId');

      final response = await http.delete(
        Uri.parse(Url.baakhapaaApi('/seasons/$seasonId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 || response.statusCode == 204) {
        DebugLogger.success('✅ Season deleted successfully: ID $seasonId');
        notifyListeners();
      } else {
        DebugLogger.error(
            '❌ Failed to delete season - Status: ${response.statusCode}');
        throw Exception(responseData['message'] ?? 'Failed to delete season');
      }
    } catch (error) {
      DebugLogger.error('❌ Error deleting season: $error');
      throw error;
    }
  }

  /// Create a new episode
  Future<Map<String, dynamic>> createEpisode({
    required String title,
    required String description,
    required int seasonId,
    required int coins,
    required int lives,
    required int coinsUsers,
    required int duration,
    String? videoUrl,
    File? videoFile,
    String? videoDescription,
    required List<int> products,
    List<int>? affiliateProductIds,
    List<int>? relatedShortsIds,
    List<int>? relatedEpisodeIds,
    required String publishDate,
    File? imageFile,
    bool? isChallenge,
    int? challengeId,
    int? storyTopicId,
    int? noOfMcq,
    int? challengePoints,
    int? challengeLives,
    int? collaborationId,
  }) async {
    try {
      DebugLogger.info('📺 Creating episode: $title');

      final url = Uri.parse(Url.baakhapaaApi('/episodes/create'));
      var request = http.MultipartRequest('POST', url);

      // Add authentication headers
      request.headers.addAll(Url.baakhapaaAuthHeadersWithFiles(authToken));

      // Add fields
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['season_id'] = seasonId.toString();
      request.fields['coins'] = coins.toString();
      request.fields['lives'] = lives.toString();
      request.fields['coins_users'] = coinsUsers.toString();
      request.fields['duration'] = duration.toString();
      request.fields['publish_date'] = publishDate;
      // Send products as indexed array for multipart compatibility
      for (int i = 0; i < products.length; i++) {
        request.fields['products[$i]'] = products[i].toString();
      }

      if (affiliateProductIds != null && affiliateProductIds.isNotEmpty) {
        for (int i = 0; i < affiliateProductIds.length; i++) {
          request.fields['affiliate_product_ids[$i]'] =
              affiliateProductIds[i].toString();
        }
      }

      if (relatedShortsIds != null && relatedShortsIds.isNotEmpty) {
        for (int i = 0; i < relatedShortsIds.length; i++) {
          request.fields['related_shorts_ids[$i]'] =
              relatedShortsIds[i].toString();
        }
      }

      if (relatedEpisodeIds != null && relatedEpisodeIds.isNotEmpty) {
        for (int i = 0; i < relatedEpisodeIds.length; i++) {
          request.fields['related_episode_ids[$i]'] =
              relatedEpisodeIds[i].toString();
        }
      }

      // Challenge fields
      if (isChallenge == true) {
        request.fields['is_challenge'] = 'true';
        if (challengeId != null) {
          request.fields['challenge_id'] = challengeId.toString();
        }
        if (storyTopicId != null) {
          request.fields['story_topic_id'] = storyTopicId.toString();
        }
        if (noOfMcq != null) {
          request.fields['no_of_mcq'] = noOfMcq.toString();
        }
        if (challengePoints != null) {
          request.fields['points'] = challengePoints.toString();
        }
        if (challengeLives != null) {
          request.fields['lives'] = challengeLives.toString();
        }
      }

      // Collaboration field
      if (collaborationId != null) {
        request.fields['collaboration_id'] = collaborationId.toString();
      }

      // Optional fields
      if (videoDescription != null && videoDescription.isNotEmpty) {
        request.fields['video_description'] = videoDescription;
      }

      // Add video
      if (videoUrl != null && videoUrl.isNotEmpty) {
        request.fields['video_url'] = videoUrl;
        request.fields['video_source'] = 'youtube';
      } else if (videoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('video', videoFile.path),
        );
        request.fields['video_source'] = 'upload';
      }

      // Add image
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      DebugLogger.info(
          '📥 Episode API Response Status: ${response.statusCode}');
      DebugLogger.info('📥 Episode API Response Body: $responseBody');

      final responseData = json.decode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle the episode ID from the response
        if (responseData['id'] != null) {
          _newlyCreatedEpisodeId = responseData['id'];
        } else if (responseData['episode'] != null &&
            responseData['episode']['id'] != null) {
          _newlyCreatedEpisodeId = responseData['episode']['id'];
        }

        DebugLogger.success(
            '✅ Episode created successfully: ID $_newlyCreatedEpisodeId');
        DebugLogger.success('✅ Full Response: ${jsonEncode(responseData)}');
        notifyListeners();
        return responseData;
      } else {
        DebugLogger.error(
            '❌ Failed to create episode - Status: ${response.statusCode}');
        DebugLogger.error('❌ Error Response: $responseBody');
        DebugLogger.error(
            '❌ Failed to create episode: ${responseData['error'] ?? responseData['message']}');
        throw Exception(responseData['error'] ??
            responseData['message'] ??
            'Failed to create episode');
      }
    } catch (error) {
      DebugLogger.error('❌ Error creating episode: $error');
      DebugLogger.error('❌ Error Type: ${error.runtimeType}');
      if (error is Exception) {
        DebugLogger.error('❌ Exception details: ${error.toString()}');
      }
      throw error;
    }
  }

  /// Create a question for an episode
  Future<Map<String, dynamic>> createQuestion({
    required int episodeId,
    required String type,
    required int time,
    required String question,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      DebugLogger.info('❓ Creating question for episode $episodeId');

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/questions/create')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: jsonEncode({
          'episode_id': episodeId,
          'type': type,
          'time': time,
          'question': question,
          'answers': answers,
        }),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 || response.statusCode == 201) {
        DebugLogger.success('✅ Question created successfully');
        notifyListeners();
        return responseData;
      } else {
        throw Exception(responseData['error'] ??
            responseData['message'] ??
            'Failed to create question');
      }
    } catch (error) {
      DebugLogger.error('❌ Error creating question: $error');
      throw error;
    }
  }

  /// Get all questions for an episode
  Future<List<dynamic>> fetchEpisodeQuestions(int episodeId) async {
    try {
      DebugLogger.info('📋 Fetching questions for episode $episodeId');

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/episodes/$episodeId/questions')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final questions = responseData['data']?['questions'] ??
            responseData['questions'] ??
            [];
        DebugLogger.success('✅ Loaded ${questions.length} questions');
        return questions;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to fetch questions');
      }
    } catch (error) {
      DebugLogger.error('❌ Error fetching questions: $error');
      throw error;
    }
  }

  /// Update a question
  Future<Map<String, dynamic>> updateQuestion({
    required int questionId,
    required String type,
    required int time,
    required String question,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      DebugLogger.info('✏️ Updating question $questionId');

      final response = await http.put(
        Uri.parse(Url.baakhapaaApi('/questions/$questionId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: jsonEncode({
          'type': type,
          'time': time,
          'question': question,
          'answers': answers,
        }),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        DebugLogger.success('✅ Question updated successfully');
        notifyListeners();
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to update question');
      }
    } catch (error) {
      DebugLogger.error('❌ Error updating question: $error');
      throw error;
    }
  }

  /// Delete a question
  Future<void> deleteQuestion(int questionId) async {
    try {
      DebugLogger.info('🗑️ Deleting question $questionId');

      final response = await http.delete(
        Uri.parse(Url.baakhapaaApi('/questions/$questionId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        DebugLogger.success('✅ Question deleted successfully');
        notifyListeners();
      } else {
        throw Exception(responseData['message'] ?? 'Failed to delete question');
      }
    } catch (error) {
      DebugLogger.error('❌ Error deleting question: $error');
      throw error;
    }
  }

  /// Delete an answer
  Future<void> deleteAnswer(int answerId) async {
    try {
      DebugLogger.info('🗑️ Deleting answer $answerId');

      final response = await http.delete(
        Uri.parse(Url.baakhapaaApi('/questions/answer/$answerId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        DebugLogger.success('✅ Answer deleted successfully');
        notifyListeners();
      } else {
        throw Exception(responseData['message'] ?? 'Failed to delete answer');
      }
    } catch (error) {
      DebugLogger.error('❌ Error deleting answer: $error');
      throw error;
    }
  }

  /// Fetch episodes for a specific season
  Future<Map<String, dynamic>> fetchSeasonEpisodes(int seasonId) async {
    try {
      DebugLogger.info('📺 Fetching episodes for season ID: $seasonId');

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/seasons/$seasonId/episodes')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        DebugLogger.success(
            '✅ Episodes fetched successfully: ${responseData['data']['episodes'].length} episodes');
        return responseData['data'];
      } else {
        DebugLogger.error('❌ Failed to fetch episodes: ${response.statusCode}');
        throw Exception(responseData['message'] ?? 'Failed to fetch episodes');
      }
    } catch (error) {
      DebugLogger.error('❌ Error fetching episodes: $error');
      throw error;
    }
  }

  /// Update an existing episode
  Future<Map<String, dynamic>> fetchEpisodeDetail(int episodeId) async {
    try {
      DebugLogger.info('📖 Fetching episode details for ID: $episodeId');

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/episodes/$episodeId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        DebugLogger.success('✅ Episode details fetched successfully');
        return data['data'] as Map<String, dynamic>;
      } else {
        final error = data['message'] ?? 'Failed to fetch episode details';
        DebugLogger.error('❌ Error: $error');
        throw Exception(error);
      }
    } catch (e) {
      DebugLogger.error('❌ Exception in fetchEpisodeDetail: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateEpisode({
    required int episodeId,
    required String title,
    required String description,
    required int seasonId,
    required int coins,
    required int lives,
    required int coinsUsers,
    required int duration,
    String? videoUrl,
    File? videoFile,
    String? videoDescription,
    required List<int> products,
    List<int>? affiliateProductIds,
    List<int>? relatedShortsIds,
    List<int>? relatedEpisodeIds,
    required String publishDate,
    File? imageFile,
    int? collaborationId,
  }) async {
    try {
      DebugLogger.info('📝 Updating episode ID: $episodeId');

      final url = Uri.parse(Url.baakhapaaApi('/episodes/$episodeId'));
      var request = http.MultipartRequest('POST', url);

      // Add authentication headers
      request.headers.addAll(Url.baakhapaaAuthHeadersWithFiles(authToken));

      // Laravel multipart PUT workaround
      request.fields['_method'] = 'PUT';

      // Add fields
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['season_id'] = seasonId.toString();
      request.fields['coins'] = coins.toString();
      request.fields['lives'] = lives.toString();
      request.fields['coins_users'] = coinsUsers.toString();
      request.fields['duration'] = duration.toString();
      request.fields['publish_date'] = publishDate;
      // Send products as indexed array
      for (int i = 0; i < products.length; i++) {
        request.fields['products[$i]'] = products[i].toString();
      }

      if (affiliateProductIds != null && affiliateProductIds.isNotEmpty) {
        for (int i = 0; i < affiliateProductIds.length; i++) {
          request.fields['affiliate_product_ids[$i]'] =
              affiliateProductIds[i].toString();
        }
      }

      if (relatedShortsIds != null && relatedShortsIds.isNotEmpty) {
        for (int i = 0; i < relatedShortsIds.length; i++) {
          request.fields['related_shorts_ids[$i]'] =
              relatedShortsIds[i].toString();
        }
      }

      if (relatedEpisodeIds != null && relatedEpisodeIds.isNotEmpty) {
        for (int i = 0; i < relatedEpisodeIds.length; i++) {
          request.fields['related_episode_ids[$i]'] =
              relatedEpisodeIds[i].toString();
        }
      }

      // Collaboration field
      if (collaborationId != null) {
        request.fields['collaboration_id'] = collaborationId.toString();
      }

      // Optional fields
      if (videoDescription != null && videoDescription.isNotEmpty) {
        request.fields['video_description'] = videoDescription;
      }

      // Add video (only if new video is provided)
      if (videoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('video', videoFile.path),
        );
        request.fields['video_source'] = 'upload';
      } else if (videoUrl != null && videoUrl.isNotEmpty) {
        request.fields['video_url'] = videoUrl;
        request.fields['video_source'] = 'youtube';
      }

      // Add image (only if new image is provided)
      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      DebugLogger.info(
          '📥 Episode Update Response Status: ${response.statusCode}');
      DebugLogger.info('📥 Episode Update Response Body: $responseBody');

      final responseData = json.decode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        DebugLogger.success('✅ Episode updated successfully: ID $episodeId');
        notifyListeners();
        return responseData;
      } else {
        DebugLogger.error(
            '❌ Failed to update episode - Status: ${response.statusCode}');
        DebugLogger.error('❌ Error Response: $responseBody');
        throw Exception(responseData['error'] ??
            responseData['message'] ??
            'Failed to update episode');
      }
    } catch (error) {
      DebugLogger.error('❌ Error updating episode: $error');
      throw error;
    }
  }

  /// Delete an episode
  Future<void> deleteEpisode(int episodeId) async {
    try {
      DebugLogger.info('🗑️ Deleting episode ID: $episodeId');

      final response = await http.delete(
        Uri.parse(Url.baakhapaaApi('/episodes/$episodeId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        DebugLogger.success('✅ Episode deleted successfully');
        notifyListeners();
      } else {
        DebugLogger.error('❌ Failed to delete episode: ${response.statusCode}');
        throw Exception(responseData['message'] ?? 'Failed to delete episode');
      }
    } catch (error) {
      DebugLogger.error('❌ Error deleting episode: $error');
      throw error;
    }
  }

  /// Fetch participants for a season challenge (similar to fetchChallengeShorts for shorts)
  Future<List<dynamic>> fetchSeasonParticipants(int seasonId) async {
    try {
      DebugLogger.info(
          '👥 Fetching participants for season challenge: $seasonId');

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/seasons/$seasonId/participants')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        // Extract participants list - handle different possible response structures
        List<dynamic> participants = [];

        if (responseData['data'] != null) {
          if (responseData['data'] is List) {
            participants = responseData['data'];
          } else if (responseData['data']['items'] != null) {
            participants = responseData['data']['items'];
          } else if (responseData['data']['participants'] != null) {
            participants = responseData['data']['participants'];
          }
        }

        DebugLogger.success(
            '✅ Fetched ${participants.length} season participants');
        return participants;
      } else {
        DebugLogger.error(
            '❌ Failed to fetch season participants: ${responseData['message']}');
        return [];
      }
    } catch (error) {
      DebugLogger.error('❌ Error fetching season participants: $error');
      // Return empty list instead of throwing to prevent crashes
      return [];
    }
  }

  /// Fetch leaderboard for a season challenge
  Future<List<dynamic>> fetchSeasonLeaderboard(int seasonId) async {
    try {
      DebugLogger.info('🏆 Fetching leaderboard for season: $seasonId');

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/seasons/$seasonId/leaderboard')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        List<dynamic> leaderboard = [];

        if (responseData['data'] != null) {
          if (responseData['data'] is List) {
            leaderboard = responseData['data'];
          } else if (responseData['data']['items'] != null) {
            leaderboard = responseData['data']['items'];
          } else if (responseData['data']['leaderboard'] != null) {
            leaderboard = responseData['data']['leaderboard'];
          }
        }

        DebugLogger.success(
            '✅ Fetched ${leaderboard.length} leaderboard entries');
        return leaderboard;
      } else {
        DebugLogger.error(
            '❌ Failed to fetch season leaderboard: ${responseData['message']}');
        return [];
      }
    } catch (error) {
      DebugLogger.error('❌ Error fetching season leaderboard: $error');
      return [];
    }
  }
}
