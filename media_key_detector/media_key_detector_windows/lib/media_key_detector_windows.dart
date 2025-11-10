import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';

/// The Windows implementation of [MediaKeyDetectorPlatform].
class MediaKeyDetectorWindows extends MediaKeyDetectorPlatform {
  bool _isPlaying = false;
  final _eventChannel = const EventChannel('media_key_detector_windows_events');

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('media_key_detector_windows');

  /// Registers this class as the default instance of [MediaKeyDetectorPlatform]
  static void registerWith() {
    MediaKeyDetectorPlatform.instance = MediaKeyDetectorWindows();
  }

  @override
  void initialize() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      final keyIdx = event as int;
      MediaKey? key;
      if (keyIdx > -1 && keyIdx < MediaKey.values.length) {
        key = MediaKey.values[keyIdx];
      }
      if (key != null) {
        triggerListeners(key);
      }
    });
  }

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }

  @override
  Future<bool> getIsPlaying() async {
    final isPlaying = await methodChannel.invokeMethod<bool>('getIsPlaying');
    return isPlaying ?? _isPlaying;
  }

  @override
  Future<void> setIsPlaying({required bool isPlaying}) async {
    _isPlaying = isPlaying;
    await methodChannel.invokeMethod<void>('setIsPlaying', <String, dynamic>{'isPlaying': isPlaying});
  }
}
