import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2E6DA4);
  static const Color primaryLight = Color(0xFF5B9BD5);
  static const Color primaryDark = Color(0xFF1A4F7A);

  static const Color secondary = Color(0xFF26A69A);
  static const Color secondaryLight = Color(0xFF64D8CB);
  static const Color secondaryDark = Color(0xFF00766C);

  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF2F7);

  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF1C2B3A);
  static const Color onSurface = Color(0xFF2C3E50);
  static const Color onSurfaceVariant = Color(0xFF546E7A);

  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFEF6C00);

  static const Color divider = Color(0xFFCFD8DC);
  static const Color shadow = Color(0x1A000000);

  // Category colors (no yellow)
  static const List<Color> categoryColors = [
    Color(0xFF2E6DA4), // כחול
    Color(0xFF26A69A), // טיל
    Color(0xFF43A047), // ירוק
    Color(0xFFEF6C00), // כתום
    Color(0xFFE53935), // אדום
    Color(0xFF8E24AA), // סגול
    Color(0xFF00838F), // ציאן
    Color(0xFF546E7A), // אפור-כחול
  ];

  // Dark theme
  static const Color backgroundDark = Color(0xFF121F2B);
  static const Color surfaceDark = Color(0xFF1E2F3F);
  static const Color surfaceVariantDark = Color(0xFF263545);
  static const Color onBackgroundDark = Color(0xFFE8EFF5);
  static const Color onSurfaceDark = Color(0xFFCDD5DC);
  static const Color onSurfaceVariantDark = Color(0xFF94A3B0);
  static const Color dividerDark = Color(0xFF2C3E50);
  static const Color shadowDark = Color(0x40000000);
}
