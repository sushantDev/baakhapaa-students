import 'dart:io';
import 'dart:async';

import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/shorts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:baakhapaa/screens/shorts/create/camera_recording_screen.dart';
import 'package:baakhapaa/screens/shorts/create/drafts_screen.dart';
import 'package:baakhapaa/widgets/header.dart';

import 'package:baakhapaa/models/affiliate_product.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:baakhapaa/providers/affiliate.dart';
import 'package:baakhapaa/widgets/creator_content_selector.dart';
import 'package:baakhapaa/widgets/affiliate_product_selector.dart';
import 'package:baakhapaa/widgets/collaborator_selector.dart';
import './preview_shorts_screen.dart';
import '../../../utils/debug_logger.dart';

class CreateShortsScreen extends StatefulWidget {
  static const routeName = '/create-shorts-screen';

  const CreateShortsScreen({Key? key}) : super(key: key);

  @override
  State<CreateShortsScreen> createState() => _CreateShortsScreenState();
}

class _CreateShortsScreenState extends State<CreateShortsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isInit = false;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController(text: '100');
  final _livesController = TextEditingController(text: '1');
  int? _selectedCategoryId;
  List<AffiliateProduct> _selectedAffiliateProducts = [];
  List<dynamic> _selectedRelatedShorts = [];
  List<dynamic> _selectedRelatedEpisodes = [];
  List<dynamic> _selectedRelatedSeasons = [];
  List<Map<String, dynamic>> _selectedCollaborators = [];
  bool? _isChallenge;
  int? _challengeId; // Store challenge_id from navigation args
  int? _collaborationId; // Store collaboration_id for invitation-first flow
  XFile? _selectedFile;
  Map<String, dynamic>? _youtubeVideoData; // Store YouTube video data
  String? _uploadMessage;

  // Animation and UI state
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int _currentStep = 0; // 0: Media selection, 1: Details, 2: Settings
  bool _isProcessing = false;
  int _draftsCount = 0;
  String _contentType = 'shorts'; // 'shorts' or 'stories'

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<Auth>(context, listen: false);
    if (!auth.isEmailVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified yet. Please verify your email first.'),
          ),
        );
        Navigator.of(context).maybePop();
      });
      return;
    }
    WidgetsBinding.instance.addObserver(this);

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Load shorts topics when screen initializes
    Provider.of<Shorts>(context, listen: false).fetchShortsTopic();
    // Fetch affiliate status
    Provider.of<AffiliateProvider>(context, listen: false)
        .fetchAffiliateStatus();
    _animationController.forward();
    _loadDraftsCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh drafts count when app comes back to foreground
      _loadDraftsCount();
    }
  }

  Future<void> _loadDraftsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStrings = prefs.getStringList('shorts_drafts') ?? [];
      setState(() {
        _draftsCount = draftStrings.length;
      });
    } catch (e) {
      DebugLogger.error('Error loading drafts count: $e');
    }
  }

  @override
  void didChangeDependencies() {
    if (!_isInit) {
      final rawArgs = ModalRoute.of(context)?.settings.arguments;
      if (rawArgs is Map<String, dynamic>) {
        _isChallenge = rawArgs['is_challenge'] as bool?;
        _challengeId = rawArgs['challenge_id'] as int?;
        _collaborationId = rawArgs['collaboration_id'] as int?;

        DebugLogger.info('🎯 CreateShortsScreen loaded');
        DebugLogger.info('🎯 isChallenge=$_isChallenge');
        DebugLogger.info('🎯 challengeId=$_challengeId');
        DebugLogger.info('🤝 collaborationId=$_collaborationId');
      } else {
        // No args or unexpected type — keep _isChallenge null
        _isChallenge = null;
        _challengeId = null;
        _collaborationId = null;
      }

      // Fetch shorts topics and handle the response
      DebugLogger.api("Fetching shorts topics...");
      Provider.of<Shorts>(context, listen: false).fetchShortsTopic().then((_) {
        DebugLogger.api("Shorts topics fetched successfully");
        if (mounted) {
          setState(() {
            // Trigger a rebuild to show the loaded categories
          });
        }
      }).catchError((error) {
        DebugLogger.api("Error fetching shorts topics: $error");
      });
      _isInit = true;
    }
    super.didChangeDependencies();
  }

  void _pickMedia() async {
    HapticFeedback.lightImpact();
    setState(() => _isProcessing = true);

    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );

    if (pickedFile != null) {
      setState(() {
        _selectedFile = pickedFile;
        _uploadMessage = 'Video selected successfully! 🎬';
        _currentStep = 1; // Move to details step
        _isProcessing = false;
      });

      // Trigger celebration animation
      _animationController.reset();
      _animationController.forward();
    } else {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _recordVideo() async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final XFile? recordedVideo = await Navigator.push<XFile>(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CameraRecordingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      );

      if (recordedVideo != null) {
        setState(() {
          _selectedFile = recordedVideo;
          _uploadMessage = 'Video recorded successfully! 🎥';
          _currentStep = 1; // Move to details step
          _isProcessing = false;
        });

        // Trigger celebration animation
        _animationController.reset();
        _animationController.forward();
      } else {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _uploadMessage = 'Failed to record video: $e';
      });
    }
  }

  // Future<void> _openYouTubeVideos() async {
  //   HapticFeedback.mediumImpact();
  //   setState(() => _isProcessing = true);

  //   try {
  //     // Check if user is connected to YouTube
  //     final socialAuthProvider =
  //         Provider.of<SocialAuthProvider>(context, listen: false);

  //     if (!socialAuthProvider.isConnectedToYouTube) {
  //       // Navigate to settings screen to connect YouTube
  //       setState(() => _isProcessing = false);

  //       await Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => SocialMediaScreen(),
  //         ),
  //       );
  //       return;
  //     }

  //     // Launch the selector screen and wait for selected video data (Map)
  //     final Map<String, dynamic>? selectedVideo =
  //         await Navigator.push<Map<String, dynamic>>(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => const YouTubeVideoSelectorScreen(),
  //       ),
  //     );

  //     // Reset processing flag if user canceled
  //     if (selectedVideo == null) {
  //       setState(() => _isProcessing = false);
  //       return;
  //     }

  //     // Show action sheet: Download to device (client-side) OR (optional) upload-from-server
  //     setState(() => _isProcessing = false);
  //     final choice = await showModalBottomSheet<String>(
  //       context: context,
  //       builder: (ctx) => SafeArea(
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             ListTile(
  //               leading: Icon(Icons.file_download),
  //               title: Text('Download to device and continue'),
  //               subtitle: Text(
  //                   'Downloads video with audio to device temporarily and continues to editing.'),
  //               onTap: () => Navigator.of(ctx).pop('download'),
  //             ),
  //             ListTile(
  //               leading: Icon(Icons.save_outlined),
  //               title: Text('Save to gallery and continue'),
  //               subtitle: Text(
  //                   'Downloads with audio and saves to gallery, then continues to editing.'),
  //               onTap: () => Navigator.of(ctx).pop('save_gallery'),
  //             ),
  //             ListTile(
  //               leading: Icon(Icons.close),
  //               title: Text('Cancel'),
  //               onTap: () => Navigator.of(ctx).pop(null),
  //             ),
  //           ],
  //         ),
  //       ),
  //     );

  //     if (choice == 'download') {
  //       // start client download flow (temporary)
  //       await _downloadYouTubeVideoAndContinue(selectedVideo);
  //     } else if (choice == 'save_gallery') {
  //       // start save-to-gallery flow
  //       await _downloadYouTubeVideoSaveGalleryAndContinue(selectedVideo);
  //     }
  //   } catch (e) {
  //     setState(() => _isProcessing = false);
  //     DebugLogger.error(
  //         'Failed to open YouTube selector or process selection: $e');
  //     setState(() {
  //       _uploadMessage = 'Failed to select YouTube video: $e';
  //     });
  //   }
  // }

  /// Check if a video file has audio streams using FFmpeg
  // Future<bool> _checkVideoHasAudio(String filePath) async {
  //   try {
  //     final mediaInfoSession = await FFprobeKit.getMediaInformation(filePath);
  //     final info = await mediaInfoSession.getMediaInformation();
  //     final streams = info?.getStreams() ?? [];

  //     final hasAudio = streams.any((stream) {
  //       final properties = stream.getAllProperties();
  //       return properties?['codec_type'] == 'audio';
  //     });

  //     DebugLogger.info('File $filePath has audio: $hasAudio');
  //     DebugLogger.info('Total streams: ${streams.length}');

  //     return hasAudio;
  //   } catch (e) {
  //     DebugLogger.error('Error checking audio in $filePath: $e');
  //     return false; // Assume no audio on error
  //   }
  // }

  /// Check if YouTube video is available before attempting download
  // Future<bool> _checkVideoAvailability(String videoId) async {
  //   try {
  //     final yt = YoutubeExplode();
  //     try {
  //       // Try to get video info - this will throw VideoUnavailableException if not available
  //       final video = await yt.videos.get(videoId);
  //       DebugLogger.info('✅ Video availability confirmed: ${video.title}');
  //       return true;
  //     } finally {
  //       yt.close();
  //     }
  //   } catch (e) {
  //     DebugLogger.error('❌ Video availability check failed: $e');

  //     String errorMessage;
  //     if (e.toString().contains('VideoUnavailableException') ||
  //         e.toString().contains('Video unavailable')) {
  //       errorMessage =
  //           '❌ This video is unavailable. It may be private, deleted, age-restricted, or region-blocked.';
  //     } else if (e.toString().contains('live stream')) {
  //       errorMessage =
  //           '❌ Cannot download live streams. Please wait for the stream to end.';
  //     } else if (e.toString().contains('network') ||
  //         e.toString().contains('connection')) {
  //       errorMessage =
  //           '❌ Network error. Please check your internet connection and try again.';
  //     } else {
  //       errorMessage = '❌ Unable to access video: ${e.toString()}';
  //     }

  //     setState(() {
  //       _uploadMessage = errorMessage;
  //     });

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(errorMessage),
  //           backgroundColor: Colors.red,
  //           duration: Duration(seconds: 5),
  //         ),
  //       );
  //     }
  //     return false;
  //   }
  // }

  // /// Ensure we have permission to save to gallery with proper user guidance
  // Future<bool> _ensureSavePermission() async {
  //   try {
  //     if (Platform.isAndroid) {
  //       // For Android API 29+ (Android 10+), we need media permissions
  //       final status = await Permission.storage.status;

  //       if (status.isGranted) {
  //         return true;
  //       }

  //       if (status.isDenied) {
  //         // Request permission
  //         final result = await Permission.storage.request();
  //         if (result.isGranted) {
  //           return true;
  //         }
  //       }

  //       // If permission is permanently denied or still denied after request
  //       if (status.isPermanentlyDenied || status.isDenied) {
  //         // Show dialog to guide user to settings
  //         final shouldOpenSettings = await showDialog<bool>(
  //           context: context,
  //           builder: (ctx) => AlertDialog(
  //             title: Text('Storage Permission Required'),
  //             content: Text(
  //               'To save videos to your gallery, this app needs storage permission.\n\n'
  //               'Please go to App Settings > Permissions and enable Storage permission.',
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.of(ctx).pop(false),
  //                 child: Text('Cancel'),
  //               ),
  //               TextButton(
  //                 onPressed: () => Navigator.of(ctx).pop(true),
  //                 child: Text('Open Settings'),
  //               ),
  //             ],
  //           ),
  //         );

  //         if (shouldOpenSettings == true) {
  //           await openAppSettings();
  //           // Check permission again after user returns from settings
  //           final newStatus = await Permission.storage.status;
  //           return newStatus.isGranted;
  //         }
  //         return false;
  //       }
  //     } else if (Platform.isIOS) {
  //       // For iOS, we need photo library permission
  //       final status = await Permission.photos.status;

  //       if (status.isGranted || status.isLimited) {
  //         return true;
  //       }

  //       if (status.isDenied) {
  //         // Request permission
  //         final result = await Permission.photos.request();
  //         if (result.isGranted || result.isLimited) {
  //           return true;
  //         }
  //       }

  //       // If permission is permanently denied or still denied after request
  //       if (status.isPermanentlyDenied || status.isDenied) {
  //         // Show dialog to guide user to settings
  //         final shouldOpenSettings = await showDialog<bool>(
  //           context: context,
  //           builder: (ctx) => AlertDialog(
  //             title: Text('Photo Library Permission Required'),
  //             content: Text(
  //               'To save videos to your photo library, this app needs photo access.\n\n'
  //               'Please go to Settings > Privacy & Security > Photos and allow access.',
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.of(ctx).pop(false),
  //                 child: Text('Cancel'),
  //               ),
  //               TextButton(
  //                 onPressed: () => Navigator.of(ctx).pop(true),
  //                 child: Text('Open Settings'),
  //               ),
  //             ],
  //           ),
  //         );

  //         if (shouldOpenSettings == true) {
  //           await openAppSettings();
  //           // Check permission again after user returns from settings
  //           final newStatus = await Permission.photos.status;
  //           return newStatus.isGranted || newStatus.isLimited;
  //         }
  //         return false;
  //       }
  //     }

  //     // For other platforms or if no specific permission needed
  //     return true;
  //   } catch (e) {
  //     DebugLogger.error('Permission check error: $e');

  //     // Show error message to user
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Permission error: ${e.toString()}'),
  //           backgroundColor: Colors.orange,
  //           duration: Duration(seconds: 3),
  //         ),
  //       );
  //     }
  //     return false;
  //   }
  // }

  // Future<void> _downloadYouTubeVideoAndContinue(
  //     Map<String, dynamic> youtubeVideoData) async {
  //   final videoId = youtubeVideoData['id'] ??
  //       youtubeVideoData['videoId'] ??
  //       youtubeVideoData['video_id'];
  //   if (videoId == null) {
  //     setState(() {
  //       _uploadMessage = 'Invalid YouTube video data';
  //     });
  //     return;
  //   }

  //   // Check video availability first
  //   if (!await _checkVideoAvailability(videoId)) {
  //     return; // Error message already shown in _checkVideoAvailability
  //   }

  //   // Confirm with user about download size / mobile data usage
  //   final should = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: Text('Download to device?'),
  //       content: Text(
  //           'This will download the YouTube video with audio (using smart stream merging) to your device temporary storage and may use mobile data. Continue?'),
  //       actions: [
  //         TextButton(
  //             onPressed: () => Navigator.of(ctx).pop(false),
  //             child: Text('Cancel')),
  //         TextButton(
  //             onPressed: () => Navigator.of(ctx).pop(true),
  //             child: Text('Download')),
  //       ],
  //     ),
  //   );

  //   if (should != true) return;

  //   setState(() => _isProcessing = true);

  //   try {
  //     File? mergedFile;

  //     // Create progress notifier for the download function
  //     final progress = ValueNotifier<double>(-1.0);
  //     final cancelNotifier = ValueNotifier<bool>(false);

  //     // Show progress dialog
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (ctx) => DownloadProgressDialog(
  //         progress: progress,
  //         onCancel: () {
  //           cancelNotifier.value = true;
  //           // dialog is popped by DownloadProgressDialog onCancel call
  //         },
  //       ),
  //     );

  //     // Use the robust download and merge function
  //     mergedFile = await _downloadAndMuxYouTubeVideo(
  //       youtubeVideoData: youtubeVideoData,
  //       progressNotifier: progress,
  //       cancelNotifier: cancelNotifier,
  //     );
  //     if (mergedFile == null) {
  //       setState(() {
  //         _isProcessing = false;
  //         _uploadMessage = 'Download cancelled or failed';
  //       });
  //       return;
  //     }

  //     // Close progress dialog
  //     if (Navigator.canPop(context)) Navigator.of(context).pop();

  //     // Create XFile from merged file
  //     final mergedXFile = XFile(mergedFile.path);

  //     // Log successful download for debugging
  //     DebugLogger.info(
  //         '✅ YouTube video downloaded and merged successfully to: ${mergedFile.path}');
  //     DebugLogger.info('📁 File size: ${await mergedFile.length()} bytes');

  //     // Check if the merged file has audio
  //     final hasAudio = await _checkVideoHasAudio(mergedFile.path);
  //     DebugLogger.info('🎵 Merged file has audio: $hasAudio');

  //     // Always set the selected file to the merged local file
  //     setState(() {
  //       _selectedFile = mergedXFile; // <- ensure uploader sees this
  //       _youtubeVideoData = youtubeVideoData; // keep metadata for context
  //       _uploadMessage = hasAudio
  //           ? '✅ Downloaded with audio and ready for upload'
  //           : '✅ Downloaded (video-only) and ready for upload';
  //       _currentStep = 1; // go to details step
  //       _isProcessing = false;
  //     });

  //     // Show success snackbar
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content:
  //               Text('📥 Video downloaded with audio and ready for editing!'),
  //           backgroundColor: Colors.green,
  //           duration: Duration(seconds: 3),
  //         ),
  //       );
  //     }

  //     // trigger celebrate animation
  //     _animationController.reset();
  //     _animationController.forward();
  //   } catch (e) {
  //     DebugLogger.error('Download failed: $e');
  //     if (Navigator.canPop(context))
  //       Navigator.of(context).pop(); // close progress
  //     setState(() {
  //       _isProcessing = false;
  //       _uploadMessage = 'Download failed: $e';
  //     });
  //   }
  // }

  // Robust download and merge function that handles both muxed and adaptive streams
  // Future<File?> _downloadAndMuxYouTubeVideo({
  //   required Map<String, dynamic> youtubeVideoData,
  //   required ValueNotifier<double> progressNotifier,
  //   required ValueNotifier<bool> cancelNotifier,
  //   int? maxBytes,
  // }) async {
  //   final videoId = youtubeVideoData['id'] ??
  //       youtubeVideoData['videoId'] ??
  //       youtubeVideoData['video_id'];
  //   if (videoId == null) throw Exception('Missing video id');

  //   final yt = YoutubeExplode();
  //   File? tempVideoFile;
  //   File? tempAudioFile;
  //   File? outputFile;

  //   try {
  //     final manifest = await yt.videos.streamsClient.getManifest(videoId);

  //     // 1) If a muxed (video+audio) stream exists, use it — simplest, no merging
  //     if (manifest.muxed.isNotEmpty) {
  //       DebugLogger.info('🎵 Found muxed stream, downloading with audio...');
  //       final streamInfo = manifest.muxed.withHighestBitrate();
  //       final totalBytes = streamInfo.size.totalBytes;
  //       if (maxBytes != null && totalBytes > maxBytes) {
  //         throw Exception('Video exceeds size limit');
  //       }

  //       final stream = yt.videos.streamsClient.get(streamInfo);
  //       final tmpDir = await getTemporaryDirectory();
  //       final videoPath =
  //           '${tmpDir.path}/${videoId}_muxed_${DateTime.now().millisecondsSinceEpoch}.mp4';
  //       tempVideoFile = File(videoPath);
  //       final sink = tempVideoFile.openWrite();

  //       int received = 0;
  //       await for (final chunk in stream) {
  //         if (cancelNotifier.value) break;
  //         sink.add(chunk);
  //         received += chunk.length;
  //         if (totalBytes > 0) progressNotifier.value = received / totalBytes;
  //       }
  //       await sink.flush();
  //       await sink.close();

  //       if (cancelNotifier.value) {
  //         try {
  //           await tempVideoFile.delete();
  //         } catch (_) {}
  //         return null;
  //       }

  //       progressNotifier.value = 1.0;
  //       return tempVideoFile;
  //     }

  //     // 2) Otherwise, manifest has adaptive streams. Get best video-only and audio-only streams.
  //     if (manifest.videoOnly.isEmpty || manifest.audio.isEmpty) {
  //       throw Exception(
  //           'No downloadable streams (video-only or audio-only) available.');
  //     }

  //     DebugLogger.info(
  //         '🔄 Using adaptive streams, downloading video and audio separately...');
  //     final videoStream = manifest.videoOnly.withHighestBitrate();
  //     final audioStream = manifest.audio.withHighestBitrate();

  //     final videoTotal = videoStream.size.totalBytes;
  //     final audioTotal = audioStream.size.totalBytes;
  //     final totalBytes =
  //         (videoTotal > 0 && audioTotal > 0) ? (videoTotal + audioTotal) : 0;

  //     if (maxBytes != null && totalBytes > 0 && totalBytes > maxBytes) {
  //       throw Exception('Video+audio exceeds size limit.');
  //     }

  //     // prepare temp files
  //     final tmpDir = await getTemporaryDirectory();
  //     final videoPath =
  //         '${tmpDir.path}/${videoId}_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
  //     final audioPath =
  //         '${tmpDir.path}/${videoId}_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
  //     final outPath =
  //         '${tmpDir.path}/${videoId}_merged_${DateTime.now().millisecondsSinceEpoch}.mp4';

  //     tempVideoFile = File(videoPath);
  //     tempAudioFile = File(audioPath);
  //     outputFile = File(outPath);

  //     // download video-only
  //     DebugLogger.info('📹 Downloading video stream...');
  //     {
  //       final stream = yt.videos.streamsClient.get(videoStream);
  //       final sink = tempVideoFile.openWrite();
  //       int received = 0;
  //       await for (final chunk in stream) {
  //         if (cancelNotifier.value) break;
  //         sink.add(chunk);
  //         received += chunk.length;
  //         if (totalBytes > 0) progressNotifier.value = (received / totalBytes);
  //       }
  //       await sink.flush();
  //       await sink.close();
  //       if (cancelNotifier.value) {
  //         try {
  //           await tempVideoFile.delete();
  //         } catch (_) {}
  //         return null;
  //       }
  //     }

  //     // download audio-only
  //     DebugLogger.info('🎵 Downloading audio stream...');
  //     {
  //       final stream = yt.videos.streamsClient.get(audioStream);
  //       final sink = tempAudioFile.openWrite();
  //       int received = 0;
  //       // For progress combine: we treat audio download as second half
  //       final videoDownloadedBytes = await tempVideoFile.length();
  //       await for (final chunk in stream) {
  //         if (cancelNotifier.value) break;
  //         sink.add(chunk);
  //         received += chunk.length;
  //         if (totalBytes > 0) {
  //           final combined = videoDownloadedBytes + received;
  //           progressNotifier.value = combined / totalBytes;
  //         }
  //       }
  //       await sink.flush();
  //       await sink.close();
  //       if (cancelNotifier.value) {
  //         try {
  //           await tempAudioFile.delete();
  //         } catch (_) {}
  //         return null;
  //       }
  //     }

  //     // 3) Merge with FFmpeg
  //     DebugLogger.info('🔗 Merging video and audio with FFmpeg...');
  //     progressNotifier.value = 0.9; // Show we're in merging phase

  //     // Build copy command first (faster, preserves quality)
  //     final copyCmd =
  //         '-y -i "${tempVideoFile.path}" -i "${tempAudioFile.path}" -c:v copy -c:a aac -b:a 192k -map 0:v:0 -map 1:a:0 "${outputFile.path}"';

  //     final session = await FFmpegKit.execute(copyCmd);
  //     final returnCode = await session.getReturnCode();

  //     if (ReturnCode.isSuccess(returnCode)) {
  //       // merged successfully with stream copy
  //       DebugLogger.success('✅ FFmpeg merge successful (copy mode)');
  //       progressNotifier.value = 1.0;
  //       // clean up parts
  //       try {
  //         await tempVideoFile.delete();
  //       } catch (_) {}
  //       try {
  //         await tempAudioFile.delete();
  //       } catch (_) {}
  //       return outputFile;
  //     } else {
  //       // try fallback re-encode command
  //       DebugLogger.warning(
  //           'ffmpeg copy failed, returnCode=${returnCode?.getValue()} trying re-encode');

  //       final reencodeCmd =
  //           '-y -i "${tempVideoFile.path}" -i "${tempAudioFile.path}" -c:v libx264 -crf 23 -preset veryfast -c:a aac -b:a 192k -map 0:v:0 -map 1:a:0 "${outputFile.path}"';
  //       final session2 = await FFmpegKit.execute(reencodeCmd);
  //       final returnCode2 = await session2.getReturnCode();
  //       if (ReturnCode.isSuccess(returnCode2)) {
  //         DebugLogger.success('✅ FFmpeg merge successful (re-encode mode)');
  //         progressNotifier.value = 1.0;
  //         try {
  //           await tempVideoFile.delete();
  //         } catch (_) {}
  //         try {
  //           await tempAudioFile.delete();
  //         } catch (_) {}
  //         return outputFile;
  //       } else {
  //         throw Exception(
  //             'FFmpeg merge failed: code ${returnCode2?.getValue()}');
  //       }
  //     }
  //   } finally {
  //     try {
  //       yt.close();
  //     } catch (_) {}
  //     // don't delete outputFile here; caller will handle it
  //   }
  // }

  // New robust download and save-to-gallery function
  // Future<String?> downloadYouTubeVideoAndSaveToGallery({
  //   required Map<String, dynamic> youtubeVideoData,
  //   bool requireWifi = false,
  //   int? maxBytes,
  //   required ValueNotifier<double> progressNotifier,
  //   required ValueNotifier<bool> cancelNotifier,
  //   VoidCallback? onCancelled,
  // }) async {
  //   final videoId = youtubeVideoData['id'] ??
  //       youtubeVideoData['videoId'] ??
  //       youtubeVideoData['video_id'];
  //   if (videoId == null) {
  //     throw Exception('Invalid YouTube video data: missing id');
  //   }

  //   // Optional: wifi check
  //   if (requireWifi) {
  //     final connectivityResults = await Connectivity().checkConnectivity();
  //     bool isWifi = connectivityResults.contains(ConnectivityResult.wifi);
  //     if (!isWifi) {
  //       throw Exception('Please connect to Wi‑Fi to download this video.');
  //     }
  //   }

  //   // Ask storage/photo permission on platforms where needed
  //   try {
  //     if (Platform.isAndroid || Platform.isIOS) {
  //       if (Platform.isAndroid) {
  //         // For Android, request storage permission
  //         final storageStatus = await Permission.storage.request();
  //         if (!storageStatus.isGranted) {
  //           DebugLogger.warning('Storage permission denied on Android');
  //           // Continue anyway as MediaStore may still work on newer Android versions
  //         }
  //       } else if (Platform.isIOS) {
  //         // For iOS, request photo library permission
  //         final photosStatus = await Permission.photos.request();
  //         if (!photosStatus.isGranted && !photosStatus.isLimited) {
  //           throw Exception(
  //               'Photo library permission is required to save videos to gallery');
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     DebugLogger.warning('Permission check warning: $e');
  //     // For Android, continue even if permission fails as MediaStore may work
  //     if (Platform.isIOS) {
  //       rethrow; // On iOS, permission is mandatory
  //     }
  //   }

  //   final yt = YoutubeExplode();
  //   File? tempFile;
  //   IOSink? sink;
  //   Stream<List<int>>? stream;

  //   try {
  //     // First check if video exists and is accessible
  //     DebugLogger.info('Checking video availability: $videoId');
  //     final video = await yt.videos.get(videoId);

  //     if (video.isLive) {
  //       throw Exception(
  //           'Cannot download live streams. Please wait for the stream to end.');
  //     }

  //     DebugLogger.info('Video title: ${video.title}');
  //     DebugLogger.info('Video duration: ${video.duration}');

  //     // Get manifest
  //     final manifest = await yt.videos.streamsClient.getManifest(videoId);

  //     // Try to get the best available stream
  //     StreamInfo? streamInfo;

  //     if (manifest.muxed.isNotEmpty) {
  //       // Prefer muxed streams (video + audio combined)
  //       streamInfo = manifest.muxed.withHighestBitrate();
  //       DebugLogger.info(
  //           'Using muxed stream with bitrate: ${streamInfo.bitrate}');
  //     } else if (manifest.videoOnly.isNotEmpty) {
  //       // Fallback to video-only stream (most common case for newer videos)
  //       streamInfo = manifest.videoOnly.withHighestBitrate();
  //       DebugLogger.info(
  //           'Using video-only stream with bitrate: ${streamInfo.bitrate}');
  //       DebugLogger.warning('Note: This will be video without audio');
  //     } else {
  //       throw Exception(
  //           'No downloadable video streams found for this video. It may be private, restricted, or requires authentication.');
  //     }

  //     // Size check
  //     final totalBytes = streamInfo.size.totalBytes;
  //     if (maxBytes != null && totalBytes > maxBytes) {
  //       throw Exception(
  //           'Video is too large (${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB). Max allowed: ${(maxBytes / (1024 * 1024)).toStringAsFixed(1)} MB.');
  //     }

  //     // Get stream
  //     stream = yt.videos.streamsClient.get(streamInfo);

  //     // prepare temp file
  //     final tempDir = await getTemporaryDirectory();
  //     final filePath =
  //         '${tempDir.path}/${videoId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
  //     tempFile = File(filePath);
  //     sink = tempFile.openWrite();

  //     // Stream to file with cancellation support
  //     int received = 0;
  //     progressNotifier.value = -1.0;

  //     await for (final chunk in stream) {
  //       if (cancelNotifier.value) break;
  //       sink.add(chunk);
  //       received += chunk.length;
  //       if (totalBytes > 0) {
  //         progressNotifier.value = received / totalBytes;
  //       } else {
  //         progressNotifier.value = -1.0;
  //       }
  //     }

  //     if (cancelNotifier.value) {
  //       // close/cleanup
  //       try {
  //         await sink.flush();
  //         await sink.close();
  //       } catch (_) {}
  //       try {
  //         if (await tempFile.exists()) await tempFile.delete();
  //       } catch (_) {}
  //       if (onCancelled != null) onCancelled();
  //       return null;
  //     }

  //     // finalize write
  //     await sink.flush();
  //     await sink.close();

  //     // Save to gallery
  //     progressNotifier.value = 0.0;
  //     final result =
  //         await GallerySaver.saveVideo(tempFile.path, albumName: 'Baakhapaa');

  //     if (result == true) {
  //       final savedPath = tempFile.path;
  //       DebugLogger.success(
  //           '✅ Video saved to gallery successfully: $savedPath');
  //       return savedPath;
  //     } else {
  //       throw Exception('Failed to save the video to gallery');
  //     }
  //   } catch (e) {
  //     // Clean up temp file on error
  //     try {
  //       if (tempFile != null && await tempFile.exists()) {
  //         await tempFile.delete();
  //       }
  //     } catch (_) {}
  //     rethrow;
  //   } finally {
  //     try {
  //       yt.close();
  //     } catch (_) {}
  //     progressNotifier.value = 1.0;
  //   }
  // }

  // Method to handle the download-to-gallery flow
  // Future<void> _downloadYouTubeVideoSaveGalleryAndContinue(
  //     Map<String, dynamic> youtubeVideoData) async {
  //   // Pre-check what type of streams are available
  //   final videoId = youtubeVideoData['id'] ??
  //       youtubeVideoData['videoId'] ??
  //       youtubeVideoData['video_id'];
  //   if (videoId == null) {
  //     setState(() {
  //       _uploadMessage = 'Invalid YouTube video data';
  //     });
  //     return;
  //   }

  //   // Check video availability first
  //   if (!await _checkVideoAvailability(videoId)) {
  //     return; // Error message already shown in _checkVideoAvailability
  //   }

  //   String dialogContent =
  //       'This will download the YouTube video and save it to your device gallery. This may use mobile data and storage space.';

  //   try {
  //     final yt = YoutubeExplode();
  //     final manifest = await yt.videos.streamsClient.getManifest(videoId);

  //     if (manifest.muxed.isEmpty && manifest.videoOnly.isNotEmpty) {
  //       dialogContent +=
  //           '\n\n⚠️ Note: This video will be downloaded without audio (video-only stream available).';
  //     }

  //     yt.close();
  //   } catch (e) {
  //     DebugLogger.warning('Could not pre-check stream types: $e');
  //   }

  //   // Confirm with user about download size and data usage
  //   final shouldDownload = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: Text('Save to Gallery'),
  //       content: Text(dialogContent + '\n\nContinue?'),
  //       actions: [
  //         TextButton(
  //             onPressed: () => Navigator.of(ctx).pop(false),
  //             child: Text('Cancel')),
  //         TextButton(
  //             onPressed: () => Navigator.of(ctx).pop(true),
  //             child: Text('Download & Save')),
  //       ],
  //     ),
  //   );

  //   if (shouldDownload != true) return;

  //   // Check and request permissions before starting download
  //   if (!await _ensureSavePermission()) {
  //     setState(() {
  //       _uploadMessage = '❌ Permission required to save videos to gallery';
  //     });
  //     return;
  //   }

  //   final progress = ValueNotifier<double>(-1.0);
  //   final cancelNotifier = ValueNotifier<bool>(false);

  //   // Show progress dialog
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (ctx) => DownloadProgressDialog(
  //       progress: progress,
  //       onCancel: () {
  //         cancelNotifier.value = true;
  //       },
  //     ),
  //   );

  //   setState(() => _isProcessing = true);

  //   try {
  //     final savedPath = await downloadYouTubeVideoAndSaveToGallery(
  //       youtubeVideoData: youtubeVideoData,
  //       requireWifi: false,
  //       maxBytes: 200 * 1024 * 1024, // 200 MB max
  //       progressNotifier: progress,
  //       cancelNotifier: cancelNotifier,
  //       onCancelled: () {
  //         if (mounted) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(content: Text('Download cancelled')),
  //           );
  //         }
  //       },
  //     );

  //     // Close dialog
  //     if (Navigator.canPop(context)) Navigator.of(context).pop();

  //     if (savedPath != null && !cancelNotifier.value) {
  //       // Create XFile so the rest of the flow works the same
  //       final downloadedXFile = XFile(savedPath);

  //       DebugLogger.success(
  //           '✅ Video saved to gallery and ready for editing: $savedPath');

  //       // Check if the saved file has audio
  //       final hasAudio = await _checkVideoHasAudio(savedPath);
  //       DebugLogger.info('🎵 Gallery saved file has audio: $hasAudio');

  //       setState(() {
  //         _selectedFile = downloadedXFile;
  //         _youtubeVideoData = youtubeVideoData;
  //         _uploadMessage = hasAudio
  //             ? '✅ Video saved to gallery with audio and ready for editing!'
  //             : '✅ Video saved to gallery (video-only) and ready for editing!';
  //         _currentStep = 1;
  //         _isProcessing = false;
  //       });

  //       // Trigger celebration animation
  //       _animationController.reset();
  //       _animationController.forward();

  //       // Show success snackbar
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('📥 Video saved to gallery and ready for editing!'),
  //             backgroundColor: Colors.green,
  //             duration: Duration(seconds: 3),
  //           ),
  //         );
  //       }
  //     } else {
  //       setState(() {
  //         _isProcessing = false;
  //         _uploadMessage = 'Download was cancelled';
  //       });
  //     }
  //   } catch (e) {
  //     DebugLogger.error('Download to gallery failed: $e');
  //     if (Navigator.canPop(context)) Navigator.of(context).pop();

  //     // Provide more specific error messages
  //     String errorMessage;
  //     if (e.toString().contains('VideoUnavailableException') ||
  //         e.toString().contains('Video unavailable')) {
  //       errorMessage =
  //           '❌ Video is unavailable. It may be private, deleted, or region-restricted.';
  //     } else if (e.toString().contains('live stream')) {
  //       errorMessage =
  //           '❌ Cannot download live streams. Please wait for the stream to end.';
  //     } else if (e.toString().contains('permission')) {
  //       errorMessage =
  //           '❌ Gallery permission denied. Please enable photo library access in settings.';
  //     } else if (e.toString().contains('network') ||
  //         e.toString().contains('connection')) {
  //       errorMessage =
  //           '❌ Network error. Please check your internet connection.';
  //     } else if (e.toString().contains('too large')) {
  //       errorMessage = '❌ Video file is too large to download.';
  //     } else {
  //       errorMessage = '❌ Download failed: ${e.toString()}';
  //     }

  //     setState(() {
  //       _isProcessing = false;
  //       _uploadMessage = errorMessage;
  //     });

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(errorMessage),
  //           backgroundColor: Colors.red,
  //           duration: Duration(seconds: 5),
  //         ),
  //       );
  //     }
  //   } finally {
  //     try {
  //       progress.dispose();
  //       cancelNotifier.dispose();
  //     } catch (_) {}
  //   }
  // }

  bool _isValidVideo(String? path) {
    if (path == null) return false;
    final validExtensions = ['.mp4', '.mov', '.avi', '.wmv'];
    return validExtensions.any((ext) => path.toLowerCase().endsWith(ext));
  }

  void _submitForm() {
    DebugLogger.info('Submit form called'); // Debug log

    // Only validate form if we're on the details step (step 1) which has the form key
    if (_currentStep == 1) {
      // Check if form key and current state are valid
      if (_formKey.currentState == null) {
        setState(() {
          _uploadMessage = 'Form not properly initialized';
        });
        DebugLogger.info('Form key current state is null'); // Debug log
        return;
      }

      if (!_formKey.currentState!.validate()) {
        setState(() {
          _uploadMessage = 'Please fill all required fields';
        });
        DebugLogger.error('Form validation failed'); // Debug log
        return;
      }
    }

    // Manual validation for settings step (step 2)
    if (_currentStep == 2) {
      // Validate title and description manually
      if (_titleController.text.trim().isEmpty) {
        setState(() {
          _uploadMessage = 'Title is required';
        });
        DebugLogger.info('Title is empty'); // Debug log
        return;
      }

      if (_descriptionController.text.trim().isEmpty) {
        setState(() {
          _uploadMessage = 'Description is required';
        });
        DebugLogger.info('Description is empty'); // Debug log
        return;
      }

      // Validate points and lives for settings step
      final points = int.tryParse(_pointsController.text);
      if (points == null || points < 100) {
        setState(() {
          _uploadMessage = 'Points must be at least 100';
        });
        DebugLogger.error('Invalid points value'); // Debug log
        return;
      }

      // Check coin balance before allowing upload
      final auth = Provider.of<Auth>(context, listen: false);
      if (points > auth.userAvailableCoins) {
        setState(() {
          _uploadMessage =
              'Insufficient coins. You have ${auth.userAvailableCoins} but need $points.';
        });
        DebugLogger.error(
            'Insufficient coins: have ${auth.userAvailableCoins}, need $points');
        return;
      }

      final lives = int.tryParse(_livesController.text);
      if (lives == null || lives < 1) {
        setState(() {
          _uploadMessage = 'Lives must be at least 1';
        });
        DebugLogger.error('Invalid lives value'); // Debug log
        return;
      }
    }

    // Validation for challenge submissions from collaborators step (step 3)
    if (_isChallenge == true && (_currentStep == 1 || _currentStep == 3)) {
      // Validate basic fields for challenge
      if (_titleController.text.trim().isEmpty) {
        setState(() {
          _uploadMessage = 'Title is required';
        });
        DebugLogger.info('Title is empty for challenge'); // Debug log
        return;
      }

      if (_descriptionController.text.trim().isEmpty) {
        setState(() {
          _uploadMessage = 'Description is required';
        });
        DebugLogger.info('Description is empty for challenge'); // Debug log
        return;
      }
    }

    if (_selectedFile == null && _youtubeVideoData == null) {
      setState(() {
        _uploadMessage = 'Please select or record a video';
      });
      DebugLogger.info('No file or YouTube video selected'); // Debug log
      return;
    }

    // Only validate local files, skip validation for YouTube videos
    if (_selectedFile != null) {
      if (!_isValidVideo(_selectedFile?.path)) {
        setState(() {
          _uploadMessage = 'Please select a valid video file';
        });
        DebugLogger.error('Invalid video file'); // Debug log
        return;
      }

      final file = File(_selectedFile!.path);
      if (!file.existsSync()) {
        setState(() {
          _uploadMessage = 'Selected file no longer exists';
        });
        DebugLogger.info('File does not exist'); // Debug log
        return;
      }
    }

    try {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      DebugLogger.info('Args: $args'); // Debug log
      DebugLogger.info('Is challenge: $_isChallenge'); // Debug log
      DebugLogger.info(
          '🤝 collaborationId in _submitForm: $_collaborationId'); // Debug log

      if (_isChallenge != null && _isChallenge!) {
        DebugLogger.info('Processing as challenge'); // Debug log

        // Build previewArgs and only include youtubeVideoData if no local file
        final previewArgs = <String, dynamic>{
          'title': _titleController.text,
          'description': _descriptionController.text,
          'isVideo': true,
          'shorts_topic_id': args?['shorts_topic_id'],
          'points': args?['points'],
          'lives': args?['lives'],
          'no_of_mcq': args?['no_of_mcq'],
          'content_type': _contentType, // Add content type (shorts/stories)
          'affiliate_product_ids':
              _selectedAffiliateProducts.map((p) => p.id).toList(),
          'related_shorts_ids':
              _selectedRelatedShorts.map((s) => s['id']).toList(),
          'related_episode_ids':
              _selectedRelatedEpisodes.map((e) => e['id']).toList(),
          'season_id': _selectedRelatedSeasons.isNotEmpty
              ? _selectedRelatedSeasons.first['id']
              : null,
          'collaborators': _selectedCollaborators,
        };

        // ✅ CRITICAL: Pass challenge_id from navigation args
        if (_challengeId != null) {
          previewArgs['challenge_id'] = _challengeId;
          DebugLogger.info('🚀 Passing challenge_id to preview: $_challengeId');
        }

        // ✅ COLLABORATION: Pass collaboration_id even in challenge path
        if (_collaborationId != null) {
          previewArgs['collaboration_id'] = _collaborationId;
          DebugLogger.info(
              '🤝 Passing collaboration_id to challenge preview: $_collaborationId');
        }

        if (_selectedFile != null) {
          previewArgs['file'] = _selectedFile;
        } else if (_youtubeVideoData != null) {
          previewArgs['youtubeVideoData'] = _youtubeVideoData;
        }

        Navigator.of(context).pushNamed(
          PreviewShortsScreen.routeName,
          arguments: previewArgs,
        );
      } else {
        DebugLogger.info('Processing as regular shorts'); // Debug log
        if (_selectedCategoryId == null) {
          setState(() {
            _uploadMessage = 'Please select a category';
          });
          DebugLogger.info('No category selected'); // Debug log
          return;
        }

        DebugLogger.info(
            'Navigating to preview with category: $_selectedCategoryId'); // Debug log

        // Build previewArgs and only include youtubeVideoData if no local file
        final previewArgs = <String, dynamic>{
          'title': _titleController.text,
          'description': _descriptionController.text,
          'isVideo': true,
          'shorts_topic_id': _selectedCategoryId,
          'points': int.parse(_pointsController.text),
          'coins_users': int.parse(_pointsController.text),
          'lives': int.parse(_livesController.text),
          'content_type': _contentType, // Add content type (shorts/stories)
          'affiliate_product_ids':
              _selectedAffiliateProducts.map((p) => p.id).toList(),
          'related_shorts_ids':
              _selectedRelatedShorts.map((s) => s['id']).toList(),
          'related_episode_ids':
              _selectedRelatedEpisodes.map((e) => e['id']).toList(),
          'season_id': _selectedRelatedSeasons.isNotEmpty
              ? _selectedRelatedSeasons.first['id']
              : null,
          'collaborators': _selectedCollaborators,
        };

        // ✅ CRITICAL: Pass challenge_id if this is a challenge submission
        if (_isChallenge == true && _challengeId != null) {
          previewArgs['challenge_id'] = _challengeId;
          DebugLogger.info('🚀 Passing challenge_id to preview: $_challengeId');
        }

        // ✅ COLLABORATION: Pass collaboration_id if invitation-first flow
        if (_collaborationId != null) {
          previewArgs['collaboration_id'] = _collaborationId;
          DebugLogger.info(
              '🤝 Passing collaboration_id to preview: $_collaborationId');
        }

        if (_selectedFile != null) {
          previewArgs['file'] = _selectedFile;
        } else if (_youtubeVideoData != null) {
          previewArgs['youtubeVideoData'] = _youtubeVideoData;
        }

        Navigator.of(context).pushNamed(
          PreviewShortsScreen.routeName,
          arguments: previewArgs,
        );
      }
    } catch (e) {
      DebugLogger.error('Error in submit form: $e'); // Debug log
      setState(() {
        _uploadMessage = 'Error processing video: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortsProvider = Provider.of<Shorts>(context);
    final shortTopics = shortsProvider.shortsTopic;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: header(context: context, titleText: 'Create Shorts'),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: _buildCurrentStep(isDark, shortTopics),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _livesController.dispose();
    super.dispose();
  }

  Widget _buildCurrentStep(bool isDark, List<dynamic> shortTopics) {
    final stepContent = () {
      switch (_currentStep) {
        case 0:
          return _buildMediaSelectionStep(isDark);
        case 1:
          return _buildDetailsStep(isDark);
        case 2:
          return _buildSettingsStep(isDark, shortTopics);
        case 3:
          return _buildCollaboratorsStep(isDark);
        default:
          return _buildMediaSelectionStep(isDark);
      }
    }();

    // Show collaboration banner when navigated from an active collaboration
    if (_collaborationId != null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.purple.withOpacity(0.9),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Collaborative Short — Collaboration #$_collaborationId',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: stepContent),
        ],
      );
    }

    return stepContent;
  }

  Widget _buildMediaSelectionStep(bool isDark) {
    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [Colors.black, Color(0xFF1A1A1A)]
                  : [Colors.white, Color(0xFFF8F9FA)],
            ),
          ),
        ),

        // Main content
        SafeArea(
          child: Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),

              // Header
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      context.l10n.chooseYourContent,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      context.l10n.chooseYourContentInfo,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Media selection cards with consistent sizing
                      Row(
                        children: [
                          Expanded(
                            child: _buildTikTokMediaCard(
                              title: context.l10n.gallery,
                              subtitle: context.l10n.chooseYourContent,
                              icon: Icons.video_library_rounded,
                              gradient: [Color(0xFF667eea), Color(0xFF764ba2)],
                              onTap: _pickMedia,
                              isDark: isDark,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildTikTokMediaCard(
                              title: context.l10n.record,
                              subtitle: context.l10n.recordInfo,
                              icon: Icons.videocam_rounded,
                              gradient: [Color(0xFFf093fb), Color(0xFFf5576c)],
                              onTap: _recordVideo,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),

                      // YouTube videos option
                      SizedBox(height: 16),
                      // _buildTikTokMediaCard(
                      //   title: 'From YouTube',
                      //   subtitle: 'Select from your uploaded videos',
                      //   icon: Icons.video_collection_rounded,
                      //   gradient: [Color(0xFFFF0000), Color(0xFFCC0000)],
                      //   onTap: _openYouTubeVideos,
                      //   isDark: isDark,
                      // ),

                      // Show drafts option if there are saved drafts
                      if (_draftsCount > 0) ...[
                        SizedBox(height: 20),
                        _buildDraftsCard(isDark),
                      ],

                      SizedBox(height: 12),

                      // Creator Portal Access
                      _buildCreatorPortalCard(isDark),

                      // Success message inside scrollable area
                      if (_uploadMessage != null) ...[
                        SizedBox(height: 20),
                        _buildSuccessMessage(),
                      ],

                      // Add some bottom spacing
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Loading overlay
        if (_isProcessing) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildDetailsStep(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    100, // Space for bottom button
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.tellUsAboutYourVideo,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.white
                          : const Color.fromARGB(255, 25, 16, 16),
                    ),
                  ),
                  SizedBox(height: 32),

                  // Title field
                  _buildInstagramTextField(
                    controller: _titleController,
                    label: context.l10n.title,
                    hint: context.l10n.whatsYourVideoAbout,
                    icon: Icons.title_rounded,
                    isDark: isDark,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Title is required';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 24),

                  // Description field
                  _buildInstagramTextField(
                    controller: _descriptionController,
                    label: context.l10n.description,
                    hint: '${context.l10n.describeYourContent}...',
                    icon: Icons.description_rounded,
                    isDark: isDark,
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Description is required';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 40),

                  // Navigation buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildSecondaryButton(
                          onPressed: () => setState(() {
                            _currentStep = 0;
                            // Clear any error messages when going back
                            if (_uploadMessage != null &&
                                (_uploadMessage!.contains('Error') ||
                                    _uploadMessage!.contains('Please') ||
                                    _uploadMessage!.contains('required'))) {
                              _uploadMessage = null;
                            }
                          }),
                          label: context.l10n.back,
                          isDark: isDark,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildPrimaryButton(
                          onPressed: () {
                            if (_isChallenge == true) {
                              // Challenge mode: skip Settings (step 2), go to Collaborators (step 3)
                              if (_formKey.currentState != null &&
                                  !_formKey.currentState!.validate()) {
                                setState(() {
                                  _uploadMessage =
                                      'Please fill all required fields';
                                });
                                return;
                              }
                              setState(() => _currentStep = 3);
                            } else {
                              setState(() => _currentStep = 2);
                            }
                          },
                          label: context.l10n.next,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Error message for details step
          if (_uploadMessage != null &&
              (_uploadMessage!.contains('Error') ||
                  _uploadMessage!.contains('Please') ||
                  _uploadMessage!.contains('required')))
            _buildErrorMessage(),
        ],
      ),
    );
  }

  Widget _buildSettingsStep(bool isDark, List<dynamic> shortTopics) {
    return Form(
      child: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.setupYourChallenge,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 32),

                  // Category dropdown
                  _buildInstagramDropdown(
                    label: context.l10n.category,
                    hint: context.l10n.chooseCategory,
                    value: _selectedCategoryId,
                    items: shortTopics.map<DropdownMenuItem<int>>((topic) {
                      return DropdownMenuItem<int>(
                        value: topic['id'],
                        child: Text(topic['title'] ?? 'Unknown Category'),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategoryId = value),
                    isDark: isDark,
                    isLoading: shortTopics.isEmpty,
                  ),

                  SizedBox(height: 24),

                  // Available coins balance
                  Builder(builder: (ctx) {
                    final auth = Provider.of<Auth>(ctx, listen: false);
                    final availableCoins = auth.userAvailableCoins;
                    return Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.amber.shade900.withOpacity(0.2)
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade300.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded,
                              color: Colors.amber.shade600, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Available: ',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$availableCoins points',
                            style: TextStyle(
                              color: Colors.amber.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: 12),

                  // Points and Lives
                  Row(
                    children: [
                      Expanded(
                        child: _buildInstagramTextField(
                          controller: _pointsController,
                          label: context.l10n.pointsReward,
                          hint: 'Min: 100',
                          icon: Icons.stars_rounded,
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Required';
                            final points = int.tryParse(value);
                            if (points == null || points < 100)
                              return 'Min: 100';
                            // Check against available balance
                            final auth =
                                Provider.of<Auth>(context, listen: false);
                            if (points > auth.userAvailableCoins) {
                              return 'You only have ${auth.userAvailableCoins} coins';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildInstagramTextField(
                          controller: _livesController,
                          label: context.l10n.lives,
                          hint: 'Min: 1',
                          icon: Icons.favorite_rounded,
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Required';
                            final lives = int.tryParse(value);
                            if (lives == null || lives < 1) return 'Min: 1';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Linked Content (Shorts, Episodes, Seasons, Products)
                  Text(
                    'Linked Content',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.amber : Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Consumer<AffiliateProvider>(
                    builder: (context, affiliateProvider, _) {
                      return Text(
                        affiliateProvider.isAffiliate
                            ? 'Link your previous content and affiliate products to this video.'
                            : 'Link your previous content to this video.',
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  if (_selectedRelatedShorts.isNotEmpty ||
                      _selectedRelatedEpisodes.isNotEmpty ||
                      _selectedRelatedSeasons.isNotEmpty ||
                      _selectedAffiliateProducts.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._selectedRelatedShorts.map((s) {
                          return Chip(
                            label: Text('📹 ${s['title'] ?? 'Untitled'}'),
                            onDeleted: () => setState(
                                () => _selectedRelatedShorts.remove(s)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            backgroundColor: Colors.blue.withOpacity(0.2),
                          );
                        }),
                        ..._selectedRelatedEpisodes.map((e) {
                          return Chip(
                            label: Text('🎬 ${e['title'] ?? 'Untitled'}'),
                            onDeleted: () => setState(
                                () => _selectedRelatedEpisodes.remove(e)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            backgroundColor: Colors.purple.withOpacity(0.2),
                          );
                        }),
                        ..._selectedRelatedSeasons.map((s) {
                          return Chip(
                            label: Text('📁 ${s['title'] ?? 'Untitled'}'),
                            onDeleted: () => setState(
                                () => _selectedRelatedSeasons.remove(s)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            backgroundColor: Colors.amber.withOpacity(0.2),
                          );
                        }),
                        ..._selectedAffiliateProducts.map((p) {
                          return Chip(
                            label: Text('🛍️ ${p.title}'),
                            onDeleted: () => setState(
                                () => _selectedAffiliateProducts.remove(p)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            backgroundColor: Colors.green.withOpacity(0.2),
                          );
                        }),
                      ],
                    ),
                  SizedBox(height: 8),

                  // New dedicated Affiliate Product Selector Button
                  Consumer<AffiliateProvider>(
                    builder: (context, affiliateProvider, _) {
                      if (!affiliateProvider.isAffiliate)
                        return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildSecondaryButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AffiliateProductSelector(
                                  initialSelectedIds: _selectedAffiliateProducts
                                      .map((p) => p.id)
                                      .toList(),
                                  onSelected: (products) {
                                    setState(() {
                                      _selectedAffiliateProducts =
                                          List<AffiliateProduct>.from(products);
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                          label: _selectedAffiliateProducts.isEmpty
                              ? 'Attach Affiliate Products'
                              : 'Change Affiliate Products',
                          isDark: isDark,
                        ),
                      );
                    },
                  ),

                  _buildSecondaryButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreatorContentSelector(
                            initialSelectedShorts: _selectedRelatedShorts,
                            initialSelectedEpisodes: _selectedRelatedEpisodes,
                            initialSelectedSeasons: _selectedRelatedSeasons,
                            showProducts:
                                false, // Disable products tab in unified selector
                            initialSelectedAffiliateProducts:
                                _selectedAffiliateProducts,
                            onSelected: (
                                {required shorts,
                                required episodes,
                                required seasons,
                                required affiliateProducts}) {
                              setState(() {
                                _selectedRelatedShorts =
                                    List<dynamic>.from(shorts);
                                _selectedRelatedEpisodes =
                                    List<dynamic>.from(episodes);
                                _selectedRelatedSeasons =
                                    List<dynamic>.from(seasons);
                                _selectedAffiliateProducts =
                                    List<AffiliateProduct>.from(
                                        affiliateProducts);
                              });
                            },
                          ),
                        ),
                      );
                    },
                    label: (_selectedRelatedShorts.isEmpty &&
                            _selectedRelatedEpisodes.isEmpty &&
                            _selectedRelatedSeasons.isEmpty &&
                            _selectedAffiliateProducts.isEmpty)
                        ? 'Select Linked Content'
                        : 'Change Linked Content',
                    isDark: isDark,
                  ),

                  SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Sticky navigation bar ──────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSecondaryButton(
                    onPressed: () => setState(() {
                      _currentStep = 1;
                      if (_uploadMessage != null &&
                          (_uploadMessage!.contains('Error') ||
                              _uploadMessage!.contains('Please') ||
                              _uploadMessage!.contains('required'))) {
                        _uploadMessage = null;
                      }
                    }),
                    label: context.l10n.back,
                    isDark: isDark,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildPrimaryButton(
                    onPressed: () {
                      // Validate points and lives before proceeding
                      final points = int.tryParse(_pointsController.text);
                      final lives = int.tryParse(_livesController.text);

                      if (points == null || points < 100) {
                        setState(() =>
                            _uploadMessage = 'Points must be at least 100');
                        return;
                      }
                      if (lives == null || lives < 1) {
                        setState(
                            () => _uploadMessage = 'Lives must be at least 1');
                        return;
                      }

                      // Check coin balance
                      final auth = Provider.of<Auth>(context, listen: false);
                      if (points > auth.userAvailableCoins) {
                        setState(() => _uploadMessage =
                            'Insufficient coins. You have ${auth.userAvailableCoins} but need $points.');
                        return;
                      }

                      setState(() {
                        _uploadMessage = null;
                        _currentStep = 3;
                      });
                    },
                    label: '${context.l10n.next}: Collaborators',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 3 — Collaborators (only shown for non-challenge shorts)
  // Challenges are submitted directly from Step 1, so they never reach here.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCollaboratorsStep(bool isDark) {
    return Column(
      children: [
        _buildProgressIndicator(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite Collaborators',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Optionally invite other creators to collaborate on this video. Skip this step if you want to post solo.',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                SizedBox(height: 32),

                // If coming from an accepted collaboration, collaborators are
                // already defined by that collaboration record — show a banner.
                if (_collaborationId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.purple.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people_alt_rounded,
                            color: Colors.purple, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Collaborative Short',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This short will be submitted under your accepted collaboration. Collaborators are already set by the collaboration invitation.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (_selectedCollaborators.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedCollaborators.map((collaborator) {
                        String offerText = '';
                        if (collaborator['offer_type'] == 'points') {
                          offerText = ' (${collaborator['offer_amount']} pts)';
                        } else if (collaborator['offer_type'] == 'gift') {
                          offerText = ' (Gift)';
                        }
                        final imageUrl =
                            collaborator['image']?.toString() ?? '';
                        final hasImage = imageUrl.isNotEmpty;
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: Colors.amber,
                            backgroundImage: hasImage
                                ? CachedNetworkImageProvider(imageUrl)
                                : null,
                            child: hasImage
                                ? null
                                : Text(
                                    collaborator['username']?[0]
                                            ?.toUpperCase() ??
                                        '?',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                          ),
                          label: Text('@${collaborator['username']}$offerText'),
                          onDeleted: () => setState(() =>
                              _selectedCollaborators.remove(collaborator)),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          backgroundColor: Colors.purple.withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                  SizedBox(height: 12),
                  _buildSecondaryButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CollaboratorSelector(
                            initialSelected: _selectedCollaborators,
                            onSelected: (collaborators) {
                              setState(() {
                                _selectedCollaborators =
                                    List<Map<String, dynamic>>.from(
                                        collaborators);
                              });
                            },
                          ),
                        ),
                      );
                    },
                    label: _selectedCollaborators.isEmpty
                        ? 'Select Collaborators'
                        : 'Change Collaborators (${_selectedCollaborators.length}/4)',
                    isDark: isDark,
                  ),
                ],

                SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // ── Sticky navigation bar ──────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
          child: Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  onPressed: () => setState(() {
                    // In challenge mode, back from collaborators → details (step 1)
                    // In normal mode, back from collaborators → settings (step 2)
                    _currentStep = _isChallenge == true ? 1 : 2;
                    if (_uploadMessage != null &&
                        (_uploadMessage!.contains('Error') ||
                            _uploadMessage!.contains('Please') ||
                            _uploadMessage!.contains('required'))) {
                      _uploadMessage = null;
                    }
                  }),
                  label: context.l10n.back,
                  isDark: isDark,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildPrimaryButton(
                  onPressed: _submitForm,
                  label: context.l10n.post,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        if (_uploadMessage != null &&
            (_uploadMessage!.contains('Error') ||
                _uploadMessage!.contains('Please') ||
                _uploadMessage!.contains('required')))
          _buildErrorMessage(),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(_isChallenge == true ? 3 : 4, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isCompleted
                    ? Colors.amber
                    : isActive
                        ? Colors.amber.withValues(alpha: 0.6)
                        : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTikTokMediaCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 180, // Reduced from 200 to help with overflow
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative background pattern
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CustomPaint(
                    painter: CirclePatternPainter(),
                  ),
                ),
              ),

              // Content
              Container(
                width: double.infinity,
                height: double.infinity,
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 48,
                      color: Colors.white,
                    ),
                    SizedBox(height: 14),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatorPortalCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea).withValues(alpha: 0.1),
            Color(0xFF764ba2).withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade600.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.computer_rounded,
              color: Colors.amber.shade600,
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.creatorPortal,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  context.l10n.creatorPortalInfo,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.amber.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final Uri url = Uri.parse('https://creators.baakhapaa.com');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                context.l10n.open,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsCard(bool isDark) {
    DebugLogger.info(
        'Building drafts card with count: $_draftsCount'); // Debug log
    return GestureDetector(
      behavior:
          HitTestBehavior.opaque, // Ensure the gesture detector captures taps
      onTap: () async {
        DebugLogger.info('Drafts card tapped!'); // Debug log
        HapticFeedback.lightImpact();
        try {
          DebugLogger.info(
              'Attempting navigation to drafts screen...'); // Debug log
          await Navigator.of(context).pushNamed(
            DraftsScreen.routeName,
          );
          DebugLogger.success(
              'Navigation successful, refreshing drafts count...'); // Debug log
          // Refresh drafts count when returning from drafts screen
          _loadDraftsCount();
        } catch (e) {
          DebugLogger.error('Error navigating to drafts: $e');
          // Fallback navigation
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => DraftsScreen(),
                ),
              )
              .then((_) => _loadDraftsCount());
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(18), // Reduced from 20
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8360c3).withValues(alpha: 0.8),
              Color(0xFF2ebf91).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF8360c3).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(14), // Reduced from 16
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.drafts_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            SizedBox(width: 16), // Reduced from 20
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Prevent overflow
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Saved Drafts',
                          style: TextStyle(
                            fontSize: 18, // Reduced from 20
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_draftsCount',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2), // Reduced from 4
                  Text(
                    'Continue with saved videos',
                    style: TextStyle(
                      fontSize: 13, // Reduced from 14
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: EdgeInsets.all(24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _uploadMessage!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _uploadMessage!,
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          // Add Next button when video is selected and we're on step 0
          if (_selectedFile != null && _currentStep == 0) ...[
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _currentStep = 1);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue to Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
            SizedBox(height: 16),
            Text(
              'Processing...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstagramTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.amber.shade600),
            hintStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
            filled: true,
            fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.amber.shade600,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }

  Widget _buildInstagramDropdown({
    required String label,
    required String hint,
    required int? value,
    required List<DropdownMenuItem<int>> items,
    required void Function(int?) onChanged,
    required bool isDark,
    bool isLoading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: isLoading
              ? Container(
                  height: 60,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.amber.shade600,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '${context.l10n.loadingCategories}...',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    hint: Text(
                      hint,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                      ),
                    ),
                    value: value,
                    items: items,
                    onChanged: onChanged,
                    dropdownColor: isDark ? Colors.grey.shade800 : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback onPressed,
    required String label,
    required bool isDark,
  }) {
    return Container(
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback onPressed,
    required String label,
    required bool isDark,
  }) {
    return Container(
      height: 56,
      child: OutlinedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : Colors.black87,
          side: BorderSide(
            color: isDark ? Colors.white54 : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// Custom painter for decorative background
class CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Draw decorative circles
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      20,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.7),
      15,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.9),
      10,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
