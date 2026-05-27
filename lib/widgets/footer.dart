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
import '../screens/challenges/all_challenges_screen.dart';
import '../screens/others/creator_request_screen.dart';
import '../utils/guest_auth_helper.dart';
import './content_type_selector_sheet.dart';

// ignore: must_be_immutable
class Footer extends StatefulWidget {
  final NavigatorState? navigator;
  int index;
  final bool fullBleed;
  Footer(this.index, {this.navigator, this.fullBleed = false});

  static const Set<String> _routesWithOwnFooter = {
    '/single-product-screen',
    '/single-gift-screen',
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
    return true;
  }

  static int indexForRoute(Widget? child, String? routeName) {
    final normalizedRoute = routeName?.toLowerCase() ?? '';
    final childType = child?.runtimeType.toString().toLowerCase() ?? '';

    if (normalizedRoute.contains('challenge') ||
        childType.contains('challenge')) {
      return 2;
    }
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
      return 3;
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
      return 4;
    }
    return 0;
  }

  /// Extra space below the nav pill (system nav inset is added separately).
  static const double extraBottomSpace = 8.0;

  /// Full-screen feeds (shorts) overlay the footer; no extra gap under the nav pill.
  static bool isFullBleedRoute(String? routeName, Widget? child) {
    final normalizedRoute = routeName?.toLowerCase() ?? '';
    final childType = child?.runtimeType.toString().toLowerCase() ?? '';
    return normalizedRoute == '/shorts-screen' ||
        // normalizedRoute == '/challenges-screen' ||
        childType.contains('shortsscreen') ||
        childType.contains('challengesscreen');
  }

  /// Bottom spacer for scrollable page content so the last items clear the footer.
  static Widget scrollBottomSpacer(BuildContext context) =>
      SizedBox(height: estimatedHeight(context));

  static double estimatedHeight(BuildContext context,
      {bool fullBleed = false}) {
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

    final double adjustedHeight = (containerHeight + 16).clamp(70.0, 92.0);
    final double totalBottomPadding =
        hasThreeButtonNav ? bottomNavBarPadding : 0.0;
    final double extra = fullBleed ? 0.0 : extraBottomSpace;
    return adjustedHeight + totalBottomPadding + extra;
  }

  @override
  State<Footer> createState() => _FooterState();
}

class _FooterState extends State<Footer> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> scaffoldKeyProduct =
      GlobalKey<ScaffoldState>();
  late AnimationController _animationController;

  BuildContext get _dialogContext => widget.navigator?.context ?? context;

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
      GuestAuthHelper.showGuestLoginDialog(_dialogContext, "create content");
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
    final auth = Provider.of<Auth>(context, listen: false);
    final isUnauthenticated = auth.isGuest ||
        !auth.isAuth ||
        (auth.user.isEmpty && !auth.isLoadingUser);

    // Protect Challenges/Profile for all unauthenticated states.
    if ((index == 2 || index == 4) && isUnauthenticated) {
      await GuestAuthHelper.showGuestLoginDialog(
        _dialogContext,
        index == 2 ? 'challenges' : 'user profile',
      );
      return;
    }

    if (widget.index == index) return;

    // If user data is still loading during initial authentication, don't allow navigation
    if (auth.isLoadingUser &&
        auth.user.isEmpty &&
        (index == 0 || index == 2 || index == 3 || index == 4)) {
      return;
    }

    setState(() => widget.index = index);

    // Handle video state when navigating away from shorts screen
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    if (videoStateProvider.currentScreen == 'shorts' && index != 1) {
      videoStateProvider.handleNavigationAway();
    }

    final navigator = widget.navigator ?? Navigator.of(context);
    switch (index) {
      case 0:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        navigator.pushReplacement(PageTransition(
          child: const StoryScreen(),
          type: PageTransitionType.fade,
          settings: const RouteSettings(name: StoryScreen.routeName),
        ));
        break;
      case 1:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        navigator.pushReplacement(PageTransition(
          child: ShortsScreen(),
          type: PageTransitionType.fade,
          settings: const RouteSettings(name: ShortsScreen.routeName),
        ));
        break;
      case 2:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        navigator.pushReplacement(PageTransition(
          child: const AllChallengesScreen(),
          type: PageTransitionType.fade,
          settings: const RouteSettings(name: AllChallengesScreen.routeName),
        ));
        break;
      case 3:
        // Allow guest users to browse the store
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        navigator.pushReplacement(PageTransition(
          child: TabViewProduct(scaffoldKey: scaffoldKeyProduct),
          type: PageTransitionType.fade,
          settings: const RouteSettings(name: TabViewProduct.routeName),
        ));
        break;
      case 4:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        navigator.pushReplacement(PageTransition(
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
      case 2: // Challenges - Warm Orange/Coral
        return Color(0xFFFF9A56);
      case 3: // Store - Pink
        return Color(0xFFFF6B9D);
      case 4: // Profile - Golden/Yellow
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
      case 2: // Challenges - Warm Orange/Coral
        return Color(0xFFFF9A56).withValues(alpha: 0.5);
      case 3: // Store - Pink
        return Color(0xFFFF6B9D).withValues(alpha: 0.5);
      case 4: // Profile - Golden/Yellow
        return Color(0xFFFFD700).withValues(alpha: 0.5);
      default:
        return Colors.amber.withValues(alpha: 0.5);
    }
  }

  List<Color> _getGemGradient(int index) {
    final color = _getIconColor(index);
    return [
      Color.lerp(Colors.white, color, 0.18)!,
      color,
      Color.lerp(Colors.black, color, 0.72)!,
    ];
  }

  Widget _buildNavIcon({
    IconData? icon,
    String? imageUrl,
    required Color color,
    required double size,
    required bool shouldShowLoading,
  }) {
    if (shouldShowLoading) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: 2,
        ),
      );
    }

    if (imageUrl != null) {
      if (imageUrl.startsWith('assets/')) {
        return Image.asset(
          imageUrl,
          width: size,
          height: size,
          color: color,
          errorBuilder: (_, __, ___) => Icon(
            Icons.home_rounded,
            size: size,
            color: color,
          ),
        );
      }

      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        color: color,
        placeholder: (context, url) => SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: color,
          ),
        ),
        errorWidget: (context, url, error) => Icon(
          Icons.home_rounded,
          size: size,
          color: color,
        ),
      );
    }

    return Icon(
      icon,
      size: size,
      color: color,
    );
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
    final iconColor = _getIconColor(index);
    final glowColor = _getGlowColor(index);
    final selectedGradient = _getGemGradient(index);

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
              behavior: HitTestBehavior.opaque,
              onTap: () => _onItemTapped(index),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                offset: isSelected ? const Offset(0, -0.08) : Offset.zero,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  scale: isSelected ? 1.04 : 1.0,
                  child: SizedBox(
                    height: 56,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          width: isSelected ? 40 : 36,
                          height: isSelected ? 40 : 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: selectedGradient,
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.08),
                                      Colors.white.withValues(alpha: 0.02),
                                    ],
                                  ),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : iconColor.withValues(alpha: 0.24),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              if (isSelected) ...[
                                BoxShadow(
                                  color: glowColor.withValues(alpha: 0.85),
                                  blurRadius: 22,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                                const BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 12,
                                  offset: Offset(0, 7),
                                ),
                              ] else
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isSelected)
                                Positioned(
                                  top: 7,
                                  left: 10,
                                  child: Container(
                                    width: 13,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.32),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              _buildNavIcon(
                                icon: icon,
                                imageUrl: imageUrl,
                                color: isSelected ? Colors.white : iconColor,
                                size: isSelected ? 20 : 18,
                                shouldShowLoading: shouldShowLoading,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          constraints: BoxConstraints(
                            minHeight: isSelected ? 12 : 10,
                            maxWidth: 64,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 6 : 0,
                            vertical: isSelected ? 1 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.black.withValues(alpha: 0.28)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              textScaler: const TextScaler.linear(1.0),
                              style: TextStyle(
                                fontSize: isSelected ? 9.5 : 8.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                height: 1.1,
                                letterSpacing: 0,
                                color: isSelected
                                    ? Colors.white
                                    : iconColor.withValues(alpha: 0.86),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
    double adjustedHeight = (containerHeight + 16).clamp(70.0, 92.0);

    // Only add extra padding for Android devices with 3-button software navigation bar
    final bool isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final bool hasThreeButtonNav = isAndroid && bottomNavBarPadding >= 40;
    final totalBottomPadding = hasThreeButtonNav ? bottomNavBarPadding : 0.0;
    final extra = widget.fullBleed ? 15.0 : 0.0;

    return ColoredBox(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(bottom: totalBottomPadding),
        child: SizedBox(
          height: adjustedHeight + extra,
          child: Consumer<TutorialFlowProvider>(
            builder: (context, tutorial, _) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 4,
                      child: Container(
                        height: adjustedHeight - 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: adjustedHeight - 8,
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF172B4D),
                            Color(0xFF111827),
                            Color(0xFF241A3B),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.08),
                            blurRadius: 2,
                            offset: const Offset(0, -1),
                          ),
                          BoxShadow(
                            color: Color(0xFF5DBBFF).withValues(alpha: 0.12),
                            blurRadius: 24,
                            spreadRadius: 1,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildNavItem(
                                index: 0,
                                imageUrl: 'assets/images/sikka.png',
                                label: AppLocalizations.of(context)!.courses,
                                isSelected: widget.index == 0,
                                tutorial: tutorial,
                                tutorialCondition: tutorial.currentStep == 0 &&
                                    tutorial.isActive,
                              ),
                            ),
                            Expanded(
                              child: _buildNavItem(
                                index: 1,
                                icon: Icons.play_circle_filled_rounded,
                                label: AppLocalizations.of(context)!.shorts,
                                isSelected: widget.index == 1,
                                tutorial: tutorial,
                                tutorialCondition: tutorial.currentStep == 4 &&
                                    tutorial.isActive,
                              ),
                            ),
                            Expanded(
                              child: _buildNavItem(
                                index: 3,
                                icon: Icons.shopping_cart_rounded,
                                label: AppLocalizations.of(context)!.store,
                                isSelected: widget.index == 3,
                                tutorial: tutorial,
                                tutorialCondition: false,
                              ),
                            ),
                            Expanded(
                              child: _buildNavItem(
                                index: 2,
                                icon: Icons.emoji_events_rounded,
                                label: AppLocalizations.of(context)!.challenges,
                                isSelected: widget.index == 2,
                                tutorial: tutorial,
                                tutorialCondition: false,
                              ),
                            ),
                            Expanded(
                              child: _buildNavItem(
                                index: 4,
                                icon: Icons.person_rounded,
                                label: AppLocalizations.of(context)!.profile,
                                isSelected: widget.index == 4,
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
        ),
      ),
    );
  }
}
