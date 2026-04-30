import 'package:mirit_reminders/features/categories/domain/entities/category.dart';

abstract interface class CategoriesRepository {
  Stream<List<Category>> watchAll();
  Future<List<Category>> getAll();
  Future<Category?> getById(int id);
  Future<int> add(Category category);
  Future<void> update(Category category);
  Future<void> delete(int id);
}
