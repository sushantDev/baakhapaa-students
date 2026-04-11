import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/social_auth_provider.dart';
import '../../../utils/debug_logger.dart';
// import '../social/facebook_detail_screen.dart';
// import '../social/youtube_detail_screen.dart';
// import '../social/instagram_detail_screen.dart';

class SocialMediaScreen extends StatefulWidget {
  static const routeName = '/social-media-screen';

  const SocialMediaScreen({Key? key}) : super(key: key);

  @override
  State<SocialMediaScreen> createState() => _SocialMediaScreenState();
}

class _SocialMediaScreenState extends State<SocialMediaScreen> {
  @override
  void initState() {
    super.initState();
    // Provider is already initialized in main.dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Only initialize if not already done
        if (!context.read<SocialAuthProvider>().isInitialized) {
          context.read<SocialAuthProvider>().initialize();
        }
      } catch (e) {
        DebugLogger.info('Social auth provider initialization failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Social Media'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? Color.fromARGB(255, 9, 9, 9)
                  : Colors.white,
              Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF082032)
                  : Colors.grey.shade50,
            ],
          ),
        ),
        child: Consumer<SocialAuthProvider>(
          builder: (context, socialAuth, child) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  _buildHeaderSection(context),
                  SizedBox(height: 24),

                  // Connection Status Overview
                  _buildConnectionOverview(socialAuth),
                  SizedBox(height: 24),

                  // Social Media Platforms
                  Text(
                    'Available Platforms',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: 16),

                  // Facebook Connection
                  // _buildSocialConnectionCard(
                  //   context: context,
                  //   socialAuth: socialAuth,
                  //   platform: 'Facebook',
                  //   icon: FontAwesomeIcons.facebook,
                  //   color: Color(0xFF1877F2),
                  //   isConnected: socialAuth.isConnectedToFacebook,
                  //   isLoading: socialAuth.isLoadingFacebook,
                  //   onTap: () => _handleFacebookConnection(socialAuth),
                  // ),

                  // SizedBox(height: 16),

                  // // YouTube Connection
                  // _buildSocialConnectionCard(
                  //   context: context,
                  //   socialAuth: socialAuth,
                  //   platform: 'YouTube',
                  //   icon: FontAwesomeIcons.youtube,
                  //   color: Colors.red,
                  //   isConnected: socialAuth.isConnectedToYouTube,
                  //   isLoading: socialAuth.isLoadingYouTube,
                  //   onTap: () => _handleYouTubeConnection(socialAuth),
                  // ),

                  // SizedBox(height: 16),

                  // // Instagram Connection
                  // _buildSocialConnectionCard(
                  //   context: context,
                  //   socialAuth: socialAuth,
                  //   platform: 'Instagram',
                  //   icon: FontAwesomeIcons.instagram,
                  //   color: Color(0xFFE4405F),
                  //   isConnected: socialAuth.isConnectedToInstagram,
                  //   isLoading: socialAuth.isLoadingInstagram,
                  //   onTap: () => _handleInstagramConnection(socialAuth),
                  // ),

                  SizedBox(height: 24),

                  // Benefits Section
                  if (!socialAuth.isConnectedToFacebook &&
                      !socialAuth.isConnectedToYouTube &&
                      !socialAuth.isConnectedToInstagram) ...[
                    // _buildBenefitsSection(context),
                    SizedBox(height: 24),
                  ],

                  // Error display
                  if (socialAuth.error != null) ...[
                    _buildErrorSection(socialAuth),
                    SizedBox(height: 24),
                  ],

                  // Features Section for Connected Users
                  if (socialAuth.isConnectedToFacebook ||
                      socialAuth.isConnectedToYouTube ||
                      socialAuth.isConnectedToInstagram) ...[
                    _buildFeaturesSection(context, socialAuth),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.share, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Connect Your Social Media',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Connect your social media accounts to enhance your Baakhapaa experience with sharing, content access, and more features.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionOverview(SocialAuthProvider socialAuth) {
    int connectedCount = 0;
    if (socialAuth.isConnectedToFacebook) connectedCount++;
    if (socialAuth.isConnectedToYouTube) connectedCount++;
    if (socialAuth.isConnectedToInstagram) connectedCount++;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: connectedCount > 0
                  ? Colors.green.shade100
                  : Colors.grey.shade100,
              child: Icon(
                connectedCount > 0 ? Icons.check_circle : Icons.account_circle,
                color: connectedCount > 0 ? Colors.green : Colors.grey,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connection Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    connectedCount > 0
                        ? '$connectedCount of 3 platforms connected'
                        : 'No platforms connected',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (connectedCount > 0) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Widget _buildSocialConnectionCard({
  //   required BuildContext context,
  //   required SocialAuthProvider socialAuth,
  //   required String platform,
  //   required IconData icon,
  //   required Color color,
  //   required bool isConnected,
  //   required bool isLoading,
  //   required VoidCallback onTap,
  // }) {
  //   return Card(
  //     elevation: 3,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: ListTile(
  //       contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //       leading: CircleAvatar(
  //         backgroundColor: color.withValues(alpha: 0.1),
  //         radius: 25,
  //         child: FaIcon(icon, color: color, size: 22),
  //       ),
  //       title: Text(
  //         platform,
  //         style: TextStyle(
  //           fontWeight: FontWeight.w600,
  //           fontSize: 16,
  //         ),
  //       ),
  //       subtitle: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             isConnected
  //                 ? 'Connected and ready to use'
  //                 : 'Tap to connect your account',
  //             style: TextStyle(
  //               color: isConnected ? Colors.green : Colors.grey[600],
  //               fontSize: 13,
  //             ),
  //           ),
  //           if (isConnected) ...[
  //             SizedBox(height: 4),
  //             Row(
  //               children: [
  //                 Icon(Icons.verified, color: Colors.green, size: 14),
  //                 SizedBox(width: 4),
  //                 Text(
  //                   'Active',
  //                   style: TextStyle(
  //                     color: Colors.green,
  //                     fontSize: 11,
  //                     fontWeight: FontWeight.w500,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ],
  //       ),
  //       trailing: isLoading
  //           ? SizedBox(
  //               width: 20,
  //               height: 20,
  //               child: CircularProgressIndicator(strokeWidth: 2),
  //             )
  //           : Row(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 if (isConnected)
  //                   Icon(Icons.settings, color: Colors.grey, size: 20)
  //                 else
  //                   Icon(Icons.add_circle_outline, color: color, size: 20),
  //                 SizedBox(width: 8),
  //                 Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
  //               ],
  //             ),
  //       onTap: isLoading ? null : onTap,
  //     ),
  //   );
  // }

  // Widget _buildBenefitsSection(BuildContext context) {
  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Padding(
  //       padding: EdgeInsets.all(20),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             children: [
  //               Icon(Icons.star, color: Colors.amber, size: 24),
  //               SizedBox(width: 8),
  //               Text(
  //                 'Benefits of Connecting',
  //                 style: TextStyle(
  //                   fontWeight: FontWeight.bold,
  //                   fontSize: 18,
  //                 ),
  //               ),
  //             ],
  //           ),
  //           SizedBox(height: 16),
  //           _buildBenefitItem(
  //               Icons.share, 'Share achievements and highlights easily'),
  //           _buildBenefitItem(
  //               Icons.video_library, 'Access and use your YouTube content'),
  //           _buildBenefitItem(Icons.people, 'Connect and compete with friends'),
  //           _buildBenefitItem(
  //               Icons.notifications, 'Get social notifications and updates'),
  //           _buildBenefitItem(Icons.upload, 'Upload and manage your content'),
  //           _buildBenefitItem(Icons.analytics, 'Track your social engagement'),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildBenefitItem(IconData icon, String text) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 6),
  //     child: Row(
  //       children: [
  //         Icon(icon, color: Theme.of(context).primaryColor, size: 20),
  //         SizedBox(width: 12),
  //         Expanded(
  //           child: Text(
  //             text,
  //             style: TextStyle(fontSize: 14),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildErrorSection(SocialAuthProvider socialAuth) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection Error',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  socialAuth.error!,
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => socialAuth.clearError(),
            child: Icon(Icons.close, color: Colors.red.shade600, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(
      BuildContext context, SocialAuthProvider socialAuth) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rocket_launch, color: Colors.purple, size: 24),
                SizedBox(width: 8),
                Text(
                  'Available Features',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (socialAuth.isConnectedToYouTube) ...[
              _buildFeatureItem(
                Icons.video_library,
                'YouTube Integration',
                'Access your videos, playlists, and upload content',
                Colors.red,
              ),
            ],
            if (socialAuth.isConnectedToFacebook) ...[
              _buildFeatureItem(
                Icons.share,
                'Facebook Sharing',
                'Share your achievements and invite friends',
                Color(0xFF1877F2),
              ),
            ],
            if (socialAuth.isConnectedToInstagram) ...[
              _buildFeatureItem(
                Icons.camera_alt,
                'Instagram Stories',
                'Share highlights to your Instagram stories',
                Color(0xFFE4405F),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
      IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            radius: 20,
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Connection Handlers
  // Future<void> _handleFacebookConnection(SocialAuthProvider socialAuth) async {
  //   if (socialAuth.isConnectedToFacebook) {
  //     // Navigate to Facebook detail screen
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => const FacebookDetailScreen(),
  //       ),
  //     );
  //   } else {
  //     // Connect Facebook
  //     await socialAuth.loginWithFacebook();
  //     if (mounted) {
  //       if (socialAuth.isConnectedToFacebook) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Row(
  //               children: [
  //                 Icon(Icons.check_circle, color: Colors.white),
  //                 SizedBox(width: 8),
  //                 Text('Facebook connected successfully!'),
  //               ],
  //             ),
  //             backgroundColor: Colors.green,
  //             behavior: SnackBarBehavior.floating,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //           ),
  //         );
  //       } else {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Row(
  //               children: [
  //                 Icon(Icons.error_outline, color: Colors.white),
  //                 SizedBox(width: 8),
  //                 Expanded(
  //                   child:
  //                       Text(socialAuth.error ?? 'Facebook connection failed'),
  //                 ),
  //               ],
  //             ),
  //             backgroundColor: Colors.red,
  //             behavior: SnackBarBehavior.floating,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //           ),
  //         );
  //       }
  //     }
  //   }
  // }

  // Future<void> _handleYouTubeConnection(SocialAuthProvider socialAuth) async {
  //   if (socialAuth.isConnectedToYouTube) {
  //     // Navigate to YouTube detail screen
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => const YouTubeDetailScreen(),
  //       ),
  //     );
  //   } else {
  //     // Connect YouTube
  //     await socialAuth.loginWithYouTube();
  //     if (mounted) {
  //       if (socialAuth.isConnectedToYouTube) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Row(
  //               children: [
  //                 Icon(Icons.check_circle, color: Colors.white),
  //                 SizedBox(width: 8),
  //                 Text('YouTube connected successfully!'),
  //               ],
  //             ),
  //             backgroundColor: Colors.green,
  //             behavior: SnackBarBehavior.floating,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //           ),
  //         );
  //       } else {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Row(
  //               children: [
  //                 Icon(Icons.error_outline, color: Colors.white),
  //                 SizedBox(width: 8),
  //                 Expanded(
  //                   child:
  //                       Text(socialAuth.error ?? 'YouTube connection failed'),
  //                 ),
  //               ],
  //             ),
  //             backgroundColor: Colors.red,
  //             behavior: SnackBarBehavior.floating,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //           ),
  //         );
  //       }
  //     }
  //   }
  // }

  // Future<void> _handleInstagramConnection(SocialAuthProvider socialAuth) async {
  //   if (socialAuth.isConnectedToInstagram) {
  //     // Navigate to Instagram detail screen
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => const InstagramDetailScreen(),
  //       ),
  //     );
  //   } else {
  //     // Connect Instagram
  //     await socialAuth.loginWithInstagram();
  //     if (mounted) {
  //       if (socialAuth.isConnectedToInstagram) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Row(
  //               children: [
  //                 Icon(Icons.check_circle, color: Colors.white),
  //                 SizedBox(width: 8),
  //                 Text('Instagram connected successfully!'),
  //               ],
  //             ),
  //             backgroundColor: Colors.green,
  //             behavior: SnackBarBehavior.floating,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //           ),
  //         );
  //       } else {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Row(
  //               children: [
  //                 Icon(Icons.error_outline, color: Colors.white),
  //                 SizedBox(width: 8),
  //                 Expanded(
  //                   child:
  //                       Text(socialAuth.error ?? 'Instagram connection failed'),
  //                 ),
  //               ],
  //             ),
  //             backgroundColor: Colors.red,
  //             behavior: SnackBarBehavior.floating,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //           ),
  //         );
  //       }
  //     }
  //   }
  // }
}
