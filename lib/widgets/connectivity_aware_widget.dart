import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_service.dart';

class ConnectivityAwareWidget extends StatelessWidget {
  final Widget child;

  const ConnectivityAwareWidget({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Always include the connectivity banner in the tree
    // Let the Consumer handle showing/hiding based on connectivity state
    return Stack(
      children: [
        child,
        // Connectivity banner - always in tree, visibility controlled by Consumer
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Consumer<ConnectivityService>(
            builder: (context, connectivityService, _) {
              // Don't show banner until we've done the initial connectivity check
              // This prevents false "no connection" warnings during app startup
              if (!connectivityService.hasCheckedInitially) {
                return const SizedBox.shrink();
              }

              // Hide banner when connected
              if (connectivityService.isConnected) {
                return const SizedBox.shrink();
              }
              // Show banner when disconnected
              return Material(
                elevation: 8,
                child: Container(
                  color: Colors.red.shade700,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 8,
                    left: 16,
                    right: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No internet connection',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
