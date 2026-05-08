import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around the native `com.mirit.reminders/system` MethodChannel.
/// All methods are no-op on non-Android platforms.
class SystemSettings {
  SystemSettings._();
  static const _channel = MethodChannel('com.mirit.reminders/system');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final r =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return r ?? false;
    } catch (e) {
      debugPrint('[SystemSettings] isIgnoringBatteryOptimizations: $e');
      return false;
    }
  }

  /// Launches the system "allow this app to ignore battery optimizations"
  /// dialog. Returns true if the intent was launched (not whether the user
  /// granted it — we have to re-check via [isIgnoringBatteryOptimizations]).
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return false;
    try {
      final r = await _channel
          .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return r ?? false;
    } catch (e) {
      debugPrint('[SystemSettings] requestIgnoreBatteryOptimizations: $e');
      return false;
    }
  }

  /// Opens the app's system settings page (for manual permission management).
  static Future<bool> openAppSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final r = await _channel.invokeMethod<bool>('openAppSettings');
      return r ?? false;
    } catch (e) {
      debugPrint('[SystemSettings] openAppSettings: $e');
      return false;
    }
  }
}
