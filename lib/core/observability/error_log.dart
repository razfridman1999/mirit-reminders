import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Local rolling error log written to the app's support directory.
/// Wired from `main()`'s FlutterError.onError + zone error handler so any
/// uncaught error is captured for the user to send via the feedback button.
class ErrorLog {
  ErrorLog._();

  /// Hard cap before rotation kicks in.
  static const int _maxBytes = 50 * 1024;

  /// After rotation, this many trailing chars are kept before appending.
  static const int _keepChars = 25000;

  static const String _fileName = 'error_log.txt';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Append a single error entry to the log. Never throws.
  static Future<void> log(Object error, StackTrace? stack) async {
    try {
      final file = await _file();
      // Rotate by reading-and-rewriting when oversized. Simpler than tail copy
      // and the log is bounded to ~50 KB so the cost is negligible.
      if (await file.exists()) {
        final len = await file.length();
        if (len > _maxBytes) {
          try {
            final existing = await file.readAsString();
            final keep = existing.length > _keepChars
                ? existing.substring(existing.length - _keepChars)
                : existing;
            await file.writeAsString(keep, flush: true);
          } catch (e) {
            debugPrint('[ErrorLog] rotate failed: $e');
          }
        }
      } else {
        await file.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String();
      final entry =
          '--- [$timestamp] ---\n${error.toString()}\n${stack?.toString() ?? ''}\n\n';
      await file.writeAsString(
        entry,
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('[ErrorLog] log failed: $e');
    }
  }

  /// Returns the last [maxBytes] of the log as a string for embedding in
  /// the feedback email body. Returns empty string if no log exists.
  static Future<String> readRecent({int maxBytes = 8000}) async {
    try {
      final file = await _file();
      if (!await file.exists()) return '';
      final len = await file.length();
      if (len <= maxBytes) {
        return await file.readAsString();
      }
      final raf = await file.open();
      try {
        await raf.setPosition(len - maxBytes);
        final bytes = await raf.read(maxBytes);
        return String.fromCharCodes(bytes);
      } finally {
        await raf.close();
      }
    } catch (e) {
      debugPrint('[ErrorLog] readRecent failed: $e');
      return '';
    }
  }

  /// Empties the log file. Called after a successful "send feedback" so
  /// repeat reports don't keep including the same old errors. Never throws.
  static Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        await file.writeAsString('', flush: true);
      }
    } catch (e) {
      debugPrint('[ErrorLog] clear failed: $e');
    }
  }
}
