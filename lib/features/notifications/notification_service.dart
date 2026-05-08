import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/core/database/app_database.dart';
import 'package:mirit_reminders/core/platform/system_settings.dart';
import 'package:mirit_reminders/features/audio/built_in_sounds.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Top-level background handler. Runs in a separate isolate when the app is
/// killed and a notification action button is tapped on Android. Must reopen
/// AppDatabase and SharedPreferences itself.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  final actionId = response.actionId;
  final payload = response.payload;
  if (payload == null) return;
  final reminderId = int.tryParse(payload);
  if (reminderId == null) return;

  // Reopen DB (drift_flutter uses a file path so this is safe).
  final db = AppDatabase();

  try {
    if (actionId == 'dismiss') {
      // Cancel any pending OS notification with this id.
      await FlutterLocalNotificationsPlugin().cancel(id: reminderId);
      return;
    }

    if (actionId == 'done') {
      // Mark completed in the DB and cancel any pending OS notification.
      // Singleton state doesn't survive isolate boundaries, so use the plugin
      // directly here.
      await (db.update(db.remindersTable)
            ..where((t) => t.id.equals(reminderId)))
          .write(RemindersTableCompanion(
        completedAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ));
      await FlutterLocalNotificationsPlugin().cancel(id: reminderId);
      return;
    }

    if (actionId != 'snooze') return;

    final prefs = await SharedPreferences.getInstance();
    final snoozeMinutes = prefs.getInt('default_snooze') ?? 10;

    final query = db.select(db.remindersTable)
      ..where((t) => t.id.equals(reminderId));
    final row = await query.getSingleOrNull();
    if (row == null) return;

    final newScheduled =
        DateTime.now().add(Duration(minutes: snoozeMinutes));

    // Persist new scheduledAt.
    await (db.update(db.remindersTable)..where((t) => t.id.equals(reminderId)))
        .write(RemindersTableCompanion(
      scheduledAt: drift.Value(newScheduled),
      updatedAt: drift.Value(DateTime.now()),
    ));

    // Reschedule. We can't easily reuse NotificationService here because the
    // singleton state is per-isolate; use the plugin directly.
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(id: reminderId);

    // Determine channel id from soundPath.
    final soundPath = row.soundPath;
    final channelId = _channelIdForSoundStatic(soundPath);

    final tzData = await FlutterTimezone.getLocalTimezone();
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(tzData));
    final scheduledTz = tz.TZDateTime.from(newScheduled, tz.local);

    final snoozeLabel = 'נודניק $snoozeMinutes דק׳';

    await plugin.zonedSchedule(
      id: reminderId,
      title: AppStrings.appName,
      body: row.title,
      scheduledDate: scheduledTz,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          AppStrings.reminders,
          channelDescription: 'התראות יומן תזכורות',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_notification',
          playSound: true,
          enableVibration: true,
          groupKey: NotificationService._androidGroupKey,
          actions: [
            AndroidNotificationAction('snooze', snoozeLabel),
            const AndroidNotificationAction('done', 'בוצע'),
            const AndroidNotificationAction('dismiss', AppStrings.dismiss),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: reminderId.toString(),
    );
  } finally {
    await db.close();
  }
}

/// Returns the channel id for a given sound path.
/// `sounds/ping_simple.wav` -> `mirit_ping_simple`
/// custom file or null -> default channel
String _channelIdForSoundStatic(String? soundPath) {
  if (soundPath == null || soundPath.isEmpty) {
    return NotificationService.defaultChannelId;
  }
  if (soundPath.startsWith('sounds/')) {
    final raw = soundPath
        .substring('sounds/'.length)
        .replaceAll('.wav', '')
        .replaceAll('.mp3', '');
    final sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'mirit_$sanitized';
  }
  // custom file → default channel (silent OS notification, in-app player handles audio)
  return NotificationService.defaultChannelId;
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  AppDatabase? _database;
  int Function() _snoozeMinutesProvider = () => 10;

  void setDatabase(AppDatabase db) => _database = db;
  void setSnoozeProvider(int Function() provider) =>
      _snoozeMinutesProvider = provider;

  static const String defaultChannelId = 'mirit_reminders_channel';
  static const String _channelName = AppStrings.reminders;
  static const String _channelDescription = 'התראות יומן תזכורות';

  /// Fast, safe init that must succeed for the app to run. Sets up timezone
  /// (with fallback) and registers the plugin. Permissions and channel
  /// creation are deferred to [initializeDeferred] so a failure there cannot
  /// block the first frame.
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    await _setLocalTimezoneSafe();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      windows: WindowsInitializationSettings(
        appName: AppStrings.appName,
        appUserModelId: 'com.mirit.reminders',
        guid: 'd50a86db-4e1b-4c5b-bcfe-8c99db2dd9db',
      ),
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
    } catch (e, st) {
      debugPrint('[Notifications] plugin.initialize failed: $e\n$st');
    }

    _initialized = true;
    debugPrint('[Notifications] core initialized');
  }

  /// Permissions + channel creation. Safe to call after the first frame is
  /// rendered. Failures are logged, never thrown.
  Future<void> initializeDeferred() async {
    try {
      await _requestPermissions();
    } catch (e, st) {
      debugPrint('[Notifications] _requestPermissions failed: $e\n$st');
    }
    try {
      await _createAndroidChannels();
    } catch (e, st) {
      debugPrint('[Notifications] _createAndroidChannels failed: $e\n$st');
    }
    try {
      await _maybePromptBatteryExemptionOnFirstLaunch();
    } catch (e, st) {
      debugPrint('[Notifications] battery prompt failed: $e\n$st');
    }
    debugPrint('[Notifications] deferred init done');
  }

  /// Launches the system battery-exemption dialog the FIRST time the app
  /// runs after install. This is the single biggest reason scheduled
  /// notifications don't fire on Samsung devices.
  Future<void> _maybePromptBatteryExemptionOnFirstLaunch() async {
    if (!Platform.isAndroid) return;
    const key = 'battery_exemption_prompted_v1';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) == true) return;
    final already = await SystemSettings.isIgnoringBatteryOptimizations();
    if (already) {
      await prefs.setBool(key, true);
      return;
    }
    debugPrint('[Notifications] launching battery exemption dialog');
    await SystemSettings.requestIgnoreBatteryOptimizations();
    await prefs.setBool(key, true);
  }

  Future<void> _setLocalTimezoneSafe() async {
    String name;
    try {
      name = await FlutterTimezone.getLocalTimezone();
    } catch (e) {
      debugPrint('[Notifications] getLocalTimezone failed: $e — using Asia/Jerusalem');
      name = 'Asia/Jerusalem';
    }
    try {
      tz.setLocalLocation(tz.getLocation(name));
      debugPrint(
          '[Notifications] timezone=$name now=${tz.TZDateTime.now(tz.local)}');
      return;
    } catch (e) {
      debugPrint(
          '[Notifications] tz.getLocation($name) failed: $e — trying Asia/Jerusalem');
    }
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jerusalem'));
      debugPrint('[Notifications] timezone=Asia/Jerusalem (fallback)');
      return;
    } catch (e) {
      debugPrint('[Notifications] Asia/Jerusalem unavailable: $e — using UTC');
    }
    tz.setLocalLocation(tz.UTC);
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      final notif = await android.requestNotificationsPermission();
      final exact = await android.requestExactAlarmsPermission();
      debugPrint(
          '[Notifications] android perms: notifications=$notif exact=$exact');
    }
  }

  /// Pre-create one Android channel per built-in sound, plus one default
  /// channel. Once a channel is created with a specific sound, that sound
  /// can never change — so picking the right channel at notification time
  /// is how we "select" the sound on Android.
  Future<void> _createAndroidChannels() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // Default channel (used for null/custom sounds — no built-in sound).
    await android.createNotificationChannel(const AndroidNotificationChannel(
      defaultChannelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: false,
      enableVibration: true,
    ));

    // One channel per built-in sound.
    for (final s in builtInSounds) {
      final raw = s.asset
          .substring('sounds/'.length)
          .replaceAll('.wav', '')
          .replaceAll('.mp3', '');
      final sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final channelId = 'mirit_$sanitized';
      await android.createNotificationChannel(AndroidNotificationChannel(
        channelId,
        '${AppStrings.reminders} - ${s.name}',
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sanitized),
        enableVibration: true,
      ));
    }
    debugPrint(
        '[Notifications] created ${builtInSounds.length + 1} android channels');
  }

  static void _onNotificationResponse(NotificationResponse response) async {
    final actionId = response.actionId;
    final payload = response.payload;
    if (payload == null) return;
    final reminderId = int.tryParse(payload);
    if (reminderId == null) return;

    final db = NotificationService.instance._database;
    if (db == null) return;

    if (actionId == 'dismiss') {
      await NotificationService.instance.cancelReminder(reminderId);
      return;
    }

    if (actionId == 'done') {
      // Mark completed and stop further OS-side firing for this id. Recurring
      // reminders will reschedule on their next occurrence elsewhere.
      await (db.update(db.remindersTable)
            ..where((t) => t.id.equals(reminderId)))
          .write(RemindersTableCompanion(
        completedAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ));
      await NotificationService.instance.cancelReminder(reminderId);
      return;
    }

    if (actionId != 'snooze') return;
    final snoozeMinutes = NotificationService.instance._snoozeMinutesProvider();

    final query = db.select(db.remindersTable)
      ..where((t) => t.id.equals(reminderId));
    final row = await query.getSingleOrNull();
    if (row == null) return;

    final reminder = Reminder(
      id: row.id,
      title: row.title,
      description: row.description,
      scheduledAt: row.scheduledAt,
      recurrenceType: row.recurrenceType,
      categoryId: row.categoryId,
      soundPath: row.soundPath,
      isActive: row.isActive,
    );

    await NotificationService.instance.snooze(reminder, snoozeMinutes);
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    if (reminder.id == null) return;

    final scheduledTz = tz.TZDateTime.from(reminder.scheduledAt, tz.local);
    final nowTz = tz.TZDateTime.now(tz.local);
    if (scheduledTz.isBefore(nowTz)) {
      debugPrint(
          '[Notifications] skip schedule id=${reminder.id} (in past: $scheduledTz < $nowTz)');
      return;
    }

    // Pick the strongest schedule mode the OS will actually accept. On
    // Android 12+ exact alarms require SCHEDULE_EXACT_ALARM; if denied,
    // exactAllowWhileIdle silently throws PlatformException, so we fall
    // back to inexactAllowWhileIdle (still wakes the device, may be late
    // by up to ~10 minutes).
    var mode = AndroidScheduleMode.exactAllowWhileIdle;
    if (Platform.isAndroid) {
      try {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final canExact = await android?.canScheduleExactNotifications();
        if (canExact == false) {
          mode = AndroidScheduleMode.inexactAllowWhileIdle;
          debugPrint(
              '[Notifications] exact alarms denied — using inexactAllowWhileIdle');
        }
      } catch (e) {
        debugPrint('[Notifications] canScheduleExact check failed: $e');
      }
    }

    try {
      await _plugin.zonedSchedule(
        id: reminder.id!,
        title: AppStrings.appName,
        body: reminder.title,
        scheduledDate: scheduledTz,
        notificationDetails: _buildDetails(reminder.soundPath),
        androidScheduleMode: mode,
        payload: reminder.id.toString(),
      );
      debugPrint(
          '[Notifications] scheduled id=${reminder.id} at=$scheduledTz mode=$mode title="${reminder.title}"');
    } on PlatformException catch (e) {
      // Last-resort fallback: if exact mode fired despite the check passing
      // (some Samsung OEMs revoke the permission silently), retry inexact.
      if (mode == AndroidScheduleMode.exactAllowWhileIdle &&
          (e.code.contains('exact_alarms') ||
              e.message?.toLowerCase().contains('exact') == true)) {
        debugPrint(
            '[Notifications] exact alarm rejected at fire time, retrying inexact: ${e.code}');
        try {
          await _plugin.zonedSchedule(
            id: reminder.id!,
            title: AppStrings.appName,
            body: reminder.title,
            scheduledDate: scheduledTz,
            notificationDetails: _buildDetails(reminder.soundPath),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: reminder.id.toString(),
          );
          return;
        } catch (e2, st2) {
          debugPrint(
              '[Notifications] inexact retry also failed id=${reminder.id}: $e2\n$st2');
        }
      }
      debugPrint(
          '[Notifications] FAILED to schedule id=${reminder.id}: ${e.code} ${e.message}');
    } catch (e, st) {
      debugPrint(
          '[Notifications] FAILED to schedule id=${reminder.id}: $e\n$st');
    }
  }

  Future<void> cancelReminder(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<ShowNowResult> showNow({
    required int id,
    required String body,
    String? soundPath,
    String? payload,
  }) async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) {
        debugPrint('[Notifications] showNow: android plugin null');
        return ShowNowResult.error('android plugin null');
      }
      final enabled = await android.areNotificationsEnabled();
      if (enabled == false) {
        debugPrint('[Notifications] showNow: notifications disabled');
        return ShowNowResult.permissionDenied;
      }
      // Ensure the target channel exists (idempotent on Android).
      try {
        await _ensureChannelExists(android, soundPath);
      } catch (e, st) {
        debugPrint('[Notifications] ensureChannel failed: $e\n$st');
        return ShowNowResult.error('channel: $e');
      }
    }
    try {
      await _plugin.show(
        id: id,
        title: AppStrings.appName,
        body: body,
        notificationDetails: _buildDetails(soundPath),
        payload: payload,
      );
      debugPrint('[Notifications] showNow id=$id body="$body" sound=$soundPath');
      return ShowNowResult.success;
    } catch (e, st) {
      debugPrint('[Notifications] FAILED to showNow id=$id: $e\n$st');
      return ShowNowResult.error(e.toString());
    }
  }

  Future<void> _ensureChannelExists(
    AndroidFlutterLocalNotificationsPlugin android,
    String? soundPath,
  ) async {
    final channelId = _channelIdForSound(soundPath);
    if (channelId == defaultChannelId) {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        defaultChannelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
      ));
      return;
    }
    // Per-built-in-sound channel.
    final raw = soundPath!
        .substring('sounds/'.length)
        .replaceAll('.wav', '')
        .replaceAll('.mp3', '');
    final sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    await android.createNotificationChannel(AndroidNotificationChannel(
      channelId,
      '${AppStrings.reminders} - $sanitized',
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(sanitized),
      enableVibration: true,
    ));
  }

  /// Returns a snapshot of notification-related state for the diagnostic UI.
  Future<NotificationDiagnostics> getDiagnostics() async {
    if (!Platform.isAndroid) {
      return NotificationDiagnostics(
        platform: Platform.operatingSystem,
        notificationsEnabled: null,
        canScheduleExactAlarms: null,
        channelCount: 0,
        ignoringBatteryOptimizations: null,
      );
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return const NotificationDiagnostics(
        platform: 'android',
        notificationsEnabled: null,
        canScheduleExactAlarms: null,
        channelCount: 0,
        ignoringBatteryOptimizations: null,
        error: 'android plugin not resolved',
      );
    }
    bool? enabled;
    bool? canExact;
    int channelCount = 0;
    String? err;
    try {
      enabled = await android.areNotificationsEnabled();
    } catch (e) {
      err = 'areNotificationsEnabled: $e';
    }
    try {
      canExact = await android.canScheduleExactNotifications();
    } catch (e) {
      err = '${err == null ? '' : '$err\n'}canScheduleExact: $e';
    }
    try {
      final channels = await android.getNotificationChannels();
      channelCount = channels?.length ?? 0;
    } catch (e) {
      err = '${err == null ? '' : '$err\n'}getChannels: $e';
    }
    final ignoringBattery =
        await SystemSettings.isIgnoringBatteryOptimizations();
    return NotificationDiagnostics(
      platform: 'android',
      notificationsEnabled: enabled,
      canScheduleExactAlarms: canExact,
      channelCount: channelCount,
      ignoringBatteryOptimizations: ignoringBattery,
      error: err,
    );
  }

  /// User-triggered re-request for both permissions. Returns the latest state.
  Future<NotificationDiagnostics> requestPermissionsInteractive() async {
    try {
      await _requestPermissions();
    } catch (e) {
      debugPrint('[Notifications] interactive perm request failed: $e');
    }
    try {
      await _createAndroidChannels();
    } catch (e) {
      debugPrint('[Notifications] interactive channel create failed: $e');
    }
    return getDiagnostics();
  }

  /// Snooze: cancels the existing OS notification, persists the new
  /// scheduledAt to the DB, and reschedules. Persisting is critical so that
  /// if the user dismisses the snooze notification or restarts the app,
  /// the reminder still fires at the snoozed time (not the original).
  Future<void> snooze(Reminder reminder, int minutes) async {
    if (reminder.id == null) return;
    await cancelReminder(reminder.id!);

    final newScheduled = DateTime.now().add(Duration(minutes: minutes));

    final db = _database;
    if (db != null) {
      await (db.update(db.remindersTable)
            ..where((t) => t.id.equals(reminder.id!)))
          .write(RemindersTableCompanion(
        scheduledAt: drift.Value(newScheduled),
        updatedAt: drift.Value(DateTime.now()),
      ));
    }

    await scheduleReminder(reminder.copyWith(scheduledAt: newScheduled));
  }

  /// Returns the Android channel id to use for a given soundPath.
  String _channelIdForSound(String? soundPath) =>
      _channelIdForSoundStatic(soundPath);

  /// Stable group key so multiple reminders fire as one collapsible
  /// notification group on Android instead of N separate banners.
  static const String _androidGroupKey = 'mirit_reminders_group';

  NotificationDetails _buildDetails(String? soundPath) {
    final snoozeMin = _snoozeMinutesProvider();
    final snoozeLabel = 'נודניק $snoozeMin דק׳';
    if (Platform.isAndroid) {
      final channelId = _channelIdForSound(soundPath);
      return NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_notification',
          playSound: true,
          enableVibration: true,
          groupKey: _androidGroupKey,
          actions: [
            AndroidNotificationAction('snooze', snoozeLabel),
            const AndroidNotificationAction('done', 'בוצע'),
            const AndroidNotificationAction('dismiss', AppStrings.dismiss),
          ],
        ),
      );
    }
    // Windows
    return NotificationDetails(
      windows: WindowsNotificationDetails(
        actions: [
          WindowsAction(content: snoozeLabel, arguments: 'snooze'),
          const WindowsAction(content: AppStrings.dismiss, arguments: 'dismiss'),
        ],
      ),
    );
  }
}

class ShowNowResult {
  const ShowNowResult._(this.kind, [this.message]);
  static const success = ShowNowResult._('success');
  static const permissionDenied = ShowNowResult._('permissionDenied');
  factory ShowNowResult.error(String message) =>
      ShowNowResult._('error', message);

  final String kind;
  final String? message;

  bool get isSuccess => kind == 'success';
}

class NotificationDiagnostics {
  const NotificationDiagnostics({
    required this.platform,
    required this.notificationsEnabled,
    required this.canScheduleExactAlarms,
    required this.channelCount,
    required this.ignoringBatteryOptimizations,
    this.error,
  });

  final String platform;
  final bool? notificationsEnabled;
  final bool? canScheduleExactAlarms;
  final int channelCount;
  final bool? ignoringBatteryOptimizations;
  final String? error;
}
