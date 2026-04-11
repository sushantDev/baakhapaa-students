import 'package:flutter/material.dart';

// ignore: must_be_immutable
class AppButttons extends StatelessWidget {
  final Color textColor;
  final Color backgroundColor;
  final Color? fillCircleColor;
  final Color? borderColor;
  final IconData? iconLeft;
  final Color? iconColor;
  final IconData? iconRight;
  final String text;
  double size;

  AppButttons(
      {Key? key,
      required this.textColor,
      required this.backgroundColor,
      required this.borderColor,
      this.fillCircleColor,
      this.iconColor,
      this.iconRight,
      this.iconLeft,
      required this.text,
      required this.size})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: size,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            iconLeft == null
                ? Container(
                    height: 0,
                    width: 0,
                  )
                : Container(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: fillCircleColor == null
                                ? Colors.amber
                                : fillCircleColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(width: 1),
                          ),
                          child: Icon(
                            iconLeft,
                            color: iconColor == null ? Colors.black : iconColor,
                          )),
                    ),
                  ),
            Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            iconRight == null
                ? Container(
                    height: 0,
                    width: 0,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(width: 1),
                        ),
                        child: Icon(iconRight)),
                  ),
          ],
        ),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 251, 146, 8),
            Color.fromARGB(255, 249, 201, 89)
          ], // Example gradient colors
          begin: Alignment.centerLeft, // Start from the center right
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor as Color, width: 1.0),
      ),
    );
  }
}
