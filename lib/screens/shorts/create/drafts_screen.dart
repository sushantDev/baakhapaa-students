import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:image_picker/image_picker.dart';
import 'preview_shorts_screen.dart';
import '../../../utils/debug_logger.dart';
import '../../../widgets/skeleton_loading.dart';

class DraftsScreen extends StatefulWidget {
  static const routeName = '/drafts-screen';

  @override
  _DraftsScreenState createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<Map<String, dynamic>> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStrings = prefs.getStringList('shorts_drafts') ?? [];

      setState(() {
        _drafts = draftStrings
            .map((draftString) =>
                jsonDecode(draftString) as Map<String, dynamic>)
            .toList()
            .reversed // Show newest first
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      DebugLogger.error('Error loading drafts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDraft(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStrings = prefs.getStringList('shorts_drafts') ?? [];

      // Remove the draft (accounting for reversed order)
      final actualIndex = draftStrings.length - 1 - index;
      draftStrings.removeAt(actualIndex);

      await prefs.setStringList('shorts_drafts', draftStrings);

      setState(() {
        _drafts.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Draft deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      DebugLogger.error('Error deleting draft: $e');
    }
  }

  Future<void> _restoreDraft(Map<String, dynamic> draft) async {
    try {
      DebugLogger.info('Restoring draft: $draft'); // Debug log

      // Check if file still exists - try compressed video path first, then original
      String? filePath = draft['compressedVideoPath'] ?? draft['filePath'];

      if (filePath == null) {
        DebugLogger.info('No file path found in draft'); // Debug log
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Draft file path not found'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final file = File(filePath);
      DebugLogger.info('Checking file path: $filePath'); // Debug log

      if (!file.existsSync()) {
        // Try original file path if compressed path doesn't exist
        final originalPath = draft['filePath'];
        if (originalPath != null && originalPath != filePath) {
          final originalFile = File(originalPath);
          if (originalFile.existsSync()) {
            filePath = originalPath;
            DebugLogger.info(
                'Using original file path: $filePath'); // Debug log
          } else {
            DebugLogger.info(
                'Neither compressed nor original file exists'); // Debug log
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Original file no longer exists'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
        } else {
          DebugLogger.info('File does not exist: $filePath'); // Debug log
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Original file no longer exists'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      DebugLogger.info('File exists, creating XFile...'); // Debug log
      // Convert File to XFile for compatibility
      final xFile = XFile(filePath!);

      DebugLogger.info('Navigating to preview screen...'); // Debug log
      // Navigate back to preview with draft data
      final result = await Navigator.of(context).pushReplacementNamed(
        PreviewShortsScreen.routeName,
        arguments: {
          'title': draft['title'] ?? '',
          'description': draft['description'] ?? '',
          'file': xFile,
          'isVideo': draft['isVideo'] ?? true,
          'shorts_topic_id': draft['shorts_topic_id'] ?? 1,
          'points': draft['points'] ?? 100,
          'lives': draft['lives'] ?? 1,
          'no_of_mcq': draft['no_of_mcq'] ?? 3,
        },
      );
      DebugLogger.success(
          'Navigation completed with result: $result'); // Debug log
    } catch (e) {
      DebugLogger.error('Error restoring draft: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore draft: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF121212) : Colors.grey.shade50,
      appBar: header(context: context, titleText: 'Drafts'),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(24.0),
              child: ListSkeleton(itemCount: 4),
            )
          : _drafts.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _drafts.length,
                  itemBuilder: (context, index) =>
                      _buildDraftCard(_drafts[index], index, isDark),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drafts_outlined,
            size: 80,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'No drafts yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your saved drafts will appear here',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(Map<String, dynamic> draft, int index, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDark ? Color(0xFF2A2A2A) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isDark ? Colors.grey.shade600 : Colors.grey.shade200,
                    ),
                  ),
                  child: Icon(
                    draft['isVideo'] ? Icons.video_library : Icons.image,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft['title'] ?? 'Untitled',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.grey.shade800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatDate(draft['timestamp']),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  onSelected: (value) {
                    if (value == 'restore') {
                      _restoreDraft(draft);
                    } else if (value == 'delete') {
                      _deleteDraft(index);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore, size: 20),
                          SizedBox(width: 8),
                          Text('Restore'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (draft['description'] != null &&
                draft['description'].isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                draft['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _restoreDraft(draft),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade400,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Restore Draft'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
