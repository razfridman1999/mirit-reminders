import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/features/audio/audio_service.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService.instance;
  ref.onDispose(service.dispose);
  return service;
});
