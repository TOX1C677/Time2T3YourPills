import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_screen_layout.dart';

/// Крупная типографика без загрузки шрифтов из сети (устойчиво в эмуляторе / без Google).
abstract final class AppTypography {
  static FontWeight _displayWeight(bool bold) => bold ? FontWeight.w800 : FontWeight.w600;
  static FontWeight _titleWeight(bool bold) => bold ? FontWeight.w800 : FontWeight.w600;
  static FontWeight _bodyWeight(bool bold) => bold ? FontWeight.w700 : FontWeight.w400;
  /// Как у кнопок/навигации — иначе label выглядит «другим шрифтом» рядом с body.
  static FontWeight _labelWeight(bool bold) => bold ? FontWeight.w800 : FontWeight.w500;

  static double _s(AppScreenLayout layout) => layout.shortestSide;

  static TextTheme textTheme(
    ColorScheme scheme,
    Brightness brightness,
    AppScreenLayout layout, {
    bool boldFonts = false,
  }) {
    final onSurface = scheme.onSurface;
    final secondary =
        brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final u = _s(layout);

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: u * 0.33846,
        fontWeight: _displayWeight(boldFonts),
        height: 1.1,
        color: onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineMedium: TextStyle(
        fontSize: u * 0.11795,
        fontWeight: _titleWeight(boldFonts),
        height: 1.25,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: u * 0.0923,
        fontWeight: _titleWeight(boldFonts),
        height: 1.3,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: u * 0.08205,
        fontWeight: _titleWeight(boldFonts),
        height: 1.35,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: u * 0.06667,
        fontWeight: _titleWeight(boldFonts),
        height: 1.35,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: u * 0.08205,
        fontWeight: _bodyWeight(boldFonts),
        height: 1.4,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: u * 0.07692,
        fontWeight: _bodyWeight(boldFonts),
        height: 1.45,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: u * 0.07692,
        fontWeight: _labelWeight(boldFonts),
        height: 1.2,
        color: onSurface,
      ),
    );
  }

  /// Экран таймера — чуть компактнее глобальной темы.
  static TextTheme timerScreenFrozen(TextTheme enlarged, AppScreenLayout layout) {
    final u = layout.shortestSide;
    return enlarged.copyWith(
      displayLarge: enlarged.displayLarge?.copyWith(fontSize: u * 0.3077, height: 1.1),
      titleLarge: enlarged.titleLarge?.copyWith(fontSize: u * 0.0769, height: 1.3),
      titleMedium: enlarged.titleMedium?.copyWith(fontSize: u * 0.06667, height: 1.35),
      titleSmall: enlarged.titleSmall?.copyWith(fontSize: u * 0.06154, height: 1.35),
      bodyLarge: enlarged.bodyLarge?.copyWith(fontSize: u * 0.0718, height: 1.4),
      bodyMedium: enlarged.bodyMedium?.copyWith(fontSize: u * 0.06667, height: 1.45),
    );
  }
}
