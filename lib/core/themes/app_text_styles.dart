import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const double _displayLargeSize = 36;
  static const double _displayMediumSize = 32;
  static const double _displaySmallSize = 28;
  static const double _headlineLargeSize = 26;
  static const double _headlineMediumSize = 22;
  static const double _headlineSmallSize = 20;
  static const double _titleLargeSize = 18;
  static const double _titleMediumSize = 16;
  static const double _titleSmallSize = 14;
  static const double _bodyLargeSize = 18;
  static const double _bodyMediumSize = 16;
  static const double _bodySmallSize = 14;
  static const double _labelLargeSize = 16;
  static const double _labelMediumSize = 14;
  static const double _labelSmallSize = 12;

  static const TextStyle displayLarge = TextStyle(
    fontSize: _displayLargeSize,
    fontWeight: FontWeight.w700,
    color: AppColors.lightTextPrimary,
    height: 1.3,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: _displayMediumSize,
    fontWeight: FontWeight.w700,
    color: AppColors.lightTextPrimary,
    height: 1.3,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: _displaySmallSize,
    fontWeight: FontWeight.w600,
    color: AppColors.lightTextPrimary,
    height: 1.3,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: _headlineLargeSize,
    fontWeight: FontWeight.w600,
    color: AppColors.lightTextPrimary,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: _headlineMediumSize,
    fontWeight: FontWeight.w600,
    color: AppColors.lightTextPrimary,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: _headlineSmallSize,
    fontWeight: FontWeight.w500,
    color: AppColors.lightTextPrimary,
    height: 1.4,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: _titleLargeSize,
    fontWeight: FontWeight.w600,
    color: AppColors.lightTextPrimary,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: _titleMediumSize,
    fontWeight: FontWeight.w500,
    color: AppColors.lightTextPrimary,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: _titleSmallSize,
    fontWeight: FontWeight.w500,
    color: AppColors.lightTextPrimary,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: _bodyLargeSize,
    fontWeight: FontWeight.w400,
    color: AppColors.lightTextPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: _bodyMediumSize,
    fontWeight: FontWeight.w400,
    color: AppColors.lightTextPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: _bodySmallSize,
    fontWeight: FontWeight.w400,
    color: AppColors.lightTextSecondary,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: _labelLargeSize,
    fontWeight: FontWeight.w500,
    color: AppColors.lightTextPrimary,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: _labelMediumSize,
    fontWeight: FontWeight.w500,
    color: AppColors.lightTextPrimary,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: _labelSmallSize,
    fontWeight: FontWeight.w400,
    color: AppColors.lightTextSecondary,
    height: 1.4,
  );

  static TextStyle dark(TextStyle light) {
    final color = light.color;
    final newColor = color == AppColors.lightTextPrimary
        ? AppColors.darkTextPrimary
        : color == AppColors.lightTextSecondary
            ? AppColors.darkTextSecondary
            : color;
    return light.copyWith(color: newColor);
  }
}
