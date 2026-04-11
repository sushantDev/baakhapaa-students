import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/comment.dart';
import '../models/url.dart';
import '../utils/debug_logger.dart';

class Comments with ChangeNotifier {
  List<Comment> _comments = [];
  bool _isFetching = false;
  String authToken;

  Comments(this.authToken, this._comments);

  List<Comment> get comments {
    return [..._comments];
  }

  bool get isFetching {
    return _isFetching;
  }

  Future<void> fetchComments(int shortsId) async {
    _isFetching = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(Url.baakhapaaApi('/shorts/$shortsId/comments')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success']) {
        final List<dynamic> commentsData = responseData['data']['items'];
        final List<Comment> loadedComments = commentsData
            .map((commentData) => Comment.fromJson(commentData))
            .toList();

        _comments = loadedComments;
      } else {
        throw responseData['message'] ?? 'Failed to load comments';
      }
    } catch (error) {
      throw error;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  Future<Comment> addComment(int shortsId, String body,
      {int? parentCommentId}) async {
    try {
      final Map<String, dynamic> commentData = {
        'body': body,
      };

      if (parentCommentId != null) {
        commentData['parent_comment_id'] = parentCommentId;
      }

      final response = await http.post(
        Uri.parse(Url.baakhapaaApi('/shorts/$shortsId/comments')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode(commentData),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success']) {
        final newCommentData =
            responseData['data']['item'] ?? responseData['data'];

        if (!newCommentData.containsKey('shorts_id')) {
          newCommentData['shorts_id'] = shortsId;
        }

        try {
          final Comment newComment = Comment.fromJson(newCommentData);

          if (parentCommentId == null) {
            _comments.insert(0, newComment);
          } else {
            final int parentIndex =
                _comments.indexWhere((c) => c.id == parentCommentId);
            if (parentIndex >= 0) {
              _comments[parentIndex].replies.insert(0, newComment);
            }
          }

          notifyListeners();
          return newComment;
        } catch (e) {
          DebugLogger.error('Error parsing comment data: $e');
          throw 'Failed to process comment data: $e';
        }
      } else {
        throw responseData['message'] ?? 'Failed to add comment';
      }
    } catch (error) {
      DebugLogger.error('Error adding comment: $error');
      throw error;
    }
  }

  Future<Comment> updateComment(int commentId, String newBody) async {
    try {
      final response = await http.put(
        Uri.parse(Url.baakhapaaApi('/comments/$commentId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
        body: json.encode({'body': newBody}),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success']) {
        final updatedCommentData = responseData['data'];
        final Comment updatedComment = Comment.fromJson(updatedCommentData);

        // Find and update the comment in our local list
        int commentIndex = _comments.indexWhere((c) => c.id == commentId);
        if (commentIndex >= 0) {
          _comments[commentIndex] = updatedComment;
        } else {
          // Check if it's a reply
          for (int i = 0; i < _comments.length; i++) {
            int replyIndex =
                _comments[i].replies.indexWhere((r) => r.id == commentId);
            if (replyIndex >= 0) {
              final List<Comment> updatedReplies = [..._comments[i].replies];
              updatedReplies[replyIndex] = updatedComment;

              _comments[i] = Comment(
                id: _comments[i].id,
                shortsId: _comments[i].shortsId,
                userId: _comments[i].userId,
                username: _comments[i].username,
                userImage: _comments[i].userImage,
                body: _comments[i].body,
                createdAt: _comments[i].createdAt,
                parentCommentId: _comments[i].parentCommentId,
                replies: updatedReplies,
              );
              break;
            }
          }
        }

        notifyListeners();
        return updatedComment;
      } else {
        throw responseData['message'] ?? 'Failed to update comment';
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> deleteComment(int commentId) async {
    try {
      final response = await http.delete(
        Uri.parse(Url.baakhapaaApi('/comments/$commentId')),
        headers: Url.baakhapaaAuthHeaders(authToken),
      );

      var responseData = json.decode(utf8.decode(response.bodyBytes));

      if (responseData['success']) {
        // Remove from our local list
        int commentIndex = _comments.indexWhere((c) => c.id == commentId);
        if (commentIndex >= 0) {
          _comments.removeAt(commentIndex);
        } else {
          // Check if it's a reply
          for (int i = 0; i < _comments.length; i++) {
            int replyIndex =
                _comments[i].replies.indexWhere((r) => r.id == commentId);
            if (replyIndex >= 0) {
              final List<Comment> updatedReplies = [..._comments[i].replies];
              updatedReplies.removeAt(replyIndex);

              _comments[i] = Comment(
                id: _comments[i].id,
                shortsId: _comments[i].shortsId,
                userId: _comments[i].userId,
                username: _comments[i].username,
                userImage: _comments[i].userImage,
                body: _comments[i].body,
                createdAt: _comments[i].createdAt,
                parentCommentId: _comments[i].parentCommentId,
                replies: updatedReplies,
              );
              break;
            }
          }
        }

        notifyListeners();
      } else {
        throw responseData['message'] ?? 'Failed to delete comment';
      }
    } catch (error) {
      throw error;
    }
  }
}
