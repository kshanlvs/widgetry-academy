import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';

/// One theme for the whole app: the website's colours and fonts (DM Sans for text,
/// Unbounded for the brand and big headlines), quiet borders instead of shadows.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, Palette.light);
  static ThemeData dark() => _build(Brightness.dark, Palette.dark);

  /// Brand display font, used sparingly (wordmark, hero titles, big numbers).
  static TextStyle display({double size = 26, FontWeight weight = FontWeight.w700, Color? color, double height = 1.15}) =>
      GoogleFonts.unbounded(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: -0.4);

  static ThemeData _build(Brightness b, Palette p) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, brightness: b).copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: AppColors.gold,
      onSecondary: AppColors.goldInk,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      outline: p.line,
      outlineVariant: p.line,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.raised,
      surfaceContainer: p.raised,
      surfaceContainerHigh: p.soft,
      error: AppColors.bad,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, visualDensity: VisualDensity.standard);
    final text = _text(GoogleFonts.dmSansTextTheme(base.textTheme), p);
    final r = BorderRadius.circular(Radii.md);
    final buttonText = GoogleFonts.dmSans(fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: 0.1);

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.line,
      splashFactory: InkSparkle.splashFactory,
      extensions: [p],
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: Space.page,
        toolbarHeight: 60,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: p.line)),
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
        iconColor: p.muted,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: text.bodySmall?.copyWith(color: p.muted),
        minVerticalPadding: 12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: text.bodyMedium?.copyWith(color: p.faint),
        labelStyle: text.bodyMedium?.copyWith(color: p.muted),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: p.accent, fontWeight: FontWeight.w600),
        prefixIconColor: p.muted,
        suffixIconColor: p.muted,
        border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: p.line)),
        enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: p.line)),
        focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: p.accent, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: AppColors.bad)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: r, borderSide: const BorderSide(color: AppColors.bad, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: r),
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          foregroundColor: p.ink,
          side: BorderSide(color: p.line, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: r),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.accent, textStyle: buttonText.copyWith(fontSize: 14.5))),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.ink)),
      // Selected chips: brand green with light text (Material 3 ignores secondaryLabelStyle,
      // so the label colour must follow the selected state itself)
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return p.soft;
          return s.contains(WidgetState.selected) ? p.accent : p.surface;
        }),
        checkmarkColor: p.onAccent,
        labelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccent : p.ink),
        ),
        side: WidgetStateBorderSide.resolveWith((s) => BorderSide(color: s.contains(WidgetState.selected) ? p.accent : p.line)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm + 2)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        showCheckmark: true,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccent : p.faint),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.soft),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.line),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent, linearTrackColor: p.soft, circularTrackColor: p.soft),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: p.soft,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 23, color: s.contains(WidgetState.selected) ? p.accent : p.muted)),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall?.copyWith(fontSize: 11.5, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500, color: s.contains(WidgetState.selected) ? p.ink : p.muted),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        dragHandleColor: p.line,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
      ),
      dialogTheme: DialogThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl))),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? p.raised : AppColors.deep,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppColors.gold,
        shape: RoundedRectangleBorder(borderRadius: r),
        insetPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.deep,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        extendedTextStyle: buttonText,
      ),
      tooltipTheme: TooltipThemeData(decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(Radii.sm)), textStyle: text.bodySmall?.copyWith(color: Colors.white)),
    );
  }

  static TextTheme _text(TextTheme raw, Palette p) {
    final t = raw.apply(bodyColor: p.ink, displayColor: p.ink);
    return t.copyWith(
        headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15),
        headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.18),
        headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.22),
        titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3, fontSize: 21),
        titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1, fontSize: 16.5, height: 1.3),
        titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 14.5),
        bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.55),
        bodyMedium: t.bodyMedium?.copyWith(fontSize: 14.5, height: 1.5),
        bodySmall: t.bodySmall?.copyWith(fontSize: 12.5, height: 1.45, color: p.muted),
        labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: p.muted),
        labelSmall: t.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8, color: p.muted),
      );
  }
}
