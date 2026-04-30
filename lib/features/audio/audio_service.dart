import 'package:audioplayers/audioplayers.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playSound(String? soundPath) async {
    if (soundPath == null || soundPath.isEmpty) {
      await _playDefaultSound();
      return;
    }
    try {
      await _player.play(DeviceFileSource(soundPath));
    } catch (_) {
      await _playDefaultSound();
    }
  }

  Future<void> _playDefaultSound() async {
    try {
      await _player.play(AssetSource('sounds/default_notification.mp3'));
    } catch (_) {}
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
