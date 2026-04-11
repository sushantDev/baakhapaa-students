import 'dart:io';
import 'package:baakhapaa/models/affiliate_product.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/story_creation.dart';
import 'package:baakhapaa/providers/challenge.dart';
import '../../../utils/debug_logger.dart';
import '../../../models/url.dart';
import '../../../widgets/creator_content_selector.dart';
import '../../../widgets/collaborator_selector.dart';
import '../../../widgets/skeleton_loading.dart';

class CreateSeasonScreen extends StatefulWidget {
  static const routeName = '/create-season';

  const CreateSeasonScreen({Key? key}) : super(key: key);

  @override
  State<CreateSeasonScreen> createState() => _CreateSeasonScreenState();
}

class _CreateSeasonScreenState extends State<CreateSeasonScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Step flow
  int _currentStep = 0; // 0, 1, 2, 3
  final List<String> _stepTitles = [
    'Media',
    'Details',
    'Categories',
    'Collaborators',
  ];

  // Edit mode
  bool _isEditMode = false;
  int? _editingSeasonId;
  Map<String, dynamic>? _existingSeason;

  // Challenge mode
  bool? _isChallenge;
  int? _challengeId;
  int? _storyTopicId;
  int? _noOfMcq;
  int? _challengePoints;
  int? _challengeLives;
  int? _headingId;

  // Collaboration
  int? _collaborationId;

  // Basic fields matching API
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _directorController = TextEditingController();
  final _subDirectorController = TextEditingController();

  // Video/Image
  File? _imageFile;
  File? _videoFile;
  String? _existingImageUrl;
  String? _existingVideoUrl;
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;

  // Controllers for coin fields
  final _coinToUnlockController = TextEditingController();
  final _coinToJumpController = TextEditingController();

  // Multi-select lists
  final List<int> _selectedHeadings = [];
  final List<int> _selectedGenres = [];
  final List<int> _selectedMaturities = [];
  // final List<int> _selectedAchievements = []; // Commented out for now
  final List<String> _writers = [];
  final List<String> _casts = [];
  final List<dynamic> _selectedShorts = [];
  List<Map<String, dynamic>> _selectedCollaborators = [];

  // Settings
  bool _isJumpAvailable = false;
  int? _coinToJump;
  bool _isLocked = false;
  int? _coinToUnlock;
  DateTime _publishDate = DateTime.now();

  // Metadata from API
  bool _metadataLoaded = false;
  List<dynamic> _headings = [];
  List<dynamic> _genres = [];
  List<dynamic> _maturities = [];
  // List<dynamic> _achievements = []; // Commented out for now

  final Map<String, bool> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEditMode();
    });
    _fetchMetadata();
  }

  Future<void> _checkEditMode() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // Parse challenge arguments
    if (args != null) {
      _isChallenge = args['is_challenge'] as bool?;
      _challengeId = args['challenge_id'] as int?;
      _storyTopicId = args['story_topic_id'] as int?;
      _noOfMcq = args['no_of_mcq'] as int?;
      _challengePoints = args['points'] as int?;
      _challengeLives = args['lives'] as int?;
      _headingId = args['heading_id'] as int?;
      _collaborationId = args['collaboration_id'] as int?;

      // Pre-select heading if provided for challenge
      if (_headingId != null && !_selectedHeadings.contains(_headingId!)) {
        setState(() {
          _selectedHeadings.add(_headingId!);
        });
      }
    }

    if (args != null && args['mode'] == 'edit' && args['season'] != null) {
      _isEditMode = true;
      final simplifiedSeason = args['season'];
      _editingSeasonId = simplifiedSeason['id'];

      // Fetch full season details from API
      try {
        setState(() => _isLoading = true);
        final storyCreation =
            Provider.of<StoryCreation>(context, listen: false);
        _existingSeason =
            await storyCreation.getSeasonDetails(_editingSeasonId!);
        _populateExistingData();
      } catch (e) {
        DebugLogger.error('Error fetching season details: $e');
        if (mounted) {
          _showErrorSnackBar('Failed to load season details: ${e.toString()}');
          Navigator.of(context).pop();
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _populateExistingData() {
    if (_existingSeason == null) return;

    setState(() {
      // Basic fields
      _titleController.text = _existingSeason!['title'] ?? '';
      _descriptionController.text = _existingSeason!['description'] ?? '';
      _directorController.text = _existingSeason!['director'] ?? '';
      _subDirectorController.text = _existingSeason!['sub_director'] ?? '';

      // Writers and casts
      if (_existingSeason!['writers'] != null) {
        final writers = _existingSeason!['writers'];
        if (writers is List) {
          _writers.addAll(writers.map((w) => w.toString()));
        }
      }
      if (_existingSeason!['casts'] != null) {
        final casts = _existingSeason!['casts'];
        if (casts is List) {
          _casts.addAll(casts.map((c) => c.toString()));
        }
      }

      // Multi-select
      if (_existingSeason!['headings'] != null) {
        final headings = _existingSeason!['headings'] as List;
        _selectedHeadings.addAll(headings.map((h) => h['id'] as int));
      }
      if (_existingSeason!['genres'] != null) {
        final genres = _existingSeason!['genres'] as List;
        _selectedGenres.addAll(genres.map((g) => g['id'] as int));
      }
      if (_existingSeason!['maturities'] != null) {
        final maturities = _existingSeason!['maturities'] as List;
        _selectedMaturities.addAll(maturities.map((m) => m['id'] as int));
      }

      // Settings
      _isJumpAvailable = _existingSeason!['is_jump_available'] == 1 ||
          _existingSeason!['is_jump_available'] == true;
      _coinToJump = _existingSeason!['coin_to_jump'];
      _coinToJumpController.text = _coinToJump?.toString() ?? '';

      _isLocked = _existingSeason!['is_locked'] == 1 ||
          _existingSeason!['is_locked'] == true;
      _coinToUnlock = _existingSeason!['coin_to_unlock'];
      _coinToUnlockController.text = _coinToUnlock?.toString() ?? '';

      // Publish date
      if (_existingSeason!['publish_date'] != null) {
        try {
          _publishDate = DateTime.parse(_existingSeason!['publish_date']);
        } catch (e) {
          DebugLogger.error('Error parsing publish date: $e');
        }
      }

      // Existing media URLs
      _existingVideoUrl = _existingSeason!['trailer_url'];

      // Handle thumbnail (could be string or object)
      if (_existingSeason!['thumbnail'] != null) {
        if (_existingSeason!['thumbnail'] is String) {
          final thumbnail = _existingSeason!['thumbnail'] as String;
          if (thumbnail.isNotEmpty &&
              thumbnail.toLowerCase() != 'none' &&
              thumbnail.toLowerCase() != 'null' &&
              (thumbnail.startsWith('http://') ||
                  thumbnail.startsWith('https://'))) {
            _existingImageUrl = thumbnail;
          }
        } else if (_existingSeason!['thumbnail'] is Map) {
          _existingImageUrl = _existingSeason!['thumbnail']['url'];
        }
      }

      // Fallback to images array if thumbnail not found
      if (_existingImageUrl == null &&
          _existingSeason!['images'] != null &&
          (_existingSeason!['images'] as List).isNotEmpty) {
        final imageUrl = _existingSeason!['images'][0]['url'];
        if (imageUrl != null && imageUrl.toString().isNotEmpty) {
          _existingImageUrl = imageUrl;
        }
      }

      // Populate selected shorts
      if (_existingSeason!['linked_content'] != null &&
          _existingSeason!['linked_content']['related_shorts'] != null) {
        _selectedShorts.clear();
        _selectedShorts
            .addAll(_existingSeason!['linked_content']['related_shorts']);
      }
    });

    DebugLogger.info('✅ Populated existing season data for editing');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _directorController.dispose();
    _subDirectorController.dispose();
    _coinToUnlockController.dispose();
    _coinToJumpController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    if (mounted) {
      setState(() {
        _isVideoLoading = true;
        _isVideoInitialized = false;
      });
    }

    try {
      // Dispose previous controller if exists
      _videoPlayerController?.dispose();

      // Construct full video URL - same pattern as video_screen.dart
      final fullUrl = '${Url.mediaUrl}/$videoUrl';
      DebugLogger.info('🎥 Initializing video player with URL: $fullUrl');

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(fullUrl),
        httpHeaders: {
          'Accept': '*/*',
        },
      );

      // Add error listener
      _videoPlayerController!.addListener(() {
        if (_videoPlayerController!.value.hasError) {
          DebugLogger.error(
              '❌ Video player error: ${_videoPlayerController!.value.errorDescription}');
          if (mounted) {
            setState(() {
              _isVideoInitialized = false;
              _isVideoLoading = false;
            });
            _showErrorSnackBar(
                'Video playback error: ${_videoPlayerController!.value.errorDescription}');
          }
        }
      });

      await _videoPlayerController!.initialize();

      DebugLogger.success('✅ Video initialized successfully');
      DebugLogger.info(
          'Video duration: ${_videoPlayerController!.value.duration}');
      DebugLogger.info('Video size: ${_videoPlayerController!.value.size}');

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
      }
    } catch (e) {
      DebugLogger.error('❌ Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
          _isVideoLoading = false;
        });
        _showErrorSnackBar('Failed to load video preview: $e');
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Future<void> _fetchMetadata() async {
    try {
      final storyCreation = Provider.of<StoryCreation>(context, listen: false);
      await storyCreation.fetchSeasonMetadata();

      setState(() {
        _headings = storyCreation.headings;
        _genres = storyCreation.genres;
        _maturities = storyCreation.maturities;
        // _achievements = storyCreation.achievements; // Commented out for now
        _metadataLoaded = true;
      });
    } catch (e) {
      DebugLogger.error('Error fetching metadata: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load metadata');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final fileSize = await file.length();

        if (fileSize > 10 * 1024 * 1024) {
          _showErrorSnackBar('Image must be less than 10MB');
          return;
        }

        setState(() => _imageFile = file);
      }
    } catch (e) {
      DebugLogger.error('Error picking image: $e');
      _showErrorSnackBar('Failed to pick image');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        final file = File(video.path);
        final fileSize = await file.length();

        if (fileSize > 1024 * 1024 * 1024) {
          _showErrorSnackBar('Video must be less than 1GB');
          return;
        }

        setState(() {
          _videoFile = file;
        });

        // 🔥 Initialize video player for local file
        _initializeLocalVideoPlayer(file);
      }
    } catch (e) {
      DebugLogger.error('Error picking video: $e');
      _showErrorSnackBar('Failed to pick video');
    }
  }

  // 🔥 NEW: Initialize video player for local file
  Future<void> _initializeLocalVideoPlayer(File videoFile) async {
    if (mounted) {
      setState(() {
        _isVideoLoading = true;
        _isVideoInitialized = false;
      });
    }

    try {
      _videoPlayerController?.dispose();

      _videoPlayerController = VideoPlayerController.file(videoFile);

      _videoPlayerController!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      await _videoPlayerController!.initialize();

      DebugLogger.success('✅ Local video initialized successfully');

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
      }
    } catch (e) {
      DebugLogger.error('❌ Error initializing local video player: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
          _isVideoLoading = false;
        });
        _showErrorSnackBar('Failed to load video preview: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitSeason() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      _showErrorSnackBar(
          'Please fill in all required fields (Title, Description, Director)');
      // Navigate back to the Details step so user can see the validation errors
      setState(() => _currentStep = 1);
      return;
    }

    // Validation
    if (_selectedHeadings.isEmpty) {
      _showErrorSnackBar('Please select at least one heading');
      setState(() => _currentStep = 2);
      return;
    }
    if (_selectedGenres.isEmpty) {
      _showErrorSnackBar('Please select at least one genre');
      setState(() => _currentStep = 2);
      return;
    }
    setState(() => _isLoading = true);

    try {
      final storyCreation = Provider.of<StoryCreation>(context, listen: false);

      if (_isEditMode && _editingSeasonId != null) {
        // Update existing season
        await storyCreation.updateSeason(
          seasonId: _editingSeasonId!,
          title: _titleController.text,
          description: _descriptionController.text,
          trailerUrl: null,
          videoFile: _videoFile, // Can be null to keep existing video
          headings: _selectedHeadings,
          genres: _selectedGenres,
          maturities: _selectedMaturities,
          director: _directorController.text,
          subDirector: _subDirectorController.text.isEmpty
              ? null
              : _subDirectorController.text,
          writers: _writers.isEmpty ? null : _writers,
          casts: _casts.isEmpty ? null : _casts,
          isJumpAvailable: _isJumpAvailable,
          coinToJump: _coinToJump,
          isLocked: _isLocked,
          coinToUnlock: _coinToUnlock,
          publishDate: DateFormat('yyyy-MM-dd').format(_publishDate),
          achievements: null,
          imageFile: _imageFile, // Can be null to keep existing image
          shortsIds: _selectedShorts.map((s) => s['id'] as int).toList(),
          collaborationId: _collaborationId,
          collaborators: _selectedCollaborators,
        );

        if (mounted) {
          _showSuccessSnackBar('Season updated successfully!');
          Navigator.of(context).pop(); // Return to studio
        }
      } else {
        // Create new season
        final result = await storyCreation.createSeason(
          title: _titleController.text,
          description: _descriptionController.text,
          trailerUrl: null,
          videoFile: _videoFile,
          headings: _selectedHeadings,
          genres: _selectedGenres,
          maturities: _selectedMaturities,
          director: _directorController.text,
          subDirector: _subDirectorController.text.isEmpty
              ? null
              : _subDirectorController.text,
          writers: _writers.isEmpty ? null : _writers,
          casts: _casts.isEmpty ? null : _casts,
          isJumpAvailable: _isJumpAvailable,
          coinToJump: _coinToJump,
          isLocked: _isLocked,
          coinToUnlock: _coinToUnlock,
          publishDate: DateFormat('yyyy-MM-dd').format(_publishDate),
          achievements: null,
          imageFile: _imageFile,
          // Challenge parameters
          isChallenge: _isChallenge ?? false,
          challengeId: _challengeId,
          storyTopicId: _storyTopicId,
          noOfMcq: _noOfMcq,
          challengePoints: _challengePoints,
          challengeLives: _challengeLives,
          shortsIds: _selectedShorts.map((s) => s['id'] as int).toList(),
          // Collaboration parameter
          collaborationId: _collaborationId,
          // Collaborators parameter
          collaborators: _selectedCollaborators,
        );

        if (mounted) {
          _showSuccessSnackBar('Season created successfully!');

          // Navigate to episode creation screen for the newly created season
          final newSeasonId =
              result['season_id'] ?? storyCreation.newlyCreatedSeasonId;

          // If it's a challenge, save the season ID to local storage AND create challenge user
          if (_isChallenge == true &&
              newSeasonId != null &&
              _challengeId != null) {
            await _saveChallengeSeasonId(newSeasonId);

            // Create challenge user entry linking the challenge to this season
            try {
              // final challengeProvider =
              //     Provider.of<Challenge>(context, listen: false);
              // await challengeProvider.createChallengeUser(
              //   challengeId: _challengeId!,
              //   seasonId: newSeasonId,
              // );
              DebugLogger.success(
                  '✅ Challenge user created for challenge $_challengeId with season $newSeasonId');
            } catch (e) {
              DebugLogger.error('⚠️ Error creating challenge user: $e');
              // Don't block the flow if challenge user creation fails
              // User can still create episodes
            }
          }

          // 🔥 FETCH FULL SEASON DETAILS AND SAVE TO CHALLENGE PROVIDER
          try {
            final storyCreation =
                Provider.of<StoryCreation>(context, listen: false);

            final seasonDetails =
                await storyCreation.getSeasonDetails(newSeasonId);

            final challengeProvider =
                Provider.of<Challenge>(context, listen: false);

            challengeProvider.setChallengeSeasonDetails(seasonDetails);

            DebugLogger.success(
                '🟢 Season details stored for challenge progression');
          } catch (e) {
            DebugLogger.error('❌ Failed to fetch/store season details: $e');
          }

          // Build arguments for episode creation
          final Map<String, dynamic> episodeArgs = {
            'seasonId': newSeasonId,
            'seasonTitle': _titleController.text,
          };

          // If it's a challenge, pass challenge parameters to episode screen
          if (_isChallenge == true) {
            episodeArgs['is_challenge'] = _isChallenge;
            episodeArgs['challenge_id'] = _challengeId;
            episodeArgs['story_topic_id'] = _storyTopicId;
            episodeArgs['no_of_mcq'] = _noOfMcq;
            episodeArgs['points'] = _challengePoints;
            episodeArgs['lives'] = _challengeLives;
          }

          Navigator.of(context).pushReplacementNamed(
            '/create-episode',
            arguments: episodeArgs,
          );
        }
      }
    } catch (e) {
      DebugLogger.error('Error creating season: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to create season: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Save challenge season ID to local storage (workaround for missing API field)
  Future<void> _saveChallengeSeasonId(int seasonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> ids =
          prefs.getStringList('challenge_season_ids') ?? [];
      if (!ids.contains(seasonId.toString())) {
        ids.add(seasonId.toString());
        await prefs.setStringList('challenge_season_ids', ids);
        DebugLogger.info('💾 Saved challenge season ID: $seasonId');
      }
    } catch (e) {
      DebugLogger.error('Error saving challenge season ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_metadataLoaded) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          title: const Text('Create Season'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Padding(
          padding: EdgeInsets.all(24.0),
          child: ListSkeleton(itemCount: 5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(_isChallenge == true
            ? 'Create Season (Challenge)'
            : _isEditMode
                ? 'Edit Season'
                : 'Create Season'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: _buildCurrentStep(isDark),
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(_stepTitles.length, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
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

  Widget _buildCurrentStep(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStepOneMedia(isDark);
      case 1:
        return _buildStepTwoDetails(isDark);
      case 2:
        return _buildStepThreeMeta(isDark);
      case 3:
        return _buildStepFourCollaborators(isDark);
      default:
        return const SizedBox();
    }
  }

  // Step 1: Media
  Widget _buildStepOneMedia(bool isDark) {
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
                  'Add Your Media',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload a cover image for your season. A trailer video is optional.',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),

                // Season Image
                Text(
                  'Season Cover Image',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildImagePicker(),
                const SizedBox(height: 32),

                // Trailer Video
                Text(
                  'Trailer Video (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Leave unchanged if not selecting a video.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildVideoPicker(),
              ],
            ),
          ),
        ),

        // Bottom navigation
        Padding(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildPrimaryButton(
                  onPressed: () {
                    setState(() => _currentStep = 1);
                  },
                  label: 'Next: Details',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 2: Details
  Widget _buildStepTwoDetails(bool isDark) {
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
                bottom: MediaQuery.of(context).viewInsets.bottom + 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Season Details',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your season — title, description, and crew.',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildInstagramTextField(
                    controller: _titleController,
                    label: 'Season Title *',
                    hint: 'Give your season a name',
                    icon: Icons.title_rounded,
                    isDark: isDark,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 24),
                  _buildInstagramTextField(
                    controller: _descriptionController,
                    label: 'Description *',
                    hint: 'What is your season about?',
                    icon: Icons.description_rounded,
                    isDark: isDark,
                    maxLines: 4,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Description is required'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  _buildInstagramTextField(
                    controller: _directorController,
                    label: 'Director *',
                    hint: 'Who directed this season?',
                    icon: Icons.person_rounded,
                    isDark: isDark,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Director is required' : null,
                  ),
                  const SizedBox(height: 24),
                  _buildInstagramTextField(
                    controller: _subDirectorController,
                    label: 'Assistant Director',
                    hint: 'Optional',
                    icon: Icons.person_outline_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 32),
                  _buildWritersSection(isDark),
                  const SizedBox(height: 24),
                  _buildCastsSection(isDark),
                ],
              ),
            ),
          ),

          // Bottom navigation
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSecondaryButton(
                    onPressed: () => setState(() => _currentStep = 0),
                    label: 'Back',
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildPrimaryButton(
                    onPressed: () {
                      if (_formKey.currentState != null &&
                          !_formKey.currentState!.validate()) {
                        return;
                      }
                      setState(() => _currentStep = 2);
                    },
                    label: 'Next: Categories',
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

  // Step 3: Categories + Settings
  Widget _buildStepThreeMeta(bool isDark) {
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
                  'Categories & Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose categories, genres, and configure season settings.',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),

                _buildMultiSelectSection(
                  'Categories *',
                  _headings,
                  _selectedHeadings,
                  isDisabled: _isChallenge == true,
                ),
                const SizedBox(height: 24),
                _buildMultiSelectSection('Genres *', _genres, _selectedGenres),
                const SizedBox(height: 24),
                _buildMultiSelectSection('Maturity Ratings (Optional)',
                    _maturities, _selectedMaturities),
                const SizedBox(height: 32),

                // Locked toggle
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'Locked Season',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Users must pay coins to unlock',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    value: _isLocked,
                    onChanged: (v) => setState(() => _isLocked = v),
                    activeColor: Colors.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_isLocked) ...[
                  const SizedBox(height: 12),
                  _buildInstagramTextField(
                    controller: _coinToUnlockController,
                    label: 'Coins to Unlock',
                    hint: 'How many coins?',
                    icon: Icons.lock_open_rounded,
                    isDark: isDark,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _coinToUnlock = int.tryParse(v),
                  ),
                ],
                const SizedBox(height: 24),

                _buildShortsSelector(),
                const SizedBox(height: 24),
                _buildPublishDate(),
              ],
            ),
          ),
        ),

        // Bottom navigation
        Padding(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
          child: Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  label: 'Back',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildPrimaryButton(
                  onPressed: () {
                    if (_selectedHeadings.isEmpty) {
                      _showErrorSnackBar('Please select at least one category');
                      return;
                    }
                    if (_selectedGenres.isEmpty) {
                      _showErrorSnackBar('Please select at least one genre');
                      return;
                    }
                    setState(() => _currentStep = 3);
                  },
                  label: 'Next: Collaborators',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 4: Collaborators
  Widget _buildStepFourCollaborators(bool isDark) {
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
                const SizedBox(height: 8),
                Text(
                  'Optionally invite other creators to collaborate on this season. Skip this step if you want to post solo.',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),
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
                        const Icon(Icons.people_alt_rounded,
                            color: Colors.purple, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Collaborative Season',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This season will be submitted under your accepted collaboration. Collaborators are already set by the collaboration invitation.',
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
                        final hasImage = collaborator['image'] != null &&
                            (collaborator['image'] as String).isNotEmpty;
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: Colors.amber,
                            backgroundImage: hasImage
                                ? CachedNetworkImageProvider(
                                    collaborator['image'])
                                : null,
                            child: hasImage
                                ? null
                                : Text(
                                    collaborator['username']?[0]
                                            ?.toUpperCase() ??
                                        '?',
                                    style: const TextStyle(
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
                  const SizedBox(height: 12),
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Bottom navigation
        Padding(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
          child: Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  onPressed: () => setState(() => _currentStep = 2),
                  label: 'Back',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _isLoading
                    ? Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade600.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : _buildPrimaryButton(
                        onPressed: _submitSeason,
                        label: _isEditMode ? 'Update Season' : 'Create Season',
                        isDark: isDark,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    if (_imageFile != null) {
      return Stack(
        children: [
          Image.file(_imageFile!,
              height: 200, width: double.infinity, fit: BoxFit.cover),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() => _imageFile = null),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
        ],
      );
    }

    if (_existingImageUrl != null &&
        _existingImageUrl!.isNotEmpty &&
        _isEditMode) {
      return Stack(
        children: [
          Image.network(
            _existingImageUrl!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[300],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 50, color: Colors.grey[600]),
                    SizedBox(height: 8),
                    Text('Failed to load image',
                        style: TextStyle(color: Colors.grey[600])),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image),
                      label: Text('Select New Image'),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.edit),
              label: const Text('Change Image'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.image),
      label: const Text('Select Image'),
    );
  }

  // ...existing code...

  Widget _buildVideoPicker() {
    if (_videoFile != null) {
      return Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.video_file, color: Colors.green),
              title: Text(_videoFile!.path.split('/').last),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _videoPlayerController?.dispose();
                  setState(() {
                    _videoFile = null;
                    _videoPlayerController = null;
                    _isVideoInitialized = false;
                  });
                },
              ),
            ),
            if (_videoPlayerController != null && _isVideoInitialized)
              _buildVideoPlayerPreview(),
          ],
        ),
      );
    }

    if (_existingVideoUrl != null && _isEditMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.green.withOpacity(0.1),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Existing Trailer Video'),
                  subtitle: Text(_existingVideoUrl!),
                  trailing: OutlinedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.edit),
                    label: const Text('Change'),
                  ),
                ),
                if (_videoPlayerController != null && _isVideoInitialized)
                  _buildVideoPlayerPreview()
                else if (_isVideoLoading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: ShimmerLoading(
                      child: SkeletonBox(
                          width: double.infinity,
                          height: 200,
                          borderRadius: 12),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _initializeVideoPlayer(_existingVideoUrl!),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Load Video Preview'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _pickVideo,
      icon: const Icon(Icons.video_library),
      label: const Text('Select Video'),
    );
  }

  Widget _buildVideoPlayerPreview() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Container(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: _videoPlayerController!.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController!),
            ),
          ),
          VideoProgressIndicator(
            _videoPlayerController!,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Theme.of(context).primaryColor,
              bufferedColor: Colors.grey,
              backgroundColor: Colors.black12,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _videoPlayerController!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                onPressed: () {
                  setState(() {
                    if (_videoPlayerController!.value.isPlaying) {
                      _videoPlayerController!.pause();
                    } else {
                      _videoPlayerController!.play();
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.replay),
                onPressed: () {
                  _videoPlayerController!.seekTo(Duration.zero);
                  _videoPlayerController!.play();
                },
              ),
              Text(
                '${_formatDuration(_videoPlayerController!.value.position)} / ${_formatDuration(_videoPlayerController!.value.duration)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

// ...existing code...

  Widget _buildWritersSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Writers',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ..._writers.asMap().entries.map((entry) {
          final index = entry.key;
          final writer = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: writer,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Writer ${index + 1}',
                      prefixIcon: Icon(Icons.edit_rounded,
                          color: Colors.amber.shade600),
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                      ),
                      filled: true,
                      fillColor:
                          isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _writers[index] = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _writers.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          );
        }),
        _buildSecondaryButton(
          onPressed: () {
            setState(() {
              _writers.add('');
            });
          },
          label: 'Add Writer',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildCastsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cast Members',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ..._casts.asMap().entries.map((entry) {
          final index = entry.key;
          final cast = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: cast,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cast ${index + 1}',
                      prefixIcon: Icon(Icons.person_rounded,
                          color: Colors.amber.shade600),
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                      ),
                      filled: true,
                      fillColor:
                          isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _casts[index] = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _casts.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          );
        }),
        _buildSecondaryButton(
          onPressed: () {
            setState(() {
              _casts.add('');
            });
          },
          label: 'Add Cast Member',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildShortsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Stories (Shorts)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CreatorContentSelector(
                  onSelected: ({
                    required List<AffiliateProduct> affiliateProducts,
                    required List<dynamic> episodes,
                    required List<dynamic> seasons,
                    required List<dynamic> shorts,
                  }) {
                    setState(() {
                      _selectedShorts.clear();
                      _selectedShorts.addAll(shorts);
                    });
                  },
                  initialSelectedShorts: _selectedShorts,
                  initialSelectedEpisodes: const [],
                  initialSelectedSeasons: const [],
                ),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add/Edit Stories'),
        ),
        if (_selectedShorts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedShorts.map((short) {
                return Chip(
                  label: Text(short['title'] ?? 'Untitled'),
                  onDeleted: () {
                    setState(() {
                      _selectedShorts
                          .removeWhere((s) => s['id'] == short['id']);
                    });
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildPublishDate() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading:
            Icon(Icons.calendar_today_rounded, color: Colors.amber.shade600),
        title: Text(
          'Publish Date',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          DateFormat('yyyy-MM-dd').format(_publishDate),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            color: isDark ? Colors.white54 : Colors.black45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _publishDate,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (date != null) setState(() => _publishDate = date);
        },
      ),
    );
  }

  Widget _buildMultiSelectSection(
    String title,
    List<dynamic> items,
    List<int> selected, {
    bool isDisabled = false,
    int initialItemCount = 3, // 👈 tweak as needed
  }) {
    // 🔥 FIX: Force concrete List copy to get real .length
    final List<dynamic> allItems = List<dynamic>.from(items);

    DebugLogger.info(
        '🔎 $title: ${allItems.length} total items'); // 👈 Debug log

    final isExpanded = _expandedSections[title] ?? false;

    final visibleItems =
        isExpanded ? allItems : allItems.take(initialItemCount).toList();

    final canExpand = allItems.length > initialItemCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (isDisabled && selected.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Category pre-selected for this challenge',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: visibleItems.map<Widget>((item) {
            final id = item['id'] as int;
            final name =
                item['name'] ?? item['title'] ?? item['heading_title'] ?? '';
            final isSelected = selected.contains(id);

            return FilterChip(
              label: Text(name),
              selected: isSelected,
              onSelected: isDisabled
                  ? null
                  : (bool value) {
                      setState(() {
                        if (value) {
                          selected.add(id);
                        } else {
                          selected.remove(id);
                        }
                      });
                    },
              backgroundColor:
                  isDisabled && !isSelected ? Colors.grey.shade200 : null,
              disabledColor: isSelected ? Colors.amber.shade100 : null,
            );
          }).toList(),
        ),
        if (canExpand)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _expandedSections[title] = !isExpanded;
                });
              },
              child: Text(
                isExpanded ? 'See less...' : 'See more...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SHARED UI HELPERS (matching Create Shorts design)
  // ═══════════════════════════════════════════════════════════

  Widget _buildInstagramTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
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
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
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
            contentPadding: const EdgeInsets.all(20),
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
    return SizedBox(
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
          style: const TextStyle(
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
    return SizedBox(
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
