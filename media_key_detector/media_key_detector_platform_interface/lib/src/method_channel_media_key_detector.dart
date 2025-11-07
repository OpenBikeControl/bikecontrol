import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';

/// An implementation of [MediaKeyDetectorPlatform] that uses method channels.
class MethodChannelMediaKeyDetector extends MediaKeyDetectorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('media_key_detector');

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
    return methodChannel.invokeMethod<String>('setIsPlaying', [isPlaying]);
  }

  @override
  void initialize() {}
}
