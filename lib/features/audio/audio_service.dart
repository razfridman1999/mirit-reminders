import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// App-wide audio player. Singleton instance lives for the lifetime of the
/// process; on `AppLifecycleState.detached` the inner [AudioPlayer] is
/// disposed so resources are released cleanly (notably during Windows hot
/// reload, where the singleton would otherwise keep an audio session open).
class AudioService with WidgetsBindingObserver {
  AudioService._() {
    // Binding may not exist in pure-Dart tests; guard with a runtime check.
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
  }

  static final AudioService instance = AudioService._();

  AudioPlayer _player = AudioPlayer();
  bool _disposed = false;

  /// Play a built-in asset sound (e.g. 'sounds/ping_simple.wav')
  Future<void> playAsset(String assetPath) async {
    try {
      _ensurePlayer();
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (e, st) {
      debugPrint('[Audio] playAsset failed asset=$assetPath: $e\n$st');
    }
  }

  /// Play a custom file from device storage
  Future<void> playSound(String? soundPath) async {
    if (soundPath == null || soundPath.isEmpty) {
      await playAsset('sounds/ping_simple.wav');
      return;
    }
    try {
      _ensurePlayer();
      await _player.stop();
      await _player.play(DeviceFileSource(soundPath));
    } catch (e, st) {
      debugPrint(
          '[Audio] playSound failed path=$soundPath: $e\n$st — falling back to default');
      await playAsset('sounds/ping_simple.wav');
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    await _player.stop();
  }

  /// Releases the underlying [AudioPlayer]. After calling [dispose], any
  /// subsequent `playAsset` / `playSound` will lazily recreate the player.
  /// Call this from `main()` shutdown paths (or rely on the lifecycle
  /// observer below).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('[Audio] dispose failed: $e');
    }
  }

  void _ensurePlayer() {
    if (_disposed) {
      _player = AudioPlayer();
      _disposed = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // Fire-and-forget; framework is tearing down the engine.
      dispose();
    }
  }
}
