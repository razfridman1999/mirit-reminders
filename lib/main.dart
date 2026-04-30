import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/database/app_database.dart';
import 'package:mirit_reminders/features/notifications/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  NotificationService.instance.setDatabase(AppDatabase());
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
