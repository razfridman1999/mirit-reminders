import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mirit_reminders/core/database/database_provider.dart';

import 'cloud_auth_service.dart';
import 'cloud_credentials.dart';
import 'drive_sync_service.dart';

/// Drop-in widget for the Settings screen — handles connect/disconnect,
/// manual sync, conflict resolution, and the auto-sync toggle.
class CloudSyncSection extends ConsumerStatefulWidget {
  const CloudSyncSection({super.key});

  @override
  ConsumerState<CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends ConsumerState<CloudSyncSection> {
  bool _busy = false;
  bool _autoSync = true;
  DateTime? _lastSyncedAt;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final auto = await DriveSyncService.instance.autoSyncEnabled;
    final last = await DriveSyncService.instance.lastSyncedAt;
    if (!mounted) return;
    setState(() {
      _autoSync = auto;
      _lastSyncedAt = last;
    });
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _lastError = null;
    });
    try {
      final ok = await CloudAuthService.instance.signIn();
      if (!mounted) return;
      if (!ok) {
        setState(() => _lastError = 'התחברות בוטלה');
        return;
      }
      // Fetch the user's email for display.
      final email = await DriveSyncService.instance.fetchUserEmail();
      if (email != null) {
        await CloudAuthService.instance.rememberEmail(email);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _lastError = 'שגיאת התחברות: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastError = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      await CloudAuthService.instance.signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _busy = true;
      _lastError = null;
    });
    try {
      final db = ref.read(databaseProvider);
      final status = await DriveSyncService.instance.inspect();
      switch (status.action) {
        case SyncAction.noop:
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('הכל מסונכרן — אין שינויים להעלאה')),
          );
          return;
        case SyncAction.uploadLocal:
          final result =
              await DriveSyncService.instance.uploadLocal(db: db);
          await _afterAction(result, isUpload: true);
          return;
        case SyncAction.downloadRemote:
          final confirmed = await _confirmRestartAfterDownload();
          if (confirmed != true) return;
          final result =
              await DriveSyncService.instance.downloadRemote(db: db);
          await _afterAction(result, isUpload: false);
          return;
        case SyncAction.conflict:
          final choice = await _showConflictDialog(
            remote: status.remoteModified,
            local: status.localModified,
          );
          if (choice == _ConflictChoice.keepLocal) {
            final result =
                await DriveSyncService.instance.uploadLocal(db: db);
            await _afterAction(result, isUpload: true);
          } else if (choice == _ConflictChoice.keepRemote) {
            final result =
                await DriveSyncService.instance.downloadRemote(db: db);
            await _afterAction(result, isUpload: false);
          }
          return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastError = 'שגיאת סנכרון: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _afterAction(DriveSyncResult result,
      {required bool isUpload}) async {
    if (!result.isSuccess) {
      if (!mounted) return;
      setState(() => _lastError = result.error ?? 'שגיאה לא ידועה');
      return;
    }
    await _refresh();
    if (!mounted) return;
    if (isUpload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הועלה לענן בהצלחה')),
      );
    } else {
      // After download, the in-memory DB connection is stale. Force a quit
      // so the next launch picks up the new file. Mirrors the import flow.
      await _showRestartDialog(
        title: 'הסנכרון הושלם',
        body: 'הנתונים מהענן הורדו. האפליקציה תיסגר עכשיו, '
            'פתחי אותה מחדש כדי לראות את התזכורות המעודכנות.',
      );
      if (Platform.isAndroid) {
        await SystemNavigator.pop();
      } else {
        exit(0);
      }
    }
  }

  Future<bool?> _confirmRestartAfterDownload() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('הורדה מהענן'),
        content: const Text(
          'הנתונים בענן חדשים מהמקומיים. אם נמשיך, הנתונים בענן יחליפו את אלו '
          'במכשיר הזה והאפליקציה תיסגר. להמשיך?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('המשך'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
  }

  Future<_ConflictChoice?> _showConflictDialog({
    required DateTime? remote,
    required DateTime? local,
  }) async {
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'he_IL');
    return showDialog<_ConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('התנגשות סנכרון'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'גם המקומי וגם הענן השתנו מאז הסנכרון האחרון. '
              'איזו גרסה לשמור?',
            ),
            const SizedBox(height: 12),
            if (local != null)
              Text('ענן עודכן: ${remote != null ? fmt.format(remote) : "—"}'),
            if (remote != null)
              Text('מכשיר עודכן: ${local != null ? fmt.format(local) : "—"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_ConflictChoice.keepRemote),
            child: const Text('שמור את הענן'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_ConflictChoice.keepLocal),
            child: const Text('שמור את המכשיר'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRestartDialog(
      {required String title, required String body}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('הבנתי'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!CloudCredentials.isConfigured) {
      // The feature ships disabled until OAuth credentials are wired in.
      return ListTile(
        leading: Icon(Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        title: const Text('סנכרון ענן'),
        subtitle: const Text('עדיין לא מוגדר — צור קשר עם רז'),
        enabled: false,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final signedIn = CloudAuthService.instance.isSignedIn;
    final email = CloudAuthService.instance.userEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(Icons.cloud_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'סנכרון ענן (Google Drive)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (!signedIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'התחברי לחשבון Google כדי לסנכרן את התזכורות בין הטלפון למחשב.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('התחברי ל-Google'),
                  onPressed: _busy ? null : _connect,
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (email != null)
                  Text('מחובר כ: $email',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),
                if (_lastSyncedAt != null)
                  Text(
                    'סנכרון אחרון: '
                    '${DateFormat('dd/MM/yyyy HH:mm', 'he_IL').format(_lastSyncedAt!)}',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
                  )
                else
                  Text('עדיין לא בוצע סנכרון',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.sync),
                        label: const Text('סנכרן עכשיו'),
                        onPressed: _busy ? null : _syncNow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('סנכרון אוטומטי בפתיחה'),
                  subtitle: const Text(
                    'בדוק את הענן בכל פתיחה של האפליקציה',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _autoSync,
                  onChanged: _busy
                      ? null
                      : (v) async {
                          await DriveSyncService.instance
                              .setAutoSyncEnabled(v);
                          if (mounted) setState(() => _autoSync = v);
                        },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('התנתק'),
                  onPressed: _busy ? null : _disconnect,
                ),
              ],
            ),
          ),
        if (_lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _lastError!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
              ),
            ),
          ),
      ],
    );
  }
}

enum _ConflictChoice { keepLocal, keepRemote }
