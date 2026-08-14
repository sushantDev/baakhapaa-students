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
import '../screens/story/story_screen.dart';
import '../screens/shorts/shorts_screen.dart';
import '../screens/challenges/all_challenges_screen.dart';
import '../screens/others/creator_request_screen.dart';
import '../utils/guest_auth_helper.dart';
import '../navigation/tab_route_history.dart';
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
    '/comments-sheet',
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

  static const Set<String> _quizChildKeywords = {
    'questionscreen',
    'shortsquestionscreen',
    'shortsimagepuzzlescreen',
    'shortswinscreen',
    'shortsloosescreen',
    'guestwinnerscreen',
    'crosswordscreen',
    'imagepuzzlescreen',
    'winscreen',
    'loosescreen',
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

  static Widget? _resolveScreenChild(Widget? widget) {
    if (widget == null) return null;
    if (widget is PageTransition) {
      final dynamic dynamicWidget = widget;
      final childWidget = dynamicWidget.child;
      if (childWidget is Widget) return childWidget;
    }
    return widget;
  }

  static bool _hasBottomNavigationBar(Widget? widget) {
    final resolved = _resolveScreenChild(widget);
    if (resolved == null) return false;
    if (resolved is Scaffold && resolved.bottomNavigationBar != null) {
      return true;
    }
    return false;
  }

  static bool shouldShowOnRoute(
      BuildContext context, Widget? child, String? routeName) {
    final resolvedChild = _resolveScreenChild(child);
    if (_hasBottomNavigationBar(resolvedChild)) {
      return false;
    }
    final normalizedRoute = routeName?.toLowerCase();
    final childType =
        resolvedChild?.runtimeType.toString().toLowerCase() ?? '';

    if (_routesWithOwnFooter.contains(normalizedRoute)) {
      return false;
    }
    if (normalizedRoute != null && _quizRoutes.contains(normalizedRoute)) {
      return false;
    }
    if (_matchesAny(childType, _quizChildKeywords)) {
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
        childType.contains('commentssheet') ||
        childType.contains('youtube') ||
        childType.contains('camerarecording') ||
        childType.contains('aicontent') ||
        childType.contains('manageepisodequestions')) {
      return false;
    }
    return true;
  }

  /// Extra bottom padding for content when the global footer is visible.
  static double contentBottomInset(
    BuildContext context, {
    Widget? child,
    String? routeName,
    bool fullBleed = false,
  }) {
    if (!shouldShowOnRoute(context, child, routeName)) {
      return 0;
    }
    return estimatedHeight(context, fullBleed: fullBleed);
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
    if ((index == 2 || index == 3) && isUnauthenticated) {
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
        (index == 0 || index == 2 || index == 3)) {
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
    void openTab({
      required String routeName,
      required Widget child,
    }) {
      if (TabRouteHistory.contains(routeName)) {
        navigator.popUntil((route) => route.settings.name == routeName);
        return;
      }

      navigator.push(PageTransition(
        child: child,
        type: PageTransitionType.fade,
        settings: RouteSettings(name: routeName),
      ));
    }

    switch (index) {
      case 0:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        openTab(
          routeName: StoryScreen.routeName,
          child: const StoryScreen(),
        );
        break;
      case 1:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        openTab(
          routeName: ShortsScreen.routeName,
          child: ShortsScreen(),
        );
        break;
      case 2:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        openTab(
          routeName: AllChallengesScreen.routeName,
          child: const AllChallengesScreen(),
        );
        break;
      case 3:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        openTab(
          routeName: UserScreen.routeName,
          child: UserScreen(),
        );
        break;
    }
  }

  Color _getIconColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFA435F0);
      case 1:
        return const Color(0xFF6D28D9);
      case 2:
        return const Color(0xFFB4690E);
      case 3:
        return const Color(0xFF1C1D1F);
      default:
        return const Color(0xFFA435F0);
    }
  }

  Color _getGlowColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFA435F0).withValues(alpha: 0.22);
      case 1:
        return const Color(0xFF6D28D9).withValues(alpha: 0.20);
      case 2:
        return const Color(0xFFB4690E).withValues(alpha: 0.18);
      case 3:
        return const Color(0xFF1C1D1F).withValues(alpha: 0.14);
      default:
        return const Color(0xFFA435F0).withValues(alpha: 0.20);
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark ? const Color(0xFFEDE5F9) : iconColor;
    final idleColor =
        isDark ? Colors.white.withValues(alpha: 0.66) : const Color(0xFF6A6F73);
    final selectedTextColor = isDark ? const Color(0xFF1C1D1F) : Colors.white;

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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 10 : 6,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: glowColor,
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNavIcon(
                          icon: icon,
                          imageUrl: imageUrl,
                          color: isSelected ? selectedTextColor : idleColor,
                          size: 20,
                          shouldShowLoading: shouldShowLoading,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.centerLeft,
                          child: isSelected
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 7),
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    textScaler: const TextScaler.linear(1.0),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                      letterSpacing: 0,
                                      color: selectedTextColor,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (!isSelected) ...[
                          const SizedBox(width: 4),
                          Text(
                            label,
                            maxLines: 1,
                            textScaler: const TextScaler.linear(1.0),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              letterSpacing: 0,
                              color: idleColor,
                            ),
                          ),
                        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adjustedHeight = screenWidth <= 360 ? 72.0 : 78.0;

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
                    Container(
                      height: adjustedHeight - 8,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF111827) : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : const Color(0xFFD1D7DC),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
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
        ),
      ),
    );
  }
}
