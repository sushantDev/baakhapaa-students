import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth.dart';
import '../screens/user/edit_profile_screen.dart';

Future<bool> checkAndShowProfileDialog(BuildContext context) async {
  bool completedProfile =
      await Provider.of<Auth>(context, listen: false).completedProfile;

  if (!completedProfile) {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complete your profile'),
        content: Text(
          'Kindly update your profile with your contact information, including your mobile number, to facilitate easy communication. Your mobile number is essential for us to reach you promptly.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx)
                  .pushReplacementNamed(EditProfileScreen.routeName);
            },
            child: Text('Profile'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  return completedProfile;
}

extension BuildContextExtensions on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

void showScaffoldMessenger(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
  ));
}

void showTopSnackBar(BuildContext context, String message,
    {Color backgroundColor = Colors.red}) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).viewInsets.top +
          50, // Positioning it below the status bar
      left: 10,
      right: 10,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            message,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );

  // Inserting the overlay entry
  overlay.insert(overlayEntry);

  // Automatically remove the overlay after a delay
  Future.delayed(Duration(seconds: 3), () {
    overlayEntry.remove();
  });
}
