import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/database/database_provider.dart';
import 'package:mirit_reminders/features/categories/data/repositories/categories_repository_impl.dart';
import 'package:mirit_reminders/features/categories/domain/entities/category.dart';
import 'package:mirit_reminders/features/categories/domain/repositories/categories_repository.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepositoryImpl(ref.watch(databaseProvider));
});

final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoriesRepositoryProvider).watchAll();
});

class CategoriesNotifier extends StateNotifier<AsyncValue<void>> {
  CategoriesNotifier(this._repository) : super(const AsyncValue.data(null));

  final CategoriesRepository _repository;

  Future<void> add(Category category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.add(category).then((_) {}));
  }

  Future<void> update(Category category) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.update(category));
  }

  Future<void> delete(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.delete(id));
  }
}

final categoriesNotifierProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<void>>((ref) {
  return CategoriesNotifier(ref.watch(categoriesRepositoryProvider));
});
