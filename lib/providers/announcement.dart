import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/url.dart';
import '../utils/debug_logger.dart';

class Announcement with ChangeNotifier {
  bool _disposed = false;
  List<dynamic> _notification = [];
  final String authToken;
  final Function()? onNotificationRead;
  final Function()? onAllNotificationsRead;

  // Pagination state
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMore = false;
  bool _isLoadingMore = false;

  Announcement(
    this.authToken,
    this._notification, {
    this.onNotificationRead,
    this.onAllNotificationsRead,
  });

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

  List<dynamic> get notification {
    return _notification;
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  int get currentPage => _currentPage;

  int get notificationCount {
    // Note: This getter is kept for backward compatibility
    // The actual count should come from Auth.unreadNotificationCount
    int unreadNotification = 0;
    _notification.forEach(
        (noti) => noti['read_at'] == null ? unreadNotification++ : null);

    DebugLogger.info(
        '⚠️ ANNOUNCEMENT: Using deprecated notificationCount getter. Use Auth.unreadNotificationCount instead.');
    return unreadNotification;
  }

  Future<void> fetchAnnouncement({int page = 1}) async {
    if (_disposed) return;

    DebugLogger.info('🔄 ANNOUNCEMENT: Fetching notifications (page $page)...');
    try {
      final response = await http.get(
          Uri.parse(
              Url.baakhapaaApi('/local-notifications?per_page=20&page=$page')),
          headers: Url.baakhapaaAuthHeaders(authToken));

      if (_disposed) return;

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        final data = responseData['data'];

        // Parse items — handle both { items: [...] } and bare array formats
        final List<dynamic> items;
        if (data is Map && data['items'] != null) {
          items = data['items'] as List<dynamic>;
        } else if (data is List) {
          items = data;
        } else {
          items = [];
        }

        // Parse pagination metadata if available
        if (data is Map && data['pagination'] != null) {
          final pagination = data['pagination'];
          _currentPage = pagination['current_page'] ?? 1;
          _totalPages = pagination['total_pages'] ?? 1;
          _hasMore = pagination['has_more'] ?? false;
        } else {
          _currentPage = page;
          _hasMore = false;
        }

        if (page == 1) {
          _notification = items;
        } else {
          _notification = [..._notification, ...items];
        }

        final unreadCount =
            _notification.where((n) => n['read_at'] == null).length;
        DebugLogger.info(
            '✅ ANNOUNCEMENT: Fetched ${items.length} notifications (page $_currentPage/$_totalPages), total ${_notification.length}, $unreadCount unread, hasMore: $_hasMore');
        notifyListeners();
      } else {
        DebugLogger.info('❌ ANNOUNCEMENT: API returned success=false');
      }
    } catch (error) {
      DebugLogger.info('❌ ANNOUNCEMENT: Error fetching: $error');
      if (!_disposed) {
        throw (error);
      }
    }
  }

  /// Load the next page of notifications
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _disposed) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      await fetchAnnouncement(page: _currentPage + 1);
    } finally {
      _isLoadingMore = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final response = await http.get(
          Uri.parse(Url.baakhapaaApi('/mark-all-as-read')),
          headers: Url.baakhapaaAuthHeaders(authToken));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        // Mark all notifications as read in the local list
        _notification = _notification.map((n) {
          n['read_at'] = DateTime.now().toIso8601String();
          return n;
        }).toList();
        // Trigger callback to clear Auth notification count
        onAllNotificationsRead?.call();
        notifyListeners();
      }
    } catch (error) {
      throw (error);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final response = await http.get(
          Uri.parse(Url.baakhapaaApi('/mark-as-read/$id')),
          headers: Url.baakhapaaAuthHeaders(authToken));

      var responseData = json.decode(utf8.decode((response.bodyBytes)));
      if (responseData['success'] == true) {
        // Update the notification in the local list
        final index = _notification.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notification[index]['read_at'] = DateTime.now().toIso8601String();
          // Trigger callback to decrement Auth notification count
          onNotificationRead?.call();
        }
        notifyListeners();
      }
    } catch (error) {
      throw (error);
    }
  }
}
