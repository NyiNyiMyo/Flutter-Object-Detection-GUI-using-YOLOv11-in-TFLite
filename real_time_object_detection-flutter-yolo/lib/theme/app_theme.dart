import 'package:flutter/material.dart';

/// Central palette so every screen shares the same look.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF0A0E1A);
  static const Color bgAlt = Color(0xFF16123B);
  static const Color surface = Color(0xFF141B2E);
  static const Color surfaceHigh = Color(0xFF1D2745);

  static const Color violet = Color(0xFF7C5CFF);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color pink = Color(0xFFFF5CAA);
  static const Color mint = Color(0xFF2DE2A6);

  static const LinearGradient brand = LinearGradient(
    colors: [violet, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient header = LinearGradient(
    colors: [Color(0xFF4B2FD6), Color(0xFF0E7490)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient background = LinearGradient(
    colors: [bg, bgAlt],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.violet,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.violet,
    onPrimary: Colors.white,
    secondary: AppColors.cyan,
    onSecondary: const Color(0xFF00222B),
    tertiary: AppColors.pink,
    surface: AppColors.surface,
    onSurface: const Color(0xFFE9ECFF),
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    error: const Color(0xFFFF6B8A),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.violet.withValues(alpha: 0.35),
      height: 68,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.cyan
              : Colors.white70,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.violet,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.cyan,
        side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.7)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.pink,
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.violet.withValues(alpha: 0.45),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      shape: const StadiumBorder(),
      checkmarkColor: AppColors.cyan,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
