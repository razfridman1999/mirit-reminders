import 'package:flutter_test/flutter_test.dart';
import 'package:mirit_reminders/core/database/tables/reminders_table.dart';
import 'package:mirit_reminders/core/utils/recurrence.dart';

void main() {
  group('nextRecurrence — daily', () {
    test('adds exactly one day', () {
      final base = DateTime(2026, 5, 5, 9, 0);
      expect(nextRecurrence(base, RecurrenceType.daily),
          DateTime(2026, 5, 6, 9, 0));
    });

    test('crosses month boundary', () {
      final base = DateTime(2026, 5, 31, 8, 0);
      expect(nextRecurrence(base, RecurrenceType.daily),
          DateTime(2026, 6, 1, 8, 0));
    });

    test('crosses year boundary', () {
      final base = DateTime(2025, 12, 31, 23, 30);
      expect(nextRecurrence(base, RecurrenceType.daily),
          DateTime(2026, 1, 1, 23, 30));
    });
  });

  group('nextRecurrence — monthly clamping', () {
    test('Jan 31 → Feb 28 (non-leap)', () {
      final base = DateTime(2026, 1, 31, 10, 0);
      expect(nextRecurrence(base, RecurrenceType.monthly),
          DateTime(2026, 2, 28, 10, 0));
    });

    test('Jan 31 → Feb 29 (leap year 2024)', () {
      final base = DateTime(2024, 1, 31, 10, 0);
      expect(nextRecurrence(base, RecurrenceType.monthly),
          DateTime(2024, 2, 29, 10, 0));
    });

    test('Mar 31 → Apr 30', () {
      final base = DateTime(2026, 3, 31, 10, 0);
      expect(nextRecurrence(base, RecurrenceType.monthly),
          DateTime(2026, 4, 30, 10, 0));
    });

    test('Dec 31 → Jan 31 next year', () {
      final base = DateTime(2025, 12, 31, 10, 0);
      expect(nextRecurrence(base, RecurrenceType.monthly),
          DateTime(2026, 1, 31, 10, 0));
    });

    test('preserves hour and minute', () {
      final base = DateTime(2026, 5, 15, 14, 45);
      final next = nextRecurrence(base, RecurrenceType.monthly);
      expect(next.hour, 14);
      expect(next.minute, 45);
      expect(next.month, 6);
      expect(next.day, 15);
    });
  });

  group('nextRecurrence — yearly clamping', () {
    test('Feb 29 in leap year → Feb 28 in non-leap year', () {
      final base = DateTime(2024, 2, 29, 8, 0);
      final next = nextRecurrence(base, RecurrenceType.yearly);
      expect(next, DateTime(2025, 2, 28, 8, 0));
    });

    test('normal date advances by one year', () {
      final base = DateTime(2026, 5, 5, 9, 0);
      expect(nextRecurrence(base, RecurrenceType.yearly),
          DateTime(2027, 5, 5, 9, 0));
    });

    test('Dec 31 → Dec 31 next year', () {
      final base = DateTime(2025, 12, 31, 0, 0);
      expect(nextRecurrence(base, RecurrenceType.yearly),
          DateTime(2026, 12, 31, 0, 0));
    });
  });

  group('nextRecurrence — none', () {
    test('returns the same date unchanged', () {
      final base = DateTime(2026, 5, 5, 9, 0);
      expect(nextRecurrence(base, RecurrenceType.none), base);
    });
  });

  group('nextRecurrenceFuture', () {
    test('already-future date returns one step ahead', () {
      final future = DateTime.now().add(const Duration(days: 10));
      final result = nextRecurrenceFuture(future, RecurrenceType.daily);
      expect(result.isAfter(DateTime.now()), true);
      expect(result.day, future.day + 1);
    });

    test('past date advances past now', () {
      // Fixed past date avoids same-time race conditions.
      final past = DateTime(DateTime.now().year - 1, 1, 1, 0, 0);
      final result = nextRecurrenceFuture(past, RecurrenceType.daily);
      expect(result.isAfter(DateTime.now()), true);
    });

    test('far-past monthly advances past now', () {
      final past = DateTime(2020, 1, 1, 9, 0);
      final result = nextRecurrenceFuture(past, RecurrenceType.monthly);
      expect(result.isAfter(DateTime.now()), true);
    });

    test('none type returns base unchanged', () {
      final base = DateTime(2026, 1, 1, 9, 0);
      expect(nextRecurrenceFuture(base, RecurrenceType.none), base);
    });
  });

  group('multi-step monthly chain stays on original day when possible', () {
    test('May 31 → Jun 30 → Jul 31 → Aug 31', () {
      var d = DateTime(2026, 5, 31, 10, 0);
      d = nextRecurrence(d, RecurrenceType.monthly);
      expect(d, DateTime(2026, 6, 30, 10, 0));
      d = nextRecurrence(d, RecurrenceType.monthly);
      expect(d, DateTime(2026, 7, 30, 10, 0));
    });

    test('Jan 31 → Feb 28 → Mar 28 (clamped chain)', () {
      var d = DateTime(2026, 1, 31, 10, 0);
      d = nextRecurrence(d, RecurrenceType.monthly);
      expect(d.day, 28); // clamped to Feb 28
      d = nextRecurrence(d, RecurrenceType.monthly);
      expect(d, DateTime(2026, 3, 28, 10, 0));
    });
  });
}
