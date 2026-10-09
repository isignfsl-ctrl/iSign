import 'package:flutter/material.dart';
import 'theme_state.dart';

class AppColors {
  AppColors._();

  // Dynamic colors — read from ThemeStateManager
  static Color get primary => ThemeStateManager.instance.primaryColor;
  static Color get accent => ThemeStateManager.instance.accentColor;

  static Color get primaryLight => _lighten(ThemeStateManager.instance.primaryColor, 0.25);
  static Color get primaryDark => _darken(ThemeStateManager.instance.primaryColor, 0.3);
  static Color get accentLight => _lighten(ThemeStateManager.instance.accentColor, 0.25);
  static Color get accentDark => _darken(ThemeStateManager.instance.accentColor, 0.2);

  // Static colors — don't change with theme
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);

  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFBDBDBD);

  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF1976D2);

  static const Color highContrastText = Color(0xFF000000);
  static const Color highContrastBackground = Color(0xFFFFEB3B);

  static const Color disabled = Color(0xFF9E9E9E);
  static const Color divider = Color(0xFFBDBDBD);

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightened = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }
}
