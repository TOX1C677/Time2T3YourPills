import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/profile/ui_preferences_controller.dart';
import 'theme/app_screen_layout.dart';
import 'theme/app_theme.dart';

class Time2T3App extends StatelessWidget {
  const Time2T3App({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final bold = context.watch<UiPreferencesController>().boldFonts;
    final refLayout = AppScreenLayout.reference();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'TimeToTake',
      theme: AppTheme.light(refLayout, boldFonts: bold),
      darkTheme: AppTheme.dark(refLayout, boldFonts: bold),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (ctx, child) {
        final layout = AppScreenLayout.fromSize(MediaQuery.sizeOf(ctx));
        final useDark = Theme.of(ctx).brightness == Brightness.dark;
        return Theme(
          data: useDark ? AppTheme.dark(layout, boldFonts: bold) : AppTheme.light(layout, boldFonts: bold),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
