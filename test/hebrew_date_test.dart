import 'package:flutter_test/flutter_test.dart';
import 'package:mirit_reminders/core/utils/hebrew_date.dart';

void main() {
  group('gregorianToHebrew', () {
    test('Pesach Sheni 2026 = 14 Iyar 5786', () {
      final h = gregorianToHebrew(DateTime(2026, 5, 1));
      expect(h.year, 5786);
      expect(h.month, 2); // Iyar
      expect(h.day, 14);
    });

    test('Rosh Hashanah 5786 = 23 Sept 2025 = 1 Tishri 5786', () {
      final h = gregorianToHebrew(DateTime(2025, 9, 23));
      expect(h.year, 5786);
      expect(h.month, 7); // Tishri
      expect(h.day, 1);
    });

    test('Rosh Hashanah 5785 = 3 Oct 2024 = 1 Tishri 5785', () {
      final h = gregorianToHebrew(DateTime(2024, 10, 3));
      expect(h.year, 5785);
      expect(h.month, 7);
      expect(h.day, 1);
    });

    test('Pesach 5786 = 2 April 2026 = 15 Nisan 5786', () {
      final h = gregorianToHebrew(DateTime(2026, 4, 2));
      expect(h.year, 5786);
      expect(h.month, 1); // Nisan
      expect(h.day, 15);
    });

    test('Yom Kippur 5786 = 2 Oct 2025 = 10 Tishri 5786', () {
      final h = gregorianToHebrew(DateTime(2025, 10, 2));
      expect(h.year, 5786);
      expect(h.month, 7);
      expect(h.day, 10);
    });
  });

  group('hebrewToGregorian round-trip', () {
    test('round-trip 2026-05-01', () {
      final h = gregorianToHebrew(DateTime(2026, 5, 1));
      final g = hebrewToGregorian(h);
      expect(g.year, 2026);
      expect(g.month, 5);
      expect(g.day, 1);
    });

    test('round-trip 2025-09-23', () {
      final h = gregorianToHebrew(DateTime(2025, 9, 23));
      final g = hebrewToGregorian(h);
      expect(g.year, 2025);
      expect(g.month, 9);
      expect(g.day, 23);
    });
  });

  group('formatting', () {
    test('hebrewDayLetters 1=א׳, 15=ט״ו, 22=כ״ב', () {
      expect(hebrewDayLetters(1), 'א׳');
      expect(hebrewDayLetters(15), 'ט״ו');
      expect(hebrewDayLetters(16), 'ט״ז');
      expect(hebrewDayLetters(22), 'כ״ב');
      expect(hebrewDayLetters(30), 'ל׳');
    });

    test('hebrewYearLetters 5786 = תשפ״ו', () {
      expect(hebrewYearLetters(5786), 'תשפ״ו');
    });

    test('hebrewDayMonthLabel 2026-05-01 = ט״ו אייר (off-by-one check)', () {
      // Day 14 → י"ד אייר, not ט"ו
      expect(hebrewDayMonthLabel(DateTime(2026, 5, 1)), 'י״ד אייר');
    });

    test('hebrewMonthName 5786 (regular) Adar=12', () {
      expect(hebrewMonthName(5786, 12), 'אדר');
    });

    test('isHebrewLeapYear: 5784 leap, 5786 not, 5787 leap', () {
      expect(isHebrewLeapYear(5784), true);
      expect(isHebrewLeapYear(5785), false);
      expect(isHebrewLeapYear(5786), false);
      expect(isHebrewLeapYear(5787), true);
    });
  });

  group('leap year handling', () {
    test('Purim 5784 (leap) = Adar II 14 = March 24, 2024', () {
      // 5784 is leap; Purim is 14 Adar II (month 13)
      final purim = hebrewToGregorian(const HebrewDate(5784, 13, 14));
      expect(purim.year, 2024);
      expect(purim.month, 3);
      expect(purim.day, 24);
    });

    test('Adar I 14 in 5784 ≠ Purim (it is Purim Katan)', () {
      final adarI14 = hebrewToGregorian(const HebrewDate(5784, 12, 14));
      // Should be Feb 23, 2024
      expect(adarI14.year, 2024);
      expect(adarI14.month, 2);
      expect(adarI14.day, 23);
    });

    test('hebrewMonthName 5784 leap year shows Adar I and Adar II', () {
      expect(hebrewMonthName(5784, 12), 'אדר א׳');
      expect(hebrewMonthName(5784, 13), 'אדר ב׳');
    });
  });

  group('extended date range (10+ years)', () {
    test('Rosh Hashanah 5800 (year ~2039)', () {
      final g = hebrewToGregorian(const HebrewDate(5800, 7, 1));
      // Sanity: should be in the 2039-2040 range
      expect(g.year >= 2039 && g.year <= 2040, true,
          reason: 'got $g');
    });

    test('Far future: Rosh Hashanah 5900 round trip', () {
      final g = hebrewToGregorian(const HebrewDate(5900, 7, 1));
      final h = gregorianToHebrew(g);
      expect(h.year, 5900);
      expect(h.month, 7);
      expect(h.day, 1);
    });

    test('Past: Rosh Hashanah 5709 (Israel founded year, 1948)', () {
      final g = hebrewToGregorian(const HebrewDate(5709, 7, 1));
      // Sept/Oct 1948
      expect(g.year, 1948);
    });
  });

  group('year-end boundaries', () {
    test('29 Elul (last day of year) → 1 Tishri (next year) is 1 day apart',
        () {
      final lastDay = hebrewToGregorian(const HebrewDate(5786, 6, 29));
      final newYear = hebrewToGregorian(const HebrewDate(5787, 7, 1));
      expect(newYear.difference(lastDay).inDays, 1);
    });
  });
}
