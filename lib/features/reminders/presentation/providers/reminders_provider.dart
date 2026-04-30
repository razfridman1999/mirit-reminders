import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/database/database_provider.dart';
import 'package:mirit_reminders/core/database/tables/reminders_table.dart';
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

  DateTime _nextOccurrence(DateTime base, RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return base.add(const Duration(days: 1));
      case RecurrenceType.monthly:
        return DateTime(base.year, base.month + 1, base.day, base.hour, base.minute);
      case RecurrenceType.yearly:
        return DateTime(base.year + 1, base.month, base.day, base.hour, base.minute);
      case RecurrenceType.none:
        return base;
    }
  }

  Future<void> _scheduleIfNeeded(Reminder reminder) async {
    if (!reminder.isActive) return;
    if (reminder.scheduledAt.isAfter(DateTime.now())) {
      await NotificationService.instance.scheduleReminder(reminder);
    }
    if (reminder.recurrenceType != RecurrenceType.none) {
      final next = _nextOccurrence(reminder.scheduledAt, reminder.recurrenceType);
      if (next.isAfter(DateTime.now())) {
        await NotificationService.instance.scheduleReminder(
          reminder.copyWith(scheduledAt: next),
        );
      }
    }
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
}

final remindersNotifierProvider =
    StateNotifierProvider<RemindersNotifier, AsyncValue<void>>((ref) {
  return RemindersNotifier(ref.watch(remindersRepositoryProvider));
});
