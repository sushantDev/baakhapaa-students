import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:baakhapaa/models/url.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/screens/shorts/single_shorts_screen.dart';
import 'package:baakhapaa/screens/subscription/subscription_screen.dart';
import 'package:baakhapaa/theme/theme_constants.dart';
import 'package:baakhapaa/utils/debug_logger.dart';
import 'challenge_detail_widgets.dart';

// ==================== CHALLENGE HEADER ====================
class ChallengeHeader extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final bool isDescriptionExpanded;
  final VoidCallback onToggleDescription;

  const ChallengeHeader({
    super.key,
    required this.challenge,
    required this.isDescriptionExpanded,
    required this.onToggleDescription,
  });

  @override
  Widget build(BuildContext context) {
    void _openImageViewer(BuildContext context, String imageUrl) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "Image Viewer",
        barrierColor: Colors.black.withOpacity(0.9),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Positioned(
                          top: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        transitionBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.95, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
      );
    }

    final String imageUrl = challenge['image_url'] ?? '';
    final String? deadlineStr = challenge['deadline'];
    final String? type = challenge['platform'];
    Duration timeRemaining = Duration.zero;
    int days = 0;
    int hours = 0;
    int minutes = 0;
    int seconds = 0;

    bool isExpired = false;
    if (deadlineStr != null && deadlineStr.isNotEmpty) {
      String dateTimeStr = deadlineStr;
      if (!deadlineStr.contains('T')) {
        dateTimeStr = '$deadlineStr 23:59:59';
      }
      final DateTime? deadline = DateTime.tryParse(dateTimeStr);
      if (deadline != null) {
        if (deadline.isAfter(DateTime.now())) {
          timeRemaining = deadline.difference(DateTime.now());
          days = timeRemaining.inDays;
          hours = timeRemaining.inHours % 24;
          minutes = timeRemaining.inMinutes % 60;
          seconds = timeRemaining.inSeconds % 60;
        } else {
          isExpired = true;
        }
      }
    }

    // final String badgeText = type == 'Seasons' ? 'Season' : 'Shorts';
    // final IconData badgeIcon = type == 'Seasons'
    //     ? Icons.auto_stories_rounded
    //     : Icons.video_library_rounded;

    late final String badgeText;
    late final IconData badgeIcon;

    switch (type?.toLowerCase()) {
      case 'seasons':
      case 'season':
        badgeText = 'Season';
        badgeIcon = Icons.auto_stories_rounded;
        break;

      case 'products':
      case 'product':
        badgeText = 'Product';
        badgeIcon = Icons.shopping_bag_rounded;
        break;

      case 'shorts':
      case 'short':
      default:
        badgeText = 'Shorts';
        badgeIcon = Icons.video_library_rounded;
    }

    // final badgeConfig = {
    //   'Seasons': {
    //     'text': 'Season',
    //     'icon': Icons.auto_stories_rounded,
    //   },
    //   'Product': {
    //     'text': 'Product',
    //     'icon': Icons.shopping_bag_rounded,
    //   },
    // };

    // final badgeText = badgeConfig[type]?['text'] ?? 'Shorts';
    // final badgeIcon = badgeConfig[type]?['icon'] ?? Icons.video_library_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon),
                      const SizedBox(width: 4),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Color(0xFFFFCB0C), Color(0xFFDC9903)],
                        ).createShader(bounds),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Share.share(
                    'Check out ${challenge['title'] ?? 'this challenge'} on Baakhapaa',
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(right: 8, top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.share,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              challenge['title'] ?? 'Untitled Challenge',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                image: imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (imageUrl.isNotEmpty) {
                    _openImageViewer(context, imageUrl);
                  }
                },
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: isExpired
                          ? Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule_outlined,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Expired',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatBox('days', days.toString()),
                                _buildStatBox('hrs', hours.toString()),
                                _buildStatBox('min', minutes.toString()),
                                _buildStatBox('sec', seconds.toString()),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge['description'] ?? '',
                  maxLines: isDescriptionExpanded ? null : 2,
                  overflow: isDescriptionExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                if (isDescriptionExpanded) ...[
                  const SizedBox(height: 12),
                  _buildStatBullet(
                    'Lives',
                    (challenge['lives']?.toString() ??
                        challenge['likes']?.toString() ??
                        'N/A'),
                  ),
                  _buildStatBullet(
                    'Duration',
                    (challenge['duration'] != null
                        ? '${challenge['duration']}s'
                        : 'N/A'),
                  ),
                  _buildStatBullet(
                    'Number of MCQs',
                    (challenge['no_of_mcq']?.toString() ?? 'N/A'),
                  ),
                  _buildStatBullet(
                    'Minimum Players',
                    (challenge['min_number_of_challenge_participation']
                            ?.toString() ??
                        challenge['min_participation']?.toString() ??
                        'N/A'),
                  ),
                  _buildStatBullet(
                    'Points Required',
                    (challenge['points_required']?.toString() ??
                        challenge['unlock_points']?.toString() ??
                        'N/A'),
                  ),
                  _buildStatBullet(
                    'Winner As',
                    (challenge['winner_as'] ?? 'N/A'),
                  ),
                ],
                if ((challenge['description'] ?? '').length > 80)
                  Center(
                    child: GestureDetector(
                      onTap: onToggleDescription,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isDescriptionExpanded
                                  ? 'See less...'
                                  : 'See more...',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              duration: Duration(milliseconds: 300),
                              turns: isDescriptionExpanded ? -0.5 : 0,
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBullet(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '•  ',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  TextSpan(
                    text: ': ',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ERROR STATE ====================
class ErrorState extends StatelessWidget {
  const ErrorState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Challenge Not Found',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The requested challenge could not be loaded.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SIMPLE VIDEO PLAYER ====================
class SimpleVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final int shortsId;

  const SimpleVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.shortsId,
  }) : super(key: key);

  @override
  _SimpleVideoPlayerState createState() => _SimpleVideoPlayerState();
}

class _SimpleVideoPlayerState extends State<SimpleVideoPlayer> {
  late FlickManager _flickManager;
  bool _flickManagerInitialized = false;

  @override
  void initState() {
    super.initState();
    _flickManager = FlickManager(
      videoPlayerController: VideoPlayerController.networkUrl(
        Uri.parse('${Url.mediaUrl}/${widget.videoUrl}'),
      ),
      autoPlay: false,
      autoInitialize: true,
    );
    _flickManagerInitialized = true;
  }

  @override
  void dispose() {
    if (_flickManagerInitialized) _flickManager.dispose();
    super.dispose();
  }

  void _onTap() {
    Navigator.of(context).pushNamed(
      SingleShortsScreen.routeName,
      arguments: widget.shortsId,
    );
  }

  void _onLongPress() {
    if (_flickManager.flickVideoManager!.isPlaying) {
      _flickManager.flickControlManager!.pause();
    } else {
      _flickManager.flickControlManager!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onLongPress: _onLongPress,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: FlickVideoPlayer(
          flickManager: _flickManager,
          flickVideoWithControls: FlickVideoWithControls(
            videoFit: BoxFit.contain,
            controls: Container(),
          ),
          flickVideoWithControlsFullscreen: FlickVideoWithControls(
            videoFit: BoxFit.contain,
            controls: Container(),
          ),
        ),
      ),
    );
  }
}

// ==================== UNLOCK REWARDS TABS ====================
class UnlockRewardsTabs extends StatefulWidget {
  final Map<String, dynamic>? detailedSeasonData;
  final Map<String, dynamic>? challengeData;
  final dynamic unlockChallengeBenefit;
  final VoidCallback? onUseUnlockChallengeBenefit;

  const UnlockRewardsTabs({
    super.key,
    this.detailedSeasonData,
    this.challengeData,
    this.unlockChallengeBenefit,
    this.onUseUnlockChallengeBenefit,
  });

  @override
  State<UnlockRewardsTabs> createState() => _UnlockRewardsTabsState();
}

class _UnlockRewardsTabsState extends State<UnlockRewardsTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final data = widget.challengeData;
    final bool isUnlocked = data != null &&
        (data['has_unlocked'] == true ||
            data['has_unlocked'] == 1 ||
            data['unlocked'] == true);
    final bool isWatched = data?['watched'] ?? false;
    final bool isLocked = data != null && !isUnlocked && !isWatched;
    _tabController = TabController(
      length: 2,
      initialIndex: isLocked ? 0 : 1,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildStickyPremiumCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: widget.unlockChallengeBenefit != null &&
              widget.unlockChallengeBenefit.canUse
          ? premiumButton(
              onTap: widget.onUseUnlockChallengeBenefit,
              text: 'Unlock with Benefit',
              icon: FontAwesomeIcons.bolt.data,
            )
          : premiumButton(
              onTap: () {
                Navigator.of(context)
                    .pushNamed(SubscriptionScreen.routeName);
              },
            ),
    );
  }

  // Fetch achievement details from Auth provider
  Future<Map<String, dynamic>?> _fetchAchievementDetails(
      int achievementId) async {
    try {
      final auth = Provider.of<Auth>(context, listen: false);
      await auth.getAchievements();

      // Find the specific achievement by ID
      final achievement = auth.achievements.firstWhere(
        (a) => a['id'] == achievementId,
        orElse: () => null,
      );

      return achievement;
    } catch (e) {
      DebugLogger.error('Failed to fetch achievement details: $e');
      return null;
    }
  }

  // Helper method to format progress keys
  String _formatProgressKey(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Show detailed achievement dialog
  Future<void> _showAchievementDetailsDialog(
    BuildContext context, {
    required String achievementTitle,
    required String? achievementUrl,
    required bool hasObtainedAchievement,
    required int achievementId,
  }) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: CircularProgressIndicator(),
        ),
      ),
    );

    // Fetch achievement details
    final achievementDetails = await _fetchAchievementDetails(achievementId);

    // Close loading dialog
    if (!mounted) return;
    Navigator.of(context).pop();

    if (achievementDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load achievement details')),
      );
      return;
    }

    // Show the actual achievement details dialog
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final String description =
            achievementDetails['description'] ?? 'No description available';
        final String category =
            achievementDetails['achievement_category'] ?? 'General';
        final int? level = achievementDetails['level'];
        final dynamic claimablePoints = achievementDetails['claimable_points'];
        final bool claimed = achievementDetails['claimed'] == 1;
        final bool obtained = achievementDetails['obtained'] == 1;

        // Get progress data
        final Map<String, dynamic> progress =
            achievementDetails['progress'] ?? {};

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
              maxWidth: 400,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF2A2A2A)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: obtained
                        ? _goldGradient
                        : LinearGradient(
                            colors: [
                              Colors.grey.shade600,
                              Colors.grey.shade800
                            ],
                          ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: achievementUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: achievementUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          Icon(
                                        Icons.emoji_events,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    )
                                  : Icon(
                                      Icons.emoji_events,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  achievementTitle,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: claimed
                                            ? Colors.green
                                            : (obtained
                                                ? Colors.orange
                                                : Colors.red),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        claimed
                                            ? 'CLAIMED'
                                            : (obtained
                                                ? 'OBTAINED'
                                                : 'LOCKED'),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (level != null) ...[
                                      SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Level $level',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Category badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.category, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              category,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),

                        // Reward points
                        if (claimablePoints != null &&
                            claimablePoints != 0) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.stars,
                                    color: Colors.amber, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Reward: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '$claimablePoints points',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Progress section
                        if (progress.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Requirements Progress',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...progress.entries.map((entry) {
                            final key = entry.key;
                            final value = entry.value;

                            if (value is Map) {
                              final current = value['current'] ?? 0;
                              final required = value['required'] ?? 0;
                              final percent = value['percent'] ?? 0.0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _formatProgressKey(key),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$current / $required',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: (percent / 100).clamp(0.0, 1.0),
                                        minHeight: 8,
                                        backgroundColor:
                                            Colors.grey.withValues(alpha: 0.2),
                                        valueColor: AlwaysStoppedAnimation(
                                          percent >= 100
                                              ? Colors.green
                                              : Colors.amber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return SizedBox.shrink();
                          }).toList(),
                        ],

                        // Status message
                        const SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: obtained
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: obtained
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                obtained ? Icons.check_circle : Icons.lock,
                                color: obtained ? Colors.green : Colors.orange,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  obtained
                                      ? 'You have obtained this achievement! You can use it to unlock this challenge.'
                                      : 'Complete the requirements above to obtain this achievement and unlock the challenge.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                    height: 1.3,
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

                // Close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade300
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Colors / gradients used to match the screenshots
  static const LinearGradient _goldGradient = LinearGradient(
    colors: [
      Color.fromARGB(255, 145, 118, 52),
      Color.fromARGB(255, 238, 208, 131),
      Color.fromARGB(255, 226, 185, 83),
      Color.fromARGB(255, 207, 178, 108),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use challenge data if available, otherwise use story data
    final data = widget.challengeData;

    if (data == null) return const SizedBox.shrink();

    final maxTabBodyHeight =
        (MediaQuery.sizeOf(context).height * 0.34).clamp(200.0, 340.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF2A2A2A) : Colors.white,
            isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.8),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Colors.transparent,
                child: TabBar(
                  controller: _tabController,
                  padding: const EdgeInsets.only(left: 30, right: 30),
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.actionButtonBg(context),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.textPrimary(context),
                  unselectedLabelColor: AppColors.textSecondary(context),
                  labelStyle: AppTextStyles.interExtraBold(fontSize: 16),
                  unselectedLabelStyle: AppTextStyles.interMedium(),
                  indicatorWeight: 4,
                  tabs: const [
                    Tab(text: 'Unlock', height: 36),
                    Tab(text: 'Rewards', height: 36),
                  ],
                ),
              ),
            ),
          ),
          const Divider(
            color: Color(0x1FFFFFFF),
            thickness: 1,
            height: 1,
            indent: 12,
            endIndent: 12,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxTabBodyHeight),
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildUnlockTab(),
                ),
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildRewardsTab(),
                ),
              ],
            ),
          ),
          _buildStickyPremiumCta(),
        ],
      ),
    );
  }

  Widget _buildUnlockTab() {
    final data = widget.challengeData;

    if (data == null) return const SizedBox.shrink();

    // Extract points required with proper type handling
    // For challenges use 'unlock_points', for stories use 'coin_to_unlock'
    final dynamic coinValue = data['unlock_points'] ?? data['coin_to_unlock'];
    final int pointsRequired = coinValue is int
        ? coinValue
        : (coinValue is String
            ? int.tryParse(coinValue) ?? 0
            : (coinValue?.toInt() ?? 0));

    // Debug logging for unlock tab
    DebugLogger.api(
        '🔓 UnlockTab - Raw coin value: $coinValue (${coinValue.runtimeType})');
    DebugLogger.api('🔓 UnlockTab - Points required: $pointsRequired');

    // API returns single achievement_id and product_id, not arrays
    final int? achievementId = data['achievement_id'];
    final String achievementTitle = data['achievement_title'] ?? 'Badge';
    final String? achievementUrl = data['achievement_url'];
    final bool hasObtainedAchievement =
        data['has_obtained_achievement'] ?? false;

    final int? productId = data['product_id'];
    final String productTitle = data['product_title'] ?? 'Product';
    final List<dynamic> productUrls = data['product_url'] ?? [];
    final String? productImageUrl =
        productUrls.isNotEmpty ? productUrls[0]['url'] : null;
    final bool hasPurchasedProduct = data['has_purchased_product'] ?? false;

    // Construct full product image URL
    final String? fullProductImageUrl = productImageUrl != null
        ? (productImageUrl.startsWith('storage/')
            ? 'https://student.baakhapaa.com/storage/$productImageUrl'
            : productImageUrl)
        : null;

    // Debug logging for achievement and product
    DebugLogger.api(
        '🏆 UnlockTab - Achievement ID: $achievementId, Title: $achievementTitle, Obtained: $hasObtainedAchievement');
    DebugLogger.api(
        '🎁 UnlockTab - Product ID: $productId, Title: $productTitle, Purchased: $hasPurchasedProduct');
    DebugLogger.api('🎁 UnlockTab - Product Image URL (raw): $productImageUrl');
    DebugLogger.api(
        '🎁 UnlockTab - Product Image URL (full): $fullProductImageUrl');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Points required to unlock:',
            style: TextStyle(color: Color(0xFFB4B4B4)),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              if (pointsRequired > 0)
                Container(
                  padding: const EdgeInsets.only(
                      left: 6, right: 6, top: 10, bottom: 10),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF990000),
                          Color(0xFFFF0000),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(28)),
                  child: Row(
                    children: [
                      Image(
                          image: AssetImage('assets/images/coins.png'),
                          width: 16,
                          height: 16),
                      SizedBox(width: 4),
                      Text(
                        '$pointsRequired',
                        style: AppTextStyles.interBold(
                            color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        ' points',
                        style: AppTextStyles.interSemiBold(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.only(
                      left: 6, right: 6, top: 10, bottom: 10),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0D9900),
                          Color(0xFF0DFF00),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(28)),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'FREE',
                        style: AppTextStyles.interBold(
                            color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (achievementId != null) ...[
            SizedBox(height: 8),
            const Text('Badge required to unlock:',
                style: TextStyle(color: Color(0xFFB4B4B4))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // Show achievement details dialog
                _showAchievementDetailsDialog(
                  context,
                  achievementTitle: achievementTitle,
                  achievementUrl: achievementUrl,
                  hasObtainedAchievement: hasObtainedAchievement,
                  achievementId: achievementId,
                );
              },
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 92,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: hasObtainedAchievement
                              ? _goldGradient
                              : LinearGradient(
                                  colors: [
                                    Colors.grey.shade600,
                                    Colors.grey.shade800
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: hasObtainedAchievement
                              ? [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: achievementUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: achievementUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Icon(
                                      Icons.emoji_events,
                                      color:
                                          Colors.white.withValues(alpha: 0.6),
                                      size: 24,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    Icons.emoji_events,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    size: 24,
                                  ),
                                ),
                        ),
                      ),

                      // Achievement status indicator
                      if (hasObtainedAchievement)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 92,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: hasObtainedAchievement ? 1.0 : 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: hasObtainedAchievement
                              ? const Color(0xFFCFB26C)
                              : Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (productId != null) ...[
            // Show message if only product exists
            const Text('Badge required to unlock:',
                style: TextStyle(color: Color(0xFFB4B4B4), fontSize: 12)),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Center(
                child: Text(
                  'No achievement required to unlock this challenge.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ],
          if (productId != null) ...[
            const SizedBox(height: 8),
            const Text('Product required to unlock:',
                style: TextStyle(color: Color(0xFFB4B4B4))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // Navigate to single product screen
                if (productId > 0) {
                  Navigator.of(context).pushNamed(
                    '/single-product-screen',
                    arguments: productId,
                  );
                }
              },
              child: Stack(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasPurchasedProduct
                            ? Colors.green.withValues(alpha: 0.5)
                            : Colors.white10,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: hasPurchasedProduct
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                      color: Colors.grey[800],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: fullProductImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: fullProductImageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Icon(
                                  Icons.card_giftcard,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.card_giftcard,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                  // Purchase status indicator
                  if (hasPurchasedProduct)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (achievementId != null) ...[
            // Show message if only achievement exists
            const SizedBox(height: 8),
            const Text('Product required to unlock:',
                style: TextStyle(color: Color(0xFFB4B4B4), fontSize: 12)),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Center(
                child: Text(
                  'No product required to unlock this challenge.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRewardsTab() {
    final data = widget.challengeData;

    if (data == null) return const SizedBox.shrink();

    final Map<String, dynamic> rewardDetails = data['reward_details'] ?? {};

    // Extract reward data from the new structure
    final int pointReward = rewardDetails['reward_points'] ?? 0;
    final List<dynamic> products = rewardDetails['product'] ?? [];
    final List<dynamic> achievements = rewardDetails['achievement'] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points Reward Section
          const Text(
            'Points Reward:',
            style: TextStyle(color: Color(0xFFB4B4B4), fontSize: 12),
          ),
          const SizedBox(height: 8),
          pointsPill('$pointReward points'),
          const SizedBox(height: 12),

          // Badge Rewards Section (Achievement Rewards moved to top)
          if (achievements.isNotEmpty) ...[
            const Text('Badges Rewards:',
                style: TextStyle(color: Color(0xFFB4B4B4), fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              height: 65,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final achievement = achievements[index];
                  final String title = achievement['title'] ?? 'Achievement';
                  final String imageUrl = achievement['image_url'] ?? '';
                  final bool isClaimed = achievement['is_claimed'] ?? false;
                  final List<dynamic> progress = achievement['progress'] ?? [];
                  final double progressValue =
                      isClaimed ? 1.0 : (progress.isNotEmpty ? 0.5 : 0.0);

                  return badgeItemWidget(
                    imageUrl: imageUrl,
                    title: title,
                    earned: progressValue > 0,
                    claimed: isClaimed,
                    progress: progressValue,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/achievements-screen',
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ] else if (products.isNotEmpty) ...[
            const Text('Badges Rewards:',
                style: TextStyle(color: Color(0xFFB4B4B4), fontSize: 12)),
            // Show message if only products exist
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Center(
                child: Text(
                  'No badge rewards available for this challenge.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ],

          // Gift Rewards Section (Product Rewards renamed)
          if (products.isNotEmpty) ...[
            const Text('Gifts Rewards:',
                style: TextStyle(color: Color(0xFFB4B4B4), fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              height: 55,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final String imageUrl = product['image_url'] ?? '';
                  final int productId = product['id'] ?? 0;
                  final String fullImageUrl = imageUrl.isNotEmpty
                      ? (imageUrl.startsWith('storage/')
                          ? 'https://student.baakhapaa.com/storage/$imageUrl'
                          : imageUrl)
                      : '';

                  return giftIconWidget(
                    imageUrl: fullImageUrl,
                    unlocked: true,
                    onTap: () {
                      if (productId > 0) {
                        Navigator.of(context).pushNamed(
                          '/single-product-screen',
                          arguments: productId,
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ] else if (achievements.isNotEmpty) ...[
            // Show message if only achievements exist
            const Text('Gift Rewards:',
                style: TextStyle(color: Color(0xFFB4B4B4), fontSize: 12)),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Center(
                child: Text(
                  'No gift rewards available for this challenge.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Header style constant
const TextStyle _headerStyle = TextStyle(
  fontFamily: 'Inter',
  color: Colors.white60,
  fontSize: 10,
  fontWeight: FontWeight.w500,
);

// ==================== CHALLENGE LEADERBOARD ====================
class ChallengeLeaderboard extends StatelessWidget {
  final List<dynamic> challengeShorts;
  final int? currentUserId;

  const ChallengeLeaderboard({
    super.key,
    required this.challengeShorts,
    this.currentUserId,
  });

  List<Color> _rankGradientColors(int rank) {
    switch (rank) {
      case 1:
        return [
          const Color(0xFFDC9903),
          const Color.fromARGB(164, 252, 199, 11)
        ];
      case 2:
        return [const Color(0xFFB3B3B3), const Color(0xFF4D4D4D)];
      case 3:
        return [const Color(0xFFA05B28), const Color(0xFF3A210F)];
      default:
        return [];
    }
  }

  Color _borderColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFCB0C);
      case 2:
        return const Color(0xFFB3B3B3);
      case 3:
        return const Color(0xFFA05B28);
      default:
        return Colors.white.withValues(alpha: 0.05);
    }
  }

  String _rankLabel(int rank) {
    if (rank == 1) return "1st";
    if (rank == 2) return "2nd";
    if (rank == 3) return "3rd";
    return "${rank}th";
  }

  @override
  Widget build(BuildContext context) {
    if (challengeShorts.isEmpty) return const SizedBox();

    final sortedShorts = [...challengeShorts]
      ..sort((a, b) => (b['likes'] ?? 0).compareTo(a['likes'] ?? 0));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leaderboard',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: Text("Rank", style: _headerStyle)),
              Expanded(flex: 2, child: Text("Name", style: _headerStyle)),
              Expanded(child: Text("Like", style: _headerStyle)),
              Expanded(child: Text("Comment", style: _headerStyle)),
              SizedBox(width: 8),
              Expanded(child: Text("Share", style: _headerStyle)),
              Expanded(child: Text("Played", style: _headerStyle)),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(sortedShorts.length, (index) {
            final short = sortedShorts[index];
            final rank = index + 1;
            final gradientColors = _rankGradientColors(rank);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                gradient: gradientColors.isNotEmpty
                    ? LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: gradientColors.isEmpty ? const Color(0xFF262626) : null,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _borderColor(rank),
                  width: rank <= 3 ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _rankLabel(rank),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      short['username'] ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  _metric(short['likes'], Colors.blue),
                  _metric(short['comments'], Colors.grey),
                  const SizedBox(width: 8),
                  _metric(short['shares'], Colors.green),
                  _metric(short['views'], Colors.orange),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _metric(dynamic value, Color dotColor) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value?.toString() ?? '0',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== MY VIDEO REPORT CARD ====================
class MyVideoReportCard extends StatelessWidget {
  final Map<String, dynamic>? videoData;

  const MyVideoReportCard({super.key, this.videoData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (videoData == null) return const SizedBox.shrink();

    final username = videoData!['username'] ?? 'Unknown';
    final description = videoData!['description'] ?? 'No description';
    final profileUrl = videoData!['profile_image_url'] ?? '';
    final videoUrl = videoData!['video_url'] ?? '';
    final likes = videoData!['likes'] ?? 0;
    final comments = videoData!['comments'] ?? 0;
    final shares = videoData!['shares'] ?? 0;
    final completion = videoData!['completion'] ?? 0;

    int rank = 0;
    if (videoData!['challenge_details'] != null &&
        videoData!['challenge_details'].isNotEmpty) {
      rank = videoData!['challenge_details'][0]['rank'] ?? 0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Video Report',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 140,
                  height: 200,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: SimpleVideoPlayer(
                          videoUrl: videoUrl,
                          shortsId: videoData!['id'],
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.favorite,
                                  size: 12, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                likes >= 1000
                                    ? '${(likes / 1000).toStringAsFixed(0)}k'
                                    : '$likes',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: profileUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(profileUrl)
                                  : null,
                              backgroundColor: Colors.white24,
                              child: profileUrl.isEmpty
                                  ? const Icon(Icons.person,
                                      size: 12, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 60,
                              child: Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Challenge Video',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFD54F),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (rank > 0) _statText('Rank', '$rank'),
                      _statText('Likes', '$likes'),
                      _statText('Comments', '$comments'),
                      _statText('Share', '$shares'),
                      _statText('Played/One Completion', '$completion'),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _statText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label : ',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PARTICIPATED VIDEOS ====================
class ParticipatedVideos extends StatelessWidget {
  final List<dynamic> challengeShorts;

  const ParticipatedVideos({
    super.key,
    required this.challengeShorts,
  });

  String _formatCount(dynamic v) {
    final n = (v is int) ? v : int.tryParse('$v') ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _smallTile(dynamic s) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 81.5,
        height: 126.03053283691406,
        child: Stack(
          children: [
            Positioned.fill(
              child: SimpleVideoPlayer(
                videoUrl: s['video_url'],
                shortsId: s['id'],
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      _formatCount(s['likes']),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundImage: s['user_image'] != null
                        ? CachedNetworkImageProvider(s['user_image'])
                        : null,
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 60,
                    child: Text(
                      s['username'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _featuredTile(dynamic s) {
    final bool isWinner = s['challenge_details'] != null &&
        s['challenge_details'].isNotEmpty &&
        s['challenge_details'][0]['is_winner'] == 1;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: isWinner ? scale : 1,
          child: Container(
            decoration: isWinner
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.6),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 163,
                height: 254,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SimpleVideoPlayer(
                        videoUrl: s['video_url'],
                        shortsId: s['id'],
                      ),
                    ),
                    if (isWinner)
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(seconds: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.transparent,
                                Colors.amber.withOpacity(0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _pill(
                        icon: Icons.favorite,
                        value: _formatCount(s['likes']),
                      ),
                    ),
                    if (isWinner)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.9, end: 1.1),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeInOut,
                          builder: (_, scale, __) {
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFB8860B),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.7),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.emoji_events,
                                  size: 14,
                                  color: Colors.black,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (isWinner)
                      Positioned(
                        left: 0,
                        top: 36,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFB8860B),
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'WINNER',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: s['user_image'] != null
                                ? CachedNetworkImageProvider(s['user_image'])
                                : null,
                            backgroundColor: Colors.white24,
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 60,
                            child: Text(
                              s['username'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
          ),
        );
      },
    );
  }

  Widget _pill({required IconData icon, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (challengeShorts.isEmpty) return const SizedBox();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final featured = challengeShorts[0];
    final rightTop = challengeShorts.skip(1).take(4).toList();
    final remaining = challengeShorts.skip(5).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Participated Videos:',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${challengeShorts.length} Videos',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _featuredTile(featured),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: rightTop.isNotEmpty
                                ? _smallTile(rightTop[0])
                                : const SizedBox()),
                        const SizedBox(width: 10),
                        Expanded(
                            child: rightTop.length > 1
                                ? _smallTile(rightTop[1])
                                : const SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: rightTop.length > 2
                                ? _smallTile(rightTop[2])
                                : const SizedBox()),
                        const SizedBox(width: 10),
                        Expanded(
                            child: rightTop.length > 3
                                ? _smallTile(rightTop[3])
                                : const SizedBox()),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
          if (remaining.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: remaining.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 9 / 16,
              ),
              itemBuilder: (_, i) => _smallTile(remaining[i]),
            ),
          ]
        ],
      ),
    );
  }
}
