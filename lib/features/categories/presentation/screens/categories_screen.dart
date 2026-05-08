import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/core/widgets/haptics.dart';
import 'package:mirit_reminders/core/widgets/undo_snackbar.dart';
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _CategoriesErrorState(
          onRetry: () => ref.invalidate(allCategoriesProvider),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return const _CategoriesEmptyState();
          }
          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final category = categories[index];
              final tile = _CategoryTile(category: category);
              // Preset categories cannot be deleted, so they shouldn't
              // be swipeable either.
              if (category.isPreset || category.id == null) {
                return tile;
              }
              return Dismissible(
                key: ValueKey(category.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsetsDirectional.only(start: 24),
                  child: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                confirmDismiss: (_) =>
                    _CategoryTile.confirmDeleteDialog(context),
                onDismissed: (_) => _CategoryTile.performDelete(
                  context,
                  ref,
                  category,
                ),
                child: tile,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_categories',
        tooltip: 'הוסף קטגוריה',
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
              tooltip: 'מחק קטגוריה',
              onPressed: () => _confirmDelete(context, ref),
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDeleteDialog(context);
    if (confirmed == true && context.mounted) {
      await performDelete(context, ref, category);
    }
  }

  /// Shared confirmation dialog used by both the trash icon and the
  /// swipe-to-dismiss `confirmDismiss` callback.
  static Future<bool?> confirmDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחק קטגוריה'),
        content: const Text('האם למחוק קטגוריה זו?'),
        // RTL: destructive action on leading edge (right), Cancel on trailing
        // (left). Cancel is the visually prominent button — safe for elderly.
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('מחק'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
        ],
      ),
    );
  }

  /// Performs the actual delete and surfaces an undo snackbar so the user
  /// can recover from accidental taps/swipes.
  static Future<void> performDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    if (category.id == null) return;
    final notifier = ref.read(categoriesNotifierProvider.notifier);
    await notifier.delete(category.id!);
    await Haptics.delete();
    if (!context.mounted) return;
    UndoSnackbar.show(
      context,
      message: 'הקטגוריה נמחקה',
      onUndo: () => ref
          .read(categoriesNotifierProvider.notifier)
          .add(category),
    );
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
    'cake',
    'celebration',
    'card_giftcard',
    'medical_services',
    'medication',
    'pets',
    'restaurant',
    'flight',
    'directions_car',
    'savings',
    'event_note',
    'alarm',
    'phone',
    'email',
    'spa',
    'local_florist',
    'beach_access',
    'book',
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
    'cake': Icons.cake,
    'celebration': Icons.celebration,
    'card_giftcard': Icons.card_giftcard,
    'medical_services': Icons.medical_services,
    'medication': Icons.medication,
    'pets': Icons.pets,
    'restaurant': Icons.restaurant,
    'flight': Icons.flight,
    'directions_car': Icons.directions_car,
    'savings': Icons.savings,
    'event_note': Icons.event_note,
    'alarm': Icons.alarm,
    'phone': Icons.phone,
    'email': Icons.email,
    'spa': Icons.spa,
    'local_florist': Icons.local_florist,
    'beach_access': Icons.beach_access,
    'book': Icons.menu_book,
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
    await Haptics.success();

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
        return InkWell(
          onTap: () => onSelected(color),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: CircleAvatar(
                radius: 22,
                backgroundColor: color,
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: iconNames.map((name) {
        final isSelected = name == selectedIconName;
        return InkWell(
          onTap: () => onSelected(name),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              iconMap[name],
              color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CategoriesEmptyState extends StatelessWidget {
  const _CategoriesEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'אין קטגוריות',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'לחץ + להוספת קטגוריה',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CategoriesErrorState extends StatelessWidget {
  const _CategoriesErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'שגיאה בטעינת קטגוריות',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('נסה שוב'),
            ),
          ],
        ),
      ),
    );
  }
}
