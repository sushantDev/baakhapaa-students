import 'package:baakhapaa/helpers/helpers.dart';
import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:baakhapaa/providers/auth.dart';
// import 'package:baakhapaa/providers/social_auth_provider.dart';
import 'package:baakhapaa/widgets/header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// import '../../theme/AppStateNotifier.dart';
import '../../providers/puppet_interaction_provider.dart';
import '../../utils/puppet_screen_mapping.dart';
import '../../utils/debug_logger.dart';
import '../affiliate/affiliate_dashboard_screen.dart';
// import 'social_media_screen.dart';

class SettingScreen extends StatefulWidget {
  static const routeName = '/setting-screen';

  const SettingScreen({Key? key}) : super(key: key);
  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen>
    with PuppetInteractionMixin {
  @override
  void initState() {
    super.initState();

    // Initialize puppet provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<PuppetInteractionProvider>().initState();
      } catch (e) {
        DebugLogger.puppet('Puppet provider not available: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(
          context: context, titleText: AppLocalizations.of(context)!.settings),
      body: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: <Widget>[
            Flexible(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.only(right: 10),
                height: 700,
                child: ListView(
                  children: <Widget>[
                    // Edit Profile
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(Icons.edit, color: Colors.blue),
                        ),
                        title: Text(
                          AppLocalizations.of(context)!.editProfile,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(context.l10n.updateProfileInfo),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.of(context)
                              .pushNamed('/user-details-screen');
                        },
                      ),
                    ),
                    SizedBox(height: 12),

                    // Profile Privacy Settings
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.cyan.shade100,
                          child: Icon(Icons.lock, color: Colors.cyan),
                        ),
                        title: Text(
                          'Profile Privacy',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle:
                            Text('Control what others see on your profile'),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.of(context)
                              .pushNamed('/profile-privacy-screen');
                        },
                      ),
                    ),
                    SizedBox(height: 12),

                    // Dark Mode Toggle
                    // Card(
                    //   elevation: 2,
                    //   shape: RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.circular(12),
                    //   ),
                    //   child: ListTile(
                    //     leading: CircleAvatar(
                    //       backgroundColor: appStateNotifier.isDarkModeOn
                    //           ? Colors.grey.shade800
                    //           : Colors.amber.shade100,
                    //       child: Icon(
                    //         appStateNotifier.isDarkModeOn
                    //             ? Icons.light_mode
                    //             : Icons.dark_mode,
                    //         color: appStateNotifier.isDarkModeOn
                    //             ? Colors.amber
                    //             : Colors.amber.shade800,
                    //       ),
                    //     ),
                    //     title: Text(
                    //       Theme.of(context).brightness == Brightness.dark
                    //           ? context.l10n.darkMode
                    //           : AppLocalizations.of(context)!.lightMode,
                    //       style: TextStyle(fontWeight: FontWeight.w600),
                    //     ),
                    //     subtitle: Text(context.l10n.toggleSwitchInfo),
                    //     trailing: Switch(
                    //       value: appStateNotifier.isDarkModeOn,
                    //       onChanged: (value) {
                    //         appStateNotifier.toggleTheme();
                    //       },
                    //     ),
                    //   ),
                    // ),
                    // SizedBox(height: 12),
                    // Assistive Touch (Always Enabled - Cannot be disabled)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.shade100,
                          child: Icon(Icons.touch_app, color: Colors.purple),
                        ),
                        title: Text(
                          AppLocalizations.of(context)!.assistiveTouch,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Always enabled for easy navigation'),
                        trailing: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),

                    // Affiliate Program
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.shade100,
                          child:
                              const Icon(Icons.storefront, color: Colors.amber),
                        ),
                        title: const Text(
                          'Affiliate Program',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle:
                            const Text('Earn commissions by linking products'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            AffiliateDashboardScreen.routeName,
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 12),

                    // Contact Us
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child:
                              Icon(Icons.contact_support, color: Colors.green),
                        ),
                        title: Text(
                          AppLocalizations.of(context)!.contactUs,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(context.l10n.contactUsInfo),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.of(context).pushNamed('/contact-us-screen');
                        },
                      ),
                    ),
                    SizedBox(height: 12),

                    // Contact Us
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color.fromARGB(255, 230, 229, 200),
                          child: Icon(Icons.language,
                              color: const Color.fromARGB(255, 172, 76, 175)),
                        ),
                        title: Text(
                          AppLocalizations.of(context)!.language,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(context.l10n.languageInfo),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.of(context)
                              .pushNamed('/language-selector-screen');
                        },
                      ),
                    ),
                    SizedBox(height: 12),

                    // Social Media Connections
                    // Card(
                    //   elevation: 2,
                    //   shape: RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.circular(12),
                    //   ),
                    //   child: Consumer<SocialAuthProvider>(
                    //     builder: (context, socialAuth, child) {
                    //       final connectedCount = _getConnectedCount(socialAuth);
                    //       return ListTile(
                    //         leading: CircleAvatar(
                    //           backgroundColor: Colors.blue.shade100,
                    //           child: Stack(
                    //             children: [
                    //               Icon(Icons.share, color: Colors.blue),
                    //               if (connectedCount > 0)
                    //                 Positioned(
                    //                   right: 0,
                    //                   top: 0,
                    //                   child: Container(
                    //                     width: 8,
                    //                     height: 8,
                    //                     decoration: BoxDecoration(
                    //                       color: Colors.green,
                    //                       shape: BoxShape.circle,
                    //                     ),
                    //                   ),
                    //                 ),
                    //             ],
                    //           ),
                    //         ),
                    //         title: Text(
                    //           'Social Media',
                    //           style: TextStyle(fontWeight: FontWeight.w600),
                    //         ),
                    //         subtitle: Text(
                    //           connectedCount > 0
                    //               ? '$connectedCount platform${connectedCount > 1 ? 's' : ''} connected'
                    //               : 'Connect Facebook, YouTube, Instagram & more',
                    //         ),
                    //         trailing: Row(
                    //           mainAxisSize: MainAxisSize.min,
                    //           children: [
                    //             if (socialAuth.isConnectedToFacebook)
                    //               Padding(
                    //                 padding: const EdgeInsets.only(right: 4),
                    //                 child: FaIcon(
                    //                   FontAwesomeIcons.facebook,
                    //                   size: 16,
                    //                   color: Color(0xFF1877F2),
                    //                 ),
                    //               ),
                    //             if (socialAuth.isConnectedToYouTube)
                    //               Padding(
                    //                 padding: const EdgeInsets.only(right: 4),
                    //                 child: FaIcon(
                    //                   FontAwesomeIcons.youtube,
                    //                   size: 16,
                    //                   color: Colors.red,
                    //                 ),
                    //               ),
                    //             if (socialAuth.isConnectedToInstagram)
                    //               Padding(
                    //                 padding: const EdgeInsets.only(right: 4),
                    //                 child: FaIcon(
                    //                   FontAwesomeIcons.instagram,
                    //                   size: 16,
                    //                   color: Color(0xFFE4405F),
                    //                 ),
                    //               ),
                    //             Icon(Icons.arrow_forward_ios, size: 16),
                    //           ],
                    //         ),
                    //         onTap: () {
                    //           Navigator.of(context).pushNamed(
                    //             SocialMediaScreen.routeName,
                    //           );
                    //         },
                    //       );
                    //     },
                    //   ),
                    // ),
                    // SizedBox(height: 12),

                    // Logout
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child: Icon(Icons.logout, color: Colors.red),
                        ),
                        title: Text(
                          '${context.l10n.logoutButton}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        subtitle: Text(context.l10n.logoutInfo),
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.red),
                        onTap: () => _showLogoutDialog(context),
                      ),
                    ),
                    SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    // Get auth provider before showing dialog
    final authProvider = Provider.of<Auth>(context, listen: false);

    showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Color(0xff222831)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text(context.l10n.logoutButton,
                style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(context.l10n.logoutConfirmation),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'Cancel'),
            child: Text(
              context.l10n.cancel,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Close the dialog first
              Navigator.pop(dialogContext);

              // Sign out the user
              await authProvider.signout();

              // Then navigate to home/login screen using the root navigator
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil(
                  '/',
                  (route) => false, // Remove all routes
                );
              }
            },
            child: Text(context.l10n.logoutButton),
          ),
        ],
      ),
    );
  }

  // int _getConnectedCount(SocialAuthProvider socialAuth) {
  //   int count = 0;
  //   if (socialAuth.isConnectedToFacebook) count++;
  //   if (socialAuth.isConnectedToYouTube) count++;
  //   if (socialAuth.isConnectedToInstagram) count++;
  //   return count;
  // }
}
