import 'package:mirit_reminders/core/database/tables/reminders_table.dart';

/// Compute the next occurrence of a recurring reminder, clamping the day
/// to the last valid day of the target month so Jan 31 → Feb 28/29 instead
/// of Mar 3 (which is what naive `DateTime` arithmetic auto-rolls to).
DateTime nextRecurrence(DateTime base, RecurrenceType type) {
  switch (type) {
    case RecurrenceType.daily:
      return base.add(const Duration(days: 1));
    case RecurrenceType.monthly:
      return _addMonthsClamped(base, 1);
    case RecurrenceType.yearly:
      final clampedDay =
          _clampDayToMonth(base.year + 1, base.month, base.day);
      return DateTime(
          base.year + 1, base.month, clampedDay, base.hour, base.minute);
    case RecurrenceType.none:
      return base;
  }
}

/// Advance to the next future occurrence, walking past any past ones.
/// Used after marking a recurring reminder as completed and after a
/// "skip next" action.
DateTime nextRecurrenceFuture(DateTime base, RecurrenceType type) {
  if (type == RecurrenceType.none) return base;
  var next = nextRecurrence(base, type);
  while (next.isBefore(DateTime.now())) {
    next = nextRecurrence(next, type);
  }
  return next;
}

DateTime _addMonthsClamped(DateTime base, int months) {
  final totalMonths = base.month - 1 + months;
  final targetYear = base.year + (totalMonths ~/ 12);
  final targetMonth = (totalMonths % 12) + 1;
  final clampedDay = _clampDayToMonth(targetYear, targetMonth, base.day);
  return DateTime(
      targetYear, targetMonth, clampedDay, base.hour, base.minute);
}

int _clampDayToMonth(int year, int month, int day) {
  // Day 0 of month+1 rolls back to the last day of `month`.
  final lastDay = DateTime(year, month + 1, 0).day;
  return day > lastDay ? lastDay : day;
}
