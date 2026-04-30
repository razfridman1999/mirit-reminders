import 'package:drift/drift.dart';

class CategoriesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get colorHex => text()();
  TextColumn get iconName => text()();
  BoolColumn get isPreset => boolean().withDefault(const Constant(false))();

}
