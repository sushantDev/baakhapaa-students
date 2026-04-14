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
          content: Text('Email not verified yet. Please verify your email first.'),
        ),
      );
      return;
    }

    if (auth.role == 'vendor' || auth.role == 'creator') {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const ContentTypeSelectorSheet(),
      );
      return;
    }

    // Check if user is a creator
    if (auth.role != 'creator') {
      // User is not a creator, redirect to creator request screen
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
        Navigator.pushReplacement(
            context,
            PageTransition(
                child: const StoryScreen(), type: PageTransitionType.fade));
        break;
      case 1:
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        Navigator.pushReplacement(
            context,
            PageTransition(
                child: ShortsScreen(), type: PageTransitionType.fade));
        break;
      case 2:
        // Allow guest users to browse the store
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        Navigator.pushReplacement(
            context,
            PageTransition(
                child: TabViewProduct(scaffoldKey: scaffoldKeyProduct),
                type: PageTransitionType.fade));
        break;
      case 3:
        if (auth.isGuest) {
          await GuestAuthHelper.showGuestLoginDialog(context, "user profile");
          return;
        }
        // small haptic feedback on tab switch
        HapticFeedback.selectionClick();
        Navigator.pushReplacement(context,
            PageTransition(child: UserScreen(), type: PageTransitionType.fade));
        break;
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                constraints: BoxConstraints(
                  minHeight: 50,
                  maxHeight: 60,
                  minWidth: 50,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            Colors.amber.shade400.withValues(alpha: 0.2),
                            Colors.amber.shade600.withValues(alpha: 0.2),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                          width: 1,
                        )
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
                              width: isSelected ? 24 : 22,
                              height: isSelected ? 24 : 22,
                              child: CircularProgressIndicator(
                                color: isSelected
                                    ? Colors.amber.shade600
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : Colors.black87),
                                strokeWidth: 2,
                              ),
                            )
                          : imageUrl != null
                              ? SizedBox(
                                  width: isSelected ? 24 : 22,
                                  height: isSelected ? 24 : 22,
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    color: isSelected
                                        ? Colors.amber.shade600
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.7)
                                            : Colors.black87),
                                    placeholder: (context, url) => SizedBox(
                                      width: isSelected ? 24 : 22,
                                      height: isSelected ? 24 : 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.home_rounded,
                                      size: isSelected ? 24 : 22,
                                      color: isSelected
                                          ? Colors.amber.shade600
                                          : (isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.7)
                                              : Colors.black87),
                                    ),
                                  ),
                                )
                              : Icon(
                                  icon,
                                  size: isSelected ? 24 : 22,
                                  color: isSelected
                                      ? Colors.amber.shade600
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.black87),
                                ),
                    ),
                    SizedBox(height: 4),
                    if (!isSelected)
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.black87,
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
    // (typically older Samsung devices with back/home/recent buttons)
    // - Android 3-button nav bar: ~48dp
    // - Android gesture navigation: ~20-24dp (small gesture pill)
    // - iOS home indicator: ~34dp
    // We only want to adjust for the large 3-button nav bar (>= 40dp) on Android
    final bool isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final bool hasThreeButtonNav = isAndroid && bottomNavBarPadding >= 40;
    final totalBottomPadding = hasThreeButtonNav ? bottomNavBarPadding : 0.0;

    return Container(
      height: adjustedHeight + totalBottomPadding,
      padding: EdgeInsets.only(bottom: totalBottomPadding),
      child: Consumer<TutorialFlowProvider>(
        builder: (context, tutorial, _) {
          return SizedBox(
            height: adjustedHeight + 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Modern navigation bar
                Container(
                  height: adjustedHeight + 10,
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF1A1A1A)
                            : Colors.white,
                        Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF2D2D2D)
                            : Colors.grey.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: Offset(0, -5),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Story tab
                        Expanded(
                          child: _buildNavItem(
                            index: 0,
                            imageUrl:
                                'https://baakhapaa.com/assets/img/vector/tst-vector1.png',
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

                        // Center space for FAB
                        SizedBox(width: 56),

                        // Store tab
                        Expanded(
                          child: _buildNavItem(
                            index: 2,
                            icon: Icons.store_rounded,
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

                // Simplified Floating Action Button for Create Shorts
                Positioned(
                  top: -6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.amber.shade400,
                            Colors.amber.shade600,
                            Colors.amber.shade700,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(26),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _toggleDial();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Consumer<Auth>(
                                builder: (context, auth, child) {
                                  if (auth.isLoadingUser && auth.user.isEmpty) {
                                    return SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }

                                  return Icon(
                                    auth.isGuest
                                        ? Icons.login
                                        : Icons.add_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
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
