import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/core/database/tables/reminders_table.dart';
import 'package:mirit_reminders/core/utils/date_utils.dart';
import 'package:mirit_reminders/features/categories/domain/entities/category.dart';
import 'package:mirit_reminders/features/categories/presentation/providers/categories_provider.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:mirit_reminders/features/reminders/presentation/providers/reminders_provider.dart';
import 'package:mirit_reminders/features/reminders/presentation/screens/add_edit_reminder_screen.dart';

class RemindersListScreen extends ConsumerStatefulWidget {
  const RemindersListScreen({super.key});

  @override
  ConsumerState<RemindersListScreen> createState() =>
      _RemindersListScreenState();
}

class _RemindersListScreenState extends ConsumerState<RemindersListScreen> {
  bool _showAll = false;

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = _showAll
        ? ref.watch(allRemindersProvider)
        : ref.watch(upcomingRemindersProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.reminders),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_showAll ? Icons.filter_list_off : Icons.filter_list),
            tooltip: _showAll ? 'הצג קרובות בלבד' : 'הצג הכל',
            onPressed: () => setState(() => _showAll = !_showAll),
          ),
        ],
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'שגיאה: $error',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        data: (reminders) {
          if (reminders.isEmpty) {
            return _EmptyState();
          }

          final categories = categoriesAsync.valueOrNull ?? [];
          final dates = reminders.map((r) => r.scheduledAt).toList();

          // Build a flat list of items: either a header label (String) or a
          // reminder index (int), so we can render date-group separators.
          final items = <dynamic>[];
          for (int i = 0; i < reminders.length; i++) {
            final label = AppDateUtils.groupLabel(dates, i);
            if (label != null) items.add(label);
            items.add(i);
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final item = items[idx];

              if (item is String) {
                // Date-group header
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              // item is int — a reminder index
              final reminder = reminders[item as int];
              final category = reminder.categoryId != null
                  ? categories
                      .where((c) => c.id == reminder.categoryId)
                      .firstOrNull
                  : null;

              return _ReminderCard(
                reminder: reminder,
                category: category,
                formattedDate: _formatDate(reminder.scheduledAt),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddEditReminderScreen(reminder: reminder),
                  ),
                ),
                onToggle: () {
                  if (reminder.id != null) {
                    ref
                        .read(remindersNotifierProvider.notifier)
                        .toggleActive(reminder.id!, !reminder.isActive);
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_reminders',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AddEditReminderScreen(reminder: null),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.category,
    required this.formattedDate,
    required this.onTap,
    required this.onToggle,
  });

  final Reminder reminder;
  final Category? category;
  final String formattedDate;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final barColor = category?.color ?? AppColors.primary;

    return Opacity(
      opacity: reminder.isActive ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored vertical bar on the left (leading edge in RTL)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: Container(
                    width: 5,
                    color: barColor,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                reminder.title,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  decoration: reminder.isActive
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            if (reminder.recurrenceType != RecurrenceType.none)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.repeat,
                                  size: 16,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        if (category != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: category!.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  category!.name,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Toggle active button
                IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    reminder.isActive
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: reminder.isActive
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.noReminders,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'לחץ + להוספת תזכורת',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
