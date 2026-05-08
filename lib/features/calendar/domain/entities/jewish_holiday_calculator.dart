import 'package:mirit_reminders/core/utils/hebrew_date.dart';
import 'jewish_holiday.dart';

/// Computes Jewish holidays dynamically for any Hebrew year.
/// Replaces the hard-coded list in JewishHolidaysData.
class JewishHolidayCalculator {
  /// Returns all holidays for the given Hebrew year (Tishri 1 → Elul 29).
  static List<JewishHoliday> forHebrewYear(int hebrewYear) {
    final list = <JewishHoliday>[];

    DateTime g(int month, int day) =>
        hebrewToGregorian(HebrewDate(hebrewYear, month, day));

    // ─── Tishri (month 7) ────────────────────────────────────────────────
    // Erev Rosh HaShanah = 29 Elul of *previous* year — handled by previous
    // year iteration. Add it here for completeness, treating "previous year"
    // explicitly.
    list.add(JewishHoliday(
      hebrewName: 'ערב ראש השנה',
      date: hebrewToGregorian(HebrewDate(hebrewYear - 1, 6, 29)),
      type: HolidayType.eve,
    ));
    list.add(JewishHoliday(
      hebrewName: 'ראש השנה',
      date: g(7, 1),
      type: HolidayType.holiday,
    ));
    list.add(JewishHoliday(
      hebrewName: 'ראש השנה',
      date: g(7, 2),
      type: HolidayType.holiday,
    ));

    // Tzom Gedalia — 3 Tishri, postponed to 4 if Shabbat
    var tzomG = g(7, 3);
    if (tzomG.weekday == DateTime.saturday) tzomG = g(7, 4);
    list.add(JewishHoliday(
      hebrewName: 'צום גדליה',
      date: tzomG,
      type: HolidayType.fast,
    ));

    list.add(JewishHoliday(
      hebrewName: 'ערב יום כיפור',
      date: g(7, 9),
      type: HolidayType.eve,
    ));
    list.add(JewishHoliday(
      hebrewName: 'יום כיפור',
      date: g(7, 10),
      type: HolidayType.holiday,
    ));

    list.add(JewishHoliday(
      hebrewName: 'ערב סוכות',
      date: g(7, 14),
      type: HolidayType.eve,
    ));
    list.add(JewishHoliday(
      hebrewName: 'סוכות',
      date: g(7, 15),
      type: HolidayType.holiday,
    ));
    for (int d = 16; d <= 20; d++) {
      list.add(JewishHoliday(
        hebrewName: 'חול המועד סוכות',
        date: g(7, d),
        type: HolidayType.intermediateDays,
      ));
    }
    list.add(JewishHoliday(
      hebrewName: 'הושענא רבה',
      date: g(7, 21),
      type: HolidayType.special,
    ));
    list.add(JewishHoliday(
      hebrewName: 'שמיני עצרת / שמחת תורה',
      date: g(7, 22),
      type: HolidayType.holiday,
    ));

    // ─── Hanukkah (Kislev 25 → 8 days) ───────────────────────────────────
    final hanukkahStart = g(9, 25);
    for (int i = 0; i < 8; i++) {
      list.add(JewishHoliday(
        hebrewName: 'חנוכה - נר ${i + 1}',
        date: hanukkahStart.add(Duration(days: i)),
        type: HolidayType.special,
      ));
    }

    // ─── Asara b'Tevet (10 Tevet) ────────────────────────────────────────
    list.add(JewishHoliday(
      hebrewName: 'צום עשרה בטבת',
      date: g(10, 10),
      type: HolidayType.fast,
    ));

    // ─── Tu BiShvat (15 Shevat) ──────────────────────────────────────────
    list.add(JewishHoliday(
      hebrewName: 'ט״ו בשבט',
      date: g(11, 15),
      type: HolidayType.special,
    ));

    // ─── Purim — Adar 14 (Adar II in leap years) ─────────────────────────
    final purimMonth = isHebrewLeapYear(hebrewYear) ? 13 : 12;
    list.add(JewishHoliday(
      hebrewName: 'תענית אסתר',
      date: _movePurimFastIfShabbat(hebrewYear, purimMonth),
      type: HolidayType.fast,
    ));
    list.add(JewishHoliday(
      hebrewName: 'ערב פורים',
      date: hebrewToGregorian(HebrewDate(hebrewYear, purimMonth, 13)),
      type: HolidayType.eve,
    ));
    list.add(JewishHoliday(
      hebrewName: 'פורים',
      date: hebrewToGregorian(HebrewDate(hebrewYear, purimMonth, 14)),
      type: HolidayType.holiday,
    ));
    list.add(JewishHoliday(
      hebrewName: 'שושן פורים',
      date: hebrewToGregorian(HebrewDate(hebrewYear, purimMonth, 15)),
      type: HolidayType.special,
    ));

    // ─── Pesach (Nisan 15-21) ────────────────────────────────────────────
    list.add(JewishHoliday(
      hebrewName: 'ערב פסח',
      date: g(1, 14),
      type: HolidayType.eve,
    ));
    list.add(JewishHoliday(
      hebrewName: 'פסח',
      date: g(1, 15),
      type: HolidayType.holiday,
    ));
    for (int d = 16; d <= 20; d++) {
      list.add(JewishHoliday(
        hebrewName: 'חול המועד פסח',
        date: g(1, d),
        type: HolidayType.intermediateDays,
      ));
    }
    list.add(JewishHoliday(
      hebrewName: 'שביעי של פסח',
      date: g(1, 21),
      type: HolidayType.holiday,
    ));

    // ─── Yom HaShoah (Nisan 27, with postponements) ──────────────────────
    var yomHaShoah = g(1, 27);
    if (yomHaShoah.weekday == DateTime.friday) {
      yomHaShoah = g(1, 26);
    } else if (yomHaShoah.weekday == DateTime.sunday) {
      yomHaShoah = g(1, 28);
    }
    list.add(JewishHoliday(
      hebrewName: 'יום השואה',
      date: yomHaShoah,
      type: HolidayType.special,
    ));

    // ─── Yom HaZikaron / Yom HaAtzma'ut (4-5 Iyar, with postponements) ──
    final iyar5Weekday = g(2, 5).weekday;
    int yhzDay, yhaDay;
    if (iyar5Weekday == DateTime.friday) {
      yhzDay = 3;
      yhaDay = 4;
    } else if (iyar5Weekday == DateTime.saturday) {
      yhzDay = 2;
      yhaDay = 3;
    } else if (iyar5Weekday == DateTime.monday) {
      yhzDay = 5;
      yhaDay = 6;
    } else {
      yhzDay = 4;
      yhaDay = 5;
    }
    list.add(JewishHoliday(
      hebrewName: 'יום הזיכרון',
      date: g(2, yhzDay),
      type: HolidayType.special,
    ));
    list.add(JewishHoliday(
      hebrewName: 'יום העצמאות',
      date: g(2, yhaDay),
      type: HolidayType.holiday,
    ));

    // ─── Lag b'Omer (18 Iyar) ────────────────────────────────────────────
    list.add(JewishHoliday(
      hebrewName: 'ל״ג בעומר',
      date: g(2, 18),
      type: HolidayType.special,
    ));

    // ─── Yom Yerushalayim (28 Iyar) ──────────────────────────────────────
    list.add(JewishHoliday(
      hebrewName: 'יום ירושלים',
      date: g(2, 28),
      type: HolidayType.holiday,
    ));

    // ─── Shavuot (6 Sivan) ───────────────────────────────────────────────
    list.add(JewishHoliday(
      hebrewName: 'ערב שבועות',
      date: g(3, 5),
      type: HolidayType.eve,
    ));
    list.add(JewishHoliday(
      hebrewName: 'שבועות',
      date: g(3, 6),
      type: HolidayType.holiday,
    ));

    // ─── 17 Tammuz / 9 Av (postponed to next day if Shabbat) ────────────
    var tzom17 = g(4, 17);
    if (tzom17.weekday == DateTime.saturday) tzom17 = g(4, 18);
    list.add(JewishHoliday(
      hebrewName: 'צום י״ז בתמוז',
      date: tzom17,
      type: HolidayType.fast,
    ));

    var tishaBav = g(5, 9);
    if (tishaBav.weekday == DateTime.saturday) tishaBav = g(5, 10);
    list.add(JewishHoliday(
      hebrewName: 'תשעה באב',
      date: tishaBav,
      type: HolidayType.fast,
    ));

    return list;
  }

  // Ta'anit Esther: 13 Adar (II), pushed back to Thursday 11 Adar if Shabbat
  static DateTime _movePurimFastIfShabbat(int hebrewYear, int purimMonth) {
    final nominal = hebrewToGregorian(HebrewDate(hebrewYear, purimMonth, 13));
    if (nominal.weekday == DateTime.saturday) {
      return hebrewToGregorian(HebrewDate(hebrewYear, purimMonth, 11));
    }
    return nominal;
  }
}
