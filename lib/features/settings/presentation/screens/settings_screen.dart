import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mirit_reminders/core/constants/app_strings.dart';
import 'package:mirit_reminders/core/database/database_provider.dart';
import 'package:mirit_reminders/core/observability/error_log.dart';
import 'package:mirit_reminders/core/platform/system_settings.dart';
import 'package:mirit_reminders/features/cloud_sync/cloud_sync_widget.dart';
import 'package:mirit_reminders/features/audio/audio_service.dart';
import 'package:mirit_reminders/features/audio/built_in_sounds.dart';
import 'package:mirit_reminders/features/audio/sound_picker_widget.dart';
import 'package:mirit_reminders/features/notifications/notification_service.dart';
import 'package:mirit_reminders/features/settings/data/backup_service.dart';
import 'package:mirit_reminders/features/settings/domain/app_settings.dart';
import 'package:mirit_reminders/features/settings/presentation/providers/settings_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hardcoded app version. Kept in sync with pubspec.yaml manually.
const String _appVersion = '1.1.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        children: [
          // ─── Notifications ────────────────────────────────────────────
          _SectionHeader('התראות'),
          ListTile(
            leading: Icon(Icons.notifications_active_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('שלח התראת בדיקה'),
            subtitle: const Text('בדוק שצליל ההתראה עובד תקין'),
            onTap: () => _sendTestNotification(context, settings),
          ),
          const Divider(height: 1),
          if (Platform.isAndroid)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _NotificationDiagnostics(),
            ),
          if (Platform.isAndroid) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SoundPickerWidget(
              currentSoundPath: settings.defaultSoundPath,
              onSoundSelected: (path) => _guardedSave(
                context,
                () => notifier
                    .setDefaultSoundPath(path ?? 'sounds/ping_simple.wav'),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.snooze_outlined, color: Theme.of(context).colorScheme.primary),
            title: const Text('משך נודניק ברירת מחדל'),
            subtitle: Text('${settings.defaultSnoozeMinutes} דקות'),
            trailing: DropdownButton<int>(
              value: settings.defaultSnoozeMinutes,
              underline: const SizedBox(),
              items: const [5, 10, 15, 20, 30, 45, 60]
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text('$m דק׳')))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  _guardedSave(
                    context,
                    () => notifier.setDefaultSnoozeMinutes(v),
                  );
                }
              },
            ),
          ),

          // ─── Display ──────────────────────────────────────────────────
          _SectionHeader('תצוגה'),
          ListTile(
            leading: Icon(Icons.text_fields, color: Theme.of(context).colorScheme.primary),
            title: const Text('גודל טקסט'),
            subtitle: Text(_fontSizeLabel(settings.fontSize)),
          ),
          _FontSizeSelector(
            value: settings.fontSize,
            onChanged: (size) => _guardedSave(
              context,
              () => notifier.setFontSize(size),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.palette_outlined, color: Theme.of(context).colorScheme.primary),
            title: const Text('ערכת נושא'),
            subtitle: Text(_themeLabel(settings.themeMode)),
          ),
          _ThemeSelector(
            value: settings.themeMode,
            onChanged: (mode) => _guardedSave(
              context,
              () => notifier.setThemeMode(mode),
            ),
          ),

          // ─── Widget ──────────────────────────────────────────────────
          if (Platform.isAndroid) ...[
            _SectionHeader('ווידג\'ט'),
            ListTile(
              leading: Icon(Icons.widgets_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('ווידג\'ט למסך הבית'),
              subtitle: const Text(
                'לחצי לאורך על שטח פנוי במסך הבית ← ווידג\'טים ← יומן תזכורות. מציג את 3 התזכורות הקרובות הבאות.',
              ),
              isThreeLine: true,
            ),
            const Divider(height: 1),
          ],

          // ─── Cloud Sync ──────────────────────────────────────────────
          _SectionHeader('סנכרון ענן'),
          const CloudSyncSection(),

          // ─── Support ──────────────────────────────────────────────────
          _SectionHeader('תמיכה'),
          ListTile(
            leading: Icon(Icons.support_agent,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('שלח משוב לרז'),
            subtitle: const Text('שאלה, באג, או הצעה? נשמח לקבל'),
            onTap: () => _sendFeedback(context),
          ),

          // ─── Backup ───────────────────────────────────────────────────
          _SectionHeader('גיבוי ושחזור'),
          ListTile(
            leading: Icon(Icons.cloud_upload_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('יצוא גיבוי לקובץ'),
            subtitle: const Text('שמור את כל התזכורות והקטגוריות לקובץ'),
            onTap: () => _exportBackup(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.cloud_download_outlined,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('שחזור מקובץ'),
            subtitle: const Text('יחליף את הנתונים הנוכחיים'),
            onTap: () => _importBackup(context, ref),
          ),

          // ─── About ────────────────────────────────────────────────────
          _SectionHeader('אודות'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 96,
                      height: 96,
                      errorBuilder: (ctx, _, __) => const Icon(
                        Icons.image_not_supported,
                        size: 96,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'יומן תזכורות',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'גרסה $_appVersion',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('פותח עבור מירית פרידמן'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Runs a setting save and surfaces any persistence error to the user.
  /// The notifier reverts state on failure so the UI stays consistent.
  Future<void> _guardedSave(
    BuildContext context,
    Future<void> Function() save,
  ) async {
    try {
      await save();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('שמירת ההגדרה נכשלה. נסה שוב.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _sendTestNotification(
    BuildContext context,
    AppSettings settings,
  ) async {
    final result = await NotificationService.instance.showNow(
      id: -100,
      body: 'התראת בדיקה — אם את רואה את ההודעה, הכל עובד',
      soundPath: settings.defaultSoundPath,
    );
    // On Android the notification itself plays the sound through the OS, so
    // playing again via AudioService would double-trigger. Keep the in-app
    // playback for Windows where the notification system has no sound.
    if (Platform.isWindows) {
      if (builtInSounds.any((s) => s.asset == settings.defaultSoundPath)) {
        await AudioService.instance.playAsset(settings.defaultSoundPath);
      } else {
        await AudioService.instance.playSound(settings.defaultSoundPath);
      }
    }
    if (!context.mounted) return;
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('נשלחה התראת בדיקה — אם לא הופיעה, פתח את האבחון בהמשך'),
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('שליחת ההתראה נכשלה'),
          content: Text(_describeShowNowResult(result)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('הבנתי'),
            ),
          ],
        ),
      );
    }
  }

  /// Builds a Hebrew feedback body, opens the system share sheet, and
  /// clears the captured error log on success so the next report starts fresh.
  Future<void> _sendFeedback(BuildContext context) async {
    try {
      final logSnippet = await ErrorLog.readRecent();
      final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      final errorsBlock =
          logSnippet.trim().isEmpty ? 'אין שגיאות מתועדות' : logSnippet;
      final body = 'משוב — יומן תזכורות\n'
          '\n'
          'גרסה: $_appVersion\n'
          'תאריך: $now\n'
          '\n'
          'אנא תארי את הבעיה או ההצעה שלך:\n'
          '\n'
          '\n'
          '\n'
          '───────────────────────────────────\n'
          'שגיאות אחרונות שנקלטו אוטומטית:\n'
          '$errorsBlock\n';

      await Share.share(
        body,
        subject: 'משוב — יומן תזכורות [v$_appVersion]',
      );
      // Optimistic clear: share_plus has no reliable success callback.
      await ErrorLog.clear();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('השליחה נכשלה — נסי שוב מאוחר יותר'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  String _describeShowNowResult(ShowNowResult r) {
    switch (r.kind) {
      case 'permissionDenied':
        return 'הרשאת ההתראות חסומה. גללי לסעיף "אבחון" וראי ההוראות לתיקון.';
      case 'error':
        return 'שגיאה: ${r.message ?? 'לא ידועה'}';
    }
    return 'תוצאה לא ידועה: ${r.kind}';
  }

  /// After a backup operation closes the AppDatabase, the app can no longer
  /// access SQLite. Force-quit so the user must reopen with a fresh DB
  /// connection — otherwise every subsequent UI action would throw.
  Future<void> _quitApp() async {
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final result = await BackupService.exportToFile(db: db);
    if (!context.mounted) return;
    switch (result.status) {
      case BackupExportStatus.savedToFile:
        await _showRestartRequiredDialog(
          context,
          'הגיבוי הושלם',
          'הגיבוי נשמר ב:\n${result.path ?? ''}\n\n'
              'האפליקציה תיסגר עכשיו. פתח אותה מחדש כדי להמשיך.',
        );
        await _quitApp();
        break;
      case BackupExportStatus.shared:
        await _showRestartRequiredDialog(
          context,
          'הגיבוי הושלם',
          'הגיבוי נשלח. האפליקציה תיסגר עכשיו. פתח אותה מחדש כדי להמשיך.',
        );
        await _quitApp();
        break;
      case BackupExportStatus.cancelled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הגיבוי בוטל')),
        );
        break;
      case BackupExportStatus.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הגיבוי נכשל')),
        );
        break;
    }
  }

  Future<void> _showRestartRequiredDialog(
    BuildContext context,
    String title,
    String content,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('הבנתי'),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('שחזור גיבוי'),
        content: const Text(
          'הפעולה תחליף את כל התזכורות והקטגוריות הנוכחיות בנתונים מקובץ הגיבוי. '
          'יש להפעיל את האפליקציה מחדש לאחר השחזור. להמשיך?',
        ),
        // RTL convention: destructive on leading edge (right), Cancel on trailing.
        // Cancel is the prominent button (safer default for an elderly user).
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'המשך',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.error,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final db = ref.read(databaseProvider);
    final ok = await BackupService.importFromFile(db: db);
    if (!context.mounted) return;
    if (ok) {
      await _showRestartRequiredDialog(
        context,
        'השחזור הושלם',
        'הנתונים שוחזרו בהצלחה. האפליקציה תיסגר עכשיו. פתח אותה מחדש כדי שהשינויים יחולו.',
      );
      await _quitApp();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('השחזור בוטל או נכשל')),
      );
    }
  }

  String _fontSizeLabel(AppFontSize size) {
    switch (size) {
      case AppFontSize.regular:
        return 'רגיל';
      case AppFontSize.large:
        return 'גדול';
      case AppFontSize.xLarge:
        return 'ענק';
    }
  }

  String _themeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'לפי המערכת';
      case AppThemeMode.light:
        return 'בהיר';
      case AppThemeMode.dark:
        return 'כהה';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FontSizeSelector extends StatelessWidget {
  final AppFontSize value;
  final ValueChanged<AppFontSize> onChanged;
  const _FontSizeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Clamp the segment text scale so xLarge global setting doesn't overflow
    // the three-segment row on a narrow screen.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.0,
        child: SegmentedButton<AppFontSize>(
          segments: const [
            ButtonSegment(
              value: AppFontSize.regular,
              label: Text('רגיל'),
            ),
            ButtonSegment(
              value: AppFontSize.large,
              label: Text('גדול'),
            ),
            ButtonSegment(
              value: AppFontSize.xLarge,
              label: Text('ענק'),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

class _NotificationDiagnostics extends StatefulWidget {
  const _NotificationDiagnostics();

  @override
  State<_NotificationDiagnostics> createState() =>
      _NotificationDiagnosticsState();
}

class _NotificationDiagnosticsState extends State<_NotificationDiagnostics> {
  NotificationDiagnostics? _diag;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final d = await NotificationService.instance.getDiagnostics();
      if (!mounted) return;
      setState(() => _diag = d);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _busy = true);
    try {
      final d =
          await NotificationService.instance.requestPermissionsInteractive();
      if (!mounted) return;
      setState(() => _diag = d);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestBatteryExemption() async {
    setState(() => _busy = true);
    try {
      await SystemSettings.requestIgnoreBatteryOptimizations();
      // The user is taken to a system dialog; refresh after they return.
      // No reliable callback for "user returned", so just refresh on demand.
      final d = await NotificationService.instance.getDiagnostics();
      if (!mounted) return;
      setState(() => _diag = d);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = _diag;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.health_and_safety_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'אבחון מצב ההתראות',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'רענן',
              onPressed: _busy ? null : _refresh,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (d == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _DiagRow(
            label: 'הרשאת התראות',
            state: d.notificationsEnabled,
          ),
          _DiagRow(
            label: 'אזעקה מדויקת',
            state: d.canScheduleExactAlarms,
          ),
          _DiagRow(
            label: 'ערוצי התראות נוצרו',
            valueText: '${d.channelCount}',
            ok: d.channelCount > 0,
          ),
          _DiagRow(
            label: 'פטור מחיסכון בסוללה',
            state: d.ignoringBatteryOptimizations,
          ),
          if (d.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'הערה טכנית: ${d.error}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 8),
          if (d.notificationsEnabled == false)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: const Text(
                'ההתראות חסומות. כדי לתקן:\n'
                '1. פתחי "הגדרות" באנדרואיד\n'
                '2. אפליקציות ← יומן תזכורות\n'
                '3. התראות ← הפעלי\n'
                '4. חזרי לכאן ולחצי "רענן"',
                style: TextStyle(fontSize: 13),
              ),
            ),
          if (d.canScheduleExactAlarms == false)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: const Text(
                  'אזעקה מדויקת לא מאושרת — התראות עלולות לאחר. '
                  'בלחיצה על "בקש הרשאות" ייפתח עמוד הגדרות. הפעלי שם את "אזעקה מדויקת" וחזרי.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          if (d.ignoringBatteryOptimizations == false)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: const Text(
                  'הסוללה חוסמת התראות. זאת הסיבה הכי שכיחה שהתראות '
                  'לא יורות במכשירי Samsung. לחצי "בקשי פטור מסוללה" '
                  'ואשרי בחלון שייפתח.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('בקש הרשאות'),
                  onPressed: _busy ? null : _requestPermissions,
                ),
              ),
            ],
          ),
          if (d.ignoringBatteryOptimizations == false) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.battery_charging_full),
                    label: const Text('בקשי פטור מסוללה'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC62828),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _busy ? null : _requestBatteryExemption,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('פתחי הגדרות אנדרואיד'),
                  onPressed: _busy
                      ? null
                      : () async {
                          await SystemSettings.openAppSettings();
                        },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({
    required this.label,
    this.state,
    this.valueText,
    this.ok,
  });

  final String label;
  final bool? state;
  final String? valueText;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final isOk = ok ?? state == true;
    final isBad = ok == false || state == false;
    final color = isOk
        ? const Color(0xFF2E7D32)
        : isBad
            ? const Color(0xFFC62828)
            : Colors.grey;
    final icon = isOk
        ? Icons.check_circle
        : isBad
            ? Icons.cancel
            : Icons.help_outline;
    final text = valueText ??
        (state == true
            ? 'מאושר'
            : state == false
                ? 'דחויה / לא מאושרת'
                : 'לא ידוע');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;
  const _ThemeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.0,
        child: SegmentedButton<AppThemeMode>(
          segments: const [
            ButtonSegment(
              value: AppThemeMode.system,
              icon: Icon(Icons.settings_brightness),
              label: Text('מערכת'),
            ),
            ButtonSegment(
              value: AppThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('בהיר'),
            ),
            ButtonSegment(
              value: AppThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('כהה'),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}
