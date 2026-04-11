import 'package:flutter/material.dart';

class Styles {
  static BoxDecoration getContainerDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.amber.shade500
          : Color(0xff24b7c1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        width: 2,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.amber
            : Color(0xff010101),
      ),
    );
  }

  static containerHeight(screenWidth, BuildContext context) {
    return screenWidth <= 400
        ? (0.45 * MediaQuery.of(context).size.height)
        : screenWidth <= 500
            ? (0.45 * MediaQuery.of(context).size.height)
            : screenWidth >= 600 && screenWidth < 1000
                ? (0.55 * MediaQuery.of(context).size.height)
                : (0.5 * MediaQuery.of(context).size.height);
  }

  static containerWidth(screenWidth, BuildContext context) {
    return screenWidth <= 400
        ? (0.7 * MediaQuery.of(context).size.width)
        : screenWidth <= 500
            ? (0.7 * MediaQuery.of(context).size.width)
            : screenWidth >= 600 && screenWidth < 1000
                ? (0.62 * MediaQuery.of(context).size.width)
                : (0.52 * MediaQuery.of(context).size.width);
  }

  static final TextStyle titleTextStyle = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.bold,
    color: Colors.blue,
  );

  static final TextStyle bodyTextStyle = TextStyle(
    fontSize: 16.0,
    color: Colors.black,
  );
}
