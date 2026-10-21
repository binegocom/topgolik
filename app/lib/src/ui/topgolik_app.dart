import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';
import 'design/topgolik_ui.dart';
import 'home_screen.dart';

class TopgolikApp extends StatelessWidget {
  const TopgolikApp({super.key});
  static const background = StadiumColors.background;
  static const panel = StadiumColors.surface;
  static const accent = StadiumColors.green;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Topgolik',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: StadiumColors.background,
        surface: panel,
        onSurface: Colors.white,
        error: StadiumColors.red,
      ),
      cardColor: panel,
      dividerColor: StadiumColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 21, color: Colors.white, fontWeight: FontWeight.w800),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: Color(0xFF123928),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StadiumColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StadiumColors.border)),
      ),
    ),
    supportedLocales: const [Locale('de'), Locale('fr'), Locale('it'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    localeResolutionCallback: (locale, supported) {
      if (locale != null && supported.any((item) => item.languageCode == locale.languageCode)) {
        return Locale(locale.languageCode);
      }
      return const Locale('en');
    },
    home: const HomeScreen(),
  );
}
