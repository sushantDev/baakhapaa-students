import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../../models/ai_generated_content.dart';
import '../../../widgets/creator_content_selector.dart';
import '../../../widgets/affiliate_product_selector.dart';
import '../../../models/affiliate_product.dart';
import '../../../widgets/skeleton_loading.dart';

import '../../../providers/story_creation.dart';
import '../../../providers/affiliate.dart';
import '../../../utils/debug_logger.dart';
import '../../../models/url.dart';

class CreateEpisodeScreen extends StatefulWidget {
  static const routeName = '/create-episode';

  const CreateEpisodeScreen({Key? key}) : super(key: key);

  @override
  State<CreateEpisodeScreen> createState() => _CreateEpisodeScreenState();
}

class _CreateEpisodeScreenState extends State<CreateEpisodeScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;
  int? _episodeId;

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Step flow
  int _currentStep = 0; // 0, 1, 2
  final List<String> _stepTitles = ['Media', 'Details & Game', 'Extras'];

  // Add this to track expansion state
  final Map<String, bool> _expandedSections = {};

  // Basic fields matching API
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coinsController = TextEditingController(text: '0');
  final _livesController = TextEditingController(text: '3');
  final _coinsUsersController = TextEditingController(text: '0');
  final _durationController = TextEditingController(text: '30');

  // Video/Image
  File? _imageFile;
  File? _videoFile;
  String? _existingThumbnailUrl;
  String? _existingVideoUrl;
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;

  // Selected values
  int? _selectedSeasonId;
  String? _selectedSeasonTitle;
  final List<int> _selectedProducts = [];
  List<AffiliateProduct> _selectedAffiliateProducts = [];
  List<dynamic> _selectedRelatedShorts = [];
  List<dynamic> _selectedRelatedEpisodes = [];
  DateTime _publishDate = DateTime.now();

  // Challenge mode
  bool? _isChallenge;
  int? _challengeId;
  int? _storyTopicId;
  int? _noOfMcq;
  int? _challengePoints;
  int? _challengeLives;
  int? _challengeDuration;
  // int? _achievementId;
  int? _productId;

  // Metadata from API
  bool _metadataLoaded = false;
  List<dynamic> _seasons = [];
  List<dynamic> _products = [];

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
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _isChallenge = args['is_challenge'] as bool?;
        _challengeId = args['challenge_id'] as int?;
        _storyTopicId = args['story_topic_id'] as int?;
        _noOfMcq = args['no_of_mcq'] as int?;
        _challengePoints = args['points'] as int?;
        _challengeLives = args['lives'] as int?;
        _challengeDuration = args['duration'] as int?;
        // _achievementId = args['achievement_id'] as int?;
        _productId = args['product_id'] as int?;

        final aiPrefilled = args['aiPrefilled'] as AiGeneratedContent?;
        if (aiPrefilled != null) {
          _titleController.text = aiPrefilled.title;
          _descriptionController.text = aiPrefilled.description;
          _coinsController.text = aiPrefilled.coins.toString();
          _livesController.text = aiPrefilled.lives.toString();
          _coinsUsersController.text = aiPrefilled.pointsUsers.toString();
          _durationController.text = aiPrefilled.duration.toString();
          _publishDate = aiPrefilled.publishDate;
        }

        if (_challengeLives != null) {
          _livesController.text = _challengeLives.toString();
        }
        if (_challengeDuration != null) {
          _durationController.text = _challengeDuration.toString();
        }
        if (_productId != null && !_selectedProducts.contains(_productId!)) {
          setState(() {
            _selectedProducts.add(_productId!);
          });
        }

        final mode = args['mode'] as String? ?? 'create';
        _isEditMode = mode == 'edit';

        _selectedSeasonId = args['seasonId'] as int?;
        _selectedSeasonTitle = args['seasonTitle'] as String?;

        if (_isEditMode) {
          final episode = args['episode'] as Map<String, dynamic>?;
          if (episode != null && episode['id'] != null) {
            _episodeId = episode['id'];
            _fetchEpisodeDetails();
          }
        } else if (_selectedSeasonTitle != null) {
          DebugLogger.info(
            '📺 Creating episode for season: $_selectedSeasonTitle (ID: $_selectedSeasonId)',
          );
        }
      }
      _fetchMetadata();
      Provider.of<AffiliateProvider>(
        context,
        listen: false,
      ).fetchAffiliateStatus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _coinsController.dispose();
    _livesController.dispose();
    _coinsUsersController.dispose();
    _durationController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _fetchEpisodeDetails() async {
    if (_episodeId == null) return;

    setState(() => _isLoading = true);

    try {
      final storyCreation = Provider.of<StoryCreation>(context, listen: false);
      final episode = await storyCreation.fetchEpisodeDetail(_episodeId!);

      if (mounted) {
        _populateEpisodeData(episode);
      }
    } catch (e) {
      DebugLogger.error('Error fetching episode details: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load episode details: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateEpisodeData(Map<String, dynamic> episode) {
    setState(() {
      _titleController.text = episode['title'] ?? '';
      _descriptionController.text = episode['description'] ?? '';
      _coinsController.text = (episode['coins'] ?? 0).toString();
      _livesController.text = (episode['lives'] ?? 3).toString();
      _coinsUsersController.text = (episode['coins_users'] ?? 0).toString();
      _durationController.text = (episode['duration'] ?? 30).toString();

      final thumbnail = episode['thumbnail'] as String?;
      if (thumbnail != null && thumbnail.isNotEmpty && thumbnail != 'null') {
        _existingThumbnailUrl = thumbnail;
      }

      final videoUrl = episode['video_url'] as String?;
      if (videoUrl != null && videoUrl.isNotEmpty && videoUrl != 'null') {
        _existingVideoUrl = videoUrl;
      }

      final season = episode['season'] as Map<String, dynamic>?;
      if (season != null) {
        _selectedSeasonId = season['id'] as int?;
        _selectedSeasonTitle = season['title'] as String?;
      }

      final publishDateStr = episode['publish_date'] as String?;
      if (publishDateStr != null && publishDateStr.isNotEmpty) {
        try {
          final dateStr = publishDateStr.split(' ')[0];
          _publishDate = DateTime.parse(dateStr);
        } catch (e) {
          DebugLogger.error('Error parsing publish date: $e');
        }
      }

      final products = episode['products'] as List?;
      if (products != null) {
        _selectedProducts.clear();
        for (var product in products) {
          if (product is Map && product['id'] != null) {
            _selectedProducts.add(product['id'] as int);
          }
        }
      }
    });
  }

  Future<void> _fetchMetadata() async {
    try {
      final storyCreation = Provider.of<StoryCreation>(context, listen: false);
      await storyCreation.fetchEpisodeMetadata();

      setState(() {
        _seasons = storyCreation.seasons;
        _products = storyCreation.products;
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

        _initializeVideoPlayer(file);
      }
    } catch (e) {
      DebugLogger.error('Error picking video: $e');
      _showErrorSnackBar('Failed to pick video');
    }
  }

  Future<void> _initializeVideoPlayer(File videoFile) async {
    if (mounted) {
      setState(() {
        _isVideoLoading = true;
        _isVideoInitialized = false;
      });
    }

    try {
      _videoPlayerController?.dispose();

      _videoPlayerController = VideoPlayerController.file(videoFile);

      await _videoPlayerController!.initialize();

      _videoPlayerController!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

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

  Future<void> _initializeNetworkVideoPlayer(String videoUrl) async {
    if (mounted) {
      setState(() {
        _isVideoLoading = true;
        _isVideoInitialized = false;
      });
    }

    try {
      _videoPlayerController?.dispose();

      final fullUrl = '${Url.mediaUrl}/$videoUrl';
      DebugLogger.info('🎥 Initializing video player with URL: $fullUrl');

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(fullUrl),
        httpHeaders: {'Accept': '*/*'},
      );

      _videoPlayerController!.addListener(() {
        if (_videoPlayerController!.value.hasError) {
          DebugLogger.error(
            '❌ Video player error: ${_videoPlayerController!.value.errorDescription}',
          );
          if (mounted) {
            setState(() {
              _isVideoInitialized = false;
              _isVideoLoading = false;
            });
            _showErrorSnackBar(
              'Video playback error: ${_videoPlayerController!.value.errorDescription}',
            );
          }
        }
      });

      await _videoPlayerController!.initialize();

      DebugLogger.success('✅ Video initialized successfully');

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

  Future<void> _submitEpisode() async {
    // Only validate if the form is currently in the widget tree (Step 1).
    // On Step 2, form is unmounted but fields were already validated before advancing.
    if (_formKey.currentState != null && !_formKey.currentState!.validate())
      return;

    if (_selectedSeasonId == null) {
      _showErrorSnackBar('Please select a season');
      return;
    }
    if (!_isEditMode && _videoFile == null) {
      _showErrorSnackBar('Please select an episode video');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storyCreation = Provider.of<StoryCreation>(context, listen: false);

      if (_isEditMode && _episodeId != null) {
        await storyCreation.updateEpisode(
          episodeId: _episodeId!,
          title: _titleController.text,
          description: _descriptionController.text,
          seasonId: _selectedSeasonId!,
          coins: int.parse(_coinsController.text),
          lives: int.parse(_livesController.text),
          coinsUsers: int.parse(_coinsUsersController.text),
          duration: int.parse(_durationController.text),
          videoUrl: null,
          videoFile: _videoFile,
          videoDescription: null,
          products: _selectedProducts,
          affiliateProductIds: _selectedAffiliateProducts
              .map((p) => p.id)
              .toList(),
          relatedShortsIds: _selectedRelatedShorts
              .map((s) => s['id'] as int)
              .toList(),
          relatedEpisodeIds: _selectedRelatedEpisodes
              .map((e) => e['id'] as int)
              .toList(),
          publishDate: DateFormat('yyyy-MM-dd').format(_publishDate),
          imageFile: _imageFile,
        );

        if (mounted) {
          _showSuccessSnackBar('Episode updated successfully!');
          Navigator.of(context).pop();
        }
      } else {
        await storyCreation.createEpisode(
          title: _titleController.text,
          description: _descriptionController.text,
          seasonId: _selectedSeasonId!,
          coins: int.parse(_coinsController.text),
          lives: int.parse(_livesController.text),
          coinsUsers: int.parse(_coinsUsersController.text),
          duration: int.parse(_durationController.text),
          videoUrl: null,
          videoFile: _videoFile!,
          videoDescription: null,
          products: _selectedProducts,
          affiliateProductIds: _selectedAffiliateProducts
              .map((p) => p.id)
              .toList(),
          relatedShortsIds: _selectedRelatedShorts
              .map((s) => s['id'] as int)
              .toList(),
          relatedEpisodeIds: _selectedRelatedEpisodes
              .map((e) => e['id'] as int)
              .toList(),
          publishDate: DateFormat('yyyy-MM-dd').format(_publishDate),
          imageFile: _imageFile,
          isChallenge: _isChallenge,
          challengeId: _challengeId,
          storyTopicId: _storyTopicId,
          noOfMcq: _noOfMcq,
          challengePoints: _challengePoints,
          challengeLives: _challengeLives,
        );

        if (mounted) {
          _showSuccessSnackBar('Episode created successfully!');
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      DebugLogger.error(
        'Error ${_isEditMode ? 'updating' : 'creating'} episode: $e',
      );
      if (mounted) {
        _showErrorSnackBar(
          'Failed to ${_isEditMode ? 'update' : 'create'} episode: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_metadataLoaded) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          title: const Text('Create Episode'),
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
        title: Text(
          _isChallenge == true
              ? 'Create Episode (Challenge)'
              : _isEditMode
              ? 'Edit Episode'
              : 'Create Episode',
        ),
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
        return _buildStepTwoDetailsGame(isDark);
      case 2:
        return _buildStepThreeExtras(isDark);
      default:
        return const SizedBox();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 1: MEDIA (Season, Video, Thumbnail)
  // ═══════════════════════════════════════════════════════════
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
                  'Episode Media',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the season, upload your episode video, and add a thumbnail.',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),

                // Season Selection
                Text(
                  'Season *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                if (_selectedSeasonTitle != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade900
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.movie_rounded, color: Colors.amber.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedSeasonTitle!,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.lock_rounded,
                          color: isDark ? Colors.white38 : Colors.black26,
                          size: 18,
                        ),
                      ],
                    ),
                  )
                else
                  _buildInstagramDropdown(
                    label: '',
                    hint: 'Choose a season',
                    value: _selectedSeasonId,
                    items: _seasons.map<DropdownMenuItem<int>>((season) {
                      return DropdownMenuItem<int>(
                        value: season['id'] as int,
                        child: Text(season['title'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedSeasonId = value),
                    isDark: isDark,
                  ),
                const SizedBox(height: 32),

                // Episode Video
                Text(
                  _isEditMode ? 'Episode Video (Optional)' : 'Episode Video *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildVideoPicker(),
                const SizedBox(height: 32),

                // Episode Thumbnail
                Text(
                  'Episode Thumbnail',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildImagePicker(),
              ],
            ),
          ),
        ),

        // Bottom navigation
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildPrimaryButton(
                  onPressed: () {
                    if (_selectedSeasonId == null) {
                      _showErrorSnackBar('Please select a season');
                      return;
                    }
                    if (!_isEditMode && _videoFile == null) {
                      _showErrorSnackBar('Please select an episode video');
                      return;
                    }
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

  // ═══════════════════════════════════════════════════════════
  // STEP 2: DETAILS & GAME SETTINGS
  // ═══════════════════════════════════════════════════════════
  Widget _buildStepTwoDetailsGame(bool isDark) {
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
                    'Episode Details',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add title, description, and configure game settings.',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildInstagramTextField(
                    controller: _titleController,
                    label: 'Episode Title *',
                    hint: 'Give your episode a name',
                    icon: Icons.title_rounded,
                    isDark: isDark,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 24),

                  _buildInstagramTextField(
                    controller: _descriptionController,
                    label: 'Description *',
                    hint: 'What happens in this episode?',
                    icon: Icons.description_rounded,
                    isDark: isDark,
                    maxLines: 4,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Description is required'
                        : null,
                  ),
                  const SizedBox(height: 32),

                  // Game Settings section
                  Text(
                    'Game Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.amber : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInstagramTextField(
                          controller: _coinsController,
                          label: 'Coins *',
                          hint: '0',
                          icon: Icons.monetization_on_rounded,
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInstagramTextField(
                          controller: _livesController,
                          label: 'Lives *',
                          hint: '3',
                          icon: Icons.favorite_rounded,
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          enabled:
                              !(_isChallenge == true &&
                                  _challengeLives != null),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInstagramTextField(
                          controller: _coinsUsersController,
                          label: 'Coins Users *',
                          hint: '0',
                          icon: Icons.people_rounded,
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInstagramTextField(
                          controller: _durationController,
                          label: 'Duration (s) *',
                          hint: '30',
                          icon: Icons.timer_rounded,
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          enabled:
                              !(_isChallenge == true &&
                                  _challengeDuration != null),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom navigation
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
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
                    label: 'Next: Extras',
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

  // ═══════════════════════════════════════════════════════════
  // STEP 3: EXTRAS (Products, Affiliate, Featured, Publish)
  // ═══════════════════════════════════════════════════════════
  Widget _buildStepThreeExtras(bool isDark) {
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
                  'Extras & Publish',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add products, featured content, and set the publish date.',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),

                // Products
                _buildProductsSection(isDark),
                const SizedBox(height: 24),

                // Affiliate Products
                if (context.watch<AffiliateProvider>().isAffiliate) ...[
                  Text(
                    'Affiliate Products (Optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Link products to earn commissions when viewers buy from your content.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedAffiliateProducts.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedAffiliateProducts.map((p) {
                        return Chip(
                          label: Text(p.title),
                          onDeleted: () => setState(
                            () => _selectedAffiliateProducts.remove(p),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          backgroundColor: Colors.amber.withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  _buildSecondaryButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AffiliateProductSelector(
                            initialSelectedIds: _selectedAffiliateProducts
                                .map<int>((p) => p.id)
                                .toList(),
                            onSelected: (products) {
                              setState(
                                () => _selectedAffiliateProducts =
                                    List<AffiliateProduct>.from(products),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    label: _selectedAffiliateProducts.isEmpty
                        ? 'Select Affiliate Products'
                        : 'Change Affiliate Products',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 24),
                ],

                // Featured Content
                Text(
                  'Featured Content (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Link your previous shorts and episodes to help viewers discover more of your content.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedRelatedShorts.isNotEmpty ||
                    _selectedRelatedEpisodes.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._selectedRelatedShorts.map((s) {
                        return Chip(
                          label: Text('📹 ${s['title'] ?? 'Untitled'}'),
                          onDeleted: () =>
                              setState(() => _selectedRelatedShorts.remove(s)),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          backgroundColor: Colors.blue.withOpacity(0.2),
                        );
                      }),
                      ..._selectedRelatedEpisodes.map((e) {
                        return Chip(
                          label: Text('🎬 ${e['title'] ?? 'Untitled'}'),
                          onDeleted: () => setState(
                            () => _selectedRelatedEpisodes.remove(e),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          backgroundColor: Colors.purple.withOpacity(0.2),
                        );
                      }),
                    ],
                  ),
                const SizedBox(height: 8),
                _buildSecondaryButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreatorContentSelector(
                          initialSelectedShorts: _selectedRelatedShorts,
                          initialSelectedEpisodes: _selectedRelatedEpisodes,
                          initialSelectedSeasons: const [],
                          onSelected:
                              ({
                                required List<AffiliateProduct>
                                affiliateProducts,
                                required shorts,
                                required episodes,
                                required seasons,
                              }) {
                                setState(() {
                                  _selectedRelatedShorts = List<dynamic>.from(
                                    shorts,
                                  );
                                  _selectedRelatedEpisodes = List<dynamic>.from(
                                    episodes,
                                  );
                                });
                              },
                        ),
                      ),
                    );
                  },
                  label:
                      (_selectedRelatedShorts.isEmpty &&
                          _selectedRelatedEpisodes.isEmpty)
                      ? 'Select Featured Content'
                      : 'Change Featured Content',
                  isDark: isDark,
                ),
                const SizedBox(height: 24),

                // Publish Date
                _buildPublishDate(isDark),
                const SizedBox(height: 24),

                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.shade900.withOpacity(0.2)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.shade300.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue.shade400,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'After creating the episode, you can add quiz questions.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom navigation
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(context).padding.bottom + 16,
          ),
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
                        onPressed: _submitEpisode,
                        label: _isEditMode
                            ? 'Update Episode'
                            : 'Create Episode',
                        isDark: isDark,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSection(bool isDark) {
    final List<dynamic> allProducts = List<dynamic>.from(_products);
    final isExpanded = _expandedSections['products'] ?? false;
    final initialItemCount = 6;
    final visibleProducts = isExpanded
        ? allProducts
        : allProducts.take(initialItemCount).toList();
    final canExpand = allProducts.length > initialItemCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attach Products (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        if (_isChallenge == true && _productId != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.amber.shade900.withOpacity(0.2)
                  : Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade300.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_rounded,
                  color: Colors.amber.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Product pre-selected for this challenge',
                    style: TextStyle(
                      color: isDark
                          ? Colors.amber.shade200
                          : Colors.amber.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (allProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'No products available',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleProducts.map<Widget>((product) {
              final id = product['id'] as int;
              final name =
                  product['name'] ??
                  product['title'] ??
                  product['product_name'] ??
                  'Product #$id';
              final isSelected = _selectedProducts.contains(id);
              final isDisabled = _isChallenge == true && _productId != null;

              return FilterChip(
                label: Text(name),
                selected: isSelected,
                selectedColor: Colors.amber.withOpacity(0.3),
                checkmarkColor: Colors.amber.shade700,
                onSelected: isDisabled
                    ? null
                    : (bool value) {
                        setState(() {
                          if (value) {
                            _selectedProducts.add(id);
                          } else {
                            _selectedProducts.remove(id);
                          }
                        });
                      },
                backgroundColor: isDark
                    ? Colors.grey.shade800
                    : (isDisabled && !isSelected ? Colors.grey.shade200 : null),
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
                  _expandedSections['products'] = !isExpanded;
                });
              },
              child: Text(
                isExpanded ? 'See less...' : 'See more...',
                style: TextStyle(
                  color: Colors.amber.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPER WIDGETS
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
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          enabled: enabled,
          onChanged: onChanged,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: Colors.amber.shade600, size: 20)
                : null,
            filled: true,
            fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.amber.shade600, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstagramDropdown<T>({
    required String label,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            filled: true,
            fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.amber.shade600, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          foregroundColor: isDark ? Colors.white70 : Colors.black87,
          side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildPublishDate(bool isDark) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _publishDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) setState(() => _publishDate = date);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: Colors.amber.shade600,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Publish Date',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMMM dd, yyyy').format(_publishDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.file(
              _imageFile!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _imageFile = null),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_existingThumbnailUrl != null && _isEditMode) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.network(
              _existingThumbnailUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          size: 48,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load thumbnail',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Change',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_rounded,
                size: 40,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to add thumbnail',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPicker() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_videoFile != null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.video_file_rounded,
                  color: Colors.green.shade600,
                ),
              ),
              title: Text(
                _videoFile!.path.split('/').last,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: GestureDetector(
                onTap: () {
                  _videoPlayerController?.dispose();
                  setState(() {
                    _videoFile = null;
                    _videoPlayerController = null;
                    _isVideoInitialized = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.red.shade400,
                  ),
                ),
              ),
            ),
            if (_videoPlayerController != null && _isVideoInitialized)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: _buildVideoPlayerPreview(),
              ),
          ],
        ),
      );
    }

    if (_existingVideoUrl != null && _isEditMode) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.video_library_rounded,
                  color: Colors.blue.shade600,
                ),
              ),
              title: Text(
                'Current Video',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              trailing: GestureDetector(
                onTap: _pickVideo,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Change',
                    style: TextStyle(
                      color: Colors.amber.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            if (_videoPlayerController != null && _isVideoInitialized)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: _buildVideoPlayerPreview(),
              )
            else if (_isVideoLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: ShimmerLoading(
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 200,
                    borderRadius: 12,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildSecondaryButton(
                  onPressed: () =>
                      _initializeNetworkVideoPlayer(_existingVideoUrl!),
                  label: 'Load Video Preview',
                  isDark: isDark,
                ),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_rounded,
                size: 40,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to add video (Max 1GB)',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayerPreview() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController!),
              ),
            ),
          ),
          const SizedBox(height: 8),
          VideoProgressIndicator(
            _videoPlayerController!,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Colors.amber.shade600,
              bufferedColor: Colors.grey.shade600,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _videoPlayerController!.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: isDark ? Colors.white : Colors.black87,
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
                icon: Icon(
                  Icons.replay_rounded,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                onPressed: () {
                  _videoPlayerController!.seekTo(Duration.zero);
                  _videoPlayerController!.play();
                },
              ),
              Text(
                '${_formatDuration(_videoPlayerController!.value.position)} / ${_formatDuration(_videoPlayerController!.value.duration)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
