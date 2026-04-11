import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/cart.dart';
import '../screens/shop/cart_screen.dart';

// Global variable to prevent multiple rapid taps on cart
DateTime? _lastCartTapDefault;

AppBar headerDefault(context,
    {bool isAppTitle = false, required String titleText}) {
  // Helper function to check if enough time has passed since last tap
  bool canNavigateToCart() {
    if (_lastCartTapDefault == null) return true;
    return DateTime.now().difference(_lastCartTapDefault!).inMilliseconds >
        1000; // 1 second debounce
  }

  // Helper function to check if current screen is CartScreen
  bool isCurrentScreenCartScreen() {
    final currentRoute = ModalRoute.of(context);
    return currentRoute?.settings.name == CartScreen.routeName ||
        currentRoute?.settings.arguments.toString().contains('CartScreen') ==
            true;
  }

  return AppBar(
    toolbarHeight: 85,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1A1A1A).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF2A2A2A).withValues(alpha: 0.90)
                : Colors.grey.shade50.withValues(alpha: 0.90),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
    ),
    leading: Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: IconButton(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87,
        iconSize: 24,
        icon: Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context, true),
      ),
    ),
    title: isAppTitle
        ? RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Baakh',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                TextSpan(
                  text: 'apaa',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
        : Text(
            titleText.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              letterSpacing: 1.2,
            ),
          ),
    actions: [
      Container(
        margin: EdgeInsets.only(right: 12),
        child: Consumer<Cart>(
          builder: (_, cart, ch) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
              ),
              child: Stack(
                children: [
                  IconButton(
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.black87,
                    icon: Icon(
                      Icons.shopping_bag_rounded,
                      size: 22,
                    ),
                    onPressed: () {
                      // Block navigation if already on CartScreen
                      if (isCurrentScreenCartScreen()) {
                        return;
                      }

                      if (canNavigateToCart()) {
                        _lastCartTapDefault = DateTime.now();
                        Navigator.of(context).pushNamed(CartScreen.routeName);
                      }
                    },
                  ),
                  if (cart.itemCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          cart.itemCount > 99
                              ? '99+'
                              : cart.itemCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ],
    centerTitle: false, // Changed to false for left alignment
    titleSpacing: 0, // Remove extra spacing for better left alignment
    systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
  );
}
