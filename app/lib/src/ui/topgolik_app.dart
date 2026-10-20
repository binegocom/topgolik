import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import 'home_screen.dart';

class TopgolikApp extends StatelessWidget {
  const TopgolikApp({super.key});
  static const background = Color(0xFF07121C);
  static const panel = Color(0xFF102131);
  static const accent = Color(0xFF24E77A);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Topgolik',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: background,
          colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark, surface: background, primary: accent),
          cardColor: panel,
          appBarTheme: const AppBarTheme(backgroundColor: background, scrolledUnderElevation: 0),
          navigationBarTheme: const NavigationBarThemeData(backgroundColor: panel, indicatorColor: Color(0xFF174B35)),
        ),
        supportedLocales: const [Locale('de'), Locale('fr'), Locale('it'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        localeResolutionCallback: (locale, supported) {
          if (locale != null && supported.any((s) => s.languageCode == locale.languageCode)) {
            return Locale(locale.languageCode);
          }
          return const Locale('en');
        },
        home: const HomeScreen(),
      );
}
