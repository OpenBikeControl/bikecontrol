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
