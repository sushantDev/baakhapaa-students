import 'dart:io';
import 'dart:convert';
import 'package:baakhapaa/providers/shorts.dart';
import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/screens/shorts/create/create_shorts_question_screen.dart';
import 'package:baakhapaa/screens/shorts/shorts_screen.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import '../../../utils/debug_logger.dart';

class PreviewShortsScreen extends StatefulWidget {
  static const routeName = '/preview-shorts-screen';

  @override
  _PreviewShortsScreenState createState() => _PreviewShortsScreenState();
}

class _PreviewShortsScreenState extends State<PreviewShortsScreen> {
  VideoPlayerController? _videoController;

  // nullable fields now
  String? _title;
  String? _description;
  XFile? _xfile; // incoming XFile (if provided)
  File? _file; // local File (from XFile.path) when present
  Map<String, dynamic>? _youtubeVideoData; // if provided instead of local file
  List<int>? _affiliateProductIds;
  List<int>? _relatedShortsIds;
  List<int>? _relatedEpisodeIds;
  int? _seasonId;

  bool _isVideo = false;
  bool _isMuted = false;
  bool _isCompressing = false;
  String? _compressedVideoPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_title != null ||
        _description != null ||
        _file != null ||
        _youtubeVideoData != null) {
      // already initialized
      return;
    }

    try {
      final rawArgs = ModalRoute.of(context)?.settings.arguments;

      if (rawArgs == null || rawArgs is! Map<String, dynamic>) {
        throw Exception('No preview arguments provided');
      }
      final args = rawArgs;

      _title = args['title'] is String ? args['title'] as String : null;
      _description =
          args['description'] is String ? args['description'] as String : null;

      // Try to parse local file (XFile)
      final dynamic fileArg = args['file'];
      if (fileArg is XFile) {
        _xfile = fileArg;
        _file = File(_xfile!.path);

        if (!_file!.existsSync()) {
          throw Exception('Local file does not exist at path: ${_file!.path}');
        }

        _isVideo = args['isVideo'] is bool ? args['isVideo'] as bool : true;
      } else {
        _xfile = null;
        _file = null;
      }

      // Try to parse YouTube data (Map)
      final dynamic ytArg = args['youtubeVideoData'];
      if (ytArg is Map<String, dynamic>) {
        _youtubeVideoData = ytArg;
      } else {
        _youtubeVideoData = null;
      }

      _affiliateProductIds = (args['affiliate_product_ids'] as List?)
          ?.map((e) => e as int)
          .toList();

      _relatedShortsIds =
          (args['related_shorts_ids'] as List?)?.map((e) => e as int).toList();

      _relatedEpisodeIds =
          (args['related_episode_ids'] as List?)?.map((e) => e as int).toList();

      _seasonId = args['season_id'] is int ? args['season_id'] as int : null;

      // If neither provided, error
      if (_file == null && _youtubeVideoData == null) {
        throw Exception('No local file or YouTube video provided for preview.');
      }

      // If we have a local video file, start compression/initialization
      if (_file != null && _isVideo) {
        _compressAndInitializeVideo();
      }
    } catch (e) {
      DebugLogger.error('Error initializing preview: $e');
      // Show error dialog and navigate back
      Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text('Error'),
            content: Text('Failed to load preview: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  Future<void> _compressAndInitializeVideo() async {
    if (_file == null || !_isVideo) return;

    setState(() => _isCompressing = true);

    try {
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        _file!.path,
        quality: VideoQuality.Res960x540Quality,
        deleteOrigin: false,
      );

      if (mediaInfo?.path != null) {
        _compressedVideoPath = mediaInfo!.path;
        await _initializeVideo(File(_compressedVideoPath!));
      } else {
        throw Exception('Failed to compress video');
      }
    } catch (e) {
      DebugLogger.error('Error compressing video: $e');
      // Try to play original file if compression fails
      try {
        await _initializeVideo(_file!);
      } catch (e) {
        DebugLogger.error('Error playing original video: $e');
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Error'),
            content: Text('Failed to process video'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() => _isCompressing = false);
    }
  }

  Future<void> _initializeVideo(File videoFile) async {
    _videoController = VideoPlayerController.file(videoFile);
    await _videoController!.initialize();
    // Don't autoplay
    setState(() {});
  }

  Future<void> _submitShorts() async {
    bool isUploading = true;
    try {
      // If we were playing, pause and dispose
      if (_videoController != null) {
        await _videoController!.pause();
        await _videoController!.dispose();
        _videoController = null;
      }

      final rawArgs = ModalRoute.of(context)?.settings.arguments;
      final args =
          (rawArgs is Map<String, dynamic>) ? rawArgs : <String, dynamic>{};

      // Build formData
      Map<String, dynamic> formData = {
        'title': _title ?? '',
        'description': _description ?? '',
        'shorts_topic_id': args['shorts_topic_id'] ?? 1,
        'coins': 1,
        'coins_users': args['points'],
        'lives': args['lives'] ?? 1,
        'affiliate_product_ids': _affiliateProductIds,
        'related_shorts_ids': _relatedShortsIds,
        'related_episode_ids': _relatedEpisodeIds,
        'season_id': _seasonId,
      };

      // ✅ CRITICAL: Include challenge_id if present
      if (args['challenge_id'] != null) {
        formData['challenge_id'] = args['challenge_id'];
        DebugLogger.info(
            '🚀 Submitting shorts with challenge_id: ${args['challenge_id']}');
      }

      // ✅ COLLABORATION: Include collaborators if present
      if (args['collaborators'] != null &&
          (args['collaborators'] as List).isNotEmpty) {
        formData['collaborators'] = args['collaborators'];
        DebugLogger.info(
            '🤝 Submitting shorts with ${(args['collaborators'] as List).length} collaborators');
      }

      // ✅ COLLABORATION: If collaboration_id is present (invitation-first flow)
      if (args['collaboration_id'] != null) {
        formData['collaboration_id'] = args['collaboration_id'];
        DebugLogger.info(
            '🤝 Submitting collaborative shorts from collaboration #${args['collaboration_id']}');
      }
      DebugLogger.info(
          'PreviewShortsScreen: Submitting formData with season_id: $_seasonId, related_episode_ids: $_relatedEpisodeIds');

      // Show loading indicator
      if (isUploading) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Uploading shorts...'),
                ],
              ),
            ),
          ),
        );
      }

      var shortsProvider = Provider.of<Shorts>(context, listen: false);

      // Branch upload by source
      if (_youtubeVideoData != null) {
        // NOTE: backend/upload-from-youtube must be implemented to support this.
        // For now show an informative dialog and pop the loading dialog.
        isUploading = false;
        if (Navigator.canPop(context)) Navigator.of(context).pop();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Upload from YouTube'),
            content: Text(
              'Uploading directly from a YouTube video is not implemented in this client. '
              'You can download the video locally and then retry, or implement server-side '
              'support to accept a YouTube video id/URL.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Local-file upload path (existing behavior)
      if (_file == null && _compressedVideoPath == null) {
        // Nothing to upload
        isUploading = false;
        if (Navigator.canPop(context)) Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('No file'),
            content: Text('No local file available to upload.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final videoFile =
          _compressedVideoPath != null ? File(_compressedVideoPath!) : _file!;

      await shortsProvider.uploadShorts(formData, videoFile).then((_) async {
        isUploading = false;
        // Pop the loading dialog
        if (Navigator.canPop(context)) Navigator.of(context).pop();

        // ✅ COLLABORATION: Backend ShortsController@store already handles
        // invited_collaborators[] — creates ContentCollaboration + participants
        // + fires CollaborationInvitationSent event. No need to call
        // CollaborationProvider.createCollaboration() again (that would create
        // duplicate records). Just log for visibility.
        final collaborators = args['collaborators'];
        if (collaborators != null &&
            collaborators is List &&
            collaborators.isNotEmpty) {
          DebugLogger.success(
              '✅ Short uploaded with ${collaborators.length} collaborator(s) — backend handles invitations via invited_collaborators[]');
        }

        // Remove corresponding draft if it exists
        await _removeCorrespondingDraft();

        final int totalMcqsRequired = args['no_of_mcq'] ?? 3;

        if (totalMcqsRequired > 0) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PopScope(
              canPop: false,
              child: AlertDialog(
                title: Text('MCQs Required'),
                content: Text(
                    'We have prepared demo MCQs for your shorts, would you like to modify them?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      showScaffoldMessenger(context,
                          'Your shorts has been uploaded successfully!');
                      Navigator.of(context)
                          .pushReplacementNamed(ShortsScreen.routeName);
                    },
                    child: Text('No, Continue'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).popAndPushNamed(
                        CreateShortsQuestionScreen.routeName,
                        arguments: {
                          'shortsId': shortsProvider.newlyCreatedShortsId,
                          'totalMcqsRequired': totalMcqsRequired,
                        },
                      );
                    },
                    child: Text('Yes, Modify MCQs'),
                  ),
                ],
              ),
            ),
          );
        } else {
          // No MCQs needed — navigate back to shorts screen
          showScaffoldMessenger(
              context, 'Your shorts has been uploaded successfully!');
          Navigator.of(context).pushReplacementNamed(ShortsScreen.routeName);
        }
      });
    } catch (e, stackTrace) {
      isUploading = false;
      // Remove loading dialog if it's showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      DebugLogger.error('Failed to upload shorts: ${e.toString()}');
      DebugLogger.info('Stack trace: $stackTrace');

      // Show user-friendly error message
      String errorMsg = e.toString();
      String errorTitle = 'Upload Failed';
      IconData errorIcon = Icons.error_outline;

      if (errorMsg.contains('Insufficient coins') ||
          errorMsg.contains('insufficient') ||
          errorMsg.contains('balance')) {
        errorTitle = 'Insufficient Coins';
        errorMsg = 'You don\'t have enough coins to create this short. '
            'Please reduce the points reward or earn more coins.';
        errorIcon = Icons.account_balance_wallet_outlined;
      } else if (errorMsg.contains('server error') ||
          errorMsg.contains('SQLSTATE') ||
          errorMsg.contains('Exception')) {
        errorTitle = 'Server Error';
        errorMsg = 'Something went wrong on our end. Please try again later.';
        errorIcon = Icons.cloud_off_outlined;
      } else if (errorMsg.contains('Could not create') ||
          errorMsg.contains('Something went wrong')) {
        errorTitle = 'Upload Failed';
        errorIcon = Icons.cloud_off_outlined;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(errorIcon, color: Colors.red.shade400, size: 48),
          title: Text(errorTitle),
          content: Text(errorMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _toggleVolume() {
    setState(() {
      _isMuted = !_isMuted;
      _videoController?.setVolume(_isMuted ? 0 : 1);
    });
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawArgs = ModalRoute.of(context)?.settings.arguments;
      final args =
          (rawArgs is Map<String, dynamic>) ? rawArgs : <String, dynamic>{};

      final draftData = <String, dynamic>{
        'title': _title ?? '',
        'description': _description ?? '',
        'isVideo': _isVideo,
        'compressedVideoPath': _compressedVideoPath,
        'shorts_topic_id': args['shorts_topic_id'] ?? 1,
        'points': args['points'],
        'lives': args['lives'] ?? 1,
        'no_of_mcq': args['no_of_mcq'] ?? 3,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (_file != null) {
        draftData['filePath'] = _file!.path;
      } else if (_youtubeVideoData != null) {
        // Save youtube metadata instead of file path
        draftData['youtubeVideoData'] = _youtubeVideoData;
      }

      // Get existing drafts
      final existingDrafts = prefs.getStringList('shorts_drafts') ?? [];

      // Add new draft
      existingDrafts.add(jsonEncode(draftData));

      // Save back to preferences
      await prefs.setStringList('shorts_drafts', existingDrafts);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Draft saved successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      DebugLogger.error('Error saving draft: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save draft: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeCorrespondingDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStrings = prefs.getStringList('shorts_drafts') ?? [];

      // If we have a local file, remove drafts matching that path
      if (_file != null) {
        final updatedDrafts = draftStrings.where((draftString) {
          try {
            final draft = jsonDecode(draftString) as Map<String, dynamic>;
            return draft['filePath'] != _file!.path;
          } catch (e) {
            return true; // Keep drafts we can't parse
          }
        }).toList();
        await prefs.setStringList('shorts_drafts', updatedDrafts);
      } else if (_youtubeVideoData != null) {
        // Remove drafts matching youtube id/title if you stored such identifiers
        final ytId = _youtubeVideoData?['id'] ?? _youtubeVideoData?['videoId'];
        final updatedDrafts = draftStrings.where((draftString) {
          try {
            final draft = jsonDecode(draftString) as Map<String, dynamic>;
            final dYt = draft['youtubeVideoData'];
            if (dYt is Map<String, dynamic>) {
              return dYt['id'] != ytId && dYt['videoId'] != ytId;
            }
            return true;
          } catch (e) {
            return true;
          }
        }).toList();
        await prefs.setStringList('shorts_drafts', updatedDrafts);
      }
    } catch (e) {
      DebugLogger.error('Error removing corresponding draft: $e');
    }
  }

  void _togglePlayPause() {
    if (_videoController?.value.isPlaying ?? false) {
      _videoController?.pause();
    } else {
      _videoController?.play();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    VideoCompress.cancelCompression();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: Text(
              'Preview',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            actions: [
              Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () {
                    // Show options menu
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => _buildOptionsMenu(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Main content area
          if (_isCompressing)
            _buildProcessingView()
          else if (_file != null &&
              _isVideo &&
              _videoController != null &&
              _videoController!.value.isInitialized)
            _buildVideoView()
          else if (_youtubeVideoData != null)
            _buildYouTubeView()
          else if (_file != null)
            _buildImageView()
          else
            Center(
                child: Text('Nothing to preview',
                    style: TextStyle(color: Colors.white))),
          // Overlay controls
          if (!_isCompressing) ...[
            _buildSideControls(),
            _buildBottomInfo(),
            _buildPostButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildYouTubeView() {
    final thumbnail = _youtubeVideoData?['thumbnail'] as String?;
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: thumbnail != null
            ? Image.network(thumbnail,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey))
            : Container(color: Colors.grey),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade900,
            Colors.blue.shade900,
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Processing your shorts...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This may take a moment',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      ),
    );
  }

  Widget _buildImageView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: _file != null
          ? FittedBox(fit: BoxFit.cover, child: Image.file(_file!))
          : Container(),
    );
  }

  Widget _buildSideControls() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.3,
      child: Column(
        children: [
          if (_file != null && _isVideo) ...[
            _buildControlButton(
              icon: _isMuted ? Icons.volume_off : Icons.volume_up,
              onTap: _toggleVolume,
            ),
            SizedBox(height: 20),
            _buildControlButton(
              icon: _videoController?.value.isPlaying ?? false
                  ? Icons.pause
                  : Icons.play_arrow,
              onTap: _togglePlayPause,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Positioned(
      bottom: 120,
      left: 16,
      right: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((_title ?? '').isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _title ?? '',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          SizedBox(height: 12),
          if ((_description ?? '').isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ExpandableText(
                _description ?? '',
                expandText: 'more',
                collapseText: 'less',
                expandOnTextTap: true,
                collapseOnTextTap: true,
                maxLines: 3,
                linkColor: Colors.blue.shade300,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostButton() {
    return Positioned(
      bottom: 30,
      left: 16,
      right: 16,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.pink.shade400,
              Colors.purple.shade500,
              Colors.blue.shade600,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              HapticFeedback.mediumImpact();
              _submitShorts();
            },
            child: Container(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rocket_launch,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Post Shorts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsMenu() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),
          _buildMenuItem(
            icon: Icons.save_alt,
            title: 'Save Draft',
            onTap: () {
              Navigator.pop(context);
              _saveDraft();
            },
          ),
          _buildMenuItem(
            icon: Icons.delete_outline,
            title: 'Discard',
            onTap: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            isDestructive: true,
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white,
                size: 24,
              ),
              SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isDestructive ? Colors.red : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
