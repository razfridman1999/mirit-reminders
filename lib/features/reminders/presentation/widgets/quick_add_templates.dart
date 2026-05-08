import 'package:flutter/material.dart';
import 'package:mirit_reminders/core/database/tables/reminders_table.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';

/// Pre-built templates for common reminders (medication, doctor visit, etc.).
/// The picker shows them in a bottom sheet; the selected template returns
/// a partially-filled [Reminder] which the caller pushes into the
/// edit screen for the user to confirm/adjust.
class QuickAddTemplates {
  QuickAddTemplates._();

  /// Shows the template picker. Returns the chosen template's pre-built
  /// [Reminder], or null if the user cancelled.
  static Future<Reminder?> showPicker(BuildContext context) {
    return showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _QuickAddTemplatesSheet(),
    );
  }
}

/// Returns today at [hour]:[minute], or tomorrow if that moment already passed.
DateTime _todayOrTomorrow(int hour, int minute) {
  final now = DateTime.now();
  var dt = DateTime(now.year, now.month, now.day, hour, minute);
  if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
  return dt;
}

DateTime _daysFromNow(int days, int hour, int minute) {
  final now = DateTime.now();
  final base = DateTime(now.year, now.month, now.day, hour, minute);
  return base.add(Duration(days: days));
}

class _Template {
  final String label;
  final IconData icon;
  final Reminder Function() build;

  const _Template({
    required this.label,
    required this.icon,
    required this.build,
  });
}

List<_Template> _buildTemplates() {
  return [
    _Template(
      label: 'תרופה — כל בוקר',
      icon: Icons.medication,
      build: () => Reminder(
        title: 'תרופה — כל בוקר',
        scheduledAt: _todayOrTomorrow(8, 0),
        recurrenceType: RecurrenceType.daily,
        categoryId: 3, // בריאות
      ),
    ),
    _Template(
      label: 'תרופה — כל ערב',
      icon: Icons.medication,
      build: () => Reminder(
        title: 'תרופה — כל ערב',
        scheduledAt: _todayOrTomorrow(22, 0),
        recurrenceType: RecurrenceType.daily,
        categoryId: 3, // בריאות
      ),
    ),
    _Template(
      label: 'פגישת רופא',
      icon: Icons.medical_services,
      build: () => Reminder(
        title: 'פגישת רופא',
        scheduledAt: _daysFromNow(1, 10, 0),
        recurrenceType: RecurrenceType.none,
        categoryId: 4, // פגישות
      ),
    ),
    _Template(
      label: 'חידוש מרשם',
      icon: Icons.medical_services,
      build: () => Reminder(
        title: 'חידוש מרשם',
        scheduledAt: _daysFromNow(7, 9, 0),
        recurrenceType: RecurrenceType.monthly,
        categoryId: 3, // בריאות
      ),
    ),
    _Template(
      label: 'יום הולדת',
      icon: Icons.cake,
      build: () => Reminder(
        title: 'יום הולדת',
        scheduledAt: _todayOrTomorrow(9, 0),
        recurrenceType: RecurrenceType.yearly,
        categoryId: 2, // משפחה
      ),
    ),
    _Template(
      label: 'תשלום חשבון',
      icon: Icons.savings,
      build: () => Reminder(
        title: 'תשלום חשבון',
        scheduledAt: _daysFromNow(5, 10, 0),
        recurrenceType: RecurrenceType.monthly,
        categoryId: 5, // אחר
      ),
    ),
    _Template(
      label: 'פגישה משפחתית',
      icon: Icons.family_restroom,
      build: () => Reminder(
        title: 'פגישה משפחתית',
        scheduledAt: _daysFromNow(1, 18, 0),
        recurrenceType: RecurrenceType.none,
        categoryId: 2, // משפחה
      ),
    ),
    _Template(
      label: 'תור מספרה',
      icon: Icons.spa,
      build: () => Reminder(
        title: 'תור מספרה',
        scheduledAt: _daysFromNow(30, 11, 0),
        recurrenceType: RecurrenceType.none,
        categoryId: 5, // אחר
      ),
    ),
  ];
}

class _QuickAddTemplatesSheet extends StatelessWidget {
  const _QuickAddTemplatesSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final templates = _buildTemplates();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'תבניות מהירות',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'בחרי תבנית לפתיחה מהירה — תמיד אפשר להתאים אותה אחר כך.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final tpl = templates[index];
                  final preview = tpl.build();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                      foregroundColor: colorScheme.primary,
                      child: Icon(tpl.icon),
                    ),
                    title: Text(
                      tpl.label,
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      _subtitleFor(preview),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(tpl.build()),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

String _subtitleFor(Reminder r) {
  final when = _formatWhen(r.scheduledAt);
  final rec = _formatRecurrence(r.recurrenceType, r.scheduledAt);
  if (rec.isEmpty) return when;
  return '$when • $rec';
}

String _formatWhen(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diffDays = target.difference(today).inDays;
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');

  if (diffDays == 0) return 'היום $hh:$mm';
  if (diffDays == 1) return 'מחר $hh:$mm';
  return 'בעוד $diffDays ימים, $hh:$mm';
}

String _formatRecurrence(RecurrenceType type, DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  switch (type) {
    case RecurrenceType.none:
      return '';
    case RecurrenceType.daily:
      return 'כל יום $hh:$mm';
    case RecurrenceType.monthly:
      return 'חודשי';
    case RecurrenceType.yearly:
      return 'שנתי';
  }
}
