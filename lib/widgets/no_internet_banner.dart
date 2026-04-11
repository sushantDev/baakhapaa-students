import 'package:flutter/material.dart';

class NoInternetBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      color: Colors.red.shade400,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.wifi_off, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Text(
            'No Internet Connection',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
