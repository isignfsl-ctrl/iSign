import 'package:flutter/material.dart';

class ThemeStateManager {
  ThemeStateManager._();

  static final ThemeStateManager instance = ThemeStateManager._();

  Color _primaryColor = const Color(0xFF1A237E);
  Color _accentColor = const Color(0xFF42A5F5);

  Color get primaryColor => _primaryColor;
  Color get accentColor => _accentColor;

  void updateColors({required Color primary, required Color accent}) {
    _primaryColor = primary;
    _accentColor = accent;
  }
}
