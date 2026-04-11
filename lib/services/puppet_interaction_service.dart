import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/url.dart';
import '../models/puppet_interaction.dart';
import '../utils/debug_logger.dart';

class PuppetInteractionService {
  static String? _cachedToken;
  static String? _sessionId;

  static Future<String?> _getAuthToken() async {
    if (_cachedToken != null) return _cachedToken;

    final prefs = await SharedPreferences.getInstance();

    // First try to get the main auth token (for authenticated users)
    _cachedToken = prefs.getString('token');
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      DebugLogger.info(
          '🎭 Found main auth token: ${_cachedToken!.substring(0, 10)}...');
      return _cachedToken;
    }

    // Fallback to api_token (legacy support)
    _cachedToken = prefs.getString('api_token');
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      DebugLogger.info(
          '🎭 Found legacy api_token: ${_cachedToken!.substring(0, 10)}...');
      return _cachedToken;
    }

    // Try to extract token from user preferences (where Auth provider stores it)
    final userData = prefs.getString('userData');
    if (userData != null) {
      try {
        final userDataMap = json.decode(userData);
        final token = userDataMap['token'];
        if (token != null && token.isNotEmpty) {
          _cachedToken = token;
          DebugLogger.info(
              '🎭 Found token in userData: ${_cachedToken!.substring(0, 10)}...');
          return _cachedToken;
        }
      } catch (e) {
        DebugLogger.info('🎭 Error parsing userData for token: $e');
      }
    }

    DebugLogger.info('🎭 No auth token found - user is likely a guest');
    return null;
  }

  static Future<String> _getSessionId() async {
    if (_sessionId != null) return _sessionId!;

    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString('session_id') ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await prefs.setString('session_id', _sessionId!);
    return _sessionId!;
  }

  static void _clearCachedToken() {
    _cachedToken = null;
    DebugLogger.info('🎭 Cleared cached token due to 401 error');
  }

  // Helper method to build cache keys with context parameters
  static String _buildCacheKey(String screenName,
      {int? itemId, String? itemType}) {
    if (itemId != null && itemType != null) {
      return '${screenName}_${itemType}_$itemId';
    }
    return screenName;
  }

  static Future<List<PuppetInteraction>?> getScreenSuggestions(
    String screenName, {
    int? itemId,
    String? itemType,
  }) async {
    DebugLogger.puppet(
        '🎭 🎭 Fetching puppet suggestions for screen: $screenName');

    // Log context parameters if provided
    if (itemId != null || itemType != null) {
      DebugLogger.puppet(
          '🎭 🎭 Context parameters - itemId: $itemId, itemType: $itemType');
    }

    try {
      // Build URL with query parameters for ID-based screens
      var url = Url.baakhapaaApi('/puppets/screen/$screenName/suggestions');

      // Add query parameters if provided
      if (itemId != null && itemType != null) {
        url += '?item_id=$itemId&item_type=${itemType.toLowerCase()}';
      }

      DebugLogger.puppet('🎭 Puppet API URL: $url');

      final token = await _getAuthToken();
      DebugLogger.puppet(
          '🎭 Auth token available: ${token != null ? "YES" : "NO"}');

      final headers = token != null
          ? Url.baakhapaaAuthHeaders(token)
          : Url.baakhapaaHeaders;

      DebugLogger.puppet('🎭 Making API request to puppet service...');
      DebugLogger.puppet(
          '🎭 Using authentication: ${token != null ? "YES (User authenticated)" : "NO (Guest mode)"}');

      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse(url), headers: headers).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          DebugLogger.puppet(
              '🎭 ❌ Puppet API request timed out after 30 seconds');
          throw TimeoutException(
              'Puppet API request timed out', const Duration(seconds: 30));
        },
      );
      stopwatch.stop();
      DebugLogger.puppet(
          '🎭 ✅ API request completed in ${stopwatch.elapsedMilliseconds}ms');

      DebugLogger.puppet('🎭 Puppet API Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        DebugLogger.puppet(
            '🎭 Puppet API Full Response: $data'); // Full response debug log

        // Handle the new API structure: data.item (single object)
        if (data['data'] != null && data['data']['item'] != null) {
          final itemData = data['data']['item'];
          DebugLogger.puppet(
              '🎭 Found puppet interaction item: $itemData'); // Debug log

          final interaction = PuppetInteraction.fromJson(itemData);
          final interactions = [
            interaction
          ]; // Convert single item to list for consistency

          DebugLogger.puppet(
              '🎭 Processed 1 puppet interaction for screen: $screenName');
          DebugLogger.puppet(
              '🎭 Puppet details - ID: ${interaction.id}, Title: "${interaction.title}", Message: "${interaction.message}"');
          DebugLogger.puppet(
              '🎭 Puppet action details - Type: ${interaction.actionType}, ID: ${interaction.actionId}');

          // Cache the results
          await _cacheScreenSuggestions(screenName, interactions,
              itemId: itemId, itemType: itemType);
          return interactions;
        } else {
          DebugLogger.puppet(
              '🎭 No puppet item found in response structure for screen: $screenName'); // Debug log
          DebugLogger.puppet('🎭 Response data structure: ${data['data']}');
          DebugLogger.puppet('🎭 API Message: ${data['message']}');
          DebugLogger.puppet('🎭 Respecting API decision - no puppets to show');

          // Return empty list as API intended - no fallback
          return [];
        }
      } else if (response.statusCode == 401) {
        DebugLogger.puppet(
            '🎭 Puppet API returned 401 Unauthorized - clearing cached token');
        _clearCachedToken();
      } else {
        DebugLogger.puppet(
            '🎭 Puppet API returned error status: ${response.statusCode}');
        DebugLogger.puppet('🎭 Error response body: ${response.body}');
      }
    } catch (e) {
      DebugLogger.puppet(
          '🎭 ❌ Error fetching puppet suggestions for $screenName: $e');
      DebugLogger.puppet('🎭 ❌ Error type: ${e.runtimeType}');
      if (e is TimeoutException) {
        DebugLogger.puppet(
            '🎭 ❌ Request timed out - network may be slow or API unavailable');
      } else if (e.toString().contains('SocketException')) {
        DebugLogger.puppet(
            '🎭 ❌ Network connection error - check internet connectivity');
      } else if (e.toString().contains('HandshakeException')) {
        DebugLogger.puppet(
            '🎭 ❌ SSL/TLS handshake error - certificate or connection issue');
      } else {
        DebugLogger.puppet('🎭 ❌ Unexpected error details: $e');
      }
    }

    // Return cached data if API fails
    DebugLogger.puppet(
        '🎭 Checking for cached puppet suggestions for screen: $screenName');
    final cachedResults = await _getCachedScreenSuggestions(screenName,
        itemId: itemId, itemType: itemType);
    DebugLogger.puppet(
        '🎭 Found ${cachedResults?.length ?? 0} cached puppet suggestions');
    return cachedResults;
  }

  static Future<void> _cacheScreenSuggestions(
    String screenName,
    List<PuppetInteraction> interactions, {
    int? itemId,
    String? itemType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = interactions.map((i) => i.toJson()).toList();

      // Create cache key with context parameters for ID-based screens
      final cacheKey =
          _buildCacheKey(screenName, itemId: itemId, itemType: itemType);

      await prefs.setString('puppet_suggestions_$cacheKey', json.encode(data));
      await prefs.setInt('puppet_suggestions_${cacheKey}_timestamp',
          DateTime.now().millisecondsSinceEpoch);

      DebugLogger.puppet('🎭 🎭 Cached puppet suggestions with key: $cacheKey');
    } catch (e) {
      DebugLogger.puppet('Error caching puppet suggestions: $e');
    }
  }

  static Future<List<PuppetInteraction>?> _getCachedScreenSuggestions(
    String screenName, {
    int? itemId,
    String? itemType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create cache key with context parameters
      final cacheKey =
          _buildCacheKey(screenName, itemId: itemId, itemType: itemType);

      final cachedData = prefs.getString('puppet_suggestions_$cacheKey');
      final timestamp =
          prefs.getInt('puppet_suggestions_${cacheKey}_timestamp') ?? 0;

      // Check if cache is still valid (24 hours)
      final now = DateTime.now().millisecondsSinceEpoch;
      if (cachedData != null && (now - timestamp) < 86400000) {
        final data = json.decode(cachedData) as List;
        return data.map((item) => PuppetInteraction.fromJson(item)).toList();
      }
    } catch (e) {
      DebugLogger.puppet('Error getting cached puppet suggestions: $e');
    }
    return null;
  }

  static Future<bool> trackInteractionView(int puppetInteractionId) async {
    try {
      final url = Url.baakhapaaApi('/puppets/track/view');
      final token = await _getAuthToken();
      final sessionId = await _getSessionId();

      final headers = token != null
          ? Url.baakhapaaAuthHeaders(token)
          : Url.baakhapaaHeaders;

      final body = json.encode({
        'puppet_interaction_id': puppetInteractionId,
        'session_id': sessionId,
      });

      final response =
          await http.post(Uri.parse(url), headers: headers, body: body);
      return response.statusCode == 200;
    } catch (e) {
      DebugLogger.puppet('Error tracking interaction view: $e');
      return false;
    }
  }

  static Future<bool> trackInteractionCompletion(
    int puppetInteractionId, {
    bool isCompleted = false,
    bool isSkipped = false,
    bool isDismissed = false,
    int? timeSpentSeconds,
  }) async {
    try {
      final url = Url.baakhapaaApi('/puppets/track/completion');
      final token = await _getAuthToken();
      final sessionId = await _getSessionId();

      final headers = token != null
          ? Url.baakhapaaAuthHeaders(token)
          : Url.baakhapaaHeaders;

      final body = json.encode({
        'puppet_interaction_id': puppetInteractionId,
        'session_id': sessionId,
        'is_completed': isCompleted,
        'is_skipped': isSkipped,
        'is_dismissed': isDismissed,
        'time_spent_seconds': timeSpentSeconds,
      });

      final response =
          await http.post(Uri.parse(url), headers: headers, body: body);
      return response.statusCode == 200;
    } catch (e) {
      DebugLogger.puppet('Error tracking interaction completion: $e');
      return false;
    }
  }

  static Future<PuppetInteractionProgress?> getInteractionProgress(
      int puppetInteractionId) async {
    try {
      final url = Url.baakhapaaApi('/puppets/progress/$puppetInteractionId');
      final token = await _getAuthToken();
      final sessionId = await _getSessionId();

      final headers = token != null
          ? Url.baakhapaaAuthHeaders(token)
          : Url.baakhapaaHeaders;

      final response = await http.get(Uri.parse('$url?session_id=$sessionId'),
          headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return PuppetInteractionProgress.fromJson(data['data']);
        }
      }
    } catch (e) {
      DebugLogger.puppet('Error fetching interaction progress: $e');
    }
    return null;
  }

  // Comprehensive progress tracking method
  static Future<bool> trackProgress(
    int interactionId,
    String action, {
    double? completionPercentage,
    int? timeSpent,
    String? screenName,
    Map<String, dynamic>? interactionData,
    String? notes,
  }) async {
    DebugLogger.info('🎭 TRACK PROGRESS START');
    DebugLogger.info('🎭 interactionId: $interactionId');
    DebugLogger.info('🎭 action: $action');
    DebugLogger.info('🎭 completionPercentage: $completionPercentage');
    DebugLogger.info('🎭 timeSpent: $timeSpent');
    DebugLogger.info('🎭 screenName: $screenName');
    DebugLogger.info('🎭 notes: $notes');

    try {
      final url = Url.baakhapaaApi('/puppets/interaction/$interactionId/track');
      DebugLogger.info('🎭 API URL: $url');

      final token = await _getAuthToken();
      DebugLogger.info('🎭 Auth token present: ${token != null}');
      DebugLogger.info('🎭 Auth token length: ${token?.length ?? 0}');

      final sessionId = await _getSessionId();
      DebugLogger.info('🎭 Session ID: $sessionId');

      final headers = token != null
          ? Url.baakhapaaAuthHeaders(token)
          : Url.baakhapaaHeaders;
      DebugLogger.info('🎭 Headers: $headers');

      // Get device and app information for AI training purposes
      final defaultInteractionData = await _getDefaultInteractionData();
      DebugLogger.info('🎭 Default interaction data: $defaultInteractionData');

      final mergedInteractionData = {
        ...defaultInteractionData,
        ...?interactionData,
      };
      DebugLogger.info('🎭 Merged interaction data: $mergedInteractionData');

      // For guest users, we might need to use a different approach
      // Check if user is guest and handle accordingly
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('userData');
      bool isGuestUser = false;

      if (userData != null) {
        try {
          final userDataMap = json.decode(userData);
          final role = userDataMap['user']?['role'];
          isGuestUser = role == 'guest' || role == null;
          DebugLogger.info('🎭 User role: $role, isGuest: $isGuestUser');
        } catch (e) {
          DebugLogger.info('🎭 Error checking user role: $e');
          isGuestUser = token == null; // If no token, assume guest
        }
      } else {
        isGuestUser = token == null;
        DebugLogger.info('🎭 No userData found, isGuest: $isGuestUser');
      }

      // For guest users, add special parameters or use different endpoint
      final requestBody = {
        'action': action,
        'completion_percentage': completionPercentage ?? 0,
        'time_spent': timeSpent ?? 0,
        'screen_name': screenName,
        'interaction_data': mergedInteractionData,
        'session_id': sessionId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'notes': notes,
        'is_guest': isGuestUser, // Add guest flag
      };

      final body = json.encode(requestBody);

      DebugLogger.puppet(
          '🎭 Tracking progress: interactionId=$interactionId, action=$action, '
          'completion=${completionPercentage ?? 0}%, timeSpent=${timeSpent ?? 0}s');

      DebugLogger.info('🎭 Making HTTP POST request...');
      final response =
          await http.post(Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        DebugLogger.info('🎭 Parsed response data: $data');
        DebugLogger.puppet(
            '🎭 Progress tracking successful: ${data['message'] ?? 'OK'}');
        final success = data['success'] ?? false;
        DebugLogger.info('🎭 Success value: $success');
        return success;
      } else if (response.statusCode == 401) {
        DebugLogger.info('🎭 HTTP ERROR: 401 - Authentication failed');
        DebugLogger.info('🎭 Error body: ${response.body}');

        // Special handling for guest users - don't fail completely
        if (isGuestUser) {
          DebugLogger.info(
              '🎭 Guest user tracking failed - storing locally for future sync');
          await _storeFailedTrackingLocally(interactionId, action, requestBody);
          DebugLogger.puppet(
              '🎭 Guest progress tracking stored locally due to auth failure');
          return true; // Return success for guest users to avoid blocking UI
        } else {
          DebugLogger.puppet(
              '🎭 Progress tracking failed: Authentication required');
          return false;
        }
      } else {
        DebugLogger.info('🎭 HTTP ERROR: ${response.statusCode}');
        DebugLogger.info('🎭 Error body: ${response.body}');
        DebugLogger.puppet(
            '🎭 Progress tracking failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      DebugLogger.info('🎭 EXCEPTION in trackProgress: $e');
      DebugLogger.info('🎭 Stack trace: $stackTrace');
      DebugLogger.puppet('🎭 Error tracking progress: $e');
      return false;
    } finally {
      DebugLogger.info('🎭 TRACK PROGRESS END');
    }
  }

  // Helper method to get default interaction data for AI training
  static Future<Map<String, dynamic>> _getDefaultInteractionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return {
        'platform': 'baakhapaa',
        'session_id': await _getSessionId(),
        'user_type':
            prefs.getString('api_token') != null ? 'authenticated' : 'guest',
        'timestamp': DateTime.now().toIso8601String(),
        'timezone': DateTime.now().timeZoneName,
      };
    } catch (e) {
      DebugLogger.puppet('Error getting default interaction data: $e');
      return {
        'device_type': 'mobile',
        'platform': 'flutter',
        'session_id': await _getSessionId(),
      };
    }
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('puppet_suggestions_'))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      DebugLogger.puppet('Error clearing puppet cache: $e');
    }
  }

  // Store failed tracking attempts locally for guest users
  static Future<void> _storeFailedTrackingLocally(int interactionId,
      String action, Map<String, dynamic> requestBody) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing failed tracking attempts
      final existingData = prefs.getString('failed_puppet_tracking') ?? '[]';
      final List<dynamic> failedAttempts = json.decode(existingData);

      // Add new failed attempt
      failedAttempts.add({
        'interaction_id': interactionId,
        'action': action,
        'request_body': requestBody,
        'failed_at': DateTime.now().toIso8601String(),
      });

      // Limit to last 50 failed attempts to prevent storage bloat
      if (failedAttempts.length > 50) {
        failedAttempts.removeRange(0, failedAttempts.length - 50);
      }

      // Store back to preferences
      await prefs.setString(
          'failed_puppet_tracking', json.encode(failedAttempts));

      DebugLogger.info(
          '🎭 Stored failed tracking attempt locally. Total stored: ${failedAttempts.length}');
    } catch (e) {
      DebugLogger.info('🎭 Error storing failed tracking locally: $e');
    }
  }
}
