import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_key_detector_platform_interface/media_key_detector_platform_interface.dart';

/// The Windows implementation of [MediaKeyDetectorPlatform].
class MediaKeyDetectorWindows extends MediaKeyDetectorPlatform {
  bool _isPlaying = false;

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('media_key_detector_windows');

  /// Registers this class as the default instance of [MediaKeyDetectorPlatform]
  static void registerWith() {
    MediaKeyDetectorPlatform.instance = MediaKeyDetectorWindows();
  }

  @override
  void initialize() {
    ServicesBinding.instance.keyboard.addHandler(defaultHandler);
  }

  @override
  Future<String?> getPlatformName() {
    return methodChannel.invokeMethod<String>('getPlatformName');
  }

  @override
  Future<bool> getIsPlaying() async {
    return _isPlaying;
  }

  @override
  Future<void> setIsPlaying({required bool isPlaying}) async {
    _isPlaying = isPlaying;
  }
}
