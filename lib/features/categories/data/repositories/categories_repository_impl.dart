import 'package:drift/drift.dart';
import 'package:mirit_reminders/core/database/app_database.dart';
import 'package:mirit_reminders/features/categories/domain/entities/category.dart';
import 'package:mirit_reminders/features/categories/domain/repositories/categories_repository.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  CategoriesRepositoryImpl(this._db);

  final AppDatabase _db;

  Category _toEntity(CategoriesTableData row) => Category(
        id: row.id,
        name: row.name,
        colorHex: row.colorHex,
        iconName: row.iconName,
        isPreset: row.isPreset,
      );

  CategoriesTableCompanion _toCompanion(Category category) =>
      CategoriesTableCompanion(
        id: category.id != null ? Value(category.id!) : const Value.absent(),
        name: Value(category.name),
        colorHex: Value(category.colorHex),
        iconName: Value(category.iconName),
        isPreset: Value(category.isPreset),
      );

  @override
  Stream<List<Category>> watchAll() =>
      _db.select(_db.categoriesTable).watch().map(
            (rows) => rows.map(_toEntity).toList(),
          );

  @override
  Future<List<Category>> getAll() async {
    final rows = await _db.select(_db.categoriesTable).get();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<Category?> getById(int id) async {
    final query = _db.select(_db.categoriesTable)
      ..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<int> add(Category category) async {
    final companion = CategoriesTableCompanion.insert(
      name: category.name,
      colorHex: category.colorHex,
      iconName: category.iconName,
      isPreset: Value(category.isPreset),
    );
    final row = await _db.into(_db.categoriesTable).insertReturning(companion);
    return row.id;
  }

  @override
  Future<void> update(Category category) async {
    final companion = _toCompanion(category);
    await (_db.update(_db.categoriesTable)
          ..where((t) => t.id.equals(category.id!)))
        .write(companion);
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.categoriesTable)..where((t) => t.id.equals(id))).go();
  }
}
