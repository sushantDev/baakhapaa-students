import 'dart:convert';
import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'skeleton_loading.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fluttericon/font_awesome_icons.dart';

import '../providers/auth.dart';
import '../providers/story.dart';
import '../screens/story/episode_screen.dart';
import '../utils/debug_logger.dart';
import '../utils/season_unlock_helper.dart';
// import './tutorials.dart';

class StoryCard extends StatefulWidget {
  final Map<String, dynamic> season;
  final Map<String, dynamic> user;
  final int index;
  final String screenName;
  final List? screenArgs;

  StoryCard(
      this.index, this.season, this.user, this.screenName, this.screenArgs);

  @override
  State<StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<StoryCard> {
  bool _isLoading = false;
  GlobalKey keyNavigation = GlobalKey();

  // Performance optimization: cache expensive calculations
  String? _cachedThumbnailUrl;

  // Reduce debug logging frequency for performance
  static int _debugLogCounter = 0;

  String getSeasonImageThumbnail() {
    // Return cached result if available
    if (_cachedThumbnailUrl != null) {
      return _cachedThumbnailUrl!;
    }

    const fallbackUrl =
        'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';

    final images = widget.season['images'];
    if (images == null || images.isEmpty) {
      _cachedThumbnailUrl = fallbackUrl;
      return fallbackUrl;
    }

    try {
      final imageList = json.decode(json.encode(images));
      if (imageList is List && imageList.isNotEmpty && imageList[0] != null) {
        final url = imageList[0]['url'] ?? fallbackUrl;
        _cachedThumbnailUrl = url;
        return url;
      }
    } catch (e) {
      if (_debugLogCounter % 20 == 0) {
        DebugLogger.error('Error parsing season images: $e');
      }
    }

    _cachedThumbnailUrl = fallbackUrl;
    return fallbackUrl;
  }

  void startOrStopLoading() {
    setState(() {
      _isLoading = !_isLoading;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('An error occurred'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('Okay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed(UserScreen.routeName);
            },
            child: Text('Watch Ads'),
          ),
        ],
      ),
    );
  }

  void unlockSeason() async {
    try {
      startOrStopLoading();
      int userAvailableCoins =
          Provider.of<Auth>(context, listen: false).userAvailableCoins;
      List<int> claimedAchievements =
          await Provider.of<Auth>(context, listen: false)
              .getClaimedAchievements();

      DebugLogger.info(
          'Required achievements for this season: ${widget.season['achievements']}');
      DebugLogger.auth('User\'s claimed achievements: $claimedAchievements');

      // Check if there are required achievements
      if (widget.season['achievements'] != null &&
          widget.season['achievements'].isNotEmpty) {
        // Extract the achievement titles from the achievements array

        List<String> requiredAchievementTitles =
            (widget.season['achievements'] as List<dynamic>? ?? [])
                .map((achievement) => achievement['title'] as String? ?? '')
                .where((title) => title.isNotEmpty)
                .toList();

        // Extract the achievement IDs from the achievements array
        List<int> requiredAchievementIds =
            (widget.season['achievements'] as List)
                .map((achievement) => achievement['id'] as int)
                .toList();

        // Check if the user has claimed any of the required achievements
        bool hasRequiredAchievement = requiredAchievementIds
            .any((requiredId) => claimedAchievements.contains(requiredId));

        if (!hasRequiredAchievement) {
          // Join the titles into a single string
          String titles = requiredAchievementTitles.join(', ');

          // Show error if required achievement is not claimed
          _showErrorDialog(
              'You need to claim the required achievement $titles to unlock this course');
          startOrStopLoading();
          return;
        }
      }

      // Proceed with unlocking the season
      if (userAvailableCoins >= (widget.season['coin_to_unlock'] as int)) {
        await Provider.of<Story>(context, listen: false).unlockSeason(
          widget.user['id'] as int,
          widget.season['id'] as int,
          widget.season['title'] as String? ?? 'Untitled Season',
          widget.season['coin_to_unlock'] as int,
        );

        // Update local state to reflect unlock
        if (mounted) {
          setState(() {
            // Force rebuild to reflect unlock status
          });

          DebugLogger.success('Season unlocked - local state updated');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully unlocked season!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _showErrorDialog('Insufficient points. Please earn/buy more points.');
      }

      startOrStopLoading();
    } catch (errorMessage) {
      _showErrorDialog(
          'Oops! An error occurred. Please check your profile for any missing information.');
      startOrStopLoading();
    }
  }

  void navEpisodeScreen(BuildContext context) {
    try {
      DebugLogger.info(
          'navEpisodeScreen called for season: ${widget.season['id']}');

      var story = Provider.of<Story>(context, listen: false);

      // Add creator information if this is from CreatorStoryScreen
      Map<String, dynamic> seasonWithContext = Map.from(widget.season);
      DebugLogger.info('navEpisodeScreen - screenName: ${widget.screenName}');
      DebugLogger.info('navEpisodeScreen - screenArgs: ${widget.screenArgs}');

      if (widget.screenName == 'CreatorStoryScreen' &&
          widget.screenArgs != null &&
          widget.screenArgs!.isNotEmpty &&
          widget.screenArgs![0] != null) {
        seasonWithContext['creatorId'] = widget.screenArgs![0];
        seasonWithContext['isCreatorSeason'] = true;
        DebugLogger.info(
            'navEpisodeScreen - Added creator context: ${widget.screenArgs![0]}');
      } else {
        seasonWithContext['isCreatorSeason'] = false;
      }

      DebugLogger.info(
          'navEpisodeScreen - Setting selected season and navigating');
      story.setSelectedSeason(seasonWithContext).then((_) {
        DebugLogger.info('navEpisodeScreen - Navigation successful');
        Navigator.of(context).pushNamed(EpisodeScreen.routeName);
      }).catchError((error) {
        DebugLogger.error('navEpisodeScreen - Navigation error: $error');
      });
    } catch (e) {
      DebugLogger.error('navEpisodeScreen error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Dramatically reduce debug logging frequency for performance
      _debugLogCounter++;
      if (_debugLogCounter % 50 == 0) {
        DebugLogger.info(
            'StoryCard build started - Season keys: ${widget.season.keys.toList()}');
        DebugLogger.info('StoryCard title: ${widget.season['title']}');
      }

      final thumbnailUrl = getSeasonImageThumbnail();
      final bool hasUnlocked = isSeasonUnlocked(widget.season);

      if (_debugLogCounter % 50 == 0) {
        DebugLogger.info('StoryCard thumbnail URL: $thumbnailUrl');
        DebugLogger.info('StoryCard hasUnlocked: $hasUnlocked');
      }

      return GestureDetector(
        onTap: () {
          // Always navigate to episode screen - let users see unlock requirements for locked seasons
          navEpisodeScreen(context);
        },
        child: Container(
          height:
              widget.screenName == 'CreatorStoryScreen' ? 495 : double.infinity,
          width:
              widget.screenName == 'CreatorStoryScreen' ? 300 : double.infinity,
          child: Stack(
            children: [
              // Main background image
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: widget.season['thumbnail'] ?? thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withValues(alpha: 0.3),
                            Colors.orange.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: ShimmerLoading(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withValues(alpha: 0.3),
                            Colors.orange.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Icon(
                        FontAwesome.book,
                        size: 64,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ),
              ),

              // Gradient overlay for the specified filter effect
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),

              // Dark overlay for better text readability
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Top status indicators
              Positioned(
                top: 16,
                left: 16,
                child: _buildStatusIndicator(),
              ),

              // Dynamic tag in top right
              if (_shouldShowTag())
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildDynamicTag(),
                ),

              // Bottom content overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Center align content
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Genres row - centered
                      _buildGenresRow(),

                      SizedBox(height: 8), // Reduced spacing

                      // Bottom buttons row - center aligned
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Points button - only show if available
                          if (_buildPointsButton() != null) ...[
                            _buildPointsButton()!,
                            SizedBox(width: 8), // Reduced spacing when 3 items
                          ],

                          // Badges button - only show if available
                          if (_buildBadgesButton(
                                  _buildPointsButton() != null) !=
                              null) ...[
                            _buildBadgesButton(_buildPointsButton() != null)!,
                            SizedBox(width: 8), // Reduced spacing
                          ],

                          // Gifts button - only show if available
                          if (_buildGiftsButton(_buildPointsButton() != null) !=
                              null)
                            _buildGiftsButton(_buildPointsButton() != null)!,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      DebugLogger.error('StoryCard build error: $e');
      DebugLogger.error('StoryCard stackTrace: $stackTrace');

      // Return a safe fallback widget
      return Container(
        height:
            widget.screenName == 'CreatorStoryScreen' ? 495 : double.infinity,
        width:
            widget.screenName == 'CreatorStoryScreen' ? 300 : double.infinity,
        color: Colors.grey[300],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 48, color: Colors.red),
              SizedBox(height: 8),
              Text('Error loading story card'),
              SizedBox(height: 4),
              Text(e.toString(), style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }
  }

  // Helper methods for building UI components
  Widget _buildStatusIndicator() {
    final bool hasUnlocked = isSeasonUnlocked(widget.season);
    final isLocked = !hasUnlocked;
    return isLocked
        ? SvgPicture.asset(
            'assets/svgs/lock.svg',
            width: 24,
            height: 24,
          )
        : Container(height: 0);
  }

  bool _shouldShowTag() {
    // Only show tag if API sends a tag field with content
    return widget.season['tag'] != null &&
        widget.season['tag'].toString().trim().isNotEmpty;
  }

  Widget _buildDynamicTag() {
    // Get tag text from API, default to empty if null
    String tagText =
        widget.season['tag']?.toString().trim().toUpperCase() ?? '';

    // Default orange gradient for all tags
    List<Color> tagColors = [Colors.orange, Colors.deepOrange];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tagColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        tagText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGenresRow() {
    final genres = (widget.season['genres'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const [];

    // Use actual genres if available, otherwise use default movie-style labels
    final items = genres.isNotEmpty
        ? genres
        : const [
            'Action',
            'Comedy',
            'Highest Point',
            'Thriller',
            'High reward'
          ];

    return Center(
      // Center the entire row
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center, // Center align items
        spacing: 8, // Reduced spacing
        runSpacing: 4,
        children: [
          for (int i = 0; i < items.length && i < 5; i++) ...[
            Text(
              items[i],
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.black87,
              ),
            ),
            if (i != items.length - 1 && i < 4)
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget? _buildPointsButton() {
    final rc =
        widget.season['reward_counts'] as Map<String, dynamic>? ?? const {};
    final points = rc['reward_points'] ??
        widget.season['points'] ??
        widget.season['coin_to_unlock'];

    // Hide button if points is null, 0, or empty
    if (points == null || points == 0 || points == '') {
      return null;
    }

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Reduced padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
        ),
        borderRadius: BorderRadius.circular(20), // Reduced radius
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.3), // Reduced shadow
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/coins.png',
              width: 14, height: 14), // Smaller icon
          SizedBox(width: 4),
          Text(
            '$points',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBadgesButton([bool hasPoints = false]) {
    final rc =
        widget.season['reward_counts'] as Map<String, dynamic>? ?? const {};
    final achievement = rc['achievement'];

    // Hide button if achievement is null or empty
    if (achievement == null || achievement.toString().trim().isEmpty) {
      return null;
    }

    // Use shorter limit when 3 rewards are present
    final maxLength = hasPoints ? 8 : 16;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFFA7DCFF), // Background color #A7DCFF
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color(0xFF0064A7), // Border color #0064A7
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0064A7)
                .withValues(alpha: 0.2), // Reduced shadow with theme color
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/svgs/star-badge-solid.svg',
            width: 14,
            height: 14,
            colorFilter: ColorFilter.mode(
              Color(0xFF0064A7),
              BlendMode.srcIn,
            ),
          ),
          SizedBox(width: 4),
          Text(
            achievement.toString().length > maxLength
                ? achievement.toString().substring(0, maxLength) + '...'
                : achievement.toString(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0064A7), // Text color #0064A7
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildGiftsButton([bool hasPoints = false]) {
    final rc =
        widget.season['reward_counts'] as Map<String, dynamic>? ?? const {};
    final product = rc['product'];

    // Hide button if product is null or empty
    if (product == null || product.toString().trim().isEmpty) {
      return null;
    }

    // Use shorter limit when 3 rewards are present
    final maxLength = hasPoints ? 8 : 10;

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Reduced padding
      decoration: BoxDecoration(
        color: Color(0xFFB8F7B5), // Background color #B8F7B5
        borderRadius: BorderRadius.circular(20), // Reduced radius
        border: Border.all(
          color: Color(0xFF0DB601), // Border color #0DB601
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0DB601)
                .withValues(alpha: 0.2), // Reduced shadow with theme color
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.gift,
            color: Color(0xFF0DB601), // Icon color #0DB601
            size: 14,
          ),
          SizedBox(width: 4),
          Text(
            product.toString().length > maxLength
                ? product.toString().substring(0, maxLength) + '...'
                : product.toString(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0DB601), // Text color #0DB601
            ),
          ),
        ],
      ),
    );
  }
}
