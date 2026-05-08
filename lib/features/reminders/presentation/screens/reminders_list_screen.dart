import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/core/database/tables/reminders_table.dart';
import 'package:mirit_reminders/core/utils/date_utils.dart';
import 'package:mirit_reminders/core/widgets/haptics.dart';
import 'package:mirit_reminders/core/widgets/undo_snackbar.dart';
import 'package:mirit_reminders/features/categories/domain/entities/category.dart';
import 'package:mirit_reminders/features/categories/presentation/providers/categories_provider.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:mirit_reminders/features/reminders/presentation/providers/reminders_provider.dart';
import 'package:mirit_reminders/features/reminders/presentation/screens/add_edit_reminder_screen.dart';
import 'package:mirit_reminders/features/reminders/presentation/screens/reminder_detail_screen.dart';
import 'package:mirit_reminders/features/reminders/presentation/widgets/quick_add_templates.dart';

enum _TimeBucket { morning, noon, evening, night }

extension _TimeBucketLabel on _TimeBucket {
  String get label {
    switch (this) {
      case _TimeBucket.morning:
        return 'בוקר';
      case _TimeBucket.noon:
        return 'צהריים';
      case _TimeBucket.evening:
        return 'ערב';
      case _TimeBucket.night:
        return 'לילה';
    }
  }
}

_TimeBucket _bucketOf(DateTime dt) {
  final h = dt.hour;
  if (h >= 4 && h < 12) return _TimeBucket.morning;
  if (h >= 12 && h < 17) return _TimeBucket.noon;
  if (h >= 17 && h < 22) return _TimeBucket.evening;
  return _TimeBucket.night;
}

class RemindersListScreen extends ConsumerStatefulWidget {
  const RemindersListScreen({super.key});

  @override
  ConsumerState<RemindersListScreen> createState() =>
      _RemindersListScreenState();
}

class _RemindersListScreenState extends ConsumerState<RemindersListScreen> {
  bool _showAll = false;
  bool _searchOpen = false;
  String _searchQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  bool _matchesSearch(Reminder r) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final inTitle = r.title.toLowerCase().contains(q);
    final inDesc = (r.description ?? '').toLowerCase().contains(q);
    return inTitle || inDesc;
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.deleteReminder),
        content: const Text(AppStrings.deleteConfirm),
        // RTL: destructive on leading edge (right), Cancel as prominent button
        // on trailing — safer default for elderly user.
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
    return confirmed == true;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Reminder reminder,
  ) async {
    final confirmed = await _showDeleteConfirmation(context);
    if (confirmed && reminder.id != null) {
      await ref.read(remindersNotifierProvider.notifier).delete(reminder.id!);
      await Haptics.delete();
      if (!context.mounted) return;
      UndoSnackbar.show(
        context,
        message: 'תזכורת נמחקה',
        onUndo: () {
          // Re-add: id will be assigned by repository, recreating the row.
          ref.read(remindersNotifierProvider.notifier).add(
                reminder.copyWith(id: null),
              );
        },
      );
    }
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  int _todayCount(List<Reminder> reminders) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return reminders
        .where((r) =>
            r.isActive &&
            !r.isCompletedOneShot &&
            !r.scheduledAt.isBefore(start) &&
            r.scheduledAt.isBefore(end))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final remindersProvider =
        _showAll ? allRemindersProvider : upcomingRemindersProvider;
    final remindersAsync = ref.watch(remindersProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: 'חיפוש תזכורת…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              )
            : const Text(AppStrings.reminders),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            tooltip: _searchOpen ? 'סגור חיפוש' : 'חיפוש',
            onPressed: _toggleSearch,
          ),
          if (!_searchOpen)
            IconButton(
              icon: Icon(_showAll ? Icons.filter_list_off : Icons.filter_list),
              tooltip: _showAll ? 'הצג קרובות בלבד' : 'הצג הכל',
              onPressed: () => setState(() => _showAll = !_showAll),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onRetry: () => ref.invalidate(remindersProvider),
        ),
        data: (rawReminders) {
          // Hide completed one-shots even in "show all" view; the Stats
          // screen is the right place to inspect them.
          final allReminders = rawReminders
              .where((r) => !r.isCompletedOneShot)
              .toList(growable: false);
          final reminders =
              allReminders.where(_matchesSearch).toList(growable: false);
          if (allReminders.isEmpty && !_searchOpen) {
            return ListView(
              children: [
                _GreetingCard(todayCount: _todayCount(allReminders)),
                const _EmptyState(),
              ],
            );
          }
          if (allReminders.isEmpty) {
            return const _EmptyState();
          }
          if (reminders.isEmpty) {
            return _NoSearchResults(query: _searchQuery);
          }

          final categories = categoriesAsync.valueOrNull ?? [];
          final dates = reminders.map((r) => r.scheduledAt).toList();

          // Build a flat list of items: greeting card, date headers,
          // bucket sub-headers, or reminder indices.
          final items = <_ListItem>[];
          if (!_searchOpen) {
            items.add(_GreetingItem(_todayCount(allReminders)));
          }

          _TimeBucket? currentBucket;
          for (int i = 0; i < reminders.length; i++) {
            final dateLabel = AppDateUtils.groupLabel(dates, i);
            if (dateLabel != null) {
              items.add(_DateHeaderItem(dateLabel));
              currentBucket = null;
            }
            final bucket = _bucketOf(reminders[i].scheduledAt);
            if (bucket != currentBucket) {
              items.add(_BucketHeaderItem(bucket));
              currentBucket = bucket;
            }
            items.add(_ReminderItem(i));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final item = items[idx];

              if (item is _GreetingItem) {
                return _GreetingCard(todayCount: item.todayCount);
              }

              if (item is _DateHeaderItem) {
                return Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                );
              }

              if (item is _BucketHeaderItem) {
                return Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 2),
                  child: Text(
                    item.bucket.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                );
              }

              final reminderIdx = (item as _ReminderItem).index;
              final reminder = reminders[reminderIdx];
              final category = reminder.categoryId != null
                  ? categories
                      .where((c) => c.id == reminder.categoryId)
                      .firstOrNull
                  : null;

              // Cap the entry-animation stagger so a long list doesn't keep
              // the user waiting on later items.
              final staggerMs = (reminderIdx.clamp(0, 14)) * 50;

              return TweenAnimationBuilder<double>(
                key: ValueKey('reminder-${reminder.id ?? reminderIdx}'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 280 + staggerMs),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) {
                  return Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 16),
                      child: child,
                    ),
                  );
                },
                child: _ReminderCard(
                  reminder: reminder,
                  category: category,
                  formattedDate: _formatDate(reminder.scheduledAt),
                  // Tap opens the read-only detail view. Edit/delete are
                  // explicit actions on the card or inside the detail screen.
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReminderDetailScreen(reminder: reminder),
                    ),
                  ),
                  onMarkDone: () async {
                    if (reminder.id == null) return;
                    await Haptics.success();
                    await ref
                        .read(remindersNotifierProvider.notifier)
                        .markCompleted(reminder.id!);
                  },
                  onUnmarkDone: () async {
                    if (reminder.id == null) return;
                    await Haptics.light();
                    await ref
                        .read(remindersNotifierProvider.notifier)
                        .unmarkCompleted(reminder.id!);
                  },
                  onEdit: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          AddEditReminderScreen(reminder: reminder),
                    ),
                  ),
                  onDelete: () => _confirmDelete(context, ref, reminder),
                  onConfirmDeleteSwipe: () =>
                      _showDeleteConfirmation(context),
                  onSwipeDelete: () async {
                    if (reminder.id == null) return;
                    await Haptics.medium();
                    await ref
                        .read(remindersNotifierProvider.notifier)
                        .delete(reminder.id!);
                    if (!context.mounted) return;
                    UndoSnackbar.show(
                      context,
                      message: 'תזכורת נמחקה',
                      onUndo: () {
                        ref
                            .read(remindersNotifierProvider.notifier)
                            .add(reminder.copyWith(id: null));
                      },
                    );
                  },
                  onSwipeToggle: () async {
                    if (reminder.id == null) return;
                    await Haptics.medium();
                    await ref
                        .read(remindersNotifierProvider.notifier)
                        .toggleActive(reminder.id!, !reminder.isActive);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: GestureDetector(
        onLongPress: () => _openQuickAddTemplates(context),
        child: FloatingActionButton(
          heroTag: 'fab_reminders',
          tooltip: 'הוסף תזכורת (לחיצה ארוכה לתבניות)',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddEditReminderScreen(reminder: null),
            ),
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _openQuickAddTemplates(BuildContext context) async {
    final template = await QuickAddTemplates.showPicker(context);
    if (template == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditReminderScreen(reminder: template),
      ),
    );
  }
}

// Sealed-style marker for ListView items, to avoid `dynamic` runtime checks.
abstract class _ListItem {
  const _ListItem();
}

class _GreetingItem extends _ListItem {
  const _GreetingItem(this.todayCount);
  final int todayCount;
}

class _DateHeaderItem extends _ListItem {
  const _DateHeaderItem(this.label);
  final String label;
}

class _BucketHeaderItem extends _ListItem {
  const _BucketHeaderItem(this.bucket);
  final _TimeBucket bucket;
}

class _ReminderItem extends _ListItem {
  const _ReminderItem(this.index);
  final int index;
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.todayCount});

  final int todayCount;

  String _greetingForHour(int hour) {
    if (hour >= 4 && hour < 12) return 'בוקר טוב';
    if (hour >= 12 && hour < 17) return 'צהריים טובים';
    if (hour >= 17 && hour < 22) return 'ערב טוב';
    return 'לילה טוב';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final greeting = _greetingForHour(DateTime.now().hour);
    final subtitle = todayCount == 0
        ? 'אין תזכורות להיום, ההפסקה מגיעה לך 🌟'
        : 'יש לך $todayCount תזכורות היום';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Card(
        color: colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                greeting,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
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
    required this.onMarkDone,
    required this.onUnmarkDone,
    required this.onEdit,
    required this.onDelete,
    required this.onConfirmDeleteSwipe,
    required this.onSwipeDelete,
    required this.onSwipeToggle,
  });

  final Reminder reminder;
  final Category? category;
  final String formattedDate;
  final VoidCallback onTap;
  final VoidCallback onMarkDone;
  final VoidCallback onUnmarkDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<bool> Function() onConfirmDeleteSwipe;
  final VoidCallback onSwipeDelete;
  final VoidCallback onSwipeToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isActive = reminder.isActive;
    final isDoneOneShot = reminder.isCompletedOneShot;
    // One-shots that are done get the visual "done" treatment; inactive
    // reminders also dim. Recurring reminders never strike-through —
    // completedAt is just a stat marker for them.
    final isDimmed = !isActive || isDoneOneShot;

    final now = DateTime.now();
    final isOverdue = isActive &&
        !isDoneOneShot &&
        reminder.scheduledAt.isBefore(now) &&
        reminder.recurrenceType == RecurrenceType.none;
    final isTodayReminder = isActive &&
        !isDoneOneShot &&
        AppDateUtils.isSameDay(reminder.scheduledAt, now) &&
        !isOverdue;

    Color barColor;
    if (!isActive || isDoneOneShot) {
      barColor = category?.color ?? colorScheme.primary;
    } else if (isOverdue) {
      barColor = AppColors.error;
    } else if (isTodayReminder) {
      barColor = AppColors.warning;
    } else {
      barColor = category?.color ?? colorScheme.primary;
    }

    final titleColor =
        colorScheme.onSurface.withValues(alpha: isDimmed ? 0.5 : 1.0);
    final subtleColor =
        colorScheme.onSurfaceVariant.withValues(alpha: isDimmed ? 0.5 : 1.0);

    final heroTag = 'reminder-card-${reminder.id ?? "new"}';

    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored vertical bar on the leading edge (right in RTL)
              ClipRRect(
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(12),
                  bottomStart: Radius.circular(12),
                ),
                child: Container(
                  width: 5,
                  color: barColor.withValues(alpha: isDimmed ? 0.5 : 1.0),
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
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                                // Strike-through only for completed one-shots
                                // (inactive reminders dim but stay readable).
                                decoration: isDoneOneShot
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (isOverdue)
                            _StatusBadge(
                              label: 'פגה',
                              color: AppColors.error,
                            ),
                          if (isTodayReminder)
                            _StatusBadge(
                              label: 'היום',
                              color: AppColors.warning,
                            ),
                          if (reminder.recurrenceType != RecurrenceType.none)
                            Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(end: 4),
                              child: Icon(
                                Icons.repeat,
                                size: 16,
                                color: subtleColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: textTheme.bodySmall?.copyWith(
                          color: subtleColor,
                        ),
                      ),
                      if (category != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: category!.color
                                      .withValues(alpha: isDimmed ? 0.5 : 1.0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                category!.name,
                                style: textTheme.bodySmall?.copyWith(
                                  color: subtleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Action buttons: edit, delete, mark-done. All explicit and
              // visible — discoverable for an elderly user who won't know
              // to tap-the-card-to-edit.
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onEdit,
                        tooltip: 'ערוך',
                        icon: Icon(
                          Icons.edit_outlined,
                          color: colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: onDelete,
                        tooltip: 'מחק',
                        icon: Icon(
                          Icons.delete_outline,
                          color: colorScheme.error,
                        ),
                      ),
                      IconButton(
                        onPressed: isDoneOneShot ? onUnmarkDone : onMarkDone,
                        tooltip:
                            isDoneOneShot ? 'ביטול סימון' : 'סמן שבוצע',
                        icon: Icon(
                          isDoneOneShot
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isDoneOneShot
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('dismissible-reminder-${reminder.id ?? identityHashCode(reminder)}'),
      // endToStart in RTL = swipe from right edge toward left = delete.
      // startToEnd in RTL = swipe from left edge toward right = toggle.
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsetsDirectional.only(start: 20),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(
          color: isActive ? AppColors.warning : AppColors.success,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsetsDirectional.only(end: 20),
        alignment: AlignmentDirectional.centerEnd,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await onConfirmDeleteSwipe();
        }
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onSwipeDelete();
        } else {
          onSwipeToggle();
        }
      },
      child: Hero(
        tag: heroTag,
        child: card,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.noReminders,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
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

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'לא נמצאו תזכורות עם "$query"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'אירעה שגיאה בטעינת התזכורות',
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
