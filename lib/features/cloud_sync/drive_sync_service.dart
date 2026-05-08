import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mirit_reminders/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_auth_service.dart';

/// Decision the sync engine reaches when comparing local and remote state.
enum SyncAction {
  noop, // both sides already in sync
  uploadLocal, // local newer or only local exists
  downloadRemote, // remote newer or only remote exists
  conflict, // both sides changed since last sync — user must pick
}

class SyncStatus {
  const SyncStatus({
    required this.action,
    this.remoteModified,
    this.localModified,
    this.message,
  });

  final SyncAction action;
  final DateTime? remoteModified;
  final DateTime? localModified;
  final String? message;
}

class DriveSyncResult {
  const DriveSyncResult({required this.action, this.error});
  final SyncAction action;
  final String? error;
  bool get isSuccess => error == null;
}

class DriveSyncService {
  DriveSyncService._();
  static final DriveSyncService instance = DriveSyncService._();

  /// Filename inside Drive's appDataFolder. Matches the on-device DB name
  /// for symmetry; users never see this name.
  static const String _remoteFileName = 'mirit_reminders_db.sqlite';
  static const String _kLastSyncedAt = 'cloud_sync_last_synced_at';
  static const String _kLastSyncedRemoteRevision =
      'cloud_sync_last_remote_revision';
  static const String _kAutoSyncEnabled = 'cloud_sync_auto';

  static Future<File> _dbFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'mirit_reminders_db.sqlite'));
  }

  Future<bool> get autoSyncEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoSyncEnabled) ?? true;
  }

  Future<void> setAutoSyncEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoSyncEnabled, v);
  }

  Future<DateTime?> get lastSyncedAt async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastSyncedAt);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _markSynced(String? remoteRevision) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _kLastSyncedAt, DateTime.now().millisecondsSinceEpoch);
    if (remoteRevision != null) {
      await prefs.setString(_kLastSyncedRemoteRevision, remoteRevision);
    }
  }

  Future<String?> get _lastSyncedRemoteRevision async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastSyncedRemoteRevision);
  }

  /// Inspect both sides without making any changes. The UI uses this to
  /// build the conflict dialog.
  Future<SyncStatus> inspect() async {
    final client = await CloudAuthService.instance.authenticatedClient();
    if (client == null) {
      return const SyncStatus(
          action: SyncAction.noop, message: 'not signed in');
    }
    final api = drive.DriveApi(client);
    final remote = await _findRemoteFile(api);
    final localFile = await _dbFile();
    final localExists = await localFile.exists();
    final localModified =
        localExists ? (await localFile.stat()).modified : null;

    final remoteRev = remote?.headRevisionId;
    final lastSyncedRev = await _lastSyncedRemoteRevision;
    final lastSynced = await lastSyncedAt;

    if (remote == null && !localExists) {
      return const SyncStatus(action: SyncAction.noop);
    }
    if (remote == null) {
      return SyncStatus(
        action: SyncAction.uploadLocal,
        localModified: localModified,
      );
    }
    if (!localExists) {
      return SyncStatus(
        action: SyncAction.downloadRemote,
        remoteModified: remote.modifiedTime,
      );
    }

    final remoteChangedSinceSync = remoteRev != lastSyncedRev;
    final localChangedSinceSync = lastSynced == null
        ? true
        : localModified != null && localModified.isAfter(lastSynced);

    if (remoteChangedSinceSync && localChangedSinceSync) {
      return SyncStatus(
        action: SyncAction.conflict,
        remoteModified: remote.modifiedTime,
        localModified: localModified,
      );
    }
    if (remoteChangedSinceSync) {
      return SyncStatus(
        action: SyncAction.downloadRemote,
        remoteModified: remote.modifiedTime,
      );
    }
    if (localChangedSinceSync) {
      return SyncStatus(
        action: SyncAction.uploadLocal,
        localModified: localModified,
      );
    }
    return const SyncStatus(action: SyncAction.noop);
  }

  /// Push the local DB to Drive (creates or updates the remote file).
  /// Unlike [BackupService.exportToFile], this does NOT close [db]; instead
  /// it flushes the WAL via `PRAGMA wal_checkpoint(TRUNCATE)` so the main
  /// `.sqlite` file is consistent on disk while the app stays responsive.
  Future<DriveSyncResult> uploadLocal({required AppDatabase db}) async {
    try {
      final client = await CloudAuthService.instance.authenticatedClient();
      if (client == null) {
        return const DriveSyncResult(
            action: SyncAction.uploadLocal, error: 'not signed in');
      }
      final api = drive.DriveApi(client);

      // Force pending writes from -wal back into the main DB file. After
      // this returns, reading `mirit_reminders_db.sqlite` directly is safe.
      try {
        await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (e) {
        debugPrint('[DriveSync] WAL checkpoint failed (continuing): $e');
      }

      final src = await _dbFile();
      if (!await src.exists()) {
        return const DriveSyncResult(
            action: SyncAction.uploadLocal, error: 'local DB missing');
      }
      final bytes = await src.readAsBytes();
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'application/octet-stream',
      );

      final existing = await _findRemoteFile(api);
      drive.File result;
      if (existing == null) {
        final meta = drive.File()
          ..name = _remoteFileName
          ..parents = ['appDataFolder'];
        result = await api.files.create(meta, uploadMedia: media);
      } else {
        final meta = drive.File()..name = _remoteFileName;
        result = await api.files.update(meta, existing.id!, uploadMedia: media);
      }
      await _markSynced(result.headRevisionId);
      return const DriveSyncResult(action: SyncAction.uploadLocal);
    } catch (e, st) {
      debugPrint('[DriveSync] upload failed: $e\n$st');
      return DriveSyncResult(
          action: SyncAction.uploadLocal, error: e.toString());
    }
  }

  /// Pull the remote DB and overwrite the local DB. Caller MUST close [db]
  /// before calling. The app must restart afterwards (same as import).
  Future<DriveSyncResult> downloadRemote({required AppDatabase db}) async {
    try {
      final client = await CloudAuthService.instance.authenticatedClient();
      if (client == null) {
        return const DriveSyncResult(
            action: SyncAction.downloadRemote, error: 'not signed in');
      }
      final api = drive.DriveApi(client);
      final remote = await _findRemoteFile(api);
      if (remote == null) {
        return const DriveSyncResult(
            action: SyncAction.downloadRemote, error: 'no remote file');
      }

      // Buffer the download fully before touching the local file so a
      // network failure mid-stream doesn't leave the DB half-overwritten.
      final media = await api.files.get(remote.id!,
          downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      await db.close();
      final dest = await _dbFile();
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(bytes, flush: true);
      await _markSynced(remote.headRevisionId);
      return const DriveSyncResult(action: SyncAction.downloadRemote);
    } catch (e, st) {
      debugPrint('[DriveSync] download failed: $e\n$st');
      return DriveSyncResult(
          action: SyncAction.downloadRemote, error: e.toString());
    }
  }

  /// "Smart" entry point — inspects state and applies a non-conflicting
  /// action automatically. If the result is `conflict`, the caller must
  /// resolve it (typically via a UI dialog) and then call uploadLocal or
  /// downloadRemote explicitly.
  Future<DriveSyncResult> autoSync({required AppDatabase db}) async {
    final status = await inspect();
    switch (status.action) {
      case SyncAction.noop:
        return const DriveSyncResult(action: SyncAction.noop);
      case SyncAction.uploadLocal:
        return uploadLocal(db: db);
      case SyncAction.downloadRemote:
        return downloadRemote(db: db);
      case SyncAction.conflict:
        return DriveSyncResult(
          action: SyncAction.conflict,
          error: 'manual resolution required',
        );
    }
  }

  Future<drive.File?> _findRemoteFile(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_remoteFileName' and trashed=false",
      $fields: 'files(id,name,modifiedTime,headRevisionId,size)',
      pageSize: 5,
    );
    final files = list.files ?? [];
    if (files.isEmpty) return null;
    // If multiple exist (shouldn't happen, but defensive), keep newest.
    files.sort((a, b) =>
        (b.modifiedTime ?? DateTime(0)).compareTo(a.modifiedTime ?? DateTime(0)));
    return files.first;
  }

  /// Best-effort fetch of the signed-in user's email (for display). Uses
  /// the About endpoint which is available on the appdata scope.
  Future<String?> fetchUserEmail() async {
    try {
      final client = await CloudAuthService.instance.authenticatedClient();
      if (client == null) return null;
      // Drive About requires `drive` or `drive.metadata.readonly` — appdata
      // scope alone won't return user.emailAddress. Fall back to the
      // userinfo endpoint via the same authenticated client.
      final resp = await client
          .get(Uri.parse('https://openidconnect.googleapis.com/v1/userinfo'));
      if (resp.statusCode != 200) return null;
      final body = resp.body;
      // Cheap parse — the access token grants openid implicitly via
      // GoogleSignIn defaults? If userinfo isn't accessible, return null.
      final emailMatch = RegExp(r'"email"\s*:\s*"([^"]+)"').firstMatch(body);
      return emailMatch?.group(1);
    } catch (e) {
      debugPrint('[DriveSync] fetchUserEmail failed: $e');
      return null;
    }
  }
}

