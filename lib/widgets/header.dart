import 'package:baakhapaa/utils/guest_auth_helper.dart';
import 'package:baakhapaa/widgets/puppet_dashboard.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../navigation/root_navigator_key.dart' show mainNavigatorKey;
import '../models/url.dart';
import '../providers/story.dart';
import '../screens/others/notification_screen.dart';
import '../screens/story/reading_streak_screen.dart';
import '../providers/auth.dart';

const bool _disablePuppetDrawerPanel = false;

// Helper function to calculate adaptive font size based on text length
double _getAdaptiveFontSize(String text) {
  if (text.length <= 8) {
    return 32.0; // Large for short titles
  } else if (text.length <= 15) {
    return 24.0; // Medium for moderate length
  } else if (text.length <= 25) {
    return 20.0; // Smaller for longer titles
  } else {
    return 18.0; // Smallest for very long titles
  }
}

AppBar header({
  required BuildContext context,
  bool isAppTitle = false,
  required String titleText,
  GlobalKey<ScaffoldState>? scaffoldKey,
}) {
  return AppBar(
    toolbarHeight: 57,
    backgroundColor: Colors.black,
    elevation: 0,
    scrolledUnderElevation: 0,
    flexibleSpace: Container(decoration: BoxDecoration(color: Colors.black)),
    leading: scaffoldKey != null
        ? Container(
            margin: EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () async {
                final auth = Provider.of<Auth>(context, listen: false);

                if (_disablePuppetDrawerPanel) {
                  return;
                }

                if (auth.isGuest) {
                  await GuestAuthHelper.showGuestLoginDialog(
                    context,
                    'open menu',
                  );
                  return;
                }

                // Show puppet dashboard half-sheet
                PuppetDashboard.show(context, navigatorKey: mainNavigatorKey);
              },
              child: Consumer<Auth>(
                builder: (context, auth, _) {
                  // Get puppet image URL from user's current puppet
                  String puppetUrl = '${Url.mediaUrl}/assets/puppetdev.png';
                  try {
                    if (auth.puppetImage != null &&
                        auth.puppetImage!.isNotEmpty) {
                      puppetUrl = auth.puppetImage!;
                    } else {
                      final puppet = auth.user['current_puppet'];
                      if (puppet != null && puppet['image'] != null) {
                        puppetUrl = puppet['image'];
                      }
                    }
                  } catch (_) {}

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF4B625),
                            width: 2,
                          ),
                          color: Colors.grey.shade900,
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: puppetUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.smart_toy,
                                color: Color(0xFFF4B625),
                                size: 20,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey.shade800,
                              child: const Icon(
                                Icons.smart_toy,
                                color: Color(0xFFF4B625),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (auth.unreadMessageCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5A5F),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              auth.unreadMessageCount > 99
                                  ? '99+'
                                  : auth.unreadMessageCount.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          )
        : null,
    title: Text(
      titleText,
      style: GoogleFonts.poppins(
        textStyle: Theme.of(context).textTheme.displayLarge,
        fontSize: _getAdaptiveFontSize(titleText),
        fontWeight: FontWeight.w700,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),

    //   ),
    // ),
    actions: [
      Container(
        margin: EdgeInsets.only(right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Streak flame icon (Duolingo-style) with glow
            Selector<Story, int>(
              selector: (_, story) =>
                  story.readingStreak['current_streak'] ?? 0,
              shouldRebuild: (prev, next) => prev != next,
              builder: (context, currentStreak, _) {
                final bool isActive = currentStreak > 0;
                return GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(ReadingStreakScreen.routeName),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        isActive
                            ? _HeaderFlameIcon(size: 24)
                            : Icon(
                                Icons.local_fire_department_rounded,
                                size: 24,
                                color: Colors.grey,
                              ),
                        if (isActive) ...[
                          const SizedBox(width: 2),
                          Text(
                            '$currentStreak',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            // Notification Icon with alert indicator
            Container(
              margin: EdgeInsets.symmetric(horizontal: 2),
              child: Selector<Auth, int>(
                selector: (_, auth) => auth.unreadNotificationCount,
                builder: (_, count, ch) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          padding: EdgeInsets.all(8),
                          constraints: BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          color: Colors.white,
                          icon: Icon(Icons.notifications_rounded, size: 24),
                          onPressed: () {
                            // Check if NotificationScreen is already in the navigation stack
                            bool isNotificationScreenAlreadyOpen =
                                ModalRoute.of(context)?.settings.name ==
                                    NotificationScreen.routeName;

                            if (!isNotificationScreenAlreadyOpen) {
                              Navigator.pushNamed(
                                context,
                                NotificationScreen.routeName,
                              );
                            }
                          },
                        ),
                        // Badge with count
                        if (count > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade400,
                                    Colors.orange.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              constraints: BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                count > 99 ? '99+' : count.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // SizedBox(width: 4),

            // Gift/Shopping Cart Icon (white)
            // Container(
            //   margin: EdgeInsets.only(right: 4),
            //   child: Consumer<Cart>(
            //     builder: (_, cart, ch) {
            //       return Container(
            //         decoration: BoxDecoration(
            //           borderRadius: BorderRadius.circular(12),
            //           color: Colors.transparent,
            //         ),
            //         child: Stack(
            //           children: [
            //             IconButton(
            //               padding: EdgeInsets.all(8),
            //               constraints: BoxConstraints(
            //                 minWidth: 44,
            //                 minHeight: 44,
            //               ),
            //               color: Colors.white,
            //               icon: FaIcon(FontAwesomeIcons.gift, size: 24),
            //               onPressed: () {
            //                 // Check if current screen is GiftScreen
            //                 final currentRoute = ModalRoute.of(context);
            //                 bool isGiftScreenAlreadyOpen =
            //                     currentRoute?.settings.name ==
            //                             GiftScreen.routeName ||
            //                         currentRoute?.settings.arguments
            //                                 .toString()
            //                                 .contains('GiftScreen') ==
            //                             true;

            //                 if (!isGiftScreenAlreadyOpen) {
            //                   Navigator.pushNamed(
            //                       context, GiftScreen.routeName);
            //                 }
            //               },
            //             ),
            //             // if (cart.itemCount > 0)
            //             //   Positioned(
            //             //     right: 6,
            //             //     top: 6,
            //             //     child: Container(
            //             //       padding: EdgeInsets.all(4),
            //             //       decoration: BoxDecoration(
            //             //         gradient: LinearGradient(
            //             //           colors: [
            //             //             Colors.green.shade400,
            //             //             Colors.green.shade600
            //             //           ],
            //             //         ),
            //             //         borderRadius: BorderRadius.circular(10),
            //             //         boxShadow: [
            //             //           BoxShadow(
            //             //             color: Colors.green.withValues(alpha: 0.4),
            //             //             blurRadius: 4,
            //             //             offset: Offset(0, 2),
            //             //           ),
            //             //         ],
            //             //       ),
            //             //       constraints: BoxConstraints(
            //             //         minWidth: 18,
            //             //         minHeight: 18,
            //             //       ),
            //             //       child: Text(
            //             //         cart.itemCount > 99
            //             //             ? '99+'
            //             //             : cart.itemCount.toString(),
            //             //         style: TextStyle(
            //             //           color: Colors.white,
            //             //           fontSize: 10,
            //             //           fontWeight: FontWeight.bold,
            //             //         ),
            //             //         textAlign: TextAlign.center,
            //             //       ),
            //             //     ),
            //             //   ),
            //           ],
            //         ),
            //       );
            //     },
            //   ),
            // ),
          ],
        ),
      ),
    ],
    centerTitle: false,
    systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
  );
}

/// Compact animated flame icon for the header bar with subtle glow and pulse.
class _HeaderFlameIcon extends StatefulWidget {
  final double size;
  const _HeaderFlameIcon({this.size = 24});

  @override
  State<_HeaderFlameIcon> createState() => _HeaderFlameIconState();
}

class _HeaderFlameIconState extends State<_HeaderFlameIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulse.value,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF6B35), Color(0xFFFFD700), Color(0xFFFF4500)],
              stops: [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: widget.size,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
