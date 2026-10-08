import 'dart:io';

import 'past_workout.dart';
import 'workout_repository.dart';
import 'workout_summary.dart';

/// A [WorkoutRepository] that keeps rides in memory. Lives in `lib/` like the
/// fake channels, so widget tests and captures can inject it.
class MemoryWorkoutRepository extends WorkoutRepository {
  MemoryWorkoutRepository({List<PastWorkout> rides = const []}) {
    for (final r in rides) {
      _rides[r.fileName] = r;
    }
  }

  final Map<String, PastWorkout> _rides = {};
  final Map<String, List<int>> _bytes = {};
  int saves = 0;

  static String fileNameFor(DateTime startedAt) {
    final d = startedAt.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'workout-${d.year}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}${two(d.second)}Z.fit';
  }

  @override
  Future<Directory> rootDirectory() async => Directory('/memory/workouts');

  @override
  Future<File> save({required DateTime startedAt, required List<int> fitBytes, WorkoutSummary? summary}) async {
    saves++;
    final name = fileNameFor(startedAt);
    final file = File('/memory/workouts/$name');
    _rides[name] = PastWorkout(file: file, startedAt: startedAt.toUtc(), sizeBytes: fitBytes.length, summary: summary);
    _bytes[name] = fitBytes;
    return file;
  }

  @override
  Future<List<PastWorkout>> list() async => _rides.values.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<void> delete(File file) async {
    final name = file.uri.pathSegments.last;
    _rides.remove(name);
    _bytes.remove(name);
  }

  @override
  Future<PastWorkout> update(PastWorkout ride, WorkoutSummary summary) async {
    final updated = PastWorkout(
      file: ride.file,
      startedAt: ride.startedAt,
      sizeBytes: ride.sizeBytes,
      summary: summary,
    );
    _rides[ride.fileName] = updated;
    return updated;
  }

  @override
  Future<List<int>> readBytes(PastWorkout ride) async => _bytes[ride.fileName] ?? const [];
}
