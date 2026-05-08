import 'package:mirit_reminders/core/utils/hebrew_date.dart';
import 'jewish_holiday.dart';
import 'jewish_holiday_calculator.dart';

/// Lazy, dynamic Jewish holiday lookup. Caches per Gregorian year so that
/// subsequent lookups within the same year are O(1).
class JewishHolidaysData {
  /// Soft upper bound on the number of cached Gregorian years. When the
  /// cache exceeds this size we evict the entry whose year is farthest from
  /// the year of the most recent lookup, keeping working-set entries hot.
  static const int _maxCachedYears = 30;

  static final Map<int, Map<DateTime, List<JewishHoliday>>>
      _cacheByGregorianYear = {};

  /// Returns all Jewish holidays falling on the given Gregorian date.
  static List<JewishHoliday> forDate(DateTime date) {
    final yearMap = _cacheByGregorianYear.putIfAbsent(
      date.year,
      () => _buildYear(date.year),
    );
    _evictIfNeeded(date.year);
    final key = DateTime(date.year, date.month, date.day);
    return yearMap[key] ?? const [];
  }

  /// Keeps the cache from growing unbounded. When over capacity, drop the
  /// year with the largest distance from [currentYear].
  static void _evictIfNeeded(int currentYear) {
    while (_cacheByGregorianYear.length > _maxCachedYears) {
      int? farthestYear;
      int farthestDistance = -1;
      for (final y in _cacheByGregorianYear.keys) {
        final d = (y - currentYear).abs();
        if (d > farthestDistance) {
          farthestDistance = d;
          farthestYear = y;
        }
      }
      if (farthestYear == null || farthestYear == currentYear) break;
      _cacheByGregorianYear.remove(farthestYear);
    }
  }

  static Map<DateTime, List<JewishHoliday>> _buildYear(int gregorianYear) {
    final map = <DateTime, List<JewishHoliday>>{};
    final hYearStart =
        gregorianToHebrew(DateTime(gregorianYear, 1, 1)).year;
    final hYearEnd =
        gregorianToHebrew(DateTime(gregorianYear, 12, 31)).year;
    // A Gregorian year overlaps two Hebrew years; iterate through both
    // (and one extra at each end so Erev RH and post-RH holidays land).
    for (int hy = hYearStart - 1; hy <= hYearEnd + 1; hy++) {
      for (final h in JewishHolidayCalculator.forHebrewYear(hy)) {
        if (h.date.year != gregorianYear) continue;
        final key = DateTime(h.date.year, h.date.month, h.date.day);
        map.putIfAbsent(key, () => []).add(h);
      }
    }
    return map;
  }
}
