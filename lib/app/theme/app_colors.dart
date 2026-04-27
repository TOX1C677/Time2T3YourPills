import 'package:flutter/material.dart';

/// Палитра из `UI_DESIGN_PLAN.md` §B.1 (светлая / тёмная).
abstract final class AppColors {
  static const Color lightScreenBg = Color(0xFFF4F1EC);
  static const Color lightCardBg = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF16181D);
  static const Color lightTextSecondary = Color(0xFF3E4450);
  static const Color lightBorder = Color(0xFFD9D3C7);
  static const Color lightPositive = Color(0xFF0B6E4F);
  static const Color lightWarning = Color(0xFF5A4A17);
  static const Color lightNegative = Color(0xFFB23A1F);

  static const Color darkScreenBg = Color(0xFF0E1013);
  static const Color darkCardBg = Color(0xFF1A1D22);
  static const Color darkTextPrimary = Color(0xFFF2EFE8);
  static const Color darkTextSecondary = Color(0xFFB7BCC7);
  static const Color darkBorder = Color(0xFF2B2F37);
  static const Color darkPositive = Color(0xFF4FD39A);
  static const Color darkWarning = Color(0xFFE0B84A);
  static const Color darkNegative = Color(0xFFFF7A5C);

  static ColorScheme lightScheme() {
    return ColorScheme.fromSeed(
      seedColor: lightPositive,
      brightness: Brightness.light,
      surface: lightCardBg,
      onSurface: lightTextPrimary,
      primary: lightPositive,
      onPrimary: Colors.white,
      secondary: lightWarning,
      onSecondary: Colors.white,
      error: lightNegative,
      outline: lightBorder,
    );
  }

  static ColorScheme darkScheme() {
    return ColorScheme.fromSeed(
      seedColor: darkPositive,
      brightness: Brightness.dark,
      surface: darkCardBg,
      onSurface: darkTextPrimary,
      primary: darkPositive,
      onPrimary: darkScreenBg,
      secondary: darkWarning,
      onSecondary: darkScreenBg,
      error: darkNegative,
      outline: darkBorder,
    );
  }
}
