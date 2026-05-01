import 'package:baakhapaa/providers/auth.dart';
import 'package:baakhapaa/screens/user/points_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import '../providers/cart.dart';

AppBar headerDefault(context,
    {bool isAppTitle = false, required String titleText}) {
  var _authProvider = Provider.of<Auth>(context, listen: false);
  // Helper function to check if current screen is CartScreen

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
      child: IconButton(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87,
        iconSize: 24,
        icon: Icon(
          Icons.arrow_back,
        ),
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
      InkWell(
        onTap: () {
          Navigator.push(
            context,
            PageTransition(
              child: PointsScreen(),
              type: PageTransitionType.fade,
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.only(right: 5, top: 5),
          child: Consumer<Cart>(
            builder: (_, cart, ch) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                ),
                child: Expanded(
                  child: Container(
                      padding:
                          EdgeInsets.only(top: 5, right: 8, bottom: 5, left: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade400,
                            Colors.orange.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/coins.png',
                            width: 24,
                            height: 24,
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_authProvider.userAvailableCoins}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                ' Sikka',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )),
                ),
              );
            },
          ),
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
