import '../sensors/health_kit_channel.dart';
import 'health_workout_channel.dart';
import 'health_workout_payload.dart';

/// Scripted [HealthWorkoutChannel] for unit and widget tests. Lives in `lib/`
/// like `FakeHealthKitChannel`, so widget tests can inject it.
class FakeHealthWorkoutChannel implements HealthWorkoutChannel {
  bool available = true;
  HealthKitAuthorization authorization = HealthKitAuthorization.granted;
  int authorizeCalls = 0;
  int openSettingsCalls = 0;

  /// Thrown by the next [authorize] (after counting it) when set.
  Object? authorizeError;

  /// Thrown by every [saveWorkout] while set.
  Object? saveError;

  final List<HealthWorkoutPayload> saved = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<HealthKitAuthorization> authorize() async {
    authorizeCalls++;
    final error = authorizeError;
    if (error != null) throw error;
    return authorization;
  }

  @override
  Future<String?> saveWorkout(HealthWorkoutPayload payload) async {
    final error = saveError;
    if (error != null) throw error;
    saved.add(payload);
    return 'fake-${saved.length}';
  }

  @override
  Future<void> openHealthSettings() async => openSettingsCalls++;
}
