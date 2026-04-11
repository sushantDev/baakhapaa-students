import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../utils/debug_logger.dart';

class WalletLauncher {
  // Track if we've already attempted to launch the wallet to prevent loops
  static bool _launchAttempted = false;

  static Future<void> launchWalletApp() async {
    // Prevent recursive launch attempts
    if (_launchAttempted) {
      DebugLogger.info("Wallet launch already attempted, preventing loop");
      return;
    }

    _launchAttempted = true;

    try {
      final walletAppUri = Uri.parse('baakhapaawallet://');
      // Replace with your actual App Store/Play Store URLs
      final appStoreUri =
          Uri.parse('https://apps.apple.com/app/baakhapaa/id1621440391');
      final playStoreUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.baakhapaawallet.com');

      DebugLogger.info("Attempting to launch wallet app: ${walletAppUri.toString()}");

      // First try to launch the app
      bool launched = false;
      try {
        launched = await launchUrl(
          walletAppUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        DebugLogger.error("Error launching wallet app: $e");
        launched = false;
      }

      // If the app couldn't be launched, open the appropriate store
      if (!launched) {
        DebugLogger.info("Wallet app not installed, redirecting to store");
        if (Platform.isIOS) {
          await launchUrl(appStoreUri);
        } else if (Platform.isAndroid) {
          await launchUrl(playStoreUri);
        }
      }

      // Reset after a delay to allow for future attempts
      Future.delayed(Duration(seconds: 3), () {
        _launchAttempted = false;
      });
    } catch (e) {
      DebugLogger.error("Error in launchWalletApp: $e");
      _launchAttempted = false;
    }
  }

  // Add this method to reset the flag manually if needed
  static void resetLaunchFlag() {
    _launchAttempted = false;
  }
}
