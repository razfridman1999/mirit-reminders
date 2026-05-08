import 'package:flutter/material.dart';

enum AppThemeMode { system, light, dark }

enum AppFontSize { regular, large, xLarge }

class AppSettings {
  final AppThemeMode themeMode;
  final AppFontSize fontSize;
  final String defaultSoundPath;
  final int defaultSnoozeMinutes;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.fontSize = AppFontSize.regular,
    this.defaultSoundPath = 'sounds/ping_simple.wav',
    this.defaultSnoozeMinutes = 10,
  });

  double get textScale {
    switch (fontSize) {
      case AppFontSize.regular:
        return 1.0;
      case AppFontSize.large:
        return 1.25;
      case AppFontSize.xLarge:
        return 1.5;
    }
  }

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AppFontSize? fontSize,
    String? defaultSoundPath,
    int? defaultSnoozeMinutes,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      defaultSoundPath: defaultSoundPath ?? this.defaultSoundPath,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
    );
  }
}
