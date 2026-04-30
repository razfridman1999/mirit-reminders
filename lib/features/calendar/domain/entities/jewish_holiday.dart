enum HolidayType { eve, holiday, intermediateDays, fast, special }

class JewishHoliday {
  final String hebrewName;
  final DateTime date;
  final HolidayType type;

  const JewishHoliday({
    required this.hebrewName,
    required this.date,
    required this.type,
  });
}
