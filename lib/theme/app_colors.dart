import 'package:flutter/material.dart';

class AppColors {
  // Primary colors (Sophisticated bronze/taupe instead of bright amber)
  static const Color primaryLight = Color(0xFF8B7355); // Muted bronze
  static const Color primaryDark = Color(0xFF6B5B47); // Darker bronze

  // Secondary colors (Complementary warm tones)
  static const Color secondaryLight = Color(0xFF9B8568); // Warm taupe
  static const Color secondaryDark = Color(0xFF7A6B56); // Darker taupe

  // Background colors
  static const Color backgroundLight = Color(0xFFFFFBFE); // Warm white
  static const Color backgroundDark = Color(0xFF141218); // Rich dark

  // Surface colors (for cards, dialogs, etc.)
  static const Color surfaceLight =
      Color(0xFFF7F2FA); // Soft purple-tinted white
  static const Color surfaceDark = Color(0xFF201A20); // Elevated dark surface

  // Text colors for surfaces
  static const Color onSurfaceLight = Color(0xFF1C1B1F);
  static const Color onSurfaceDark = Color(0xFFE6E1E5);

  // Text colors for backgrounds
  static const Color onBackgroundLight = Color(0xFF1C1B1F);
  static const Color onBackgroundDark = Color(0xFFFFFBFE);

  // Text colors for primary surfaces
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onPrimaryDark = Color(0xFF3C2E1A);

  // Text colors for secondary surfaces
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color onSecondaryDark = Color(0xFF403831);

  // Error colors
  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color errorDark = Color(0xFFFFB4AB);

  // Shadow colors
  static const Color shadowLight = Color(0x1A000000); // 10% black
  static const Color shadowDark = Color(0x33000000); // 20% black

  // Accent colors for special elements
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color accentGreen = Color(0xFF7ED321);
  static const Color accentRed = Color(0xFFD0021B);

  // Context-dependent getters
  static Color getPrimary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? primaryDark : primaryLight;
  }

  static Color getSecondary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? secondaryDark : secondaryLight;
  }

  static Color getBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? backgroundDark : backgroundLight;
  }

  static Color getSurface(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surfaceDark : surfaceLight;
  }

  static Color getOnSurface(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? onSurfaceDark : onSurfaceLight;
  }

  static Color getOnBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? onBackgroundDark : onBackgroundLight;
  }

  static Color getOnPrimary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? onPrimaryDark : onPrimaryLight;
  }

  static Color getOnSecondary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? onSecondaryDark : onSecondaryLight;
  }

  static Color getError(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? errorDark : errorLight;
  }

  static Color getShadow(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? shadowDark : shadowLight;
  }

  // Utility methods for shade variations
  static Color getPrimaryShade(BuildContext context, int shade) {
    final baseColor = getPrimary(context);
    switch (shade) {
      case 100:
        return baseColor.withValues(alpha: 0.1);
      case 200:
        return baseColor.withValues(alpha: 0.2);
      case 300:
        return baseColor.withValues(alpha: 0.4);
      case 400:
        return baseColor.withValues(alpha: 0.6);
      case 500:
        return baseColor;
      case 600:
        return _darkenColor(baseColor, 0.1);
      case 700:
        return _darkenColor(baseColor, 0.2);
      case 800:
        return _darkenColor(baseColor, 0.3);
      case 900:
        return _darkenColor(baseColor, 0.4);
      default:
        return baseColor;
    }
  }

  static Color _darkenColor(Color color, double factor) {
    return HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness * (1 - factor))
            .clamp(0.0, 1.0))
        .toColor();
  }

  // Pre-defined decoration helpers
  static BoxDecoration getCardDecoration(BuildContext context) {
    return BoxDecoration(
      color: getSurface(context),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          offset: const Offset(0, 2),
          blurRadius: 8,
          color: getShadow(context),
        ),
      ],
    );
  }

  static BoxDecoration getButtonDecoration(BuildContext context) {
    return BoxDecoration(
      color: getPrimary(context),
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          offset: const Offset(0, 1),
          blurRadius: 3,
          color: getShadow(context),
        ),
      ],
    );
  }
}
