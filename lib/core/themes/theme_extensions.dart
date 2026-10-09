import 'package:flutter/material.dart';

extension ThemeColors on BuildContext {
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;
  Color get textSecondary => Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.6);
}
