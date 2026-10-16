import 'package:flutter/material.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: b,
      primary: dark ? AppColors.greenBright : AppColors.green,
      secondary: AppColors.gold,
      surface: dark ? const Color(0xFF10201B) : Colors.white,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
    final radius = BorderRadius.circular(14);
    return base.copyWith(
      scaffoldBackgroundColor: dark ? const Color(0xFF0A1512) : AppColors.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF0A1512) : AppColors.bg,
        foregroundColor: dark ? Colors.white : AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: dark ? Colors.white : AppColors.ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: dark ? const Color(0xFF1F3A31) : AppColors.line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF12302A) : const Color(0xFFF7FAF8),
        border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.line)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: dark ? const Color(0xFF1F3A31) : AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: radius), textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: radius), textStyle: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      chipTheme: base.chipTheme.copyWith(shape: const StadiumBorder(), side: BorderSide(color: dark ? const Color(0xFF1F3A31) : AppColors.line)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
