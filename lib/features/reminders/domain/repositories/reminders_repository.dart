import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';

abstract interface class RemindersRepository {
  Stream<List<Reminder>> watchAll();
  Stream<List<Reminder>> watchUpcoming();
  Future<Reminder?> getById(int id);
  Future<int> add(Reminder reminder);
  Future<void> update(Reminder reminder);
  Future<void> delete(int id);
  Future<void> toggleActive(int id, bool isActive);
}
