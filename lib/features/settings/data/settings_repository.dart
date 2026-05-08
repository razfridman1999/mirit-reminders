import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';

class SettingsRepository {
  static const _kThemeMode = 'theme_mode';
  static const _kFontSize = 'font_size';
  static const _kDefaultSound = 'default_sound';
  static const _kDefaultSnooze = 'default_snooze';

  final SharedPreferences _prefs;
  SettingsRepository(this._prefs);

  AppSettings load() {
    final defaults = const AppSettings();
    return AppSettings(
      themeMode: _readEnum(
        _kThemeMode,
        AppThemeMode.values,
        defaults.themeMode,
      ),
      fontSize: _readEnum(
        _kFontSize,
        AppFontSize.values,
        defaults.fontSize,
      ),
      defaultSoundPath:
          _prefs.getString(_kDefaultSound) ?? defaults.defaultSoundPath,
      defaultSnoozeMinutes:
          _prefs.getInt(_kDefaultSnooze) ?? defaults.defaultSnoozeMinutes,
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setInt(_kThemeMode, s.themeMode.index);
    await _prefs.setInt(_kFontSize, s.fontSize.index);
    await _prefs.setString(_kDefaultSound, s.defaultSoundPath);
    await _prefs.setInt(_kDefaultSnooze, s.defaultSnoozeMinutes);
  }

  T _readEnum<T extends Enum>(String key, List<T> values, T fallback) {
    final raw = _prefs.getInt(key);
    if (raw == null || raw < 0 || raw >= values.length) return fallback;
    return values[raw];
  }
}
