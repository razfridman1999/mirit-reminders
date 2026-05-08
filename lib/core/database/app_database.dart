import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/reminders_table.dart';
import 'tables/categories_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [RemindersTable, CategoriesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _insertDefaultCategories();
        },
        onUpgrade: (m, from, to) async {
          // v1 → v2: add the completedAt column. Non-destructive — existing
          // rows get NULL which the app treats as "not done".
          if (from < 2) {
            await m.addColumn(remindersTable, remindersTable.completedAt);
          }
        },
      );

  Future<void> _insertDefaultCategories() async {
    final defaults = [
      CategoriesTableCompanion.insert(
        name: 'עבודה',
        colorHex: '#2E6DA4',
        iconName: 'work',
        isPreset: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        name: 'משפחה',
        colorHex: '#26A69A',
        iconName: 'family_restroom',
        isPreset: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        name: 'בריאות',
        colorHex: '#43A047',
        iconName: 'favorite',
        isPreset: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        name: 'פגישות',
        colorHex: '#8E24AA',
        iconName: 'groups',
        isPreset: const Value(true),
      ),
      CategoriesTableCompanion.insert(
        name: 'אחר',
        colorHex: '#546E7A',
        iconName: 'label',
        isPreset: const Value(true),
      ),
    ];

    for (final cat in defaults) {
      await into(categoriesTable).insert(cat);
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'mirit_reminders_db');
  }
}
