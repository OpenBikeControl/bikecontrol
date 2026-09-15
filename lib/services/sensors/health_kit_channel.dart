import 'package:bike_control/main.dart';
import 'package:flutter/services.dart';

/// The rider's answer to iOS's Health permission sheet, as far as HealthKit
/// lets an app know it. Apple hides READ denials completely; `denied` is
/// reported only when the workout SHARE half was refused, which is the
/// closest observable proxy. `unknown` means the sheet was never shown.
enum HealthKitAuthorization { granted, denied, unknown }

/// Which native path is delivering samples. `session` = our own
/// `HKWorkoutSession` (iOS 26+), which is what makes AirPods Pro 3 sample
/// continuously. `passive` = an anchored query that only sees what OTHER
/// apps' workouts write — sparse, and the UI must say so.
enum HealthKitMode { session, passive }

sealed class HealthKitEvent {
  const HealthKitEvent();
}

class HealthKitSample extends HealthKitEvent {
  const HealthKitSample({required this.bpm, required this.at, required this.mode});

  final int bpm;

  /// The sample's own start time — NOT when it reached Dart. Passive
  /// delivery is batched; a minutes-old sample arriving now must not look
  /// fresh to the hub's TTL.
  final DateTime at;
  final HealthKitMode mode;
}

/// Sent once by `start` so the source knows which path is live before the
/// first sample (or in case none ever comes).
class HealthKitModeEvent extends HealthKitEvent {
  const HealthKitModeEvent(this.mode);

  final HealthKitMode mode;
}

/// Thrown by `Connection.connectHealthKit` when the rider refused the Health
/// permission sheet — an expected outcome the UI explains, not a failure.
class HealthKitDeniedException implements Exception {
  @override
  String toString() => 'HealthKitDeniedException';
}

/// The native seam. One real implementation (`MethodChannelHealthKit`) and
/// one fake; everything above this is testable without a platform.
abstract class HealthKitChannel {
  Future<bool> isAvailable();

  Future<HealthKitAuthorization> authorize();

  Future<void> start();

  Future<void> stop();

  /// Samples and mode changes after `start`. Errors on this stream are the
  /// native side's post-start failures (session ended by the OS, query
  /// error); they are reported, not fatal.
  Stream<HealthKitEvent> get events;
}

/// The real thing: talks to `ios/Runner/HealthKitHeartRate.swift`. Channel
/// names and payload shapes are the contract pinned by
/// `health_kit_channel_test.dart`; change both sides together.
class MethodChannelHealthKit implements HealthKitChannel {
  static const _method = MethodChannel('bike_control/health_kit');
  static const _event = EventChannel('bike_control/health_kit/heart_rate');

  @override
  Future<bool> isAvailable() async => await _method.invokeMethod<bool>('isAvailable') ?? false;

  @override
  Future<HealthKitAuthorization> authorize() async {
    final verdict = await _method.invokeMethod<String>('authorize');
    return switch (verdict) {
      'granted' => HealthKitAuthorization.granted,
      'denied' => HealthKitAuthorization.denied,
      _ => HealthKitAuthorization.unknown,
    };
  }

  @override
  Future<void> start() => _method.invokeMethod<void>('start');

  @override
  Future<void> stop() => _method.invokeMethod<void>('stop');

  @override
  Stream<HealthKitEvent> get events => _event
      .receiveBroadcastStream()
      .map(_decode)
      .where((e) => e != null)
      .cast<HealthKitEvent>();

  /// A malformed sample is dropped, not guessed at: a wrong heart rate is
  /// worse than none (same rule as `BleSensorSource`). Dropped frames are
  /// still recorded so a native-side regression shows up in crash reports.
  static HealthKitEvent? _decode(dynamic raw) {
    if (raw is! Map) {
      recordError(FormatException('HealthKit event is not a map: $raw'), null, context: 'MethodChannelHealthKit');
      return null;
    }
    final mode = switch (raw['mode']) {
      'session' => HealthKitMode.session,
      'passive' => HealthKitMode.passive,
      _ => null,
    };
    if (mode == null) {
      recordError(FormatException('HealthKit event without mode: $raw'), null, context: 'MethodChannelHealthKit');
      return null;
    }
    if (!raw.containsKey('bpm')) return HealthKitModeEvent(mode);
    final bpm = raw['bpm'];
    final at = raw['at'];
    if (bpm is! int || bpm <= 0 || at is! int) {
      recordError(FormatException('HealthKit sample malformed: $raw'), null, context: 'MethodChannelHealthKit');
      return null;
    }
    return HealthKitSample(bpm: bpm, at: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true), mode: mode);
  }
}
