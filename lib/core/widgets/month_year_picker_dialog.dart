import 'package:flutter/material.dart';

/// A simple "jump to month/year" picker dialog. Used by the calendar
/// screen header tap, and by the date picker flow in add-edit-reminder.
///
/// Returns `DateTime(pickedYear, pickedMonth, 1)` on confirm, or `null`
/// if the user cancelled.
class MonthYearPickerDialog extends StatefulWidget {
  const MonthYearPickerDialog({
    super.key,
    required this.initial,
    this.minYear = 1900,
    this.maxYear = 2200,
  });

  final DateTime initial;
  final int minYear;
  final int maxYear;

  @override
  State<MonthYearPickerDialog> createState() =>
      _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<MonthYearPickerDialog> {
  late int _year;
  late int _month;

  static const _monthNames = [
    'ינואר',
    'פברואר',
    'מרץ',
    'אפריל',
    'מאי',
    'יוני',
    'יולי',
    'אוגוסט',
    'ספטמבר',
    'אוקטובר',
    'נובמבר',
    'דצמבר',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('בחרי חודש ושנה'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'שנה קודמת',
                  onPressed: _year > widget.minYear
                      ? () => setState(() => _year--)
                      : null,
                ),
                Text(
                  '$_year',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'שנה הבאה',
                  onPressed: _year < widget.maxYear
                      ? () => setState(() => _year++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: List.generate(12, (i) {
                final m = i + 1;
                final isSelected = m == _month;
                return Material(
                  color: isSelected
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _month = m),
                    child: Center(
                      child: Text(
                        _monthNames[i],
                        style: TextStyle(
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ביטול'),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.of(context).pop(DateTime(_year, _month, 1)),
          child: const Text('אישור'),
        ),
      ],
    );
  }
}
