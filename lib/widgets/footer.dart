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
import '../screens/my_courses/my_courses_screen.dart';
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
    final childType = resolvedChild?.runtimeType.toString().toLowerCase() ?? '';

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

  /// Lifts modal sheet content above the global footer (e.g. on Shorts).
  static Widget wrapSheetContent(
    BuildContext context,
    Widget child, {
    bool fullBleed = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: estimatedHeight(context, fullBleed: fullBleed),
      ),
      child: child,
    );
  }

  static int indexForRoute(Widget? child, String? routeName) {
    final normalizedRoute = routeName?.toLowerCase() ?? '';
    final childType = child?.runtimeType.toString().toLowerCase() ?? '';

    if (normalizedRoute.contains('challenge') ||
        childType.contains('challenge')) {
      return 3;
    }
    if (normalizedRoute.contains('my-courses') ||
        normalizedRoute.contains('my_courses') ||
        childType.contains('mycourses')) {
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
      return 4;
    }
    return 0;
  }

  /// Extra space below the nav bar (system nav inset is added separately).
  static const double extraBottomSpace = 0.0;

  /// Core tab bar height (labels included), excluding system bottom inset.
  static const double tabBarHeight = 56.0;

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
    final bottomNavBarPadding = MediaQuery.of(context).viewPadding.bottom;
    final double extra = fullBleed ? 0.0 : extraBottomSpace;
    return tabBarHeight + bottomNavBarPadding + extra;
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

    // Protect My Courses, Challenges, and Profile for unauthenticated users.
    if ((index == 2 || index == 3 || index == 4) && isUnauthenticated) {
      final feature = index == 2
          ? 'my courses'
          : index == 3
              ? 'challenges'
              : 'user profile';
      await GuestAuthHelper.showGuestLoginDialog(_dialogContext, feature);
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
        HapticFeedback.selectionClick();
        openTab(
          routeName: MyCourses.routeName,
          child: const MyCourses(),
        );
        break;
      case 3:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        openTab(
          routeName: AllChallengesScreen.routeName,
          child: const AllChallengesScreen(),
        );
        break;
      case 4:
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
        return const Color(0xFFB4690E);
      case 1:
        return const Color(0xFFB4690E);
      case 2:
        return const Color(0xFFB4690E);
      case 3:
        return const Color(0xFFB4690E);
      case 4:
        return const Color(0xFFB4690E);
      default:
        return const Color(0xFFB4690E);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = iconColor;
    final inactiveColor =
        isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF65676B);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Consumer<Auth>(
          builder: (context, auth, child) {
            final shouldShowLoading = auth.isLoadingUser &&
                auth.user.isEmpty &&
                (index == 0 || index == 2 || index == 3 || index == 4);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onItemTapped(index),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildNavIcon(
                        icon: icon,
                        imageUrl: imageUrl,
                        color: isSelected ? activeColor : inactiveColor,
                        size: 24,
                        shouldShowLoading: shouldShowLoading,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          height: 1.1,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (tutorialCondition)
          const Positioned(
            top: -6,
            right: 4,
            child: TutorialIndicator(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavBarPadding = MediaQuery.of(context).viewPadding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFD1D7DC);

    return ColoredBox(
      color: barColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: Footer.tabBarHeight,
            decoration: BoxDecoration(
              color: barColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Consumer<TutorialFlowProvider>(
              builder: (context, tutorial, _) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildNavItem(
                        index: 0,
                        icon: Icons.home_rounded,
                        label: AppLocalizations.of(context)!.courses,
                        isSelected: widget.index == 0,
                        tutorial: tutorial,
                        tutorialCondition:
                            tutorial.currentStep == 0 && tutorial.isActive,
                      ),
                    ),
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
                    Expanded(
                      child: _buildNavItem(
                        index: 2,
                        icon: Icons.bookmark_rounded,
                        label: 'My Courses',
                        isSelected: widget.index == 2,
                        tutorial: tutorial,
                        tutorialCondition: false,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        index: 3,
                        icon: Icons.emoji_events_rounded,
                        label: AppLocalizations.of(context)!.challenges,
                        isSelected: widget.index == 3,
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
                );
              },
            ),
          ),
          if (bottomNavBarPadding > 0)
            SizedBox(
              height: bottomNavBarPadding,
              child: ColoredBox(color: barColor),
            ),
        ],
      ),
    );
  }
}
