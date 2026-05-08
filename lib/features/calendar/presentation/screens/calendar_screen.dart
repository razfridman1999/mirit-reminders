import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/core/utils/hebrew_date.dart';
import 'package:mirit_reminders/core/widgets/month_year_picker_dialog.dart';
import 'package:mirit_reminders/features/calendar/domain/entities/jewish_holiday.dart';
import 'package:mirit_reminders/features/calendar/domain/entities/jewish_holidays_data.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:mirit_reminders/features/reminders/presentation/providers/reminders_provider.dart';
import 'package:mirit_reminders/features/reminders/presentation/screens/reminder_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('he_IL', null);
  }

  List<JewishHoliday> _getHolidaysForDay(DateTime day) =>
      JewishHolidaysData.forDate(day);

  List<Reminder> _getRemindersForDay(DateTime day, List<Reminder> allReminders) {
    return allReminders.where((r) {
      final s = r.scheduledAt;
      return s.year == day.year && s.month == day.month && s.day == day.day;
    }).toList();
  }

  List<Object> _getEventsForDay(DateTime day, List<Reminder> allReminders) {
    final events = <Object>[];
    events.addAll(_getHolidaysForDay(day));
    events.addAll(_getRemindersForDay(day, allReminders));
    return events;
  }

  // Single uniform color for all holiday types per client preference.
  Color _holidayColor(HolidayType _) => AppColors.primary;

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    bool isToday, {
    bool selected = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final holidays = _getHolidaysForDay(day);
    final firstHoliday = holidays.isNotEmpty ? holidays.first : null;
    final hd = gregorianToHebrew(day);
    final hebDay = hebrewDayLetters(hd.day);

    final mainColor = selected
        ? colorScheme.onPrimary
        : isToday
            ? colorScheme.primary
            : null;
    final hebColor = selected
        ? colorScheme.onPrimary.withValues(alpha: 0.85)
        : colorScheme.onSurfaceVariant;

    // Clamp text scale to 1.0 inside calendar cells. Date letters are too
    // small for accessibility scaling and would otherwise overflow rowHeight.
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: selected
            ? BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              )
            : isToday
                ? BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  )
                : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: mainColor,
                fontWeight:
                    isToday || selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
                height: 1.0,
              ),
            ),
            Text(
              hebDay,
              style: TextStyle(
                fontSize: 9,
                color: hebColor,
                height: 1.1,
              ),
            ),
            if (firstHoliday != null)
              Text(
                firstHoliday.hebrewName,
                style: TextStyle(
                  fontSize: 7,
                  color: selected
                      ? colorScheme.onPrimary.withValues(alpha: 0.85)
                      : _holidayColor(firstHoliday.type),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildEventsList(BuildContext context, List<Reminder> allReminders) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final holidays = _getHolidaysForDay(_selectedDay);
    final reminders = _getRemindersForDay(_selectedDay, allReminders);
    final hebFull = hebrewFullLabel(_selectedDay);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text(
            hebFull,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (holidays.isEmpty && reminders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_busy_outlined,
                  size: 56,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'אין אירועים ביום זה',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ...holidays.map(
          (holiday) => ListTile(
            leading: Icon(
              Icons.star_rounded,
              color: _holidayColor(holiday.type),
            ),
            title: Text(
              holiday.hebrewName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              _holidayTypeLabel(holiday.type),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        ...reminders.map(
          (reminder) => ListTile(
            leading: Icon(
              Icons.notifications_rounded,
              color: colorScheme.primary,
            ),
            title: Text(
              reminder.title,
              style: TextStyle(color: colorScheme.onSurface),
            ),
            subtitle: Text(
              _formatTime(reminder.scheduledAt),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_left, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReminderDetailScreen(reminder: reminder),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickMonthYear() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => MonthYearPickerDialog(initial: _focusedDay),
    );
    if (picked != null) {
      setState(() => _focusedDay = picked);
    }
  }

  String _holidayTypeLabel(HolidayType type) {
    switch (type) {
      case HolidayType.holiday:
        return 'חג';
      case HolidayType.eve:
        return 'ערב חג';
      case HolidayType.intermediateDays:
        return 'חול המועד';
      case HolidayType.fast:
        return 'צום';
      case HolidayType.special:
        return 'יום מיוחד';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final remindersAsync = ref.watch(allRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.calendar),
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _CalendarErrorState(
          onRetry: () => ref.invalidate(allRemindersProvider),
        ),
        data: (allReminders) => Column(
          children: [
            // Clamp text scale around the calendar widget so the header
            // title and day-of-week row don't overflow / get cropped at
            // the "ענק" font size. Day cells already clamp internally.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.0,
              child: TableCalendar(
              firstDay: DateTime(1900, 1, 1),
              lastDay: DateTime(2200, 12, 31),
              focusedDay: _focusedDay,
              rowHeight: 56,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onHeaderTapped: (_) => _pickMonthYear(),
              calendarFormat: CalendarFormat.month,
              locale: 'he_IL',
              startingDayOfWeek: StartingDayOfWeek.sunday,
              availableGestures: AvailableGestures.horizontalSwipe,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
              ),
              eventLoader: (day) => _getEventsForDay(day, allReminders),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) =>
                    _buildDayCell(context, day, false),
                todayBuilder: (context, day, focusedDay) =>
                    _buildDayCell(context, day, true),
                selectedBuilder: (context, day, focusedDay) =>
                    _buildDayCell(context, day, false, selected: true),
              ),
            ),
            ),
            Divider(height: 1, color: colorScheme.outline),
            Expanded(
              child: _buildEventsList(context, allReminders),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarErrorState extends StatelessWidget {
  const _CalendarErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'אירעה שגיאה בטעינת הלוח',
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
