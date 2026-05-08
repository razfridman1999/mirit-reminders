import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mirit_reminders/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Outcome of an export operation, used so the UI can distinguish a
/// completed save (with location) from a share-sheet hand-off (no path)
/// from a user cancel / failure.
enum BackupExportStatus { savedToFile, shared, cancelled, failed }

class BackupExportResult {
  final BackupExportStatus status;
  final String? path;
  const BackupExportResult(this.status, {this.path});
}

class BackupService {
  static const _dbFileName = 'mirit_reminders_db.sqlite';

  /// Resolves the on-device path of the SQLite DB file.
  /// drift_flutter stores under getApplicationSupportDirectory().
  static Future<File> _dbFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _dbFileName));
  }

  /// Builds a backup filename. The `_local` suffix on the timestamp makes
  /// it explicit that the time is the device's local clock (no UTC offset
  /// is encoded in the ISO-8601 string emitted by `DateTime.now()`).
  static String _backupFileName() {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return 'mirit_backup_${stamp}_local.sqlite';
  }

  /// Exports the live SQLite file.
  ///
  /// IMPORTANT: callers must pass [db] so the database can be closed before
  /// the file is copied — otherwise on Windows the source file is locked
  /// and on Android the WAL/SHM sidecar files may be in an inconsistent
  /// state. After this returns, the app should be relaunched.
  ///
  /// On Android we hand the file off to the system share sheet (`share_plus`)
  /// because the app's `getApplicationSupportDirectory()` lives under
  /// `/data/data/.../files/` which the user cannot browse and `FilePicker
  /// .saveFile` returns a path that fails to write outside scoped storage on
  /// Android 11+. On Windows we keep the native save dialog flow.
  static Future<BackupExportResult> exportToFile({
    required AppDatabase db,
  }) async {
    try {
      // Flush WAL → main DB and release the file handle before copying.
      await db.close();

      final src = await _dbFile();
      if (!await src.exists()) {
        debugPrint('[Backup] source DB does not exist at ${src.path}');
        return const BackupExportResult(BackupExportStatus.failed);
      }

      final fileName = _backupFileName();

      if (Platform.isAndroid) {
        // Stage a copy in temp so the user-visible filename is friendly,
        // then share it. share_plus copies the bytes into whatever target
        // the user picks (Drive, Gmail, etc.).
        final tempDir = await getTemporaryDirectory();
        final stagedPath = p.join(tempDir.path, fileName);
        await src.copy(stagedPath);
        final result = await Share.shareXFiles(
          [XFile(stagedPath, mimeType: 'application/octet-stream')],
          subject: fileName,
          text: 'גיבוי יומן תזכורות',
        );
        if (result.status == ShareResultStatus.success ||
            result.status == ShareResultStatus.unavailable) {
          return BackupExportResult(BackupExportStatus.shared,
              path: stagedPath);
        }
        return const BackupExportResult(BackupExportStatus.cancelled);
      }

      // Windows / desktop path: native save dialog.
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'שמירת גיבוי',
        fileName: fileName,
      );
      if (outputPath == null) {
        return const BackupExportResult(BackupExportStatus.cancelled);
      }
      await src.copy(outputPath);
      debugPrint('[Backup] exported to $outputPath');
      return BackupExportResult(BackupExportStatus.savedToFile,
          path: outputPath);
    } catch (e, st) {
      debugPrint('[Backup] export failed: $e\n$st');
      return const BackupExportResult(BackupExportStatus.failed);
    }
  }

  /// Prompts the user to pick a backup file, then overwrites the DB.
  /// Returns true on success. The app MUST be restarted for the change to
  /// take effect — the open [AppDatabase] still references the old file
  /// handle. Callers should pass [db] so we can close it before the copy.
  static Future<bool> importFromFile({required AppDatabase db}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'בחירת קובץ גיבוי',
        type: FileType.any,
      );
      if (result == null || result.files.single.path == null) return false;
      final src = File(result.files.single.path!);
      if (!await src.exists()) return false;

      // Close DB before swapping the file underneath it. On Windows this is
      // mandatory (file locking); on Android it prevents WAL corruption.
      await db.close();

      final dest = await _dbFile();
      await dest.parent.create(recursive: true);
      await src.copy(dest.path);
      debugPrint('[Backup] imported from ${src.path}');
      return true;
    } catch (e, st) {
      debugPrint('[Backup] import failed: $e\n$st');
      return false;
    }
  }
}
