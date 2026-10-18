import 'package:flutter/material.dart';

/// Brand colours, matching widgetryacademy.in. Screens read colours from [Palette.of]
/// so light and dark mode stay consistent; these constants are the raw brand values.
abstract final class AppColors {
  static const Color green = Color(0xFF0F6B56);
  static const Color greenBright = Color(0xFF3FC79F);
  static const Color gold = Color(0xFFF2A900);
  static const Color goldInk = Color(0xFF1D1400);
  static const Color deep = Color(0xFF0C2A23);
  static const Color deep2 = Color(0xFF123A30);
  static const Color deepMuted = Color(0xFFA8C2B6);
  static const Color ink = Color(0xFF0E1F1A);
  static const Color muted = Color(0xFF5B6B63);
  static const Color line = Color(0xFFE2E8E4);
  static const Color bg = Color(0xFFF6F8F7);
  static const Color soft = Color(0xFFE8F1EC);
  static const Color ok = Color(0xFF1F8A55);
  static const Color warn = Color(0xFFA35F00);
  static const Color bad = Color(0xFFB3261E);
  static const Color whatsapp = Color(0xFF1FA855);

  // Category accents (Flutter / Android / iOS / React Native)
  static const Color flutter = Color(0xFF0F6B56);
  static const Color android = Color(0xFF2E7D4F);
  static const Color ios = Color(0xFF1C5FB8);
  static const Color reactNative = Color(0xFF066A8A);

  static Color category(String slug) => switch (slug) {
        'android' => android,
        'ios' => ios,
        'react-native' => reactNative,
        _ => flutter,
      };
}

/// Colours that change between light and dark mode. Read with `Palette.of(context)`.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.soft,
    required this.accent,
    required this.onAccent,
    required this.hero,
    required this.onHero,
    required this.onHeroMuted,
  });

  final Color bg;
  final Color surface;
  final Color raised;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color line;
  final Color soft;
  final Color accent;
  final Color onAccent;
  final Color hero;
  final Color onHero;
  final Color onHeroMuted;

  static const light = Palette(
    bg: AppColors.bg,
    surface: Colors.white,
    raised: Color(0xFFFBFCFB),
    ink: AppColors.ink,
    muted: AppColors.muted,
    faint: Color(0xFF8A9891),
    line: AppColors.line,
    soft: AppColors.soft,
    accent: AppColors.green,
    onAccent: Colors.white,
    hero: AppColors.deep,
    onHero: Colors.white,
    onHeroMuted: AppColors.deepMuted,
  );

  static const dark = Palette(
    bg: Color(0xFF0A1411),
    surface: Color(0xFF111D19),
    raised: Color(0xFF152420),
    ink: Color(0xFFE9F0EC),
    muted: Color(0xFF9DB0A7),
    faint: Color(0xFF6E8279),
    line: Color(0xFF1F2F29),
    soft: Color(0xFF17302A),
    accent: AppColors.greenBright,
    onAccent: Color(0xFF04211A),
    hero: Color(0xFF0F2C25),
    onHero: Colors.white,
    onHeroMuted: AppColors.deepMuted,
  );

  static Palette of(BuildContext context) => Theme.of(context).extension<Palette>() ?? light;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      line: l(line, other.line),
      soft: l(soft, other.soft),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      hero: l(hero, other.hero),
      onHero: l(onHero, other.onHero),
      onHeroMuted: l(onHeroMuted, other.onHeroMuted),
    );
  }
}

/// Spacing scale (4-point grid) and corner radii, so every screen lines up.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Side padding of every screen.
  static const double page = 20;
}

abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
}
