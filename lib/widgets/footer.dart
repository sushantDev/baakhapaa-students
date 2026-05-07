import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/providers/tutorial_flow_provider.dart';
import 'package:baakhapaa/providers/video_state_provider.dart';
import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:baakhapaa/widgets/tutorial_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth.dart';
import '../screens/shop/tab_view_product.dart';
import '../screens/story/story_screen.dart';
import '../screens/shorts/shorts_screen.dart';
import '../screens/others/creator_request_screen.dart';
import '../utils/guest_auth_helper.dart';
import './content_type_selector_sheet.dart';

// ignore: must_be_immutable
class Footer extends StatefulWidget {
  int index;
  Footer(this.index);

  static const Set<String> _routesWithOwnFooter = {
    '/story-screen',
    '/shorts-screen',
    '/tab_view_product',
    '/user-screen',
    '/discover-screen',
    '/challenges-screen',
    '/creator-story-screen',
    '/single-gift-screen',
    '/single-product-screen',
    '/player-profile-screen',
  };

  static const Set<String> _quizRoutes = {
    '/question-screen',
    '/shorts-question-screen',
    '/shorts-loose-screen',
    '/shorts-win-screen',
    '/guest-winner-screen',
    '/win-screen',
    '/loose-screen',
    '/video-screen',
    '/crossword-screen',
    '/image-puzzle-screen',
    '/shorts-image-puzzle-screen',
  };

  static const Set<String> _authRouteKeywords = {
    'login',
    'register',
    'welcome',
    'verify',
    'forgot',
    'onboarding',
    'splash',
    'interest-selection',
  };

  static const Set<String> _createRouteKeywords = {
    'create',
    'drafts',
    'preview',
    'selector',
    'camera_recording',
    'youtube_video_selector',
    'ai-content-generator',
    'manage-episode-questions',
  };

  static bool _matchesAny(String? value, Set<String> patterns) {
    if (value == null) return false;
    final normalized = value.toLowerCase();
    return patterns.any((pattern) => normalized.contains(pattern));
  }

  static bool _hasBottomNavigationBar(Widget? widget) {
    if (widget == null) return false;
    if (widget is Scaffold && widget.bottomNavigationBar != null) {
      return true;
    }
    if (widget is PageTransition) {
      final dynamic dynamicWidget = widget;
      final childWidget = dynamicWidget.child;
      if (childWidget is Scaffold && childWidget.bottomNavigationBar != null) {
        return true;
      }
    }
    return false;
  }

  static bool shouldShowOnRoute(
      BuildContext context, Widget? child, String? routeName) {
    if (_hasBottomNavigationBar(child)) {
      return false;
    }
    final normalizedRoute = routeName?.toLowerCase();
    final childType = child?.runtimeType.toString().toLowerCase() ?? '';

    if (_routesWithOwnFooter.contains(normalizedRoute)) {
      return false;
    }
    if (normalizedRoute != null && _quizRoutes.contains(normalizedRoute)) {
      return false;
    }
    if (_matchesAny(normalizedRoute, _authRouteKeywords) ||
        _matchesAny(childType, _authRouteKeywords)) {
      return false;
    }
    if (_matchesAny(normalizedRoute, _createRouteKeywords) ||
        _matchesAny(childType, _createRouteKeywords)) {
      return false;
    }
    if (childType.contains('create') ||
        childType.contains('drafts') ||
        childType.contains('preview') ||
        childType.contains('youtube') ||
        childType.contains('camerarecording') ||
        childType.contains('aicontent') ||
        childType.contains('manageepisodequestions')) {
      return false;
    }
    if (childType.contains('storyscreen') ||
        childType.contains('shortsscreen') ||
        childType.contains('tabviewproduct') ||
        childType.contains('userscreen') ||
        childType.contains('discoverscreen') ||
        childType.contains('challengesscreen') ||
        childType.contains('creatorstoryscreen') ||
        childType.contains('singlegiftscreen') ||
        childType.contains('singleproductscreen')) {
      return false;
    }
    return true;
  }

  static int indexForRoute(Widget? child, String? routeName) {
    final normalizedRoute = routeName?.toLowerCase() ?? '';
    final childType = child?.runtimeType.toString().toLowerCase() ?? '';

    if (normalizedRoute.contains('shorts') || childType.contains('shorts')) {
      return 1;
    }
    if (normalizedRoute.contains('shop') ||
        normalizedRoute.contains('product') ||
        normalizedRoute.contains('cart') ||
        normalizedRoute.contains('order') ||
        normalizedRoute.contains('shipping') ||
        normalizedRoute.contains('vendor') ||
        normalizedRoute.contains('gift') ||
        normalizedRoute.contains('for_you') ||
        normalizedRoute.contains('for-you') ||
        childType.contains('shop') ||
        childType.contains('product') ||
        childType.contains('cart') ||
        childType.contains('order') ||
        childType.contains('shipping') ||
        childType.contains('vendor') ||
        childType.contains('gift')) {
      return 2;
    }
    if (normalizedRoute.contains('user') ||
        normalizedRoute.contains('profile') ||
        normalizedRoute.contains('point') ||
        normalizedRoute.contains('wallet') ||
        normalizedRoute.contains('level') ||
        normalizedRoute.contains('weekly') ||
        normalizedRoute.contains('achievement') ||
        normalizedRoute.contains('setting') ||
        normalizedRoute.contains('privacy') ||
        normalizedRoute.contains('social') ||
        normalizedRoute.contains('language') ||
        normalizedRoute.contains('referral') ||
        normalizedRoute.contains('notification') ||
        normalizedRoute.contains('chat') ||
        normalizedRoute.contains('analytics') ||
        normalizedRoute.contains('affiliate') ||
        normalizedRoute.contains('mlbb') ||
        childType.contains('user') ||
        childType.contains('profile') ||
        childType.contains('point') ||
        childType.contains('wallet') ||
        childType.contains('level') ||
        childType.contains('weekly') ||
        childType.contains('achievement') ||
        childType.contains('setting') ||
        childType.contains('privacy') ||
        childType.contains('social') ||
        childType.contains('language') ||
        childType.contains('referral') ||
        childType.contains('notification') ||
        childType.contains('chat') ||
        childType.contains('analytics') ||
        childType.contains('affiliate')) {
      return 3;
    }
    return 0;
  }

  static double estimatedHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomNavBarPadding = MediaQuery.of(context).viewPadding.bottom;
    final bool isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final bool hasThreeButtonNav = isAndroid && bottomNavBarPadding >= 40;

    double containerHeight;
    if (Theme.of(context).platform == TargetPlatform.android) {
      containerHeight = screenWidth <= 380
          ? 0.175 * screenWidth
          : screenWidth <= 480
              ? 0.15 * screenWidth
              : 0.1 * screenWidth;
    } else if (screenWidth >= 768 && screenWidth <= 834) {
      containerHeight = 0.07 * screenWidth;
    } else {
      containerHeight = screenWidth <= 320
          ? 0.15 * screenWidth
          : screenWidth <= 375
              ? 0.175 * screenWidth
              : screenWidth <= 414
                  ? 0.2 * screenWidth
                  : 0.22 * screenWidth;
    }

    final double adjustedHeight = (containerHeight + 15).clamp(60.0, 90.0);
    final double totalBottomPadding =
        hasThreeButtonNav ? bottomNavBarPadding : 0.0;
    return adjustedHeight + totalBottomPadding;
  }

  @override
  State<Footer> createState() => _FooterState();
}

class _FooterState extends State<Footer> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> scaffoldKeyProduct =
      GlobalKey<ScaffoldState>();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ignore: unused_element
  void _toggleDial() {
    final auth = Provider.of<Auth>(context, listen: false);

    // If user data is still loading during initial authentication, don't allow action
    if (auth.isLoadingUser && auth.user.isEmpty) {
      return;
    }

    if (auth.isGuest) {
      GuestAuthHelper.showGuestLoginDialog(context, "create content");
      return;
    }

    if (!auth.isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Email not verified yet. Please verify your email first.'),
        ),
      );
      return;
    }

    if (auth.role == 'vendor' ||
        auth.role == 'creator' ||
        auth.role == 'student') {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const ContentTypeSelectorSheet(),
      );
      return;
    }

    // Unknown role fallback: keep existing creator request path.
    if (auth.role != 'creator' &&
        auth.role != 'student' &&
        auth.role != 'vendor') {
      Navigator.of(context).pushNamed(CreatorRequestScreen.routeName);
      return;
    }

    // Handle video state when navigating to create
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);

    if (videoStateProvider.currentScreen == 'shorts') {
      // Set the navigation flag and pause video
      videoStateProvider.setNavigatingToCreate(true);
    }

    // Show content type selector modal for creators
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ContentTypeSelectorSheet(),
    ).then((_) {
      // When returning from content creation, reset the navigation flag
      if (mounted) {
        final videoProvider =
            Provider.of<VideoStateProvider>(context, listen: false);
        if (videoProvider.isNavigatingToCreate) {
          videoProvider.setNavigatingToCreate(false);
          // If we're still on shorts screen, restore video state
          if (videoProvider.currentScreen == 'shorts') {
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) {
                videoProvider.forcePlayAfterNavigation();
              }
            });
          }
        }
      }
    });
  }

  void _onItemTapped(int index) async {
    setState(() => widget.index = index);
    final auth = Provider.of<Auth>(context, listen: false);

    // If user data is still loading during initial authentication, don't allow navigation
    if (auth.isLoadingUser &&
        auth.user.isEmpty &&
        (index == 0 || index == 2 || index == 3)) {
      return;
    }

    // Handle video state when navigating away from shorts screen
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    if (videoStateProvider.currentScreen == 'shorts' && index != 1) {
      videoStateProvider.handleNavigationAway();
    }

    switch (index) {
      case 0:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        Navigator.of(context, rootNavigator: true)
            .pushReplacement(PageTransition(
          child: const StoryScreen(),
          type: PageTransitionType.fade,
          settings: const RouteSettings(name: StoryScreen.routeName),
        ));
        break;
      case 1:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        Navigator.of(context, rootNavigator: true)
            .pushReplacement(PageTransition(
          child: ShortsScreen(),
          type: PageTransitionType.fade,
          settings: const RouteSettings(name: ShortsScreen.routeName),
        ));
        break;
      case 2:
        // Allow guest users to browse the store
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        Navigator.of(context, rootNavigator: true)
            .pushReplacement(PageTransition(
          child: TabViewProduct(scaffoldKey: scaffoldKeyProduct),
          type: PageTransitionType.fade,
          settings: const RouteSettings(name: TabViewProduct.routeName),
        ));
        break;
      case 3:
        if (auth.isGuest) {
          await GuestAuthHelper.showGuestLoginDialog(context, "user profile");
          return;
        }
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        Navigator.of(context, rootNavigator: true)
            .pushReplacement(PageTransition(
          child: UserScreen(),
          type: PageTransitionType.fade,
          settings: const RouteSettings(name: UserScreen.routeName),
        ));
        break;
    }
  }

  Color _getIconColor(int index) {
    switch (index) {
      case 0: // Courses - Blue
        return Color(0xFF5DBBFF);
      case 1: // Shorts - Purple/Magenta
        return Color(0xFFD084FF);
      case 2: // Store - Pink
        return Color(0xFFFF6B9D);
      case 3: // Profile - Golden/Yellow
        return Color(0xFFFFD700);
      default:
        return Colors.amber;
    }
  }

  Color _getGlowColor(int index) {
    switch (index) {
      case 0: // Courses - Blue
        return Color(0xFF5DBBFF).withValues(alpha: 0.5);
      case 1: // Shorts - Purple/Magenta
        return Color(0xFFD084FF).withValues(alpha: 0.5);
      case 2: // Store - Pink
        return Color(0xFFFF6B9D).withValues(alpha: 0.5);
      case 3: // Profile - Golden/Yellow
        return Color(0xFFFFD700).withValues(alpha: 0.5);
      default:
        return Colors.amber.withValues(alpha: 0.5);
    }
  }

  Widget _buildNavItem({
    required int index,
    IconData? icon,
    String? imageUrl,
    required String label,
    required bool isSelected,
    required TutorialFlowProvider tutorial,
    required bool tutorialCondition,
  }) {
    // ignore: unused_local_variable
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = _getIconColor(index);
    final glowColor = _getGlowColor(index);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Consumer<Auth>(
          builder: (context, auth, child) {
            // Check if this item should show loading state
            // Only show loading if user data is loading AND user data is empty (initial load)
            bool shouldShowLoading = auth.isLoadingUser &&
                auth.user.isEmpty &&
                (index == 0 || index == 2 || index == 3);

            return GestureDetector(
              onTap: () => _onItemTapped(index),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                constraints: BoxConstraints(
                  minHeight: 50,
                  maxHeight: 70,
                  minWidth: 50,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            glowColor.withValues(alpha: 0.15),
                            glowColor.withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? Border.all(
                          color: glowColor.withValues(alpha: 0.4),
                          width: 1.5,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: glowColor,
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      child: shouldShowLoading
                          ? SizedBox(
                              width: isSelected ? 28 : 24,
                              height: isSelected ? 28 : 24,
                              child: CircularProgressIndicator(
                                color: iconColor,
                                strokeWidth: 2,
                              ),
                            )
                          : imageUrl != null
                              ? SizedBox(
                                  width: isSelected ? 28 : 24,
                                  height: isSelected ? 28 : 24,
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    color: iconColor,
                                    placeholder: (context, url) => SizedBox(
                                      width: isSelected ? 28 : 24,
                                      height: isSelected ? 28 : 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        color: iconColor,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.home_rounded,
                                      size: isSelected ? 28 : 24,
                                      color: iconColor,
                                    ),
                                  ),
                                )
                              : Icon(
                                  icon,
                                  size: isSelected ? 28 : 24,
                                  color: iconColor,
                                ),
                    ),
                    if (!(index == 3 && isSelected)) ...[
                      SizedBox(height: 6),
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: isSelected ? 11 : 9,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: iconColor,
                            height: 1.2,
                            letterSpacing: 0.3,
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            textScaler: TextScaler.linear(1.0),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        if (tutorialCondition)
          Positioned(
            top: -10,
            right: -10,
            child: TutorialIndicator(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Get the bottom padding for system navigation bar (back, home, recent buttons)
    final bottomNavBarPadding = MediaQuery.of(context).viewPadding.bottom;
    double containerHeight;

    if (Theme.of(context).platform == TargetPlatform.android) {
      containerHeight = screenWidth <= 380
          ? 0.175 * screenWidth
          : screenWidth <= 480
              ? 0.15 * screenWidth
              : 0.1 * screenWidth;
    } else if (screenWidth >= 768 && screenWidth <= 834) {
      containerHeight = 0.07 * screenWidth;
    } else {
      containerHeight = screenWidth <= 320
          ? 0.15 * screenWidth
          : screenWidth <= 375
              ? 0.175 * screenWidth
              : screenWidth <= 414
                  ? 0.2 * screenWidth
                  : 0.22 * screenWidth;
    }

    // Apply the height, ensuring it's within the allowed range
    double adjustedHeight = (containerHeight + 15).clamp(60.0, 90.0);

    // Only add extra padding for Android devices with 3-button software navigation bar
    final bool isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final bool hasThreeButtonNav = isAndroid && bottomNavBarPadding >= 40;
    final totalBottomPadding = hasThreeButtonNav ? bottomNavBarPadding : 0.0;

    return Container(
      height: adjustedHeight + totalBottomPadding,
      padding: EdgeInsets.only(bottom: totalBottomPadding),
      child: Consumer<TutorialFlowProvider>(
        builder: (context, tutorial, _) {
          return SizedBox(
            height: adjustedHeight + 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Modern navigation bar with enhanced neon glow design
                Container(
                  height: adjustedHeight + 8,
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0F0F1F),
                        Color(0xFF1A1A2E),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 4,
                        offset: Offset(0, -8),
                      ),
                      BoxShadow(
                        color: Color(0xFF5DBBFF).withValues(alpha: 0.1),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Story tab (Courses)
                        Expanded(
                          child: _buildNavItem(
                            index: 0,
                            imageUrl: 'assets/images/sikka.png',
                            label: AppLocalizations.of(context)!.courses,
                            isSelected: widget.index == 0,
                            tutorial: tutorial,
                            tutorialCondition:
                                tutorial.currentStep == 0 && tutorial.isActive,
                          ),
                        ),

                        // Shorts tab
                        Expanded(
                          child: _buildNavItem(
                            index: 1,
                            icon: Icons.play_circle_filled_rounded,
                            label: AppLocalizations.of(context)!.shorts,
                            isSelected: widget.index == 1,
                            tutorial: tutorial,
                            tutorialCondition:
                                tutorial.currentStep == 4 && tutorial.isActive,
                          ),
                        ),

                        // Store tab
                        Expanded(
                          child: _buildNavItem(
                            index: 2,
                            icon: Icons.shopping_cart_rounded,
                            label: AppLocalizations.of(context)!.store,
                            isSelected: widget.index == 2,
                            tutorial: tutorial,
                            tutorialCondition: false,
                          ),
                        ),

                        // Profile tab
                        Expanded(
                          child: _buildNavItem(
                            index: 3,
                            icon: Icons.person_rounded,
                            label: AppLocalizations.of(context)!.profile,
                            isSelected: widget.index == 3,
                            tutorial: tutorial,
                            tutorialCondition: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
