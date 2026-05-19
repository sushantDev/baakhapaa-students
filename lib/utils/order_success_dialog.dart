import 'package:flutter/material.dart';

import '../helpers/helpers.dart';
import '../navigation/root_navigator_key.dart' show mainNavigatorKey;
import '../screens/user/orders_screen.dart';

/// Order-complete sheet shown after cart checkout or quick buy.
///
/// Uses the app root navigator so navigation still works after cart reset
/// disposes [OrderButton] or after [QuickBuyDialog] is popped.
void presentOrderSuccessDialog({
  required String detailMessage,
  bool popRouteUnderDialog = false,
}) {
  final host = mainNavigatorKey.currentContext;
  if (host == null) return;

  showDialog(
    context: host,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.teal.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Order Successful!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            detailMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (popRouteUnderDialog) {
                  mainNavigatorKey.currentState?.pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Continue Shopping',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (popRouteUnderDialog) {
                  mainNavigatorKey.currentState?.pop();
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  mainNavigatorKey.currentState?.push(
                    MaterialPageRoute<void>(
                      settings:
                          const RouteSettings(name: OrdersScreen.routeName),
                      builder: (_) => const OrdersScreen(),
                    ),
                  );
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade600, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                host.l10n.yourOrderHistory,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
