/// Hebrew calendar algorithm based on Dershowitz & Reingold's
/// "Calendrical Calculations". Pure Dart, no external dependencies.
///
/// Months are numbered with Tishri = 7 (start of civil year) and Nisan = 1
/// (start of religious year), per the standard convention. In leap years,
/// Adar I = 12 and Adar II = 13. In non-leap years, Adar = 12.
library;

class HebrewDate {
  final int year;
  final int month; // 1=Nisan ... 13=Adar II
  final int day;

  const HebrewDate(this.year, this.month, this.day);

  @override
  String toString() => '$year-$month-$day';
}

const int _hebrewEpoch = -1373427; // RD of 1 Tishri AM 1 (Reingold–Dershowitz)

bool _gregorianLeapYear(int y) =>
    (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

int _absoluteFromGregorian(int year, int month, int day) {
  final y = year - 1;
  return 365 * y +
      (y ~/ 4) -
      (y ~/ 100) +
      (y ~/ 400) +
      ((367 * month - 362) ~/ 12) +
      (month <= 2 ? 0 : (_gregorianLeapYear(year) ? -1 : -2)) +
      day;
}

bool isHebrewLeapYear(int year) => ((7 * year + 1) % 19) < 7;

int _monthsInHebrewYear(int year) => isHebrewLeapYear(year) ? 13 : 12;

int _hebrewCalendarElapsedDays(int year) {
  final monthsElapsed = (235 * year - 234) ~/ 19;
  final partsElapsed = 12084 + 13753 * monthsElapsed;
  var day = 29 * monthsElapsed + partsElapsed ~/ 25920;
  if ((3 * (day + 1)) % 7 < 3) day++;
  return day;
}

int _hebrewYearLengthCorrection(int year) {
  final ny0 = _hebrewCalendarElapsedDays(year - 1);
  final ny1 = _hebrewCalendarElapsedDays(year);
  final ny2 = _hebrewCalendarElapsedDays(year + 1);
  if (ny2 - ny1 == 356) return 2;
  if (ny1 - ny0 == 382) return 1;
  return 0;
}

int _daysInHebrewYear(int year) =>
    _hebrewCalendarElapsedDays(year + 1) +
    _hebrewYearLengthCorrection(year + 1) -
    _hebrewCalendarElapsedDays(year) -
    _hebrewYearLengthCorrection(year);

bool _longHeshvan(int year) => _daysInHebrewYear(year) % 10 == 5;

bool _shortKislev(int year) => _daysInHebrewYear(year) % 10 == 3;

int daysInHebrewMonth(int year, int month) {
  // Defensive: month 13 only exists in leap years.
  if (month == 13 && !isHebrewLeapYear(year)) return 0;
  if (const {2, 4, 6, 10, 13}.contains(month)) return 29;
  if (month == 12 && !isHebrewLeapYear(year)) return 29;
  if (month == 8 && !_longHeshvan(year)) return 29;
  if (month == 9 && _shortKislev(year)) return 29;
  return 30;
}

int _newYearDayRD(int year) =>
    _hebrewEpoch +
    _hebrewCalendarElapsedDays(year) +
    _hebrewYearLengthCorrection(year);

int _absoluteFromHebrew(int year, int month, int day) {
  int rd = _newYearDayRD(year);
  if (month < 7) {
    final monthsInYear = _monthsInHebrewYear(year);
    for (int m = 7; m <= monthsInYear; m++) {
      rd += daysInHebrewMonth(year, m);
    }
    for (int m = 1; m < month; m++) {
      rd += daysInHebrewMonth(year, m);
    }
  } else {
    for (int m = 7; m < month; m++) {
      rd += daysInHebrewMonth(year, m);
    }
  }
  return rd + day - 1;
}

HebrewDate gregorianToHebrew(DateTime date) {
  final rd = _absoluteFromGregorian(date.year, date.month, date.day);
  int year = ((rd - _hebrewEpoch) ~/ 366) + 1;
  while (rd >= _newYearDayRD(year + 1)) {
    year++;
  }
  int month = (rd < _absoluteFromHebrew(year, 1, 1)) ? 7 : 1;
  while (rd > _absoluteFromHebrew(year, month, daysInHebrewMonth(year, month))) {
    month++;
  }
  final day = rd - _absoluteFromHebrew(year, month, 1) + 1;
  return HebrewDate(year, month, day);
}

DateTime hebrewToGregorian(HebrewDate hd) {
  final rd = _absoluteFromHebrew(hd.year, hd.month, hd.day);
  // Convert RD back to Gregorian.
  int year = (rd / 366).floor();
  while (rd >= _absoluteFromGregorian(year + 1, 1, 1)) {
    year++;
  }
  int month = 1;
  while (rd >
      _absoluteFromGregorian(
        year,
        month,
        _gregorianMonthDays(year, month),
      )) {
    month++;
  }
  final day = rd - _absoluteFromGregorian(year, month, 1) + 1;
  return DateTime(year, month, day);
}

int _gregorianMonthDays(int year, int month) {
  const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month == 2 && _gregorianLeapYear(year)) return 29;
  return days[month - 1];
}

// ─── Formatting (Hebrew text) ────────────────────────────────────────────────

const List<String> _hebrewMonthsRegular = [
  '', // 0 unused
  'ניסן',
  'אייר',
  'סיון',
  'תמוז',
  'אב',
  'אלול',
  'תשרי',
  'חשון',
  'כסלו',
  'טבת',
  'שבט',
  'אדר',
  '', // 13 unused in non-leap
];

const List<String> _hebrewMonthsLeap = [
  '',
  'ניסן',
  'אייר',
  'סיון',
  'תמוז',
  'אב',
  'אלול',
  'תשרי',
  'חשון',
  'כסלו',
  'טבת',
  'שבט',
  'אדר א׳',
  'אדר ב׳',
];

String hebrewMonthName(int year, int month) {
  if (isHebrewLeapYear(year)) return _hebrewMonthsLeap[month];
  return _hebrewMonthsRegular[month];
}

const Map<int, String> _gematriaUnits = {
  1: 'א',
  2: 'ב',
  3: 'ג',
  4: 'ד',
  5: 'ה',
  6: 'ו',
  7: 'ז',
  8: 'ח',
  9: 'ט',
};

const Map<int, String> _gematriaTens = {
  10: 'י',
  20: 'כ',
  30: 'ל',
  40: 'מ',
  50: 'נ',
  60: 'ס',
  70: 'ע',
  80: 'פ',
  90: 'צ',
};

const Map<int, String> _gematriaHundreds = {
  100: 'ק',
  200: 'ר',
  300: 'ש',
  400: 'ת',
};

String _gematriaShort(int n) {
  // Numbers 1..30 (used for days)
  if (n == 15) return 'טו';
  if (n == 16) return 'טז';
  final tens = (n ~/ 10) * 10;
  final units = n % 10;
  final tStr = tens > 0 ? _gematriaTens[tens]! : '';
  final uStr = units > 0 ? _gematriaUnits[units]! : '';
  return '$tStr$uStr';
}

/// Hebrew letters for a day, with punctuation marks (geresh/gershayim).
/// e.g. 1 → "א׳", 15 → "ט״ו", 22 → "כ״ב"
String hebrewDayLetters(int day) {
  final raw = _gematriaShort(day);
  if (raw.length == 1) return '$raw׳'; // single letter + geresh
  return '${raw.substring(0, raw.length - 1)}״${raw.substring(raw.length - 1)}'; // gershayim before last letter
}

/// Hebrew letters for a year, e.g. 5786 → "תשפ״ו"
/// Drops the thousands digit (5) by convention.
String hebrewYearLetters(int year) {
  int n = year % 1000; // e.g. 786
  final buffer = StringBuffer();
  // Hundreds: any 100s up to 400, then split (e.g. 500 = ת"ק, 700 = ת"ש)
  while (n >= 400) {
    buffer.write('ת');
    n -= 400;
  }
  if (n >= 100) {
    final h = (n ~/ 100) * 100;
    buffer.write(_gematriaHundreds[h]!);
    n -= h;
  }
  if (n == 15) {
    buffer.write('טו');
    n = 0;
  } else if (n == 16) {
    buffer.write('טז');
    n = 0;
  } else {
    final tens = (n ~/ 10) * 10;
    if (tens > 0) {
      buffer.write(_gematriaTens[tens]!);
      n -= tens;
    }
    if (n > 0) {
      buffer.write(_gematriaUnits[n]!);
    }
  }
  final s = buffer.toString();
  if (s.length <= 1) return '$s׳';
  return '${s.substring(0, s.length - 1)}״${s.substring(s.length - 1)}';
}

/// Compact label for the day (just the day in gematria), e.g. "ט״ו".
String hebrewDayLabel(DateTime date) {
  final hd = gregorianToHebrew(date);
  return hebrewDayLetters(hd.day);
}

/// Full label with day + month, e.g. "ט״ו אייר".
String hebrewDayMonthLabel(DateTime date) {
  final hd = gregorianToHebrew(date);
  return '${hebrewDayLetters(hd.day)} ${hebrewMonthName(hd.year, hd.month)}';
}

/// Full label with day + month + year, e.g. "ט״ו אייר תשפ״ו".
String hebrewFullLabel(DateTime date) {
  final hd = gregorianToHebrew(date);
  return '${hebrewDayLetters(hd.day)} '
      '${hebrewMonthName(hd.year, hd.month)} '
      '${hebrewYearLetters(hd.year)}';
}
