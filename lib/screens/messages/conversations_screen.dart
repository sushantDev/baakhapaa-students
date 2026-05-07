import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/screens/messages/messages_screen.dart';
import 'package:baakhapaa/screens/messages/chat_bot_screen.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:baakhapaa/widgets/loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/puppet_screen_mapping.dart';

class ConversationsScreen extends StatefulWidget {
  static const routeName = '/conversations-screen';

  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with PuppetInteractionMixin {
  var _isInit = true;
  var _isLoading = true;
  late List<dynamic> _conversations = [];

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _initializeData();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _initializeData() async {
    try {
      var auth = Provider.of<Auth>(context, listen: false);
      await auth.fetchConversations();
      await auth.getUnreadMessageCount();

      if (mounted) {
        setState(() {
          _conversations = _sortedConversations(auth.conversations);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load conversations'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshConversations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var auth = Provider.of<Auth>(context, listen: false);
      await auth.fetchConversations();
      await auth.getUnreadMessageCount();

      if (mounted) {
        setState(() {
          _conversations = _sortedConversations(auth.conversations);
          _isLoading = false;
        });
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Conversations refreshed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh conversations'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<dynamic> _sortedConversations(List<dynamic> conversations) {
    final items = List<dynamic>.from(conversations);
    items.sort((a, b) {
      final aTime = DateTime.tryParse((a['last_message_at'] ?? '').toString());
      final bTime = DateTime.tryParse((b['last_message_at'] ?? '').toString());

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return items;
  }

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '';

    try {
      final DateTime messageTime = DateTime.parse(timeString);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(messageTime);

      if (difference.inDays > 0) {
        return DateFormat('MMM dd').format(messageTime);
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return timeString;
    }
  }

  Widget _buildEmptyState() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
            SizedBox(height: 24),
            Text(
              'No Conversations Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Start chatting with creators and other users\nto see your conversations here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshConversations,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.refresh),
              label: Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatbotCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.purple.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, ChatbotScreen.routeName);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.withValues(alpha: 0.05),
                  Colors.purple.withValues(alpha: 0.1),
                ],
              ),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Chatbot icon with animated gradient
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.purple, Colors.purple.shade300],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    // Always online indicator
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).cardColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 16),

                // Chatbot details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.purple,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Assistant',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Get instant help with points, features, and more!',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Always Online',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt,
                                  color: Colors.amber.shade700,
                                  size: 12,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Instant Reply',
                                  style: TextStyle(
                                    color: Colors.amber.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.purple.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final userImage = conversation['user_image'] ?? '';
    final name = conversation['name'] ?? '';
    final username = conversation['username'] ?? '';
    final lastMessage = conversation['lastMessage'] ?? '';
    final time = conversation['time'] ?? '';
    final displayName = name.isNotEmpty ? name : username;
    final conversationId = conversation['conversation_id'] as int;
    final unreadCount = (conversation['unread_count'] ?? 0) as int;
    final hasUnread = conversation['has_unread'] == true || unreadCount > 0;

    return Dismissible(
      key: ValueKey(conversationId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Delete Conversation'),
                content: Text(
                  'Delete chat with $displayName? This only removes it from your account.',
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        setState(() {
          _conversations.removeWhere(
            (c) => c['conversation_id'] == conversationId,
          );
        });
        try {
          final auth = Provider.of<Auth>(context, listen: false);
          await auth.deleteConversation(conversationId);
        } catch (_) {
          // If API call fails, re-fetch to restore correct state
          _initializeData();
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                MessagesScreen.routeName,
                arguments: {
                  'conversation_id': conversation['conversation_id'],
                  'user_name': displayName,
                },
              ).then((_) => _refreshConversations());
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // Profile picture with modern styling
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.amber, Colors.orange],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(2),
                        child: ClipOval(
                          child: userImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: userImage,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.amber,
                                      size: 30,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: Colors.amber.withValues(
                                      alpha: 0.1,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.amber,
                                      size: 30,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.amber,
                                    size: 30,
                                  ),
                                ),
                        ),
                      ),
                      // Online indicator (you can add logic for this)
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).cardColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 16),

                  // Conversation details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatTime(time),
                              style: TextStyle(
                                color: hasUnread
                                    ? const Color(0xFFFFC83E)
                                    : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage,
                                style: TextStyle(
                                  color: hasUnread
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontSize: 14,
                                  height: 1.3,
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasUnread) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: unreadCount > 9 ? 6 : 0,
                                  vertical: 0,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: unreadCount > 1 ? 20 : 10,
                                  minHeight: unreadCount > 1 ? 20 : 10,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF5A5F),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: unreadCount > 1
                                    ? Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ),
      ), // end of Container (child of Dismissible)
    ); // end of Dismissible
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: context.l10n.messages),
      body: _isLoading
          ? Loading()
          : RefreshIndicator(
              onRefresh: _refreshConversations,
              child: _conversations.isEmpty
                  ? SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          _buildChatbotCard(),
                          Container(
                            height: MediaQuery.of(context).size.height - 300,
                            child: _buildEmptyState(),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 8),
                      itemCount: _conversations.length + 1, // +1 for chatbot
                      itemBuilder: (ctx, index) {
                        if (index == 0) {
                          return _buildChatbotCard();
                        }
                        return _buildConversationCard(
                          _conversations[index - 1],
                        );
                      },
                    ),
            ),
    );
  }
}
