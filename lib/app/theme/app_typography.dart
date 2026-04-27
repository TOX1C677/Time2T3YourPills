import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Крупная типографика без загрузки шрифтов из сети (устойчиво в эмуляторе / без Google).
abstract final class AppTypography {
  static FontWeight _displayWeight(bool bold) => bold ? FontWeight.w800 : FontWeight.w600;
  static FontWeight _titleWeight(bool bold) => bold ? FontWeight.w800 : FontWeight.w600;
  static FontWeight _bodyWeight(bool bold) => bold ? FontWeight.w700 : FontWeight.w400;
  static FontWeight _labelWeight(bool bold) => bold ? FontWeight.w800 : FontWeight.w600;

  static TextTheme textTheme(ColorScheme scheme, Brightness brightness, {bool boldFonts = false}) {
    final onSurface = scheme.onSurface;
    final secondary =
        brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 132,
        fontWeight: _displayWeight(boldFonts),
        height: 1.1,
        color: onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineMedium: TextStyle(
        fontSize: 46,
        fontWeight: _titleWeight(boldFonts),
        height: 1.25,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 36,
        fontWeight: _titleWeight(boldFonts),
        height: 1.3,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 32,
        fontWeight: _titleWeight(boldFonts),
        height: 1.35,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 26,
        fontWeight: _titleWeight(boldFonts),
        height: 1.35,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 32,
        fontWeight: _bodyWeight(boldFonts),
        height: 1.4,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 30,
        fontWeight: _bodyWeight(boldFonts),
        height: 1.45,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 30,
        fontWeight: _labelWeight(boldFonts),
        height: 1.2,
        color: onSurface,
      ),
    );
  }

  /// Экран таймера — чуть компактнее глобальной темы, но всё же крупнее базового макета.
  static TextTheme timerScreenFrozen(TextTheme enlarged) {
    return enlarged.copyWith(
      displayLarge: enlarged.displayLarge?.copyWith(fontSize: 120, height: 1.1),
      titleLarge: enlarged.titleLarge?.copyWith(fontSize: 30, height: 1.3),
      titleMedium: enlarged.titleMedium?.copyWith(fontSize: 26, height: 1.35),
      titleSmall: enlarged.titleSmall?.copyWith(fontSize: 24, height: 1.35),
      bodyLarge: enlarged.bodyLarge?.copyWith(fontSize: 28, height: 1.4),
      bodyMedium: enlarged.bodyMedium?.copyWith(fontSize: 26, height: 1.45),
    );
  }
}
