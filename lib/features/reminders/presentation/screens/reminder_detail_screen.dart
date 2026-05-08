import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/core/database/tables/reminders_table.dart';
import 'package:mirit_reminders/core/utils/hebrew_date.dart';
import 'package:mirit_reminders/core/widgets/haptics.dart';
import 'package:mirit_reminders/features/categories/domain/entities/category.dart';
import 'package:mirit_reminders/features/categories/presentation/providers/categories_provider.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:mirit_reminders/features/reminders/presentation/providers/reminders_provider.dart';
import 'package:mirit_reminders/features/reminders/presentation/screens/add_edit_reminder_screen.dart';

/// Read-only detail view of a single reminder. Less intimidating for elderly
/// users than dropping them straight into the edit form on tap. Provides
/// Edit / Delete / Toggle-active actions.
class ReminderDetailScreen extends ConsumerWidget {
  const ReminderDetailScreen({super.key, required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // valueOrNull: in detail view we just want a snapshot — if categories
    // haven't loaded yet, we degrade gracefully to "—" rather than blocking.
    final categories = ref.watch(allCategoriesProvider).valueOrNull;
    final category = _findCategory(categories, reminder.categoryId);
    final accent = category?.color ?? theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('תזכורת'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: AppStrings.editReminder,
            onPressed: () => _openEdit(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _HeroCard(reminder: reminder, accent: accent),
              const SizedBox(height: 16),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: AppStrings.date,
                value: _formatDate(reminder.scheduledAt),
              ),
              _InfoRow(
                icon: Icons.access_time_outlined,
                label: AppStrings.time,
                value: _formatTime(reminder.scheduledAt),
              ),
              _InfoRow(
                icon: Icons.star_outline,
                label: 'תאריך עברי',
                value: hebrewFullLabel(reminder.scheduledAt),
              ),
              _InfoRow(
                icon: Icons.repeat,
                label: AppStrings.recurrence,
                value: _recurrenceLabel(reminder.recurrenceType),
              ),
              _CategoryRow(category: category),
              _InfoRow(
                icon: Icons.volume_up_outlined,
                label: AppStrings.sound,
                value: _soundLabel(reminder.soundPath),
              ),
              if (reminder.description != null &&
                  reminder.description!.trim().isNotEmpty)
                _DescriptionRow(text: reminder.description!),
              const SizedBox(height: 24),
              _ActionButtons(reminder: reminder),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    final result = await Navigator.of(context).push<Reminder?>(
      MaterialPageRoute(
        builder: (_) => AddEditReminderScreen(reminder: reminder),
      ),
    );
    // Edit screen returns a Reminder iff the user deleted it from the edit
    // form — in that case the underlying record is gone, so close the detail
    // view too and propagate the deleted reminder up to the list screen
    // (which owns the UndoSnackbar).
    if (result != null && context.mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Category? _findCategory(List<Category>? categories, int? id) {
    if (categories == null || id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _formatTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _recurrenceLabel(RecurrenceType t) {
    switch (t) {
      case RecurrenceType.none:
        return AppStrings.once;
      case RecurrenceType.daily:
        return AppStrings.daily;
      case RecurrenceType.monthly:
        return AppStrings.monthly;
      case RecurrenceType.yearly:
        return AppStrings.yearly;
    }
  }

  String _soundLabel(String? path) {
    if (path == null || path.isEmpty) return 'ברירת מחדל';
    if (path.startsWith('sounds/')) {
      final filename = path.substring('sounds/'.length);
      final dot = filename.lastIndexOf('.');
      return dot > 0 ? filename.substring(0, dot) : filename;
    }
    return 'מותאם אישית';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.reminder, required this.accent});

  final Reminder reminder;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showRecurrenceBadge =
        reminder.recurrenceType != RecurrenceType.none;
    final isDoneOneShot = reminder.isCompletedOneShot;
    // Recurring reminders that have been completed at least once show a
    // small "last done" line; one-shots already get the chip + strikethrough.
    final showRecurringLastDone =
        reminder.completedAt != null && !isDoneOneShot;

    return Hero(
      tag: 'reminder-card-${reminder.id ?? "new"}',
      child: Material(
        type: MaterialType.transparency,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                reminder.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDoneOneShot
                                      ? theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5)
                                      : null,
                                  decoration: isDoneOneShot
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(
                              isActive: reminder.isActive,
                              isDoneOneShot: isDoneOneShot,
                            ),
                          ],
                        ),
                        if (showRecurringLastDone) ...[
                          const SizedBox(height: 6),
                          Text(
                            'בוצע לאחרונה: ${_formatShortDate(reminder.completedAt!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (showRecurrenceBadge) ...[
                          const SizedBox(height: 12),
                          _RecurrenceBadge(
                            label: _badgeLabel(reminder.recurrenceType),
                            color: accent,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Vertical colored bar on the right edge of the card.
                Container(width: 5, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatShortDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _badgeLabel(RecurrenceType t) {
    switch (t) {
      case RecurrenceType.none:
        return AppStrings.once;
      case RecurrenceType.daily:
        return AppStrings.daily;
      case RecurrenceType.monthly:
        return AppStrings.monthly;
      case RecurrenceType.yearly:
        return AppStrings.yearly;
    }
  }
}

class _RecurrenceBadge extends StatelessWidget {
  const _RecurrenceBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive, this.isDoneOneShot = false});

  final bool isActive;
  final bool isDoneOneShot;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (isDoneOneShot) {
      color = AppColors.success;
      label = 'בוצע';
    } else if (isActive) {
      color = AppColors.success;
      label = 'פעיל';
    } else {
      color = AppColors.onSurfaceVariant;
      label = 'לא פעיל';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final Category? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.label_outline,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                if (category == null)
                  Text(
                    '—',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: category!.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(category!.icon,
                          size: 18, color: category!.color),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          category!.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionRow extends StatelessWidget {
  const _DescriptionRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_outlined,
                  size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                AppStrings.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 34),
            child: Text(
              text,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isRecurring = reminder.recurrenceType != RecurrenceType.none;
    final isDoneOneShot = reminder.isCompletedOneShot;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _openEdit(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text(
              'ערוך',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isRecurring) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => _skipNext(context, ref),
              icon: const Icon(Icons.skip_next),
              label: const Text(
                'דלג על הבא',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(
                    color: theme.colorScheme.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else if (isDoneOneShot) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => _unmarkCompleted(context, ref),
              icon: const Icon(Icons.replay),
              label: const Text(
                'בטל סימון',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(
                    color: theme.colorScheme.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () => _markCompleted(context, ref),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'סמן שבוצע',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text(
              'מחק',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    final result = await Navigator.of(context).push<Reminder?>(
      MaterialPageRoute(
        builder: (_) => AddEditReminderScreen(reminder: reminder),
      ),
    );
    if (result != null && context.mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _markCompleted(BuildContext context, WidgetRef ref) async {
    if (reminder.id == null) return;
    await Haptics.success();
    await ref
        .read(remindersNotifierProvider.notifier)
        .markCompleted(reminder.id!);
    // Pop with the reminder so the list screen can refresh / animate.
    if (context.mounted) Navigator.of(context).pop(reminder);
  }

  Future<void> _unmarkCompleted(BuildContext context, WidgetRef ref) async {
    if (reminder.id == null) return;
    await Haptics.light();
    await ref
        .read(remindersNotifierProvider.notifier)
        .unmarkCompleted(reminder.id!);
    if (context.mounted) Navigator.of(context).pop(reminder);
  }

  Future<void> _skipNext(BuildContext context, WidgetRef ref) async {
    if (reminder.id == null) return;
    await Haptics.success();
    await ref
        .read(remindersNotifierProvider.notifier)
        .skipNext(reminder.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('התזכורת הבאה תדלג. הבאה אחריה תפעל כרגיל.'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    if (reminder.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.deleteReminder),
        content: const Text(AppStrings.deleteConfirm),
        // Same convention as edit screen — Cancel is the prominent button
        // for elderly users; destructive action is the plain TextButton.
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.deleteReminder),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(remindersNotifierProvider.notifier).delete(reminder.id!);
    await Haptics.delete();
    // Pop with the deleted Reminder so the LIST screen can show its
    // UndoSnackbar (single source of truth for undo UX).
    if (context.mounted) Navigator.of(context).pop(reminder);
  }
}
