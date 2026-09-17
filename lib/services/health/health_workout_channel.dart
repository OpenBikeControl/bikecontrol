import 'package:flutter/services.dart';

import '../sensors/health_kit_channel.dart';
import 'health_workout_payload.dart';

/// The native seam for writing rides to Apple Health. One real
/// implementation (`MethodChannelHealthWorkout`) and one fake.
abstract class HealthWorkoutChannel {
  Future<bool> isAvailable();

  /// Asks to SHARE the workout and its samples. Read access is untouched —
  /// heart rate stays the only type we read.
  Future<HealthKitAuthorization> authorize();

  /// Writes one ride; returns the saved workout's UUID. Throws
  /// [PlatformException] (code `denied` when sharing is refused).
  Future<String?> saveWorkout(HealthWorkoutPayload payload);

  /// Opens the Health app (or the app's Settings page as a fallback), where
  /// the rider can change what BikeControl may write.
  Future<void> openHealthSettings();
}

/// Talks to `ios/Runner/HealthKitWorkoutWriter.swift`. Channel name and
/// payload shape are pinned by `health_workout_channel_test.dart`; change
/// both sides together.
class MethodChannelHealthWorkout implements HealthWorkoutChannel {
  static const _method = MethodChannel('bike_control/health_kit/workouts');

  @override
  Future<bool> isAvailable() async => await _method.invokeMethod<bool>('isAvailable') ?? false;

  @override
  Future<HealthKitAuthorization> authorize() async {
    final verdict = await _method.invokeMethod<Object?>('authorize');
    return switch (verdict) {
      'granted' => HealthKitAuthorization.granted,
      'denied' => HealthKitAuthorization.denied,
      _ => HealthKitAuthorization.unknown,
    };
  }

  @override
  Future<String?> saveWorkout(HealthWorkoutPayload payload) =>
      _method.invokeMethod<String>('saveWorkout', payload.toMap());

  @override
  Future<void> openHealthSettings() => _method.invokeMethod<void>('openHealthSettings');
}
