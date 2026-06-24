import 'package:flutter/services.dart';

/// Thin method-channel wrapper over the native (iOS/macOS/Windows) recorders.
/// All methods return defensively: failures surface as `false`/`null`, never throw.
class ScreenRecorderChannel {
  static const MethodChannel _channel = MethodChannel('screen_recorder');

  /// Whether the current OS build supports capture (macOS >= 12.3, WGC available, etc.).
  Future<bool> isSupported() async {
    final result = await _channel.invokeMethod<bool>('isSupported');
    return result ?? false;
  }

  /// True if capture permission is already granted (macOS TCC / iOS n/a → true).
  Future<bool> hasPermission() async {
    final result = await _channel.invokeMethod<bool>('hasPermission');
    return result ?? false;
  }

  /// Request capture permission. Returns true if granted.
  Future<bool> requestPermission() async {
    final result = await _channel.invokeMethod<bool>('requestPermission');
    return result ?? false;
  }

  /// Begin recording. Returns true if recording started.
  Future<bool> start() async {
    final result = await _channel.invokeMethod<bool>('start');
    return result ?? false;
  }

  /// Stop recording. Returns the saved file path, or null on failure.
  Future<String?> stop() async {
    return _channel.invokeMethod<String?>('stop');
  }
}
