import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/core/database/app_database.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  AppDatabase? _database;

  void setDatabase(AppDatabase db) => _database = db;

  static const _channelId = 'mirit_reminders_channel';
  static const _channelName = AppStrings.reminders;
  static const _channelDescription = 'התראות יומן תזכורות';

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      windows: WindowsInitializationSettings(
        appName: AppStrings.appName,
        appUserModelId: 'com.mirit.reminders',
        guid: 'd50a86db-4e1b-4c5b-bcfe-8c99db2dd9db',
      ),
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialized = true;
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

    int? snoozeMinutes;
    if (actionId == 'snooze_5') snoozeMinutes = 5;
    if (actionId == 'snooze_10') snoozeMinutes = 10;
    if (actionId == 'snooze_15') snoozeMinutes = 15;
    if (snoozeMinutes == null) return;

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
    if (scheduledTz.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id: reminder.id!,
      title: AppStrings.appName,
      body: reminder.title,
      scheduledDate: scheduledTz,
      notificationDetails: _buildDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: reminder.id.toString(),
    );
  }

  Future<void> cancelReminder(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> showNow({
    required int id,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id: id,
      title: AppStrings.appName,
      body: body,
      notificationDetails: _buildDetails(),
      payload: payload,
    );
  }

  Future<void> snooze(Reminder reminder, int minutes) async {
    if (reminder.id == null) return;
    await cancelReminder(reminder.id!);
    await scheduleReminder(reminder.copyWith(
      scheduledAt: DateTime.now().add(Duration(minutes: minutes)),
    ));
  }

  NotificationDetails _buildDetails() {
    if (Platform.isAndroid) {
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('snooze_5', 'נודניק 5 דק׳'),
            AndroidNotificationAction('snooze_10', 'נודניק 10 דק׳'),
            AndroidNotificationAction('snooze_15', 'נודניק 15 דק׳'),
            AndroidNotificationAction('dismiss', AppStrings.dismiss),
          ],
        ),
      );
    }
    // Windows
    return const NotificationDetails(
      windows: WindowsNotificationDetails(
        actions: [
          WindowsAction(content: 'נודניק 5 דק׳', arguments: 'snooze_5'),
          WindowsAction(content: 'נודניק 10 דק׳', arguments: 'snooze_10'),
          WindowsAction(content: 'נודניק 15 דק׳', arguments: 'snooze_15'),
          WindowsAction(content: AppStrings.dismiss, arguments: 'dismiss'),
        ],
      ),
    );
  }
}
