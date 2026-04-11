import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExitConfirmationDialog {
  /// Shows a confirmation dialog when the user tries to exit the app
  /// Returns true if the user confirms exit, false otherwise
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Exit App'),
          content: Text('Are you sure you want to exit?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber.shade700,
              ),
              child: Text('Exit'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Creates a PopScope wrapper for any screen to handle back button presses
  /// and show the exit confirmation dialog
  static Widget wrapWithExitConfirmation({
    required Widget child,
    required BuildContext context,
  }) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }
        final shouldExit = await show(context);
        if (shouldExit) {
          if (Platform.isAndroid) {
            SystemNavigator.pop();
          } else if (Platform.isIOS) {
            // On iOS, we need to exit the app with an error code
            // This is the only way to properly terminate an iOS app programmatically
            exit(0);
          }
        }
      },
      child: child,
    );
  }
}
