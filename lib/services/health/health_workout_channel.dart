import 'package:flutter/services.dart';

import '../sensors/health_kit_channel.dart';
import 'health_workout_payload.dart';

/// Where rides go: Apple Health on iPhone/iPad, Health Connect on Android.
enum HealthStore { appleHealth, healthConnect }

enum HealthAvailability {
  available,

  /// Health Connect is supported but not installed (Android 9–13); the
  /// rider can install it from the Play Store.
  notInstalled,
  unsupported,
}

/// The native seam for writing rides to Apple Health / Health Connect. One
/// method-channel implementation per store, and one fake.
abstract class HealthWorkoutChannel {
  HealthStore get store;

  Future<HealthAvailability> availability();

  /// Asks to WRITE the workout and its samples.
  Future<HealthKitAuthorization> authorize();

  /// Writes one ride; returns the saved workout's id. Throws
  /// [PlatformException] (code `denied` when writing is refused).
  Future<String?> saveWorkout(HealthWorkoutPayload payload);

  /// Opens the store's own permission screen, where the rider can change
  /// what BikeControl may write.
  Future<void> openHealthSettings();

  /// Opens the store itself, where saved rides are: the Health app, or
  /// Health Connect's data. Neither links to one workout.
  Future<void> openHealthApp();

  /// Opens the Play Store page of Health Connect. No-op for Apple Health.
  Future<void> openInstall();
}

/// Talks to `ios/Runner/HealthKitWorkoutWriter.swift` or
/// `android/.../HealthConnectWorkoutWriter.kt`. Channel names and payload
/// shape are pinned by `health_workout_channel_test.dart`; change both sides
/// together.
class MethodChannelHealthWorkout implements HealthWorkoutChannel {
  MethodChannelHealthWorkout.appleHealth()
    : store = HealthStore.appleHealth,
      _method = const MethodChannel('bike_control/health_kit/workouts');

  MethodChannelHealthWorkout.healthConnect()
    : store = HealthStore.healthConnect,
      _method = const MethodChannel('bike_control/health_connect/workouts');

  @override
  final HealthStore store;
  final MethodChannel _method;

  @override
  Future<HealthAvailability> availability() async {
    if (store == HealthStore.appleHealth) {
      final available = await _method.invokeMethod<bool>('isAvailable') ?? false;
      return available ? HealthAvailability.available : HealthAvailability.unsupported;
    }
    return switch (await _method.invokeMethod<Object?>('availability')) {
      'available' => HealthAvailability.available,
      'notInstalled' => HealthAvailability.notInstalled,
      _ => HealthAvailability.unsupported,
    };
  }

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

  @override
  Future<void> openHealthApp() => _method.invokeMethod<void>('openHealthApp');

  @override
  Future<void> openInstall() async {
    if (store == HealthStore.appleHealth) return;
    await _method.invokeMethod<void>('openInstall');
  }
}
