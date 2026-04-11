import 'package:flutter/material.dart';

class SubscriptionSnackbar {
  // Reusable method to show the snackbar
  static void show(BuildContext context) {
    final snackBar = SnackBar(
      content: Text(
        'Try our premium subscription for more features!',
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.blueAccent,
      duration: Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Subscribe',
        textColor: Colors.white,
        onPressed: () {
          Navigator.pushNamed(context, '/subscription-screen');
        },
      ),
      behavior: SnackBarBehavior.floating, // makes it float above content
      margin: EdgeInsets.all(16), // optional, adds padding from edges
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
