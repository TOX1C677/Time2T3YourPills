import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_screen_layout.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  /// Полный M3 [TextTheme] + наши размеры, затем один шрифт (Noto Sans) на **все** роли -
  /// иначе у частичного [AppTypography.textTheme] пустые слоты остаются Roboto (Android).
  static TextTheme _resolvedTextTheme(
    ColorScheme scheme,
    AppScreenLayout layout, {
    required bool boldFonts,
  }) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final custom = AppTypography.textTheme(scheme, scheme.brightness, layout, boldFonts: boldFonts);
    return GoogleFonts.notoSansTextTheme(base.textTheme.merge(custom));
  }

  static TextTheme _resolvedPrimaryTextTheme(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return GoogleFonts.notoSansTextTheme(base.primaryTextTheme);
  }

  static ThemeData light(AppScreenLayout layout, {bool boldFonts = false}) {
    final scheme = AppColors.lightScheme();
    final titleW = boldFonts ? FontWeight.w800 : FontWeight.w600;
    final navLabelW = boldFonts ? FontWeight.w700 : FontWeight.w500;
    final buttonW = boldFonts ? FontWeight.w800 : FontWeight.w600;
    final u = layout.shortestSide;
    final textTheme = _resolvedTextTheme(scheme, layout, boldFonts: boldFonts);
    final primaryTextTheme = _resolvedPrimaryTextTheme(scheme);
    final appFont = textTheme.bodyMedium?.fontFamily;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: appFont,
      scaffoldBackgroundColor: AppColors.lightScreenBg,
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      appBarTheme: AppBarTheme(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: u * 0.08205,
          fontWeight: titleW,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(horizontal: layout.spaceM, vertical: layout.spaceM + 4),
        border: const OutlineInputBorder(),
        labelStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: textTheme.titleSmall?.copyWith(color: scheme.primary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: textTheme.bodyMedium?.copyWith(color: scheme.error),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: layout.spaceM, vertical: layout.spaceS + 4),
        minVerticalPadding: layout.spaceS + 2,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(layout.cardRadius),
          side: BorderSide(color: AppColors.lightBorder, width: layout.borderWidth),
        ),
        margin: EdgeInsets.symmetric(horizontal: layout.spaceM, vertical: layout.spaceS),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: u * 0.246,
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelLarge?.copyWith(
            fontSize: u * 0.049,
            fontWeight: navLabelW,
            height: 1.05,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(layout.primaryButtonHeight),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: u * 0.0718, fontWeight: buttonW),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(layout.buttonRadius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(layout.preferredTouch),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: u * 0.06667, fontWeight: buttonW),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(layout.buttonRadius)),
        ),
      ),
    );
  }

  static ThemeData dark(AppScreenLayout layout, {bool boldFonts = false}) {
    final scheme = AppColors.darkScheme();
    final titleW = boldFonts ? FontWeight.w800 : FontWeight.w600;
    final navLabelW = boldFonts ? FontWeight.w700 : FontWeight.w500;
    final buttonW = boldFonts ? FontWeight.w800 : FontWeight.w600;
    final u = layout.shortestSide;
    final textTheme = _resolvedTextTheme(scheme, layout, boldFonts: boldFonts);
    final primaryTextTheme = _resolvedPrimaryTextTheme(scheme);
    final appFont = textTheme.bodyMedium?.fontFamily;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: appFont,
      scaffoldBackgroundColor: AppColors.darkScreenBg,
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      appBarTheme: AppBarTheme(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: u * 0.08205,
          fontWeight: titleW,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(horizontal: layout.spaceM, vertical: layout.spaceM + 4),
        border: const OutlineInputBorder(),
        labelStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: textTheme.titleSmall?.copyWith(color: scheme.primary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: textTheme.bodyMedium?.copyWith(color: scheme.error),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: layout.spaceM, vertical: layout.spaceS + 4),
        minVerticalPadding: layout.spaceS + 2,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(layout.cardRadius),
          side: BorderSide(color: AppColors.darkBorder, width: layout.borderWidth),
        ),
        margin: EdgeInsets.symmetric(horizontal: layout.spaceM, vertical: layout.spaceS),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: u * 0.246,
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelLarge?.copyWith(
            fontSize: u * 0.049,
            fontWeight: navLabelW,
            height: 1.05,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(layout.primaryButtonHeight),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: u * 0.0718, fontWeight: buttonW),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(layout.buttonRadius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(layout.preferredTouch),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: u * 0.06667, fontWeight: buttonW),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(layout.buttonRadius)),
        ),
      ),
    );
  }
}
