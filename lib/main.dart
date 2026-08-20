import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app_controller.dart';
import 'data/app_database.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/cycle_notification_service.dart';

/// The app is day-first everywhere: dates read and type as DD/MM/YYYY.
const appLocale = Locale('en', 'GB');
const appLocaleName = 'en_GB';

/// Loads the day-first date symbols and makes them the default for [DateFormat].
///
/// Called from [main] and from tests that assert formatted dates.
Future<void> initializeAppLocale() async {
  Intl.defaultLocale = appLocaleName;
  await initializeDateFormatting(appLocaleName);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAppLocale();
  final database = await AppDatabase.open();
  final notificationService = CycleNotificationService();
  await notificationService.initialize();
  final controller = AppController(
    database,
    notificationService: notificationService,
  );
  await controller.load();
  runApp(CycleCompassApp(controller: controller));
}

class CycleCompassApp extends StatelessWidget {
  const CycleCompassApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    // The builder wraps MaterialApp so a saved theme preference takes effect
    // as soon as it changes, not only inside the screens.
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        title: 'Cycle Compass',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: controller.themeMode,
        locale: appLocale,
        supportedLocales: const [appLocale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: controller.isOnboarded
              ? HomeShell(key: const ValueKey('home'), controller: controller)
              : OnboardingScreen(
                  key: const ValueKey('onboarding'),
                  controller: controller,
                ),
        ),
      ),
    );
  }
}

ThemeData _theme(Brightness brightness) {
  const seed = Color(0xFFB73D68);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    surface: brightness == Brightness.light ? const Color(0xFFFFFBFC) : null,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(height: 1.08),
      headlineSmall: TextStyle(height: 1.12),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
