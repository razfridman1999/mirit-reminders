import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/settings_repository.dart';
import '../../domain/app_settings.dart';

/// Overridden in main.dart with the real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main.dart',
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;
  SettingsNotifier(this._repo) : super(_repo.load());

  Future<void> setThemeMode(AppThemeMode mode) =>
      _updateAndSave(state.copyWith(themeMode: mode));

  Future<void> setFontSize(AppFontSize size) =>
      _updateAndSave(state.copyWith(fontSize: size));

  Future<void> setDefaultSoundPath(String path) =>
      _updateAndSave(state.copyWith(defaultSoundPath: path));

  Future<void> setDefaultSnoozeMinutes(int minutes) =>
      _updateAndSave(state.copyWith(defaultSnoozeMinutes: minutes));

  /// Optimistically updates state, then persists. If persistence throws
  /// (e.g. disk full, prefs corruption), the previous state is restored
  /// and the error is rethrown so the caller can surface it to the user.
  Future<void> _updateAndSave(AppSettings next) async {
    final previous = state;
    state = next;
    try {
      await _repo.save(next);
    } catch (e) {
      // Revert so the UI doesn't drift away from what's actually persisted.
      state = previous;
      rethrow;
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsRepositoryProvider));
});
