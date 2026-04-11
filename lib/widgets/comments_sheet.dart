import 'package:baakhapaa/providers/comment.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'skeleton_loading.dart';

import 'comment_item.dart';
import '../utils/debug_logger.dart';

class CommentsSheet extends StatefulWidget {
  final int shortsId;

  CommentsSheet({required this.shortsId});

  @override
  _CommentsSheetState createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to call fetchComments after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchComments();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      await Provider.of<Comments>(context, listen: false)
          .fetchComments(widget.shortsId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load comments: ${error.toString()}')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await Provider.of<Comments>(context, listen: false)
          .addComment(widget.shortsId, _commentController.text);
      _commentController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: ${error.toString()}'),
            duration: Duration(seconds: 3),
          ),
        );
        DebugLogger.error('Error adding comment: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Divider(color: Colors.grey.withValues(alpha: 0.2)),
          _buildCommentsList(),
          Divider(color: Colors.grey.withValues(alpha: 0.2)),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),
          // Header content
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
                  Icons.comment_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Consumer<Comments>(
                  builder: (ctx, commentsData, _) => Text(
                    'Comments (${commentsData.comments.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return Consumer<Comments>(
      builder: (ctx, commentsData, _) {
        // Changed from isLoading to isFetching to match your provider
        if (commentsData.isFetching) {
          return Expanded(
            child: CommentsSkeleton(count: 4),
          );
        }

        if (commentsData.comments.isEmpty) {
          return Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.comment_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No comments yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Be the first to comment!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchComments,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: commentsData.comments.length,
              separatorBuilder: (context, index) => Divider(),
              itemBuilder: (context, index) {
                return CommentItem(
                  comment: commentsData.comments[index],
                  refreshComments: _fetchComments,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: double.infinity,
              ),
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: Colors.blue.shade400, width: 2),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade800
                      : Colors.grey.shade50,
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.comment_outlined,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                  ),
                ),
                maxLines: null,
                minLines: 1,
                maxLength: 500,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _addComment(),
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isSubmitting
                    ? [Colors.grey.shade400, Colors.grey.shade500]
                    : [Colors.blue.shade400, Colors.purple.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _isSubmitting
                      ? Colors.transparent
                      : Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isSubmitting ? null : _addComment,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.all(12),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
