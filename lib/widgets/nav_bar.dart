import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/providers/collaboration_provider.dart';
import 'package:baakhapaa/screens/gift/gift_screen.dart';
import 'package:baakhapaa/screens/messages/conversations_screen.dart';
import 'package:baakhapaa/screens/user/user_details_screen.dart';
import 'package:baakhapaa/screens/user/user_screen.dart';
import 'package:baakhapaa/screens/user/setting_screen.dart';
import 'package:baakhapaa/screens/collaboration/collaborations_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/others/contact_us_screen.dart';
import '../screens/user/points_screen.dart';

class NavBar extends StatelessWidget {
  void launchMessengerApp() async {
    final url = Uri.parse("http://m.me/baakhapaa");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void launchViberGroup() async {
    final url = Uri.parse(
        "https://invite.viber.com/?g2=AQAzrYc1KMHhlFKN9OqY7V7avoAVmTPADgp3vPAFoTJ1vSStiuoW1ujAqD8yBfn%2F");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void launchFacebookApp() async {
    final url = Uri.parse("https://www.facebook.com/baakhapaa");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void launchYoutubeApp() async {
    final url = Uri.parse("https://www.youtube.com/@baakhapaa_app");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void launchInstaApp() async {
    final url = Uri.parse("https://www.instagram.com/_u/baakhapaa_app/");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  String userImageUrl(BuildContext context) {
    String imageUrl;
    var _authProvider = Provider.of<Auth>(context, listen: false);

    if (_authProvider.image == null || _authProvider.image!.isEmpty) {
      imageUrl =
          'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
    } else {
      imageUrl = _authProvider.image!.first['thumbnail'] ??
          'https://img.freepik.com/free-psd/3d-illustration-person-with-sunglasses_23-2149436188.jpg';
    }
    return imageUrl;
  }

  String userDetail(BuildContext context, detail) {
    var _authProvider = Provider.of<Auth>(context, listen: false);
    if (detail == 'name') {
      return _authProvider.userName;
    } else {
      return _authProvider.userAvailableCoins.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark ? Color(0xFF0A0A0A) : Colors.white,
              isDark ? Color(0xFF1A1A1A) : Colors.grey.shade50,
            ],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              colorFilter: ColorFilter.mode(
                Colors.amber.withValues(alpha: 0.8),
                BlendMode.srcATop,
              ),
              opacity: 0.05,
              image: AssetImage('assets/images/Temple.png'),
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
          ),
          child: Column(
            children: [
              // Modern Drawer Header
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.amber.shade400,
                      Colors.amber.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Profile Image with interactive styling
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageTransition(
                                    child: UserDetailsScreen(),
                                    type: PageTransitionType.rightToLeft,
                                  ),
                                );
                              },
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  // Profile image with border
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.amber.shade300,
                                          Colors.amber.shade700
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    padding: EdgeInsets.all(3),
                                    child: CircleAvatar(
                                      radius: 32,
                                      backgroundColor: Colors.white,
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundImage:
                                            CachedNetworkImageProvider(
                                          userImageUrl(context),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Edit badge indicator
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade600,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.2),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Username with modern typography
                                    Text(
                                      userDetail(context, 'name'),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4,
                                            color: Colors.black
                                                .withValues(alpha: 0.2),
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 8),
                                    // User status with engagement metrics
                                    Row(
                                      children: [
                                        // Coins indicator with animated shimmer effect
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              PageTransition(
                                                child: PointsScreen(),
                                                type: PageTransitionType
                                                    .rightToLeft,
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Image.asset(
                                                  'assets/images/coins.png',
                                                  width: 16,
                                                  height: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  userDetail(context, 'coins'),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Close button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Navigation Items
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    children: [
                      _buildNavItem(
                        context,
                        icon: FontAwesomeIcons.gift.data,
                        title: AppLocalizations.of(context)!.rewards,
                        onTap: () {
                          // Check if current screen is GiftScreen
                          final currentRoute = ModalRoute.of(context);
                          bool isGiftScreenAlreadyOpen =
                              currentRoute?.settings.name ==
                                      GiftScreen.routeName ||
                                  currentRoute?.settings.arguments
                                          .toString()
                                          .contains('GiftScreen') ==
                                      true;

                          if (!isGiftScreenAlreadyOpen) {
                            Navigator.pushNamed(context, GiftScreen.routeName);
                          }
                        },
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.person_rounded,
                        title: AppLocalizations.of(context)!.profile,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            PageTransition(
                              child: UserScreen(),
                              type: PageTransitionType.fade,
                            ),
                          );
                        },
                      ),
                      // Messages with unread badge
                      Consumer<Auth>(
                        builder: (context, auth, _) {
                          return _buildNavItemWithBadge(
                            context,
                            icon: Icons.message_rounded,
                            title: AppLocalizations.of(context)!.messages,
                            badgeCount: auth.unreadMessageCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                PageTransition(
                                  child: ConversationsScreen(),
                                  type: PageTransitionType.fade,
                                ),
                              );
                            },
                          );
                        },
                      ),
                      // Collaborations with pending count badge
                      Consumer<CollaborationProvider>(
                        builder: (context, collabProvider, _) {
                          return _buildNavItemWithBadge(
                            context,
                            icon: Icons.people_rounded,
                            title: 'Collaborations',
                            badgeCount: collabProvider.pendingReceivedCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                PageTransition(
                                  child: CollaborationsScreen(),
                                  type: PageTransitionType.fade,
                                ),
                              );
                            },
                          );
                        },
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.leaderboard_rounded,
                        title: AppLocalizations.of(context)!.leaderboard,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageTransition(
                              child: LeaderboardScreen(),
                              type: PageTransitionType.fade,
                            ),
                          );
                        },
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.star_rounded,
                        title: AppLocalizations.of(context)!.reviewUs,
                        onTap: () async {
                          final InAppReview inAppReview = InAppReview.instance;
                          if (await inAppReview.isAvailable()) {
                            inAppReview.requestReview();
                          }
                        },
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.contact_support_rounded,
                        title: AppLocalizations.of(context)!.contactUs,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageTransition(
                              child: ContactUsScreen(),
                              type: PageTransitionType.fade,
                            ),
                          );
                        },
                      ),
                      _buildNavItem(
                        context,
                        icon: Icons.settings_rounded,
                        title: AppLocalizations.of(context)!.settings,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageTransition(
                              child: SettingScreen(),
                              type: PageTransitionType.rightToLeft,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Social Media Section with modern design
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.3)
                          : Colors.grey.shade100,
                      isDark
                          ? Colors.grey.shade900.withValues(alpha: 0.3)
                          : Colors.grey.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.playLearnEarn,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade600,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSocialButton(
                          icon: FontAwesomeIcons.instagram.data,
                          color: Colors.purple,
                          onTap: launchInstaApp,
                        ),
                        _buildSocialButton(
                          icon: Icons.facebook,
                          color: Colors.blue,
                          onTap: launchFacebookApp,
                        ),
                        _buildSocialButton(
                          icon: FontAwesomeIcons.youtube.data,
                          color: Colors.red,
                          onTap: launchYoutubeApp,
                        ),
                        _buildSocialButton(
                          icon: FontAwesomeIcons.facebookMessenger.data,
                          color: Colors.blueAccent,
                          onTap: launchMessengerApp,
                        ),
                        _buildSocialButton(
                          icon: FontAwesomeIcons.viber.data,
                          color: Colors.deepPurple,
                          onTap: launchViberGroup,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // App Version
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Version ${snapshot.data!.version} (${snapshot.data!.buildNumber})',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.amber.shade600,
                    size: 22,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemWithBadge(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.amber.shade600,
                        size: 22,
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.8),
                  color,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
