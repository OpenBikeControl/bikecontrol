import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';

/// The MacOS implementation of [MediaKeyDetectorPlatform].
class MediaKeyDetectorMacOS extends MediaKeyDetectorPlatform {
  final _eventChannel = const EventChannel('media_key_detector_macos_events');

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('media_key_detector_macos');

  /// Registers this class as the default instance of [MediaKeyDetectorPlatform]
  static void registerWith() {
    MediaKeyDetectorPlatform.instance = MediaKeyDetectorMacOS();
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
    return isPlaying ?? false;
  }

  @override
  Future<void> setIsPlaying({required bool isPlaying}) {
    return methodChannel.invokeMethod<String>('setIsPlaying', <String, dynamic>{
      'isPlaying': isPlaying,
    });
  }
}
