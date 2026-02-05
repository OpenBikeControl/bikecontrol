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
      MediaKey? key;
      String? deviceId;
      
      // Check if event is a map (new format with device info)
      if (event is Map) {
        final keyIdx = event['key'] as int?;
        deviceId = event['device'] as String?;
        
        if (keyIdx != null && keyIdx > -1 && keyIdx < MediaKey.values.length) {
          key = MediaKey.values[keyIdx];
        }
      } else if (event is int) {
        // Backward compatibility: old format with just key index
        if (event > -1 && event < MediaKey.values.length) {
          key = MediaKey.values[event];
        }
      }
      
      if (key != null) {
        triggerListeners(key, deviceId);
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
