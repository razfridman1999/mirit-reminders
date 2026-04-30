import 'package:intl/intl.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';

class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'he');
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'he');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'he');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'he');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String formatMonthYear(DateTime date) => _monthYear.format(date);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static bool isTomorrow(DateTime date) =>
      isSameDay(date, DateTime.now().add(const Duration(days: 1)));

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  /// Returns a Hebrew label for a date relative to today.
  static String relativeDateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = date.difference(today).inDays;

    if (diff == 0) return AppStrings.today;
    if (diff == 1) return AppStrings.tomorrow;
    if (diff < 0) return 'עבר';
    if (diff <= 7) return 'השבוע';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Returns a group header label when [index] starts a new date group,
  /// or null if the item belongs to the same group as the previous item.
  static String? groupLabel(List<DateTime> dates, int index) {
    final label = relativeDateLabel(dates[index]);
    if (index == 0) return label;
    final prevLabel = relativeDateLabel(dates[index - 1]);
    return label != prevLabel ? label : null;
  }
}
