import 'package:baakhapaa/helpers/helpers.dart';
import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/puppet_screen_mapping.dart';

import '../../providers/announcement.dart';
import '../../providers/auth.dart';
import '../../widgets/header.dart';
import '../../widgets/loading.dart';
import '../../screens/shorts/single_shorts_screen.dart';
import '../../screens/story/story_screen.dart';
import '../../screens/gift/gift_screen.dart';
import '../../screens/shorts/challenges_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationScreen extends StatefulWidget {
  static const routeName = '/notification-screen';

  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  var _showAllNotifications = false; // Track whether to show all or just unread
  late List<dynamic> _notification = [];

  @override
  void didChangeDependencies() {
    if (_isInit) {
      var announcement = Provider.of<Announcement>(context, listen: false);
      var auth = Provider.of<Auth>(context, listen: false);
      announcement.fetchAnnouncement().then((_) {
        if (!mounted) return;
        setState(() {
          _notification = announcement.notification;
          _isLoading = false;
        });
        // Sync the badge count to actual DB unread count so stale FCM
        // increments (e.g. from low-priority events without DB records)
        // don't keep the badge showing an incorrect number.
        final actualUnread =
            _notification.where((n) => n['read_at'] == null).length;
        auth.syncNotificationCount(actualUnread);
      });
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var announcement = Provider.of<Announcement>(context, listen: false);
      var auth = Provider.of<Auth>(context, listen: false);
      await announcement.fetchAnnouncement(page: 1);

      if (!mounted) return;
      setState(() {
        _notification = announcement.notification;
        _isLoading = false;
      });

      // Sync badge count after refresh too
      final actualUnread =
          _notification.where((n) => n['read_at'] == null).length;
      auth.syncNotificationCount(actualUnread);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notifications refreshed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh notifications'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: context.l10n.notification),
      body: _isLoading
          ? Loading()
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshNotifications,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      child: Container(
                        child: Column(
                          children: <Widget>[
                            SizedBox(height: 16),

                            // Notifications header section
                            _buildNotificationsHeader(),

                            // Notifications list
                            _buildNotificationsList(),

                            SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Clear all button — always pinned to bottom
                _buildClearAllButton(),

                SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildNotificationsHeader() {
    final unreadCount = _notification.where((n) => n['read_at'] == null).length;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.l10n.notification}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Color(0xFF082032),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  unreadCount > 0
                      ? '$unreadCount ${context.l10n.unread} ${context.l10n.notification} ${unreadCount == 1 ? '' : 's'}'
                      : context.l10n.allCaughtUp,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: unreadCount > 0
                        ? Colors.orange[600]
                        : Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade300, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    // Check if there are no notifications at all
    if (_notification.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_none_rounded,
        title: context.l10n.noNotificationsFound,
        message: context.l10n.notificationsAppearHere,
        actionText: context.l10n.refresh,
        onAction: _refreshNotifications,
      );
    }

    // Filter notifications based on current view mode
    final displayNotifications = _showAllNotifications
        ? _notification
        : _notification.where((n) => n['read_at'] == null).toList();

    // Check if there are no unread notifications when in unread-only mode
    if (!_showAllNotifications && displayNotifications.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mark_email_read_rounded,
        title: context.l10n.allCaughtUp,
        message: context.l10n.notificationsReadMessage,
        actionText:
            '${context.l10n.show} ${context.l10n.all} ${context.l10n.notification}',
        onAction: () {
          setState(() {
            _showAllNotifications = true;
          });
        },
        isAllCaughtUp: true,
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Toggle buttons for view mode
          if (_notification.isNotEmpty) _buildViewToggle(),

          // Notifications list
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: displayNotifications.length,
            itemBuilder: (context, index) {
              final notification = displayNotifications[index];
              return _buildNotificationCard(notification,
                  showAll: _showAllNotifications);
            },
          ),

          // Load More button (pagination)
          _buildLoadMoreButton(),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    final announcement = Provider.of<Announcement>(context, listen: false);

    if (!announcement.hasMore) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: announcement.isLoadingMore
              ? null
              : () async {
                  await announcement.loadMore();
                  if (mounted) {
                    setState(() {
                      _notification = announcement.notification;
                    });
                  }
                },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: announcement.isLoadingMore
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.expand_more_rounded,
                          color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Load More',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    final unreadCount = _notification.where((n) => n['read_at'] == null).length;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showAllNotifications = false;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: !_showAllNotifications
                        ? LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mark_email_unread_rounded,
                        size: 18,
                        color: !_showAllNotifications
                            ? Colors.white
                            : Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${context.l10n.unread} ($unreadCount)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: !_showAllNotifications
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showAllNotifications = true;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: _showAllNotifications
                        ? LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.all_inbox_rounded,
                        size: 18,
                        color: _showAllNotifications
                            ? Colors.white
                            : Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${context.l10n.all} (${_notification.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _showAllNotifications
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
    bool isAllCaughtUp = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(40),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAllCaughtUp
                    ? [Colors.green.shade400, Colors.green.shade600]
                    : [Colors.blue.shade400, Colors.blue.shade600],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isAllCaughtUp
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 48,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Color(0xFF082032),
            ),
          ),
          SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.grey[600],
            ),
          ),
          if (actionText != null && onAction != null) ...[
            SizedBox(height: 24),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAllCaughtUp
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isAllCaughtUp
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAllCaughtUp
                            ? Icons.visibility_rounded
                            : Icons.refresh_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        actionText,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification,
      {bool showAll = false}) {
    final isUnread = notification['read_at'] == null;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
        border: isUnread
            ? Border.all(
                color: Colors.blue.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Dismissible(
        key: ValueKey(notification['id']),
        direction:
            isUnread ? DismissDirection.endToStart : DismissDirection.none,
        background: isUnread
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mark_email_read_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Mark as read',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            : null,
        onDismissed: (direction) {
          if (isUnread) {
            Provider.of<Announcement>(context, listen: false)
                .markAsRead(notification['id'])
                .then((_) {
              showSnackBar('Notification marked as read.');
            });
          }
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleNotificationTap(notification),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification icon — type-aware
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isUnread
                            ? [Colors.blue.shade400, Colors.blue.shade600]
                            : [Colors.grey.shade400, Colors.grey.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: isUnread
                              ? Colors.blue.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _getNotificationIcon(notification['data']['type']),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),

                  // Notification content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title with read status indicator
                        Row(
                          children: [
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (isUnread) SizedBox(width: 8),
                            if (!isUnread && showAll)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'READ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                            if (!isUnread && showAll) SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                notification['data']['title'] ?? 'Notification',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? (isUnread
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.7))
                                      : (isUnread
                                          ? Color(0xFF082032)
                                          : Colors.grey[600]),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),

                        // Message preview with "Read more" functionality
                        Text(
                          notification['data']['message'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? (isUnread
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : Colors.white.withValues(alpha: 0.6))
                                    : (isUnread
                                        ? Color(0xFF4A5568)
                                        : Colors.grey[500]),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // "Tap to read more" hint if message is long
                        if ((notification['data']['message'] ?? '').length >
                            100)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 16,
                                  color: isUnread
                                      ? Colors.blue[600]
                                      : Colors.grey[500],
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Tap to read full message',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isUnread
                                        ? Colors.blue[600]
                                        : Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: 12),

                        // Time with modern styling
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            timeago.format(
                              DateTime.parse(notification['created_at']),
                              locale: 'en_short',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow indicator to show it's tappable
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Notification type → icon mapping ────────────────────────────────────
  IconData _getNotificationIcon(dynamic type) {
    switch (type?.toString()) {
      case 'shorts_liked':
        return Icons.thumb_up_alt_rounded;
      case 'shorts_commented':
        return Icons.comment_rounded;
      case 'shorts_donation_received':
      case 'season_donation_received':
        return Icons.volunteer_activism_rounded;
      case 'season_commented':
        return Icons.rate_review_rounded;
      case 'gift_available':
        return Icons.card_giftcard_rounded;
      case 'challenge_won':
        return Icons.emoji_events_rounded;
      case 'level_upgraded':
        return Icons.trending_up_rounded;
      case 'referral_joined':
        return Icons.group_add_rounded;
      case 'view_milestone':
        return Icons.visibility_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  // ─── Navigate to relevant content or fall back to details dialog ──────────
  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Mark as read silently
    if (notification['read_at'] == null) {
      Provider.of<Announcement>(context, listen: false)
          .markAsRead(notification['id']);
    }

    final data = notification['data'];
    final type = data?['type']?.toString();
    final innerData = (data?['data'] is Map)
        ? (data['data'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    switch (type) {
      case 'shorts_liked':
      case 'shorts_commented':
      case 'shorts_donation_received':
        final rawId = innerData['shorts_id'];
        final shortsId =
            rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
        if (shortsId > 0) {
          Navigator.of(context)
              .pushNamed(SingleShortsScreen.routeName, arguments: shortsId);
        } else {
          _showNotificationDetails(notification);
        }
        break;

      case 'season_commented':
      case 'season_donation_received':
        Navigator.of(context).pushNamed(StoryScreen.routeName);
        break;

      case 'gift_available':
        Navigator.of(context).pushNamed(GiftScreen.routeName);
        break;

      case 'challenge_won':
        Navigator.of(context).pushNamed(ChallengesScreen.routeName);
        break;

      default:
        _showNotificationDetails(notification);
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF1E1E1E)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  notification['data']['title'] ?? 'Notification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Color(0xFF082032),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF1A1A1A)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    notification['data']['message'] ?? 'No message content.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.9)
                          : Color(0xFF4A5568),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 6),
                    Text(
                      timeago.format(
                        DateTime.parse(notification['created_at']),
                        locale: 'en',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Provider.of<Announcement>(context, listen: false)
                    .markAsRead(notification['id'])
                    .then((_) {
                  showSnackBar('Notification marked as read.');
                });
              },
              child: Text('Mark as Read'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClearAllButton() {
    final unreadCount = _notification.where((n) => n['read_at'] == null).length;

    if (unreadCount == 0) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Provider.of<Announcement>(context, listen: false)
                .markAllAsRead()
                .then((_) {
              showSnackBar('All notifications marked as read.');
              Navigator.of(context)
                  .pushReplacementNamed(NotificationScreen.routeName);
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade600],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.clear_all_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  context.l10n.clearAllNotifications,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
