import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';

MediaKeyDetectorPlatform get _platform => MediaKeyDetectorPlatform.instance;

/// Contains methods to add/remove listeners for the media key
class MediaKeyDetector {
  /// Contains methods to add/remove listeners for the media key
  factory MediaKeyDetector() {
    return _singleton;
  }

  MediaKeyDetector._internal();

  static final MediaKeyDetector _singleton = MediaKeyDetector._internal();

  bool _initialized = false;

  /// Listen for the media key event
  void addListener(void Function(MediaKey mediaKey) listener) {
    _lazilyInitialize();
    _platform.addListener(listener);
  }

  /// Listen for the media key event with device information
  void addListenerWithDevice(void Function(MediaKey mediaKey, String deviceId) listener) {
    _lazilyInitialize();
    _platform.addListenerWithDevice(listener);
  }

  /// Remove the previously registered listener
  void removeListener(void Function(MediaKey mediaKey) listener) {
    _lazilyInitialize();
    _platform.removeListener(listener);
  }

  /// Remove the previously registered listener with device information
  void removeListenerWithDevice(void Function(MediaKey mediaKey, String deviceId) listener) {
    _lazilyInitialize();
    _platform.removeListenerWithDevice(listener);
  }

  void _lazilyInitialize() {
    if (!_initialized) {
      _platform.initialize();
      _initialized = true;
    }
  }

  /// Get whether the active audio player is currently playing.
  Future<bool> getIsPlaying() => _platform.getIsPlaying();

  /// Set whether the active audio player is currently playing.
  Future<void> setIsPlaying({required bool isPlaying}) =>
      _platform.setIsPlaying(isPlaying: isPlaying);
}

/// Global singleton instance of the [MediaKeyDetector]
final mediaKeyDetector = MediaKeyDetector._singleton;
