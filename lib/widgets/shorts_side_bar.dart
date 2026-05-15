import 'dart:convert';

import 'package:baakhapaa/providers/video_state_provider.dart';
import 'package:baakhapaa/screens/story/creator_story_screen.dart';
import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:baakhapaa/widgets/comments_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/shorts.dart';
import '../providers/auth.dart';
import '../utils/guest_auth_helper.dart';
import '../screens/shorts/shorts_question_screen.dart';
import '../screens/shorts/shorts_image_puzzle_screen.dart';
import '../../helpers/helpers.dart';
import 'skeleton_loading.dart';
import '../../widgets/share_with_qr_modal.dart';
import '../models/url.dart';

class ShortsSideBar extends StatefulWidget {
  final int index;
  final int shortsId;
  final String image;
  final int questions;
  final int likes;
  final bool liked;
  final int lives;
  final String title;
  final int coins;
  final int coins_users;
  final bool viewed;
  final int user_id;
  final String username;
  final Function fetchMostLikedShortsCallback;
  final Function fetchMostPointsShortsCallback;
  final Function fetchLatestShortsCallback;
  final Function fetchOldestShortsCallback;
  final Function fetchRandomShortsCallback;
  final Function fetchFilteredShortsCallback;
  final Function likeAndUnlikeCallback;
  final VoidCallback onPlayPause;
  final GlobalKey? quizButtonKey;
  final String? videoUrl;

  const ShortsSideBar({
    required this.index,
    required this.shortsId,
    required this.image,
    required this.questions,
    required this.likes,
    required this.liked,
    required this.lives,
    required this.title,
    required this.coins,
    required this.coins_users,
    required this.viewed,
    required this.user_id,
    required this.username,
    required this.fetchMostLikedShortsCallback,
    required this.fetchMostPointsShortsCallback,
    required this.fetchLatestShortsCallback,
    required this.fetchOldestShortsCallback,
    required this.fetchRandomShortsCallback,
    required this.fetchFilteredShortsCallback,
    required this.likeAndUnlikeCallback,
    required this.onPlayPause,
    this.quizButtonKey,
    this.videoUrl,
  });

  @override
  State<ShortsSideBar> createState() => _ShortsSideBarState();
}

class _ShortsSideBarState extends State<ShortsSideBar>
    with TickerProviderStateMixin {
  var shorts;
  late bool _hasLiked;
  late int _likes;
  // late int _coinUser;
  GlobalKey keyNavigation = GlobalKey();
  late GlobalKey _quizIconKey;

  final donationController = TextEditingController();
  final commentController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isUserLoggedIn() {
    final authProvider = Provider.of<Auth>(context, listen: false);
    return authProvider.isAuth;
  }

  @override
  void initState() {
    super.initState();
    shorts = Provider.of<Shorts>(context, listen: false);
    _hasLiked = widget.liked;
    _likes = widget.likes;

    // Initialize stable GlobalKey for quiz icon
    _quizIconKey = GlobalKey(debugLabel: 'quiz_icon_${widget.shortsId}');
  }

  @override
  void didUpdateWidget(ShortsSideBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state when liked state or likes count changes from parent
    if (oldWidget.liked != widget.liked || oldWidget.likes != widget.likes) {
      // Add safety check before setState
      if (mounted) {
        setState(() {
          _hasLiked = widget.liked;
          _likes = widget.likes;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose text controllers
    donationController.dispose();
    commentController.dispose();
    super.dispose();
  }

  void _handleAuthenticatedAction(
      VoidCallback action, String featureName) async {
    // Check if user is logged in
    if (!_isUserLoggedIn()) {
      bool shouldLogin =
          await GuestAuthHelper.showGuestLoginDialog(context, featureName);
      if (!shouldLogin) {
        return;
      }
      // User chose to login, but we should wait for them to complete login
      // For now, just return as the login navigation will handle the flow
      return;
    }

    // Check if profile is completed
    bool isProfileCompleted = await checkAndShowProfileDialog(context);
    if (!isProfileCompleted) {
      return;
    }

    // Execute the action
    action();
  }

  void _showShortsGameModeSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose Game Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildGameModeCard(
              ctx: ctx,
              icon: Icons.quiz_outlined,
              title: 'Quiz',
              subtitle: 'Answer questions to win',
              gradient: [const Color(0xFF667eea), const Color(0xFF764ba2)],
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushNamed(
                  ShortsQuestionScreen.routeName,
                  arguments: {
                    'shortsId': widget.shortsId,
                    'lives': widget.lives,
                    'title': widget.title,
                    'coins': widget.coins,
                    'coins_users': widget.coins_users,
                    'user_id': widget.user_id,
                  },
                );
              },
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildGameModeCard(
              ctx: ctx,
              icon: Icons.extension_outlined,
              title: 'Image Puzzle',
              subtitle: 'Solve the jigsaw puzzle',
              gradient: [const Color(0xFFf093fb), const Color(0xFFf5576c)],
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushNamed(
                  ShortsImagePuzzleScreen.routeName,
                  arguments: {
                    'shortsId': widget.shortsId,
                    'lives': widget.lives,
                    'title': widget.title,
                    'coins': widget.coins,
                    'coins_users': widget.coins_users,
                    'user_id': widget.user_id,
                    'video_url': widget.videoUrl,
                    'user_image': widget.image,
                  },
                );
              },
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameModeCard({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: gradient),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Shadow shadow = Shadow(
      color: Colors.black,
      offset: Offset(1.0, 1.0),
      blurRadius: 3.0,
    );

    TextStyle style = TextStyle(
      fontSize: 13,
      color: Colors.white,
      shadows: [shadow],
    );

    String videoUrl = widget.image.isEmpty
        ? 'https://baakhapaa.com/assets/img/logo/favicon.png'
        : widget.image;

    void _onLike() async {
      bool isProfileCompleted = await checkAndShowProfileDialog(context);

      if (isProfileCompleted && mounted) {
        // Update liked state immediately for instant UI feedback
        setState(() {
          _hasLiked = true;
        });

        // Update parent state immediately (before API call)
        // Parent will increment the count and it will flow back through didUpdateWidget
        widget.likeAndUnlikeCallback(widget.shortsId);

        // Call API in background
        shorts.liked(widget.shortsId);
      }
    }

    void _onUnlike() {
      // Update liked state immediately for instant UI feedback
      setState(() {
        _hasLiked = false;
      });

      // Update parent state immediately (before API call)
      // Parent will decrement the count and it will flow back through didUpdateWidget
      widget.likeAndUnlikeCallback(widget.shortsId);

      // Call API in background
      shorts.unliked(widget.shortsId);
    }

    void _onQuiz() async {
      final auth = Provider.of<Auth>(context, listen: false);
      if (auth.isGuest || !auth.isAuth) {
        await GuestAuthHelper.showGuestLoginDialog(context, 'take quizzes');
        return;
      }

      widget.onPlayPause();
      final videoStateProvider =
          Provider.of<VideoStateProvider>(context, listen: false);

      // Save current shorts ID as the quiz source
      videoStateProvider.saveQuizSourceShorts(widget.shortsId);

      // Also save the position in case we need it
      videoStateProvider.saveCurrentShortsPosition(
          widget.index, widget.shortsId);

      // Enter quiz mode to ensure all videos stop playing
      videoStateProvider.enterQuiz();

      // Show game mode picker (quiz vs image puzzle)
      _showShortsGameModeSheet();
    }

    void donate() async {
      if (_formKey.currentState!.validate()) {
        await Provider.of<Auth>(context, listen: false)
            .donation(
          int.parse(donationController.text),
          widget.shortsId,
          commentController.text,
          'shorts',
        )
            .then((value) {
          Navigator.pop(context);
          donationController.clear();
          commentController.clear();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Thank you for your donation.'),
          ));
        });
      }
    }

    void openDonateModal() {
      final userAvailableCoins =
          Provider.of<Auth>(context, listen: false).userAvailableCoins;
      showModalBottomSheet<void>(
        isScrollControlled: true,
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
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
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Header section
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.pink.shade400,
                                Colors.red.shade400
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.supportCreator,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                'Help support this content creator',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white54
                                    : Colors.grey.shade600,
                          ),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    SizedBox(height: 32),

                    // Available points info
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/coins.png',
                            width: 24,
                            height: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Available Points: ',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$userAvailableCoins',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${context.l10n.supportCreator} ${context.l10n.points}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            controller: donationController,
                            decoration: InputDecoration(
                              hintText: 'Enter points amount',
                              prefixIcon: Padding(
                                padding: EdgeInsets.all(12),
                                child: Image.asset(
                                  'assets/images/coins.png',
                                  width: 20,
                                  height: 20,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                    color: Colors.amber.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter points amount';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              if (int.parse(value) <= 0) {
                                return 'Please enter a positive amount';
                              }
                              if (int.parse(value) > userAvailableCoins) {
                                return 'Insufficient points. Maximum: $userAvailableCoins';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Support Message (Optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: commentController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Write a supportive message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                    color: Colors.amber.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),

                    // Action buttons
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: donate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.pink.shade400,
                                    Colors.red.shade400
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.favorite_rounded,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      context.l10n.sendButton,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: Colors.pinkAccent.shade100,
                                width: 1.5,
                              ),
                              foregroundColor: Colors.pinkAccent,
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      width: 70,
      margin: EdgeInsets.only(right: 8), // Reduced right padding
      child: SingleChildScrollView(
        reverse: true,
        physics: BouncingScrollPhysics(), // Add smooth scrolling
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Profile - moved to top
            Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: _profileImageButton(
                  videoUrl, widget.user_id, widget.username),
            ),
            // Quiz button - only show if questions exist and not yet viewed
            if (widget.questions > 0 && !widget.viewed)
              Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: GestureDetector(
                  onTap: () => _onQuiz(),
                  child: _buildQuizButton(shadow),
                ),
              ),
            // Like button - clean modern design without background
            if (widget.questions > 0 && !widget.viewed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GestureDetector(
                  onTap: () {
                    final userAvailableCoins =
                        Provider.of<Auth>(context, listen: false)
                            .userAvailableCoins;

                    showModalBottomSheet(
                      context: context,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (ctx) {
                        return Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Color(0xFF2A2A2A)
                                    : Colors.white,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 12),
                                  Column(
                                    children: [
                                      Text(
                                        '${widget.title.length > 20 ? widget.title.substring(0, 20) + '...' : widget.title}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '(Points Details)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color.fromARGB(
                                                  255, 90, 89, 89)
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              ListTile(
                                leading: Icon(Icons.account_balance_wallet),
                                title: Text('Your available points'),
                                trailing: Text(
                                  '$userAvailableCoins',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ListTile(
                                leading: Icon(Icons.people),
                                title: Text('Reward Spots Left'),
                                trailing: Text(
                                  '${widget.coins_users}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ListTile(
                                leading: Image.asset(
                                  'assets/images/coins.png',
                                  width: 24,
                                  height: 24,
                                ),
                                title: Text(
                                  widget.coins_users.toString() != '0'
                                      ? 'You can earn from quiz'
                                      : 'Fallback reward (spots finished)',
                                ),
                                trailing: Text(
                                  '${widget.coins_users.toString() != '0' ? widget.coins : 1}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: Text('Close'),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/coins.png',
                        width: 32,
                        height: 32,
                      ),
                      SizedBox(height: 2),
                      Text(
                        widget.coins_users.toString() != '0'
                            ? widget.coins.toString()
                            : '1',
                        style: style,
                      )
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _handleAuthenticatedAction(
                      () => _hasLiked ? _onUnlike() : _onLike(),
                      'likes',
                    ),
                    child: Icon(
                      Icons.thumb_up,
                      shadows: <Shadow>[shadow],
                      size: 32,
                      color: _hasLiked ? Colors.amber.shade700 : Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _likes.toString(),
                    style: style,
                  )
                ],
              ),
            ),
            // Comments button - clean modern design without background
            Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _handleAuthenticatedAction(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentsSheet(
                            shortsId: widget.shortsId,
                          ),
                        ),
                      ),
                      'comments',
                    ),
                    child: Icon(
                      Icons.comment,
                      shadows: <Shadow>[shadow],
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Donate button - clean modern design without background
            Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: GestureDetector(
                onTap: () => _handleAuthenticatedAction(
                  () => openDonateModal(),
                  'donations',
                ),
                child: Icon(
                  Icons.coffee,
                  shadows: <Shadow>[shadow],
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
            // Share button - clean modern design without background
            Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: GestureDetector(
                onTap: () async {
                  // Pause video when share modal is opened
                  widget.onPlayPause();

                  // Encode the originalMap using base64
                  String bs64str1 = base64Url
                      .encode(utf8.encode(json.encode(widget.shortsId)));

                  final shareText =
                      'Baakhapaa Shorts ${Url.deepLink('/shorts/$bs64str1')}';

                  // Show a modal bottom sheet with sharing options
                  await showModalBottomSheet(
                    context: context,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (BuildContext context) {
                      return _buildShareModal(context, shareText);
                    },
                  ).then((_) {
                    // Resume video when modal is closed (optional - user can manually play)
                    // Note: We don't auto-resume to give user control
                  });
                },
                child: Icon(
                  Icons.share,
                  shadows: <Shadow>[shadow],
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
            // Report button
            Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: GestureDetector(
                onTap: () => _showReportContentDialog(context),
                child: Icon(
                  Icons.flag,
                  shadows: <Shadow>[shadow],
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizButton(Shadow shadow) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFF4B625).withOpacity(0.22),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF4B625).withOpacity(0.35),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/images/quiz.svg',
          key: _quizIconKey,
          width: 44,
          height: 44,
        ),
      ),
    );
  }

  void _showReportContentDialog(BuildContext context) {
    String _selectedReason = 'Spam';
    final List<String> reasons = [
      'Spam',
      'Harassment or bullying',
      'Hate speech',
      'Inappropriate content',
      'Misinformation',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.flag_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Report Content'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why are you reporting this video?',
                  style: TextStyle(fontSize: 13)),
              SizedBox(height: 12),
              ...reasons.map((r) => RadioListTile<String>(
                    dense: true,
                    title: Text(r, style: TextStyle(fontSize: 13)),
                    value: r,
                    groupValue: _selectedReason,
                    onChanged: (v) =>
                        setDialogState(() => _selectedReason = v!),
                    contentPadding: EdgeInsets.zero,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final auth = Provider.of<Auth>(context, listen: false);
                  await auth.reportContent(
                    type: 'short',
                    targetId: widget.shortsId,
                    reason: _selectedReason,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Report submitted. Thank you.'),
                      backgroundColor: Colors.green,
                    ));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareModal(BuildContext context, String shareText) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Limit max height
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Color(0xFF2A2A2A)
            : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
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
                    Icons.share_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'Share Shorts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Consumer<Auth>(
              builder: (ctx, auth, _) => FutureBuilder(
                future: auth.fetchConversations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const GridSkeleton(crossAxisCount: 4, itemCount: 8);
                  }
                  final conversations = auth.conversations;
                  return Container(
                    height: 160, // Reduced from 200 to prevent overflow
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: conversations.length,
                      itemBuilder: (ctx, index) {
                        final conversation = conversations[index];
                        final userImage = conversation['user_image'] ?? '';
                        final name = conversation['name'] ?? '';
                        final username = conversation['username'];

                        return GestureDetector(
                          onTap: () {
                            final authProvider =
                                Provider.of<Auth>(context, listen: false);
                            authProvider
                                .sendMessages(
                              conversation['conversation_id'],
                              shareText,
                              'text',
                              null,
                              null,
                            )
                                .then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Shared Successfully!')),
                              );
                              Navigator.pop(context);
                            }).catchError((error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Failed to share. Please try again.')),
                              );
                            });
                          },
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: userImage.isNotEmpty
                                    ? CachedNetworkImageProvider(userImage)
                                    : null,
                                child: userImage.isEmpty
                                    ? Text(name.isEmpty ? username[0] : name[0])
                                    : null,
                              ),
                              SizedBox(height: 4),
                              Text(
                                name.isEmpty ? username : name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.share,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              title: Text('Share to Other Apps'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: shareText,
                    subject: "Join Skill Sikka and earn points!",
                    sharePositionOrigin: Rect.fromLTWH(0, 0, 100, 100),
                  ),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.qr_code,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              title: Text('Share using QR'),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => ShareWithQrModal(
                    data: shareText,
                    subject: "Join Skill Sikka and earn points!",
                  ),
                );
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  _profileImageButton(String imageUrl, int id, String name) {
    return InkWell(
      onTap: () => _handleAuthenticatedAction(
        () {
          widget.onPlayPause();
          final auth = Provider.of<Auth>(context, listen: false);
          final currentUserId = auth.user['id'];
          if (id == currentUserId) {
            Navigator.of(context).pushNamed(UserScreen.routeName);
          } else {
            Navigator.of(context).pushNamed(
              CreatorStoryScreen.routeName,
              arguments: [id, name],
            );
          }
        },
        'profile viewing',
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.amber.shade700,
        child: CircleAvatar(
            radius: 18, backgroundImage: CachedNetworkImageProvider(imageUrl)),
      ),
    );
  }
}
