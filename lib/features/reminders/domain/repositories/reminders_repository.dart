import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';

abstract interface class RemindersRepository {
  Stream<List<Reminder>> watchAll();
  Stream<List<Reminder>> watchUpcoming();
  Future<Reminder?> getById(int id);
  Future<int> add(Reminder reminder);
  Future<void> update(Reminder reminder);
  Future<void> delete(int id);
  Future<void> toggleActive(int id, bool isActive);

  /// Stamp completedAt = now. For one-shot reminders this hides them from
  /// upcoming and stops the OS notification firing. For recurring reminders
  /// it's a "last completion" marker — recurrence continues regardless.
  Future<void> markCompleted(int id, {DateTime? at});

  /// Clear completedAt back to null.
  Future<void> unmarkCompleted(int id);

  /// Update scheduledAt to the next occurrence directly (caller computes it
  /// using shared recurrence math). Used by "skip next" on recurring.
  Future<void> updateScheduledAt(int id, DateTime newScheduledAt);
}
