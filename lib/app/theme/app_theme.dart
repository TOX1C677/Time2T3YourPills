import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_sizes.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light({bool boldFonts = false}) {
    final scheme = AppColors.lightScheme();
    final titleW = boldFonts ? FontWeight.w800 : FontWeight.w600;
    final navLabelW = boldFonts ? FontWeight.w700 : FontWeight.w500;
    final buttonW = boldFonts ? FontWeight.w800 : FontWeight.w600;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightScreenBg,
      textTheme: AppTypography.textTheme(scheme, Brightness.light, boldFonts: boldFonts),
      appBarTheme: AppBarTheme(
        titleTextStyle: GoogleFonts.atkinsonHyperlegible(
          fontSize: 32,
          fontWeight: titleW,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSizes.spaceM, vertical: AppSizes.spaceM + 4),
        border: const OutlineInputBorder(),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSizes.spaceM, vertical: AppSizes.spaceS + 4),
        minVerticalPadding: AppSizes.spaceS + 2,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: const BorderSide(color: AppColors.lightBorder, width: AppSizes.borderWidth),
        ),
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.spaceM, vertical: AppSizes.spaceS),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 96,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 24, fontWeight: navLabelW),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.primaryButtonHeight),
          textStyle: TextStyle(fontSize: 28, fontWeight: buttonW),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.preferredTouch),
          textStyle: TextStyle(fontSize: 26, fontWeight: buttonW),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
        ),
      ),
    );
  }

  static ThemeData dark({bool boldFonts = false}) {
    final scheme = AppColors.darkScheme();
    final titleW = boldFonts ? FontWeight.w800 : FontWeight.w600;
    final navLabelW = boldFonts ? FontWeight.w700 : FontWeight.w500;
    final buttonW = boldFonts ? FontWeight.w800 : FontWeight.w600;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkScreenBg,
      textTheme: AppTypography.textTheme(scheme, Brightness.dark, boldFonts: boldFonts),
      appBarTheme: AppBarTheme(
        titleTextStyle: GoogleFonts.atkinsonHyperlegible(
          fontSize: 32,
          fontWeight: titleW,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSizes.spaceM, vertical: AppSizes.spaceM + 4),
        border: const OutlineInputBorder(),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSizes.spaceM, vertical: AppSizes.spaceS + 4),
        minVerticalPadding: AppSizes.spaceS + 2,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          side: const BorderSide(color: AppColors.darkBorder, width: AppSizes.borderWidth),
        ),
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.spaceM, vertical: AppSizes.spaceS),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 96,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 24, fontWeight: navLabelW),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.primaryButtonHeight),
          textStyle: TextStyle(fontSize: 28, fontWeight: buttonW),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.preferredTouch),
          textStyle: TextStyle(fontSize: 26, fontWeight: buttonW),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
        ),
      ),
    );
  }
}
