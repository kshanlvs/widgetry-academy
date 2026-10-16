import 'package:flutter/material.dart';

/// Brand colours, matching widgetryacademy.in.
abstract final class AppColors {
  static const Color green = Color(0xFF0F6B56);
  static const Color greenBright = Color(0xFF3FC79F);
  static const Color gold = Color(0xFFF2A900);
  static const Color deep = Color(0xFF0C2A23);
  static const Color deep2 = Color(0xFF123A30);
  static const Color ink = Color(0xFF0E1F1A);
  static const Color muted = Color(0xFF56695F);
  static const Color line = Color(0xFFD8E2DC);
  static const Color bg = Color(0xFFF3F6F4);
  static const Color soft = Color(0xFFE3EFE9);
  static const Color ok = Color(0xFF1F9D55);
  static const Color warn = Color(0xFFB26A00);
  static const Color bad = Color(0xFFC0392B);

  // Category accents (Flutter / Android / iOS)
  static const Color android = Color(0xFF1F8A4C);
  static const Color ios = Color(0xFF0A64C2);

  static Color category(String slug) => switch (slug) {
        'android' => android,
        'ios' => ios,
        _ => green,
      };
}
