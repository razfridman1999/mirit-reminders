import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:mirit_reminders/core/database/app_database.dart';
import 'package:mirit_reminders/core/database/tables/reminders_table.dart';
import 'package:mirit_reminders/core/utils/recurrence.dart';
import 'package:mirit_reminders/features/audio/audio_service.dart';
import 'package:mirit_reminders/features/audio/built_in_sounds.dart';
import 'package:mirit_reminders/features/notifications/notification_service.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';

/// Polls the database every [interval] and fires any active reminder whose
/// scheduledAt has passed since the previous tick. This is the reliable
/// foreground delivery path — it does not depend on flutter_local_notifications
/// being able to wake the OS at the exact second (which is unreliable on
/// Windows in dev/debug builds and on Android when battery-optimised).
class ReminderPoller {
  ReminderPoller._();
  static final ReminderPoller instance = ReminderPoller._();

  static const Duration interval = Duration(seconds: 30);

  /// Reminders older than this are considered "stale" — skipped to avoid a
  /// burst when the device clock jumps forward by hours/days.
  static const Duration staleThreshold = Duration(minutes: 5);

  Timer? _timer;
  AppDatabase? _db;
  DateTime _lastCheck = DateTime.now();
  final Set<int> _firedThisSession = <int>{};

  void start(AppDatabase db) {
    if (_timer != null) return;
    _db = db;
    _lastCheck = DateTime.now();
    debugPrint(
        '[Poller] start at $_lastCheck (interval=${interval.inSeconds}s)');
    // Catch up any recurring reminders whose scheduledAt is in the past,
    // before starting the periodic loop. Don't await — let it run in the
    // background; the periodic timer will still pick up new entries.
    catchUpStaleRecurring(db);
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Find recurring reminders whose scheduledAt is in the past, advance them
  /// to the next future occurrence, persist, and re-schedule. Called once at
  /// app start so missed recurring reminders don't pile up.
  Future<void> catchUpStaleRecurring(AppDatabase db) async {
    final now = DateTime.now();
    final query = db.select(db.remindersTable)
      ..where(
        (t) =>
            t.isActive.equals(true) &
            t.scheduledAt.isSmallerThanValue(now) &
            // Mirrors the _tick filter for safety; recurring rows always pass.
            (t.completedAt.isNull() |
                t.recurrenceType.equalsValue(RecurrenceType.daily) |
                t.recurrenceType.equalsValue(RecurrenceType.monthly) |
                t.recurrenceType.equalsValue(RecurrenceType.yearly)) &
            (t.recurrenceType.equalsValue(RecurrenceType.daily) |
                t.recurrenceType.equalsValue(RecurrenceType.monthly) |
                t.recurrenceType.equalsValue(RecurrenceType.yearly)),
      );

    final stale = await query.get();
    if (stale.isEmpty) return;

    debugPrint('[Poller] catchUpStaleRecurring: ${stale.length} stale rows');

    for (final row in stale) {
      if (row.recurrenceType == RecurrenceType.none) continue;
      final next = nextRecurrenceFuture(row.scheduledAt, row.recurrenceType);

      await (db.update(db.remindersTable)
            ..where((t) => t.id.equals(row.id)))
          .write(RemindersTableCompanion(
        scheduledAt: Value(next),
        updatedAt: Value(DateTime.now()),
      ));

      final updated = Reminder(
        id: row.id,
        title: row.title,
        description: row.description,
        scheduledAt: next,
        recurrenceType: row.recurrenceType,
        categoryId: row.categoryId,
        soundPath: row.soundPath,
        isActive: row.isActive,
      );
      await NotificationService.instance.cancelReminder(row.id);
      await NotificationService.instance.scheduleReminder(updated);
      debugPrint(
          '[Poller] caught up id=${row.id} → next=$next (recur=${row.recurrenceType})');
    }
  }

  Future<void> _tick() async {
    final db = _db;
    if (db == null) return;
    final now = DateTime.now();

    // Set checkpoint BEFORE the fetch to avoid a race where a reminder added
    // between fetch and assignment would be missed forever.
    final checkpoint = _lastCheck;
    _lastCheck = now;

    // Bound lookback: only fire reminders due in (checkpoint, now] AND
    // newer than `staleThreshold`. Anything older is "stale" — skip.
    final staleCutoff = now.subtract(staleThreshold);
    final lowerBound =
        checkpoint.isAfter(staleCutoff) ? checkpoint : staleCutoff;

    final query = db.select(db.remindersTable)
      ..where(
        (t) =>
            t.isActive.equals(true) &
            t.scheduledAt.isBiggerThanValue(lowerBound) &
            t.scheduledAt.isSmallerOrEqualValue(now) &
            // Completed one-shots stay quiet; recurring rows still fire (their
            // completedAt is just a stat, not a "stop" flag).
            (t.completedAt.isNull() |
                t.recurrenceType.equalsValue(RecurrenceType.daily) |
                t.recurrenceType.equalsValue(RecurrenceType.monthly) |
                t.recurrenceType.equalsValue(RecurrenceType.yearly)),
      );

    final due = await query.get();
    if (due.isNotEmpty) {
      debugPrint(
          '[Poller] tick now=$now lower=$lowerBound checkpoint=$checkpoint → ${due.length} due');
    }

    for (final row in due) {
      if (_firedThisSession.contains(row.id)) continue;
      _firedThisSession.add(row.id);
      await _fire(row, db);
    }
  }

  Future<void> _fire(RemindersTableData row, AppDatabase db) async {
    debugPrint(
        '[Poller] fire id=${row.id} title="${row.title}" sound=${row.soundPath}');
    await NotificationService.instance.showNow(
      id: row.id,
      body: row.title,
      soundPath: row.soundPath,
      payload: row.id.toString(),
    );

    // Only play in-app sound on Windows — on Android the channel sound plays
    // via the OS notification, so playing here would double the audio.
    if (Platform.isWindows) {
      final path = row.soundPath ?? 'sounds/ping_simple.wav';
      if (builtInSounds.any((s) => s.asset == path)) {
        await AudioService.instance.playAsset(path);
      } else {
        await AudioService.instance.playSound(path);
      }
    }

    // If recurring, advance scheduledAt to the next future occurrence and
    // reschedule. This is the persistence-side counterpart to
    // catchUpStaleRecurring; without it, recurring reminders only fire once.
    if (row.recurrenceType != RecurrenceType.none) {
      final next = nextRecurrenceFuture(row.scheduledAt, row.recurrenceType);
      await (db.update(db.remindersTable)..where((t) => t.id.equals(row.id)))
          .write(RemindersTableCompanion(
        scheduledAt: Value(next),
        updatedAt: Value(DateTime.now()),
      ));

      // Allow this id to fire again on its next occurrence.
      _firedThisSession.remove(row.id);

      final updated = Reminder(
        id: row.id,
        title: row.title,
        description: row.description,
        scheduledAt: next,
        recurrenceType: row.recurrenceType,
        categoryId: row.categoryId,
        soundPath: row.soundPath,
        isActive: row.isActive,
      );
      await NotificationService.instance.scheduleReminder(updated);
      debugPrint(
          '[Poller] recurring id=${row.id} advanced → next=$next');
    }
  }
}
