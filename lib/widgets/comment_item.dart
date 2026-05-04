import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/comment.dart';
import '../providers/auth.dart';
import 'package:baakhapaa/providers/comment.dart';
import '../screens/user/player_profile_screen.dart';
import '../utils/debug_logger.dart';
import '../utils/guest_auth_helper.dart';

class CommentItem extends StatefulWidget {
  final Comment comment;
  final bool isReply;
  final Function refreshComments;

  CommentItem({
    required this.comment,
    this.isReply = false,
    required this.refreshComments,
  });

  @override
  _CommentItemState createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  bool _isReplying = false;
  bool _isEditing = false;
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final FocusNode _editFocusNode = FocusNode();

  @override
  void dispose() {
    _replyController.dispose();
    _editController.dispose();
    _replyFocusNode.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _startReplying() {
    setState(() {
      _isReplying = true;
    });
    Future.delayed(Duration(milliseconds: 100), () {
      _replyFocusNode.requestFocus();
    });
  }

  void _startEditing() {
    _editController.text = widget.comment.body;
    setState(() {
      _isEditing = true;
    });
    Future.delayed(Duration(milliseconds: 100), () {
      _editFocusNode.requestFocus();
    });
  }

  Future<void> _submitReply() async {
    if (_replyController.text.isEmpty) return;

    try {
      int? shortsId = widget.comment.shortsId;

      // If shortsId is null, we can't proceed
      if (shortsId == null) {
        throw 'Cannot reply to this comment - missing shorts ID';
      }

      final commentsProvider = Provider.of<Comments>(context, listen: false);
      await commentsProvider.addComment(
        shortsId,
        _replyController.text,
        parentCommentId: widget.comment.id,
      );

      _replyController.clear();
      setState(() {
        _isReplying = false;
      });

      // This will refresh the full comments list
      widget.refreshComments();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not post reply: ${error.toString()}')),
      );
    }
  }

  Future<void> _submitEdit() async {
    if (_editController.text.isEmpty) return;

    try {
      final commentsProvider = Provider.of<Comments>(context, listen: false);
      await commentsProvider.updateComment(
        widget.comment.id,
        _editController.text,
      );
      _editController.clear();
      setState(() {
        _isEditing = false;
      });
      widget.refreshComments();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not update comment: ${error.toString()}')),
      );
    }
  }

  Future<void> _deleteComment() async {
    final confirmDelete = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Comment'),
        content: Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        final commentsProvider = Provider.of<Comments>(context, listen: false);
        await commentsProvider.deleteComment(widget.comment.id);
        widget.refreshComments();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not delete comment: ${error.toString()}')),
        );
      }
    }
  }

  Future<void> _reportCommentUser() async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      await GuestAuthHelper.showGuestLoginDialog(context, 'report this user');
      return;
    }

    final int targetId = widget.comment.userId ?? 0;
    if (targetId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to report this user.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String selectedReason = 'Harassment or bullying';
    const reasons = [
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
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why are you reporting @${widget.comment.username}?'),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await auth.reportContent(
                    type: 'user',
                    targetId: targetId,
                    reason: selectedReason,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted. Thank you.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _blockCommentUser() async {
    final auth = Provider.of<Auth>(context, listen: false);
    if (auth.isGuest) {
      await GuestAuthHelper.showGuestLoginDialog(context, 'block this user');
      return;
    }

    final username = widget.comment.username.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to block this user.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final shouldBlock = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Block User'),
            content: Text('Block @$username and hide their content?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Block'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldBlock) return;

    try {
      await auth.blockUser(username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('@$username has been blocked.'),
          backgroundColor: Colors.green,
        ),
      );
      widget.refreshComments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<Auth>(context, listen: false);
    final userId = auth.userId;
    final isCurrentUserComment = userId == widget.comment.userId;

    String timeAgoText;
    try {
      DateTime dateTime = widget.comment.createdAtDateTime;
      timeAgoText = timeago.format(dateTime);
    } catch (e) {
      timeAgoText = 'Just now';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: widget.isReply ? 40 : 0,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  DebugLogger.info(
                      '💬 Navigating to profile for username: ${widget.comment.username}');
                  Navigator.of(context).pushNamed(
                    PlayerProfileScreen.routeName,
                    arguments: widget.comment.username,
                  );
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: widget.comment.userImage != null
                      ? CachedNetworkImageProvider(widget.comment.userImage!)
                      : null,
                  backgroundColor: Colors.grey.shade300,
                  child: widget.comment.userImage == null
                      ? Icon(Icons.person,
                          size: 16, color: Colors.grey.shade600)
                      : null,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                DebugLogger.info(
                                    '💬 Navigating to profile for username: ${widget.comment.username}');
                                Navigator.of(context).pushNamed(
                                  PlayerProfileScreen.routeName,
                                  arguments: widget.comment.username,
                                );
                              },
                              child: Text(
                                widget.comment.username,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            timeAgoText,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Spacer(),
                          // Add edit and delete buttons directly in the UI for the comment owner
                          if (isCurrentUserComment) ...[
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: InkWell(
                                child: Icon(Icons.edit,
                                    size: 20, color: Colors.blue.shade600),
                                onTap: _startEditing,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: InkWell(
                                child: Icon(Icons.delete,
                                    size: 20, color: Colors.red.shade600),
                                onTap: _deleteComment,
                              ),
                            ),
                          ] else ...[
                            PopupMenuButton<String>(
                              tooltip: 'Comment actions',
                              icon: Icon(
                                Icons.more_vert,
                                size: 20,
                                color: Colors.grey.shade500,
                              ),
                              onSelected: (value) {
                                if (value == 'report_user') {
                                  _reportCommentUser();
                                } else if (value == 'block_user') {
                                  _blockCommentUser();
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem<String>(
                                  value: 'report_user',
                                  child: Row(
                                    children: [
                                      Icon(Icons.flag_outlined,
                                          color: Colors.orange),
                                      SizedBox(width: 10),
                                      Text('Report User'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'block_user',
                                  child: Row(
                                    children: [
                                      Icon(Icons.block, color: Colors.red),
                                      SizedBox(width: 10),
                                      Text('Block User'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      if (_isEditing)
                        _buildEditForm()
                      else
                        Text(
                          widget.comment.body,
                          style: TextStyle(fontSize: 14),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Add a visible reply button if not already a reply
        if (!widget.isReply && !_isReplying)
          Padding(
            padding: EdgeInsets.only(left: 40, bottom: 8),
            child: GestureDetector(
              onTap: _startReplying,
              child: Text(
                "Reply",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        if (_isReplying) _buildReplyForm(),

        // Display replies
        if (!widget.isReply && widget.comment.replies.isNotEmpty)
          ...widget.comment.replies.map((reply) => CommentItem(
                comment: reply,
                isReply: true,
                refreshComments: widget.refreshComments,
              )),
      ],
    );
  }

  Widget _buildReplyForm() {
    return Padding(
      padding: EdgeInsets.only(left: 40, right: 8, top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocusNode,
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.reply_rounded,
                      color: Colors.grey.shade500,
                      size: 18,
                    ),
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
                maxLines: 1,
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _submitReply,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _isReplying = false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: TextField(
              controller: _editController,
              focusNode: _editFocusNode,
              decoration: InputDecoration(
                hintText: 'Edit your comment...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.edit_rounded,
                    color: Colors.grey.shade500,
                    size: 18,
                  ),
                ),
              ),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
              maxLines: 1,
            ),
          ),
        ),
        SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.teal.shade400],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _submitEdit,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isEditing = false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
