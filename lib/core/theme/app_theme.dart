import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onPrimary,
          error: AppColors.error,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          surfaceContainerHighest: AppColors.surfaceVariant,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.heeboTextTheme(
          const TextTheme(
            displayLarge: TextStyle(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            displayMedium: TextStyle(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            titleLarge: TextStyle(color: AppColors.onBackground, fontWeight: FontWeight.w600),
            titleMedium: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w500),
            bodyLarge: TextStyle(color: AppColors.onSurface),
            bodyMedium: TextStyle(color: AppColors.onSurfaceVariant),
            labelLarge: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 2,
          shadowColor: AppColors.shadow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      );

  static ThemeData get darkTheme => lightTheme.copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryLight,
          onPrimary: AppColors.onBackground,
          secondary: AppColors.secondary,
          error: AppColors.error,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.onSurfaceDark,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
      );
}
