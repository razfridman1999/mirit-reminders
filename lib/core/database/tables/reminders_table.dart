import 'package:drift/drift.dart';
import 'categories_table.dart';

enum RecurrenceType { none, daily, monthly, yearly }

class RemindersTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get recurrenceType => textEnum<RecurrenceType>()();
  IntColumn get categoryId => integer().nullable().references(CategoriesTable, #id)();
  TextColumn get soundPath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
