import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/collaboration.dart';
import '../models/url.dart';
import '../utils/debug_logger.dart';

/// Provider for managing content collaborations
/// Handles collaboration invitations, responses, and state management
///
/// Pattern: ChangeNotifier with state preservation (following Shorts.fromPrevious pattern)
/// All API calls use http package + Url.baakhapaaApi + Url.baakhapaaAuthHeaders
class CollaborationProvider with ChangeNotifier {
  String authToken;

  // State fields
  List<Collaboration> _receivedCollaborations = [];
  List<Collaboration> _sentCollaborations = [];
  bool _isLoading = false;
  String? _error;

  // Pagination for received collaborations
  int _receivedCurrentPage = 1;
  int _receivedTotalPages = 1;
  bool _isLoadingMoreReceived = false;

  // Pagination for sent collaborations
  int _sentCurrentPage = 1;
  int _sentTotalPages = 1;
  bool _isLoadingMoreSent = false;

  CollaborationProvider(this.authToken);

  // Factory constructor that preserves state from previous instance
  CollaborationProvider.fromPrevious(
      String token, CollaborationProvider? previous)
      : authToken = token {
    if (previous != null) {
      _receivedCollaborations = previous._receivedCollaborations;
      _sentCollaborations = previous._sentCollaborations;
      _isLoading = previous._isLoading;
      _error = previous._error;
      _receivedCurrentPage = previous._receivedCurrentPage;
      _receivedTotalPages = previous._receivedTotalPages;
      _isLoadingMoreReceived = previous._isLoadingMoreReceived;
      _sentCurrentPage = previous._sentCurrentPage;
      _sentTotalPages = previous._sentTotalPages;
      _isLoadingMoreSent = previous._isLoadingMoreSent;
      DebugLogger.info(
          '🔄 CollaborationProvider: Created from previous - preserving state');
    }
  }

  // Update token without resetting state
  void updateToken(String token) {
    if (authToken != token) {
      DebugLogger.info('🔑 CollaborationProvider: Token updated');
      authToken = token;
    }
  }

  // Getters
  List<Collaboration> get receivedCollaborations =>
      [..._receivedCollaborations];
  List<Collaboration> get sentCollaborations => [..._sentCollaborations];
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Pagination getters for received
  bool get hasMoreReceivedPages => _receivedCurrentPage < _receivedTotalPages;
  bool get isLoadingMoreReceived => _isLoadingMoreReceived;

  // Pagination getters for sent
  bool get hasMoreSentPages => _sentCurrentPage < _sentTotalPages;
  bool get isLoadingMoreSent => _isLoadingMoreSent;

  // Get count of pending received collaborations (for badge)
  int get pendingReceivedCount =>
      _receivedCollaborations.where((c) => c.isPending && !c.isExpired).length;

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Create a new collaboration invitation
  /// POST /api/collaborations/create
  ///
  /// Time complexity: O(n) where n is number of collaborators
  /// Space complexity: O(n) for request payload
  Future<Collaboration?> createCollaboration({
    required String title,
    required String description,
    String contentType = 'short',
    int? challengeId,
    int? contentId, // ID of the already-created content (short/season)
    required List<Map<String, dynamic>> collaborators,
    int expiresInHours = 48,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Build nested collaborators array matching backend validation:
      //   collaborators[*].user_id      — required, exists:users,id
      //   collaborators[*].offer_type   — required, in:points,gift,none
      //   collaborators[*].offer_amount — nullable, integer
      //   collaborators[*].offer_gift_id — nullable, exists:products,id
      //   collaborators[*].message      — nullable, string, max:500
      final List<Map<String, dynamic>> collaboratorsPayload = [];

      for (final c in collaborators) {
        final offerType = c['offer_type']?.toString() ?? 'none';
        final Map<String, dynamic> entry = {
          'user_id': c['user_id'],
          'offer_type': offerType,
        };
        if (offerType == 'points') {
          final amount = c['offer_amount'] ?? 0;
          if (amount > 0) entry['offer_amount'] = amount;
        }
        if (offerType == 'gift' && c['offer_gift_id'] != null) {
          entry['offer_gift_id'] = c['offer_gift_id'];
        }
        entry['message'] = c['message']?.toString() ?? '';
        collaboratorsPayload.add(entry);
      }

      final Map<String, dynamic> body = {
        'title': title,
        'description': description,
        'content_type': contentType,
        'collaborators': collaboratorsPayload,
      };
      if (challengeId != null) body['challenge_id'] = challengeId;
      if (contentId != null) body['content_id'] = contentId;

      DebugLogger.info(
          '🤝 CollaborationProvider: Sending body: ${json.encode(body)}');

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/collaborations/create')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode(body),
      );

      final rawBody = utf8.decode(response.bodyBytes);
      DebugLogger.info(
          '🤝 CollaborationProvider: HTTP ${response.statusCode} → $rawBody');
      var responseData = json.decode(rawBody);

      if (responseData['success'] == true) {
        final collaboration = Collaboration.fromJson(responseData);

        // Add to sent collaborations list
        _sentCollaborations.insert(0, collaboration);

        _isLoading = false;
        notifyListeners();

        DebugLogger.info(
            '✅ CollaborationProvider: Created collaboration #${collaboration.id}');
        return collaboration;
      } else {
        throw responseData['message'] ?? 'Failed to create collaboration';
      }
    } catch (error) {
      _error = error.toString();
      _isLoading = false;
      notifyListeners();
      DebugLogger.error('❌ CollaborationProvider: Create failed: $error');
      rethrow;
    }
  }

  /// Fetch received collaborations
  /// GET /api/collaborations/received?status=X&page=N
  ///
  /// status='all' shows both pending and active (default).
  /// status='pending' is used for notification badge count only.
  ///
  /// Time complexity: O(n) for parsing response
  /// Space complexity: O(n) for storing collaborations
  Future<void> fetchReceived({String status = 'all', int page = 1}) async {
    try {
      if (page == 1) {
        _isLoading = true;
        _receivedCollaborations = []; // Reset on first page
        _receivedCurrentPage = 1;
      } else {
        _isLoadingMoreReceived = true;
      }
      _error = null;
      notifyListeners();

      final response = await http.get(
        Uri.parse(Url.baakhapaaApi(
            '/collaborations/received?status=$status&page=$page')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        final data = responseData['data'];

        // Parse collaborations
        if (data['items'] != null && data['items'] is List) {
          final newCollaborations = (data['items'] as List)
              .map((item) => Collaboration.fromJson(item))
              .toList();

          if (page == 1) {
            _receivedCollaborations = newCollaborations;
          } else {
            _receivedCollaborations.addAll(newCollaborations);
          }
        }

        // Update pagination (backend nests under 'pagination' key)
        final pagination = data['pagination'];
        _receivedCurrentPage =
            pagination?['current_page'] ?? data['current_page'] ?? page;
        _receivedTotalPages =
            pagination?['total_pages'] ?? data['total_pages'] ?? 1;

        _isLoading = false;
        _isLoadingMoreReceived = false;
        notifyListeners();

        DebugLogger.info(
            '✅ CollaborationProvider: Fetched ${_receivedCollaborations.length} received collaborations (page $_receivedCurrentPage/$_receivedTotalPages)');
      } else {
        throw responseData['message'] ??
            'Failed to fetch received collaborations';
      }
    } catch (error) {
      _error = error.toString();
      _isLoading = false;
      _isLoadingMoreReceived = false;
      notifyListeners();
      DebugLogger.error(
          '❌ CollaborationProvider: Fetch received failed: $error');
      rethrow;
    }
  }

  /// Load more received collaborations (pagination)
  Future<void> loadMoreReceived({String status = 'all'}) async {
    if (_isLoadingMoreReceived || !hasMoreReceivedPages) return;
    await fetchReceived(status: status, page: _receivedCurrentPage + 1);
  }

  /// Fetch sent collaborations
  /// GET /api/collaborations/sent?status=X&page=N
  ///
  /// Time complexity: O(n) for parsing response
  /// Space complexity: O(n) for storing collaborations
  Future<void> fetchSent({String status = 'all', int page = 1}) async {
    try {
      if (page == 1) {
        _isLoading = true;
        _sentCollaborations = []; // Reset on first page
        _sentCurrentPage = 1;
      } else {
        _isLoadingMoreSent = true;
      }
      _error = null;
      notifyListeners();

      final response = await http.get(
        Uri.parse(
            Url.baakhapaaApi('/collaborations/sent?status=$status&page=$page')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        final data = responseData['data'];

        // Parse collaborations
        if (data['items'] != null && data['items'] is List) {
          final newCollaborations = (data['items'] as List)
              .map((item) => Collaboration.fromJson(item))
              .toList();

          if (page == 1) {
            _sentCollaborations = newCollaborations;
          } else {
            _sentCollaborations.addAll(newCollaborations);
          }
        }

        // Update pagination (backend nests under 'pagination' key)
        final sentPagination = data['pagination'];
        _sentCurrentPage =
            sentPagination?['current_page'] ?? data['current_page'] ?? page;
        _sentTotalPages =
            sentPagination?['total_pages'] ?? data['total_pages'] ?? 1;

        _isLoading = false;
        _isLoadingMoreSent = false;
        notifyListeners();

        DebugLogger.info(
            '✅ CollaborationProvider: Fetched ${_sentCollaborations.length} sent collaborations (page $_sentCurrentPage/$_sentTotalPages)');
      } else {
        throw responseData['message'] ?? 'Failed to fetch sent collaborations';
      }
    } catch (error) {
      _error = error.toString();
      _isLoading = false;
      _isLoadingMoreSent = false;
      notifyListeners();
      DebugLogger.error('❌ CollaborationProvider: Fetch sent failed: $error');
      rethrow;
    }
  }

  /// Load more sent collaborations (pagination)
  Future<void> loadMoreSent({String status = 'all'}) async {
    if (_isLoadingMoreSent || !hasMoreSentPages) return;
    await fetchSent(status: status, page: _sentCurrentPage + 1);
  }

  /// Respond to a collaboration invitation (accept or decline)
  /// POST /api/collaborations/{id}/respond
  ///
  /// Time complexity: O(n) to find and update collaboration in list
  /// Space complexity: O(1)
  Future<bool> respondToCollaboration(
      int collaborationId, String action) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/collaborations/$collaborationId/respond')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode({
          'action': action, // 'accept' or 'decline'
        }),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        // Update the collaboration in received list
        final index =
            _receivedCollaborations.indexWhere((c) => c.id == collaborationId);
        if (index != -1) {
          if (responseData['data']?['collaboration'] != null) {
            // Backend returned the full updated object — use it
            final updatedCollaboration =
                Collaboration.fromJson(responseData['data']['collaboration']);
            _receivedCollaborations[index] = updatedCollaboration;
          } else {
            // Backend didn't return the collaboration object — optimistically
            // update the status in-place so the UI reflects the change
            // immediately without needing a network re-fetch.
            final newStatus = action == 'accept' ? 'active' : 'declined';
            _receivedCollaborations[index] =
                _receivedCollaborations[index].copyWith(status: newStatus);
          }
        }

        _isLoading = false;
        notifyListeners();

        DebugLogger.info(
            '✅ CollaborationProvider: Responded to collaboration #$collaborationId with $action');
        return true;
      } else {
        throw responseData['message'] ?? 'Failed to respond to collaboration';
      }
    } catch (error) {
      _error = error.toString();
      _isLoading = false;
      notifyListeners();
      DebugLogger.error('❌ CollaborationProvider: Respond failed: $error');
      return false;
    }
  }

  /// Accept a collaboration invitation
  Future<bool> acceptCollaboration(int collaborationId) async {
    return await respondToCollaboration(collaborationId, 'accept');
  }

  /// Decline a collaboration invitation
  Future<bool> declineCollaboration(int collaborationId) async {
    return await respondToCollaboration(collaborationId, 'decline');
  }

  /// Cancel a sent collaboration (initiator only)
  /// POST /api/collaborations/{id}/cancel
  ///
  /// Time complexity: O(n) to find and remove collaboration from list
  /// Space complexity: O(1)
  Future<bool> cancelCollaboration(int collaborationId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/collaborations/$collaborationId/cancel')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        // Remove the cancelled collaboration from sent list
        _sentCollaborations.removeWhere((c) => c.id == collaborationId);

        _isLoading = false;
        notifyListeners();

        DebugLogger.info(
            '✅ CollaborationProvider: Cancelled collaboration #$collaborationId');
        return true;
      } else {
        throw responseData['message'] ?? 'Failed to cancel collaboration';
      }
    } catch (error) {
      _error = error.toString();
      _isLoading = false;
      notifyListeners();
      DebugLogger.error('❌ CollaborationProvider: Cancel failed: $error');
      return false;
    }
  }

  /// Refresh received collaborations
  Future<void> refreshReceived({String status = 'all'}) async {
    await fetchReceived(status: status, page: 1);
  }

  /// Refresh sent collaborations
  Future<void> refreshSent({String status = 'all'}) async {
    await fetchSent(status: status, page: 1);
  }

  /// Get a single collaboration by ID from either list (in-memory cache)
  /// Time complexity: O(n) linear search
  Collaboration? getCollaborationById(int id) {
    try {
      return _receivedCollaborations.firstWhere((c) => c.id == id);
    } catch (_) {
      try {
        return _sentCollaborations.firstWhere((c) => c.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  /// Fetch a single collaboration by ID from the API and update cache
  /// GET /api/collaborations/{id}
  ///
  /// Used when navigating to detail screen after accept/respond actions
  /// where the local cache may be stale or empty.
  Future<Collaboration?> fetchCollaborationById(int id) async {
    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/collaborations/$id')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success'] == true) {
        final collaboration = Collaboration.fromJson(
          responseData['data'] is Map ? responseData['data'] : responseData,
        );

        // Update in received list if present
        final rIdx = _receivedCollaborations.indexWhere((c) => c.id == id);
        if (rIdx != -1) {
          _receivedCollaborations[rIdx] = collaboration;
        } else {
          // Check if it should be in received (user is a participant, not initiator)
          final wasReceived =
              collaboration.participants.any((p) => p.userId != 0);
          if (wasReceived) _receivedCollaborations.add(collaboration);
        }

        // Update in sent list if present
        final sIdx = _sentCollaborations.indexWhere((c) => c.id == id);
        if (sIdx != -1) {
          _sentCollaborations[sIdx] = collaboration;
        }

        notifyListeners();
        DebugLogger.success(
            '✅ CollaborationProvider: Fetched collaboration #$id from API');
        return collaboration;
      } else {
        DebugLogger.warning(
            '⚠️ CollaborationProvider: Could not fetch collaboration #$id: ${responseData['message']}');
        return null;
      }
    } catch (error) {
      DebugLogger.error(
          '❌ CollaborationProvider: fetchCollaborationById failed: $error');
      return null;
    }
  }
}
