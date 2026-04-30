import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/features/calendar/domain/entities/jewish_holiday.dart';
import 'package:mirit_reminders/features/calendar/domain/entities/jewish_holidays_data.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:mirit_reminders/features/reminders/presentation/providers/reminders_provider.dart';

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

  List<JewishHoliday> _getHolidaysForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return JewishHolidaysData.holidayMap[key] ?? [];
  }

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

  Color _holidayColor(HolidayType type) {
    switch (type) {
      case HolidayType.holiday:
        return AppColors.primary;
      case HolidayType.eve:
        return AppColors.primaryLight;
      case HolidayType.intermediateDays:
        return AppColors.secondary;
      case HolidayType.fast:
        return AppColors.error;
      case HolidayType.special:
        return AppColors.warning;
    }
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    bool isToday, {
    bool selected = false,
  }) {
    final holidays = _getHolidaysForDay(day);
    final firstHoliday = holidays.isNotEmpty ? holidays.first : null;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: selected
          ? const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)
          : isToday
              ? BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                )
              : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : isToday
                      ? AppColors.primary
                      : null,
              fontWeight:
                  isToday || selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          if (firstHoliday != null)
            Text(
              firstHoliday.hebrewName,
              style: const TextStyle(fontSize: 6, color: AppColors.secondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildEventsList(List<Reminder> allReminders) {
    final holidays = _getHolidaysForDay(_selectedDay);
    final reminders = _getRemindersForDay(_selectedDay, allReminders);

    if (holidays.isEmpty && reminders.isEmpty) {
      return Center(
        child: Text(
          'אין אירועים ביום זה',
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        ...holidays.map(
          (holiday) => ListTile(
            leading: Icon(Icons.star_rounded, color: _holidayColor(holiday.type)),
            title: Text(
              holiday.hebrewName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            subtitle: Text(
              _holidayTypeLabel(holiday.type),
              style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        ...reminders.map(
          (reminder) => ListTile(
            leading: const Icon(Icons.notifications_rounded, color: AppColors.primary),
            title: Text(
              reminder.title,
              style: const TextStyle(color: AppColors.onSurface),
            ),
            subtitle: Text(
              _formatTime(reminder.scheduledAt),
              style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
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
    final remindersAsync = ref.watch(allRemindersProvider);
    final allReminders = remindersAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.calendar),
        centerTitle: true,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2025, 1, 1),
            lastDay: DateTime(2027, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarFormat: CalendarFormat.month,
            locale: 'he_IL',
            startingDayOfWeek: StartingDayOfWeek.sunday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
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
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: _buildEventsList(allReminders),
          ),
        ],
      ),
    );
  }
}
