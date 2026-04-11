import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Global color constants with theme awareness
class AppColors {
  // Theme-aware colors using context
  static Color containerBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF262626)
          : Colors.white54;

  static Color pillBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF333240)
          : const Color(0xFFE0E0E0);

  static Color actionButtonBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF474747)
          : const Color(0xFFD0D0D0);

  static Color backgroundPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFFAFAFA);

  static Color backgroundSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0D1117)
          : Colors.blue.shade50.withValues(alpha: 0.3);

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black87;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade300
          : Colors.grey.shade600;

  static Color cardBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A2A2A)
          : Colors.white;

  static Color shadowColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.grey.withValues(alpha: 0.15);

  static Color borderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.1);
}

// Global text styles
class AppTextStyles {
  static TextStyle inter({
    Color? color,
    FontWeight? fontWeight,
    double? fontSize,
  }) {
    return GoogleFonts.inter(
      color: color,
      fontWeight: fontWeight,
      fontSize: fontSize,
    );
  }

  static TextStyle interBold({Color? color, double? fontSize}) {
    return GoogleFonts.inter(
      color: color,
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
    );
  }

  static TextStyle interSemiBold({Color? color, double? fontSize}) {
    return GoogleFonts.inter(
      color: color,
      fontWeight: FontWeight.w600,
      fontSize: fontSize,
    );
  }

  static TextStyle interMedium({Color? color, double? fontSize}) {
    return GoogleFonts.inter(
      color: color,
      fontWeight: FontWeight.w500,
      fontSize: fontSize,
    );
  }

  static TextStyle interExtraBold({Color? color, double? fontSize}) {
    return GoogleFonts.inter(
      color: color,
      fontWeight: FontWeight.w900,
      fontSize: fontSize,
    );
  }
}

class theme_constants {
  theme_constants._();
  static final ThemeData lightTheme = ThemeData(
      // unselectedWidgetColor: Colors.amber,
      // radioTheme: RadioThemeData(
      //   fillColor: MaterialStateColor.resolveWith((states) => Colors.amber),
      // ),
      colorSchemeSeed: Colors.white,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      fontFamily: 'Montserrat',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          fontSize: 12,
          color: Colors.black,
          fontFamily: 'Montserrat',
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 70,
        foregroundColor: Colors.black,
        shadowColor: Colors.black,
        toolbarTextStyle: TextStyle(
          fontFamily: 'Helvetica',
        ),
        titleSpacing: 10,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Color.fromARGB(255, 255, 254, 254),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: BorderSide(
            color: Colors.black,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: BorderSide(
            color: Colors.black,
            width: 1,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color.fromRGBO(255, 255, 255, 1),
      ));

  static final ThemeData darkTheme = ThemeData(
      primaryColorDark: Color.fromARGB(255, 194, 146, 2),
      canvasColor: Color.fromRGBO(0, 0, 0, 0.758),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      fontFamily: 'Montserrat',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontFamily: 'Montserrat',
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        centerTitle: true,
        toolbarHeight: 50,
        shadowColor: Colors.amber,
        toolbarTextStyle:
            TextStyle(fontFamily: 'Helvetica', color: Colors.white),
        titleSpacing: 5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Color.fromARGB(255, 255, 254, 254),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: BorderSide(
            color: Colors.amber,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: BorderSide(
            color: Colors.amber,
            width: 1,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xff222831),
      ));
}
