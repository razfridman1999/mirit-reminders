import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetUpdateService {
  static const _channel = MethodChannel('com.mirit.reminders/system');
  static const _prefsKey = 'widget_upcoming_reminders';

  static Future<void> update(List<Reminder> upcoming) async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final timeFmt = DateFormat('HH:mm');
      final dateFmt = DateFormat('dd/MM');

      // Store epoch millis alongside display strings so the Kotlin widget can
      // re-filter stale entries and recompute labels during Android's 30-min
      // onUpdate() call (when the Flutter engine is not running).
      final rows = upcoming.take(3).map((r) {
        final d = r.scheduledAt;
        final day = DateTime(d.year, d.month, d.day);
        final String timeLabel;
        if (day == today) {
          timeLabel = 'היום ${timeFmt.format(d)}';
        } else if (day == tomorrow) {
          timeLabel = 'מחר ${timeFmt.format(d)}';
        } else {
          timeLabel = '${dateFmt.format(d)} ${timeFmt.format(d)}';
        }
        return {
          'title': r.title,
          'time': timeLabel,
          'millis': d.millisecondsSinceEpoch,
        };
      }).toList();

      // shared_preferences stores keys with "flutter." prefix in
      // "FlutterSharedPreferences" — the Kotlin widget reads that exact key.
      await prefs.setString(_prefsKey, jsonEncode(rows));
      await _channel.invokeMethod<void>('updateWidget');
    } catch (_) {}
  }
}
