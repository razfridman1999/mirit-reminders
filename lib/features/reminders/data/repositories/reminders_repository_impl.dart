import 'package:drift/drift.dart';
import 'package:mirit_reminders/core/database/app_database.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:mirit_reminders/features/reminders/domain/repositories/reminders_repository.dart';

class RemindersRepositoryImpl implements RemindersRepository {
  RemindersRepositoryImpl(this._db);

  final AppDatabase _db;

  Reminder _toEntity(RemindersTableData data) {
    return Reminder(
      id: data.id,
      title: data.title,
      description: data.description,
      scheduledAt: data.scheduledAt,
      recurrenceType: data.recurrenceType,
      categoryId: data.categoryId,
      soundPath: data.soundPath,
      isActive: data.isActive,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  RemindersTableCompanion _toCompanion(Reminder reminder) {
    return RemindersTableCompanion(
      title: Value(reminder.title),
      description: Value(reminder.description),
      scheduledAt: Value(reminder.scheduledAt),
      recurrenceType: Value(reminder.recurrenceType),
      categoryId: Value(reminder.categoryId),
      soundPath: Value(reminder.soundPath),
      isActive: Value(reminder.isActive),
      updatedAt: Value(DateTime.now()),
    );
  }

  @override
  Stream<List<Reminder>> watchAll() {
    return _db.select(_db.remindersTable).watch().map(
      (rows) => rows.map(_toEntity).toList(),
    );
  }

  @override
  Stream<List<Reminder>> watchUpcoming() {
    final query = _db.select(_db.remindersTable)
      ..where(
        (t) =>
            t.scheduledAt.isBiggerOrEqualValue(DateTime.now()) &
            t.isActive.equals(true),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Reminder?> getById(int id) async {
    final query = _db.select(_db.remindersTable)
      ..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<int> add(Reminder reminder) async {
    final companion = RemindersTableCompanion.insert(
      title: reminder.title,
      description: Value(reminder.description),
      scheduledAt: reminder.scheduledAt,
      recurrenceType: reminder.recurrenceType,
      categoryId: Value(reminder.categoryId),
      soundPath: Value(reminder.soundPath),
      isActive: Value(reminder.isActive),
    );
    final row = await _db.into(_db.remindersTable).insertReturning(companion);
    return row.id;
  }

  @override
  Future<void> update(Reminder reminder) async {
    await (_db.update(_db.remindersTable)
          ..where((t) => t.id.equals(reminder.id!)))
        .write(_toCompanion(reminder));
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.remindersTable)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> toggleActive(int id, bool isActive) async {
    await (_db.update(_db.remindersTable)..where((t) => t.id.equals(id)))
        .write(RemindersTableCompanion(
      isActive: Value(isActive),
      updatedAt: Value(DateTime.now()),
    ));
  }
}
