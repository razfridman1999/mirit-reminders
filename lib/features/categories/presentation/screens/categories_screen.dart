import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/features/categories/domain/entities/category.dart';
import 'package:mirit_reminders/features/categories/presentation/providers/categories_provider.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.categories),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('שגיאה בטעינת קטגוריות')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('אין קטגוריות'));
          }
          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryTile(category: category);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_categories',
        onPressed: () => _showAddCategorySheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _AddCategorySheet(),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: category.color,
        child: Icon(category.icon, color: Colors.white, size: 20),
      ),
      title: Text(category.name),
      subtitle: category.isPreset ? const Text('ברירת מחדל') : null,
      trailing: category.isPreset
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחק קטגוריה'),
        content: const Text('האם למחוק קטגוריה זו?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('מחק'),
          ),
        ],
      ),
    );

    if (confirmed == true && category.id != null) {
      await ref.read(categoriesNotifierProvider.notifier).delete(category.id!);
    }
  }
}

class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet();

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Color _selectedColor = AppColors.categoryColors.first;
  String _selectedIconName = 'label';

  static const List<String> _iconNames = [
    'work',
    'family_restroom',
    'favorite',
    'groups',
    'label',
    'star',
    'home',
    'school',
    'fitness_center',
    'shopping_cart',
  ];

  static const Map<String, IconData> _iconMap = {
    'work': Icons.work,
    'family_restroom': Icons.family_restroom,
    'favorite': Icons.favorite,
    'groups': Icons.groups,
    'label': Icons.label,
    'star': Icons.star,
    'home': Icons.home,
    'school': Icons.school,
    'fitness_center': Icons.fitness_center,
    'shopping_cart': Icons.shopping_cart,
  };

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _colorHex =>
      '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'קטגוריה חדשה',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: AppStrings.categoryName,
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'יש להזין שם' : null,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.color,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _ColorPicker(
                selected: _selectedColor,
                onSelected: (color) => setState(() => _selectedColor = color),
              ),
              const SizedBox(height: 16),
              Text(
                'אייקון',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _IconPicker(
                iconNames: _iconNames,
                iconMap: _iconMap,
                selectedIconName: _selectedIconName,
                selectedColor: _selectedColor,
                onSelected: (name) => setState(() => _selectedIconName = name),
              ),
              const SizedBox(height: 24),
              Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => _save(context, ref),
                  child: const Text(AppStrings.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    if (!_formKey.currentState!.validate()) return;

    final category = Category(
      name: _nameController.text.trim(),
      colorHex: _colorHex,
      iconName: _selectedIconName,
      isPreset: false,
    );

    await ref.read(categoriesNotifierProvider.notifier).add(category);

    if (context.mounted) Navigator.of(context).pop();
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppColors.categoryColors.map((color) {
        final isSelected = color.toARGB32() == selected.toARGB32();
        return GestureDetector(
          onTap: () => onSelected(color),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: color,
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.iconNames,
    required this.iconMap,
    required this.selectedIconName,
    required this.selectedColor,
    required this.onSelected,
  });

  final List<String> iconNames;
  final Map<String, IconData> iconMap;
  final String selectedIconName;
  final Color selectedColor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: iconNames.map((name) {
        final isSelected = name == selectedIconName;
        return GestureDetector(
          onTap: () => onSelected(name),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected ? selectedColor : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              iconMap[name],
              color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              size: 22,
            ),
          ),
        );
      }).toList(),
    );
  }
}
