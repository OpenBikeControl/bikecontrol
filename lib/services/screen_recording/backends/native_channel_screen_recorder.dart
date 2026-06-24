import 'package:bike_control/services/screen_recording/screen_recording_service.dart';
import 'package:flutter/foundation.dart';
import 'package:screen_recorder/screen_recorder.dart';

/// Backend that delegates to the in-repo `screen_recorder` plugin
/// (iOS broadcast bridge / macOS ScreenCaptureKit / Windows WGC).
class NativeChannelScreenRecorder implements ScreenRecorderBackend {
  NativeChannelScreenRecorder([ScreenRecorderChannel? channel])
    : _channel = channel ?? ScreenRecorderChannel();

  final ScreenRecorderChannel _channel;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.isSupported();
    } catch (e, s) {
      debugPrintStack(label: 'screen_recorder isSupported: $e', stackTrace: s);
      return false;
    }
  }

  @override
  Future<bool> ensurePermission() async {
    try {
      if (await _channel.hasPermission()) return true;
      return await _channel.requestPermission();
    } catch (e, s) {
      debugPrintStack(label: 'screen_recorder permission: $e', stackTrace: s);
      return false;
    }
  }

  @override
  Future<bool> start() async {
    try {
      return await _channel.start();
    } catch (e, s) {
      debugPrintStack(label: 'screen_recorder start: $e', stackTrace: s);
      return false;
    }
  }

  @override
  Future<String?> stop() async {
    try {
      return await _channel.stop();
    } catch (e, s) {
      debugPrintStack(label: 'screen_recorder stop: $e', stackTrace: s);
      return null;
    }
  }
}
