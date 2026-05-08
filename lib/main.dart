import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/database/app_database.dart';
import 'package:mirit_reminders/core/database/database_provider.dart';
import 'package:mirit_reminders/core/observability/error_log.dart';
import 'package:mirit_reminders/features/cloud_sync/cloud_auth_service.dart';
import 'package:mirit_reminders/features/cloud_sync/drive_sync_service.dart';
import 'package:mirit_reminders/features/notifications/notification_service.dart';
import 'package:mirit_reminders/features/onboarding/onboarding_screen.dart';
import 'package:mirit_reminders/features/notifications/reminder_poller.dart';
import 'package:mirit_reminders/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';

void main() {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exceptionAsString()}\n${details.stack}');
      // Fire-and-forget: ErrorLog.log swallows its own errors.
      ErrorLog.log(details.exception, details.stack);
    };
    ErrorWidget.builder = (details) => _ErrorScreen(
          message: details.exceptionAsString(),
          stack: details.stack?.toString(),
        );

    SharedPreferences? prefs;
    AppDatabase? db;
    bool showOnboarding = false;
    try {
      // Core notification init (timezone + plugin). Must be safe — heavy work
      // is deferred until after the first frame.
      await NotificationService.instance.initialize();

      prefs = await SharedPreferences.getInstance();
      db = AppDatabase();
      NotificationService.instance.setDatabase(db);
      final prefsLocal = prefs;
      NotificationService.instance.setSnoozeProvider(() {
        return prefsLocal.getInt('default_snooze') ?? 10;
      });
      showOnboarding = !(await OnboardingScreen.hasSeen());
    } catch (e, st) {
      debugPrint('[main] startup failed: $e\n$st');
      runApp(_ErrorApp(message: e.toString(), stack: st.toString()));
      return;
    }

    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: _DeferredInitGate(
          database: db,
          child: App(showOnboarding: showOnboarding),
        ),
      ),
    );
  }, (error, stack) {
    debugPrint('[zone] uncaught: $error\n$stack');
    ErrorLog.log(error, stack);
  });
}

/// Runs deferred init (permissions, Android channels, ReminderPoller) once,
/// after the first frame, so the UI is visible even if any of those steps
/// take time or fail.
class _DeferredInitGate extends StatefulWidget {
  const _DeferredInitGate({required this.database, required this.child});
  final AppDatabase database;
  final Widget child;

  @override
  State<_DeferredInitGate> createState() => _DeferredInitGateState();
}

class _DeferredInitGateState extends State<_DeferredInitGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NotificationService.instance.initializeDeferred();
      } catch (e, st) {
        debugPrint('[main] deferred notif init failed: $e\n$st');
      }
      try {
        ReminderPoller.instance.start(widget.database);
      } catch (e, st) {
        debugPrint('[main] poller start failed: $e\n$st');
      }
      // Cloud sync startup: silent sign-in, then upload-only auto-sync.
      // Download / conflict states are intentionally NOT auto-resolved —
      // they trigger an app restart and need user awareness, so we surface
      // them via the Settings screen instead.
      try {
        await CloudAuthService.instance.initSilent();
        if (CloudAuthService.instance.isSignedIn &&
            await DriveSyncService.instance.autoSyncEnabled) {
          final status = await DriveSyncService.instance.inspect();
          if (status.action == SyncAction.uploadLocal) {
            await DriveSyncService.instance
                .uploadLocal(db: widget.database);
          }
        }
      } catch (e, st) {
        debugPrint('[main] cloud sync startup failed: $e\n$st');
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.message, this.stack});
  final String message;
  final String? stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: _ErrorScreen(message: message, stack: stack),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message, this.stack});
  final String message;
  final String? stack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.error_outline,
                    color: Color(0xFFC62828), size: 64),
                const SizedBox(height: 16),
                const Text(
                  'אירעה שגיאה בהפעלת האפליקציה',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'אנא צלמי את המסך ושלחי לרז',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
                if (stack != null && kDebugMode) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    stack!,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
