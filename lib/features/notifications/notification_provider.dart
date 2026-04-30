import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/features/notifications/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});
