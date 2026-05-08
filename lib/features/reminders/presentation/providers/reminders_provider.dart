import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/database/database_provider.dart';
import 'package:mirit_reminders/core/database/tables/reminders_table.dart';
import 'package:mirit_reminders/core/utils/recurrence.dart';
import 'package:mirit_reminders/features/notifications/notification_service.dart';
import 'package:mirit_reminders/features/reminders/data/repositories/reminders_repository_impl.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:mirit_reminders/features/reminders/domain/repositories/reminders_repository.dart';

final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepositoryImpl(ref.watch(databaseProvider));
});

final allRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(remindersRepositoryProvider).watchAll();
});

final upcomingRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(remindersRepositoryProvider).watchUpcoming();
});

class RemindersNotifier extends StateNotifier<AsyncValue<void>> {
  RemindersNotifier(this._repository) : super(const AsyncValue.data(null));

  final RemindersRepository _repository;

  /// Schedule the OS notification for the reminder's CURRENT scheduledAt.
  /// Recurrence is handled by the poller advancing scheduledAt after each
  /// fire — scheduling a "next" occurrence here would have its OS-level id
  /// collide with the first occurrence (zonedSchedule overwrites by id).
  ///
  /// For recurring reminders whose stored scheduledAt is already in the past
  /// (e.g. user creates "daily 8:00" at 9:00), we advance scheduledAt to the
  /// next future occurrence and persist before scheduling, so the reminder
  /// doesn't silently never fire.
  Future<void> _scheduleIfNeeded(Reminder reminder) async {
    if (!reminder.isActive) return;
    if (reminder.isCompletedOneShot) return;

    if (reminder.scheduledAt.isAfter(DateTime.now())) {
      await NotificationService.instance.scheduleReminder(reminder);
      return;
    }

    if (reminder.recurrenceType == RecurrenceType.none) return;

    final next =
        nextRecurrenceFuture(reminder.scheduledAt, reminder.recurrenceType);
    final advanced = reminder.copyWith(scheduledAt: next);
    await _repository.update(advanced);
    await NotificationService.instance.scheduleReminder(advanced);
  }

  Future<void> add(Reminder reminder) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final id = await _repository.add(reminder);
      final newReminder = await _repository.getById(id);
      if (newReminder != null) {
        await _scheduleIfNeeded(newReminder);
      }
    });
  }

  Future<void> update(Reminder reminder) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (reminder.id != null) {
        await NotificationService.instance.cancelReminder(reminder.id!);
      }
      await _repository.update(reminder);
      // Re-fetch the persisted row so any DB-applied defaults (e.g.
      // updatedAt) are reflected in what we schedule.
      if (reminder.id != null) {
        final persisted = await _repository.getById(reminder.id!);
        if (persisted != null) {
          await _scheduleIfNeeded(persisted);
          return;
        }
      }
      await _scheduleIfNeeded(reminder);
    });
  }

  Future<void> delete(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await NotificationService.instance.cancelReminder(id);
      await _repository.delete(id);
    });
  }

  Future<void> toggleActive(int id, bool isActive) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.toggleActive(id, isActive);
      if (!isActive) {
        await NotificationService.instance.cancelReminder(id);
      } else {
        final reminder = await _repository.getById(id);
        if (reminder != null) {
          await _scheduleIfNeeded(reminder);
        }
      }
    });
  }

  /// Mark a reminder as completed. For one-shot — cancels the scheduled OS
  /// notification too. For recurring — leaves scheduling alone (the next
  /// occurrence will fire on schedule); completedAt is just a stat marker.
  Future<void> markCompleted(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.markCompleted(id);
      final reminder = await _repository.getById(id);
      if (reminder == null) return;
      if (reminder.recurrenceType == RecurrenceType.none) {
        await NotificationService.instance.cancelReminder(id);
      }
    });
  }

  /// Reverse of [markCompleted]. For one-shot reminders this also re-schedules
  /// the OS notification (if still in the future).
  Future<void> unmarkCompleted(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.unmarkCompleted(id);
      final reminder = await _repository.getById(id);
      if (reminder != null) {
        await _scheduleIfNeeded(reminder);
      }
    });
  }

  /// Skip the next occurrence of a recurring reminder — advances scheduledAt
  /// without firing. No-op for one-shot reminders.
  Future<void> skipNext(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final reminder = await _repository.getById(id);
      if (reminder == null) return;
      if (reminder.recurrenceType == RecurrenceType.none) return;
      final next =
          nextRecurrenceFuture(reminder.scheduledAt, reminder.recurrenceType);
      await NotificationService.instance.cancelReminder(id);
      await _repository.updateScheduledAt(id, next);
      final advanced = await _repository.getById(id);
      if (advanced != null) {
        await NotificationService.instance.scheduleReminder(advanced);
      }
    });
  }
}

final remindersNotifierProvider =
    StateNotifierProvider<RemindersNotifier, AsyncValue<void>>((ref) {
  return RemindersNotifier(ref.watch(remindersRepositoryProvider));
});
