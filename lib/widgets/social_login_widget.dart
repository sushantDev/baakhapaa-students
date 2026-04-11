// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../providers/social_auth_provider.dart';
// import '../screens/social/facebook_detail_screen.dart';
// import '../screens/social/youtube_detail_screen.dart';
// import '../screens/social/instagram_detail_screen.dart';

// class SocialLoginWidget extends StatelessWidget {
//   final bool showTitle;
//   final bool isHorizontal;
//   final EdgeInsets padding;
//   final double buttonSpacing;

//   const SocialLoginWidget({
//     Key? key,
//     this.showTitle = true,
//     this.isHorizontal = false,
//     this.padding = const EdgeInsets.all(16.0),
//     this.buttonSpacing = 16.0,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<SocialAuthProvider>(
//       builder: (context, socialAuth, child) {
//         return Padding(
//           padding: padding,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               if (showTitle) ...[
//                 Text(
//                   'Connect Social Accounts',
//                   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                         fontWeight: FontWeight.bold,
//                       ),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   'Connect your social media accounts to enhance your experience',
//                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                         color: Colors.grey[600],
//                       ),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: buttonSpacing),
//               ],

//               // Social Login Buttons
//               if (isHorizontal)
//                 Row(
//                   children: [
//                     Expanded(child: _buildFacebookButton(context, socialAuth)),
//                     SizedBox(width: buttonSpacing),
//                     Expanded(child: _buildYouTubeButton(context, socialAuth)),
//                     SizedBox(width: buttonSpacing),
//                     Expanded(child: _buildInstagramButton(context, socialAuth)),
//                   ],
//                 )
//               else
//                 Column(
//                   children: [
//                     _buildFacebookButton(context, socialAuth),
//                     SizedBox(height: buttonSpacing),
//                     _buildYouTubeButton(context, socialAuth),
//                     SizedBox(height: buttonSpacing),
//                     _buildInstagramButton(context, socialAuth),
//                   ],
//                 ),

//               // Error Display
//               if (socialAuth.error != null) ...[
//                 SizedBox(height: buttonSpacing),
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.red.shade50,
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(color: Colors.red.shade200),
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(Icons.error_outline, color: Colors.red.shade600),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           socialAuth.error!,
//                           style: TextStyle(color: Colors.red.shade600),
//                         ),
//                       ),
//                       IconButton(
//                         onPressed: socialAuth.clearError,
//                         icon: const Icon(Icons.close),
//                         color: Colors.red.shade600,
//                         iconSize: 20,
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildFacebookButton(
//       BuildContext context, SocialAuthProvider socialAuth) {
//     final isConnected = socialAuth.isConnectedToFacebook;
//     final isLoading = socialAuth.isLoadingFacebook;

//     return _SocialButton(
//       text: isConnected ? 'Facebook Account' : 'Connect Facebook',
//       icon: Icons.facebook,
//       backgroundColor: isConnected ? Colors.green : const Color(0xFF1877F2),
//       textColor: Colors.white,
//       isLoading: isLoading,
//       isConnected: isConnected,
//       onPressed: isLoading
//           ? null
//           : () {
//               if (isConnected) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const FacebookDetailScreen(),
//                   ),
//                 );
//               } else {
//                 socialAuth.loginWithFacebook();
//               }
//             },
//     );
//   }

//   Widget _buildYouTubeButton(
//       BuildContext context, SocialAuthProvider socialAuth) {
//     final isConnected = socialAuth.isConnectedToYouTube;
//     final isLoading = socialAuth.isLoadingYouTube;

//     print(
//         '🔴 Building YouTube Button: isConnected=$isConnected, isLoading=$isLoading');

//     return _SocialButton(
//       text: isConnected ? 'YouTube Account' : 'Connect YouTube',
//       icon: Icons.video_collection,
//       backgroundColor: isConnected ? Colors.green : const Color(0xFFFF0000),
//       textColor: Colors.white,
//       isLoading: isLoading,
//       isConnected: isConnected,
//       onPressed: isLoading
//           ? null
//           : () {
//               print('🔴 YouTube Button Pressed: isConnected=$isConnected');
//               if (isConnected) {
//                 print('🔴 Navigating to YouTube Detail Screen');
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const YouTubeDetailScreen(),
//                   ),
//                 );
//               } else {
//                 print('🔴 Calling YouTube Login');
//                 socialAuth.loginWithYouTube();
//               }
//             },
//     );
//   }

//   Widget _buildInstagramButton(
//       BuildContext context, SocialAuthProvider socialAuth) {
//     final isConnected = socialAuth.isConnectedToInstagram;
//     final isLoading = socialAuth.isLoadingInstagram;

//     print(
//         '📸 Building Instagram Button: isConnected=$isConnected, isLoading=$isLoading');

//     return _SocialButton(
//       text: isConnected ? 'Instagram Account' : 'Connect Instagram',
//       icon: Icons.camera_alt, // Instagram camera icon
//       backgroundColor: isConnected ? Colors.green : const Color(0xFFE4405F),
//       textColor: Colors.white,
//       isLoading: isLoading,
//       isConnected: isConnected,
//       onPressed: isLoading
//           ? null
//           : () {
//               print('📸 Instagram Button Pressed: isConnected=$isConnected');
//               if (isConnected) {
//                 print('📸 Navigating to Instagram Detail Screen');
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const InstagramDetailScreen(),
//                   ),
//                 );
//               } else {
//                 print('📸 Calling Instagram Login');
//                 socialAuth.loginWithInstagram();
//               }
//             },
//     );
//   }
// }

// class _SocialButton extends StatelessWidget {
//   final String text;
//   final IconData icon;
//   final Color backgroundColor;
//   final Color textColor;
//   final bool isLoading;
//   final bool isConnected;
//   final VoidCallback? onPressed;

//   const _SocialButton({
//     required this.text,
//     required this.icon,
//     required this.backgroundColor,
//     required this.textColor,
//     required this.isLoading,
//     required this.isConnected,
//     this.onPressed,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 56,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: backgroundColor.withValues(alpha: 0.3),
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: ElevatedButton(
//         onPressed: onPressed,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: backgroundColor,
//           foregroundColor: textColor,
//           elevation: 0,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           padding: const EdgeInsets.symmetric(horizontal: 20),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             if (isLoading)
//               SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(
//                   color: textColor,
//                   strokeWidth: 2,
//                 ),
//               )
//             else
//               Icon(
//                 isConnected ? Icons.check_circle : icon,
//                 size: 20,
//                 color: textColor,
//               ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 text,
//                 style: TextStyle(
//                   color: textColor,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Compact Social Login Buttons for smaller spaces
// class CompactSocialButtons extends StatelessWidget {
//   const CompactSocialButtons({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<SocialAuthProvider>(
//       builder: (context, socialAuth, child) {
//         return Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _CompactSocialButton(
//               icon: Icons.facebook,
//               backgroundColor: const Color(0xFF1877F2),
//               isConnected: socialAuth.isConnectedToFacebook,
//               isLoading: socialAuth.isLoadingFacebook,
//               onPressed: socialAuth.isLoadingFacebook
//                   ? null
//                   : () {
//                       if (socialAuth.isConnectedToFacebook) {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => const FacebookDetailScreen(),
//                           ),
//                         );
//                       } else {
//                         socialAuth.loginWithFacebook();
//                       }
//                     },
//             ),
//             _CompactSocialButton(
//               icon: Icons.video_collection,
//               backgroundColor: const Color(0xFFFF0000),
//               isConnected: socialAuth.isConnectedToYouTube,
//               isLoading: socialAuth.isLoadingYouTube,
//               onPressed: socialAuth.isLoadingYouTube
//                   ? null
//                   : () {
//                       if (socialAuth.isConnectedToYouTube) {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => const YouTubeDetailScreen(),
//                           ),
//                         );
//                       } else {
//                         socialAuth.loginWithYouTube();
//                       }
//                     },
//             ),
//             _CompactSocialButton(
//               icon: Icons.camera_alt,
//               backgroundColor: const Color(0xFFE4405F),
//               isConnected: socialAuth.isConnectedToInstagram,
//               isLoading: socialAuth.isLoadingInstagram,
//               onPressed: socialAuth.isLoadingInstagram
//                   ? null
//                   : () {
//                       if (socialAuth.isConnectedToInstagram) {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => const InstagramDetailScreen(),
//                           ),
//                         );
//                       } else {
//                         socialAuth.loginWithInstagram();
//                       }
//                     },
//             ),
//           ],
//         );
//       },
//     );
//   }
// }

// class _CompactSocialButton extends StatelessWidget {
//   final IconData icon;
//   final Color backgroundColor;
//   final bool isConnected;
//   final bool isLoading;
//   final VoidCallback? onPressed;

//   const _CompactSocialButton({
//     required this.icon,
//     required this.backgroundColor,
//     required this.isConnected,
//     required this.isLoading,
//     this.onPressed,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 60,
//       height: 60,
//       decoration: BoxDecoration(
//         shape: BoxShape.circle,
//         boxShadow: [
//           BoxShadow(
//             color: backgroundColor.withValues(alpha: 0.3),
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: ElevatedButton(
//         onPressed: onPressed,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: isConnected ? Colors.green : backgroundColor,
//           foregroundColor: Colors.white,
//           elevation: 0,
//           shape: const CircleBorder(),
//           padding: EdgeInsets.zero,
//         ),
//         child: isLoading
//             ? SizedBox(
//                 width: 24,
//                 height: 24,
//                 child: CircularProgressIndicator(
//                   color: Colors.white,
//                   strokeWidth: 2,
//                 ),
//               )
//             : Icon(
//                 isConnected ? Icons.check : icon,
//                 size: 24,
//               ),
//       ),
//     );
//   }
// }
