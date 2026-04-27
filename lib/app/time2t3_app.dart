import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/profile/ui_preferences_controller.dart';
import 'theme/app_theme.dart';

class Time2T3App extends StatelessWidget {
  const Time2T3App({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final bold = context.watch<UiPreferencesController>().boldFonts;
    return MaterialApp.router(
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'Время принять таблетки',
      theme: AppTheme.light(boldFonts: bold),
      darkTheme: AppTheme.dark(boldFonts: bold),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
