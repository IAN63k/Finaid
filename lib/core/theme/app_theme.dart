import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF0E7C6B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  /// Colores semánticos para montos.
  static Color expense(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color income(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF66D9B8)
          : const Color(0xFF0E7C6B);
  static Color warning(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFFB74D)
          : const Color(0xFFEF6C00);
}
