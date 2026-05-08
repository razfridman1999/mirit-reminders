import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around HapticFeedback so semantic intent is clear at the
/// call site (e.g., `Haptics.delete()` instead of `HapticFeedback.heavyImpact()`).
class Haptics {
  Haptics._();

  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Haptics.light failed: $e');
    }
  }

  static Future<void> medium() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Haptics.medium failed: $e');
    }
  }

  static Future<void> success() async {
    // selectionClick gives a crisp, short "tick" that reads as confirmation.
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Haptics.success failed: $e');
    }
  }

  static Future<void> delete() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Haptics.delete failed: $e');
    }
  }
}
