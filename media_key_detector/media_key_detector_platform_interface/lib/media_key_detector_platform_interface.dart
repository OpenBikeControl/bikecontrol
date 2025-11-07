/// The base interface for media_key_detector
library media_key_detector_platform_interface;

import 'package:flutter/services.dart';
import 'package:media_key_detector_platform_interface/src/media_key.dart';
import 'package:media_key_detector_platform_interface/src/method_channel_media_key_detector.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

export './src/exports.dart';

/// The interface that implementations of media_key_detector must implement.
///
/// Platform implementations should extend this class
/// rather than implement it as `MediaKeyDetector`.
/// Extending this class (using `extends`) ensures that the subclass will get
/// the default implementation, while platform implementations that `implements`
/// this interface will be broken by newly added [MediaKeyDetectorPlatform]
/// methods.
abstract class MediaKeyDetectorPlatform extends PlatformInterface {
  /// Constructs a MediaKeyDetectorPlatform.
  MediaKeyDetectorPlatform() : super(token: _token);

  static final Object _token = Object();

  static MediaKeyDetectorPlatform _instance = MethodChannelMediaKeyDetector();

  /// The default instance of [MediaKeyDetectorPlatform] to use.
  ///
  /// Defaults to [MethodChannelMediaKeyDetector].
  static MediaKeyDetectorPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [MediaKeyDetectorPlatform] when they register
  /// themselves.
  static set instance(MediaKeyDetectorPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Return the current platform name.
  Future<String?> getPlatformName();

  /// Get whether the active audio player is currently playing.
  Future<bool> getIsPlaying();

  /// Set whether the active audio player is currently playing.
  Future<void> setIsPlaying({required bool isPlaying});

  /// Indicates that the platform should initialize.
  void initialize();

  final List<void Function(MediaKey mediaKey)> _listeners = [];

  /// Listen for the media key event
  void addListener(void Function(MediaKey mediaKey) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Remove the previously registered listener
  void removeListener(void Function(MediaKey mediaKey) listener) {
    _listeners.remove(listener);
  }

  /// Trigger all listeners to indicate that the specified media key was pressed
  void triggerListeners(MediaKey mediaKey) {
    for (final l in _listeners) {
      l(mediaKey);
    }
  }

  final Map<LogicalKeyboardKey, MediaKey> _keyMap = {
    LogicalKeyboardKey.mediaPlay: MediaKey.playPause,
    LogicalKeyboardKey.mediaRewind: MediaKey.rewind,
    LogicalKeyboardKey.mediaFastForward: MediaKey.fastForward,
  };

  /// The default handler to use if this platform doesn't need to implement any
  /// platform specific code to listen for the media key event
  bool defaultHandler(KeyEvent event) {
    if (_keyMap.containsKey(event.logicalKey)) {
      final key = _keyMap[event.logicalKey]!;
      triggerListeners(key);
      return true;
    }
    return false;
  }
}
