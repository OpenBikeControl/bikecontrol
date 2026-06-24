import 'package:bike_control/main.dart';
import 'package:flutter/services.dart';

/// Thin Dart wrapper over the native `bike_control/pip_ios` channel. PiP runs
/// in the app process, so gear state is pushed straight over the channel into
/// `PipGearController`'s memory — no App Group UserDefaults round-trip.
class IosPipController {
  static const _channel = MethodChannel('bike_control/pip_ios');

  /// True on iPad and non-Dynamic-Island iPhones (iOS 16+). False on
  /// Dynamic-Island iPhones and where PiP is unsupported.
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (e, s) {
      recordError(e, s, context: 'pip.ios.isSupported');
      return false;
    }
  }

  Future<void> start(Map<String, dynamic> state) async {
    try {
      await _channel.invokeMethod<void>('start', state);
    } catch (e, s) {
      recordError(e, s, context: 'pip.ios.start');
    }
  }

  Future<void> update(Map<String, dynamic> state) async {
    try {
      await _channel.invokeMethod<void>('update', state);
    } catch (e, s) {
      recordError(e, s, context: 'pip.ios.update');
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e, s) {
      recordError(e, s, context: 'pip.ios.stop');
    }
  }
}
