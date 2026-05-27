import 'package:baakhapaa/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth.dart';
import '../providers/video_state_provider.dart';
import '../screens/auth/login_screen.dart';

class GuestAuthHelper {
  /// Shows a dialog prompting guest users to log in
  static Future<bool> showGuestLoginDialog(
      BuildContext context, String feature) async {
    // Always stop any active shorts playback before showing login prompt.
    final videoStateProvider =
        Provider.of<VideoStateProvider>(context, listen: false);
    videoStateProvider.pauseVideo();
    videoStateProvider.forceStopAllVideos();
    videoStateProvider.forceStopAllRegisteredVideos();
    videoStateProvider.clearAllActiveVideos();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.login,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${context.l10n.loginButton} ${context.l10n.required}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To access $feature, you need to log in to your account.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Join Skill Sikka to unlock all features!',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                context.l10n.cancel,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                context.l10n.loginButton,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // Keep shorts muted/stopped while navigating to login.
      videoStateProvider.pauseVideo();
      videoStateProvider.forceStopAllVideos();
      videoStateProvider.forceStopAllRegisteredVideos();
      videoStateProvider.clearAllActiveVideos();

      // Navigate to login screen
      Navigator.of(context).pushNamed(LoginScreen.routeName);
      return true;
    }
    return false;
  }

  /// Checks if user is guest and shows login dialog if needed
  static Future<bool> requireAuth(BuildContext context, String feature) async {
    final authProvider = Provider.of<Auth>(context, listen: false);

    if (authProvider.isGuest) {
      return await showGuestLoginDialog(context, feature);
    }
    return true; // User is authenticated
  }

  /// Shows a snackbar for guest users
  static void showGuestSnackbar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Login required to access $feature',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.amber.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).pushNamed(LoginScreen.routeName);
          },
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }
}
