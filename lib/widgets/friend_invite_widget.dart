import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/social_auth_provider.dart';

class FriendInviteWidget extends StatelessWidget {
  final String? customMessage;
  final String? appUrl;

  const FriendInviteWidget({
    Key? key,
    this.customMessage,
    this.appUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Invite Friends',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Share Baakhapaa with your friends and start playing together!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // Sharing buttons
            Consumer<SocialAuthProvider>(
              builder: (context, socialAuth, child) {
                return Column(
                  children: [
                    // Facebook Share Button
                    // if (socialAuth.isConnectedToFacebook)
                    //   _buildShareButton(
                    //     icon: Icons.facebook,
                    //     label: 'Share on Facebook',
                    //     color: const Color(0xFF1877F2),
                    //     onPressed: () => _shareOnFacebook(context, socialAuth),
                    //   ),

                    // const SizedBox(height: 12),

                    // General Share Button
                    _buildShareButton(
                      icon: Icons.share,
                      label: 'Share with Friends',
                      color: Colors.green,
                      onPressed: () => _shareGeneral(context),
                    ),

                    const SizedBox(height: 12),

                    // Copy Link Button
                    _buildShareButton(
                      icon: Icons.copy,
                      label: 'Copy Invite Link',
                      color: Colors.orange,
                      onPressed: () => _copyInviteLink(context),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // void _shareOnFacebook(
  //     BuildContext context, SocialAuthProvider socialAuth) async {
  //   try {
  //     final result = await socialAuth.shareAppInvitation(
  //       customMessage: customMessage,
  //     );

  //     if (result['success']) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Opening Facebook to share...'),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Failed to share: ${result['error']}'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  void _shareGeneral(BuildContext context) {
    final String shareText = customMessage ??
        'Join me on Skill Sikka! 🎮 The amazing learning app where you can play, compete, and win real rewards! Download now: ${appUrl ?? 'https://play.google.com/store/apps/details?id=com.baakhapaa.com'}';

    SharePlus.instance.share(ShareParams(text: shareText));
  }

  void _copyInviteLink(BuildContext context) {
    final String inviteLink = appUrl ??
        'https://play.google.com/store/apps/details?id=com.baakhapaa.com';

    Clipboard.setData(ClipboardData(text: inviteLink));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
