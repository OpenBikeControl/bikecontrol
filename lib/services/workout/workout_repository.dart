import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'past_workout.dart';
import 'workout_summary.dart';

class WorkoutRepository {
  final Directory? _rootOverride;

  /// Where a damaged sidecar is reported (recordError in the app).
  final void Function(Object error, StackTrace stack, String context)? onError;

  WorkoutRepository({Directory? rootOverride, this.onError}) : _rootOverride = rootOverride;

  Future<Directory> rootDirectory() async {
    final override = _rootOverride;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}workouts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> save({
    required DateTime startedAt,
    required List<int> fitBytes,
    WorkoutSummary? summary,
  }) async {
    final dir = await rootDirectory();
    final name = _filenameFor(startedAt);
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    // Write to a temp file then rename so a crash mid-write doesn't leave a
    // half .fit file that list() would surface as a "past workout".
    await _atomicWriteBytes(file, fitBytes);
    if (summary != null) {
      await _atomicWriteString(_sidecarFor(file), jsonEncode(summary.toJson()));
    }
    return file;
  }

  Future<void> _atomicWriteBytes(File target, List<int> bytes) async {
    final tmp = File('${target.path}.tmp');
    if (await tmp.exists()) await tmp.delete();
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
  }

  Future<void> _atomicWriteString(File target, String contents) async {
    final tmp = File('${target.path}.tmp');
    if (await tmp.exists()) await tmp.delete();
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(target.path);
  }

  Future<List<PastWorkout>> list() async {
    final dir = await rootDirectory();
    final entries = await dir.list().toList();
    final workouts = <PastWorkout>[];
    for (final e in entries) {
      if (e is! File) continue;
      if (!e.path.toLowerCase().endsWith('.fit')) continue;
      final parsed = _parseFilename(e.path);
      if (parsed == null) continue;
      final stat = await e.stat();
      workouts.add(
        PastWorkout(
          file: e,
          startedAt: parsed,
          sizeBytes: stat.size,
          summary: await _readSidecar(e),
        ),
      );
    }
    workouts.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return workouts;
  }

  Future<void> delete(File file) async {
    if (await file.exists()) await file.delete();
    final sidecar = _sidecarFor(file);
    if (await sidecar.exists()) await sidecar.delete();
  }

  /// Every ride and its sidecar.
  Future<void> deleteAll() async {
    for (final ride in await list()) {
      await delete(ride.file);
    }
  }

  /// The ride saved under [fileName], or null when it is gone.
  Future<PastWorkout?> find(String fileName) async {
    for (final ride in await list()) {
      if (ride.fileName == fileName) return ride;
    }
    return null;
  }

  /// Rewrites [ride]'s sidecar (export bookkeeping), keeping the .fit.
  Future<PastWorkout> update(PastWorkout ride, WorkoutSummary summary) async {
    await _atomicWriteString(_sidecarFor(ride.file), jsonEncode(summary.toJson()));
    return PastWorkout(file: ride.file, startedAt: ride.startedAt, sizeBytes: ride.sizeBytes, summary: summary);
  }

  Future<List<int>> readBytes(PastWorkout ride) => ride.file.readAsBytes();

  File _sidecarFor(File fit) => File('${fit.path}.json');

  Future<WorkoutSummary?> _readSidecar(File fit) async {
    final sidecar = _sidecarFor(fit);
    if (!await sidecar.exists()) return null;
    try {
      final raw = await sidecar.readAsString();
      final json = jsonDecode(raw) as Map<String, Object?>;
      return WorkoutSummary.fromJson(json);
    } catch (e, s) {
      // A damaged sidecar only costs the ride its numbers; the .fit stays.
      onError?.call(e, s, 'WorkoutRepository.readSidecar');
      return null;
    }
  }

  String _filenameFor(DateTime when) {
    final d = when.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${d.year}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}${two(d.second)}Z';
    return 'workout-$stamp.fit';
  }

  DateTime? _parseFilename(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final match = RegExp(r'^workout-(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z\.fit$').firstMatch(name);
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
}
