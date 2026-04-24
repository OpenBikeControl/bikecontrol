import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'past_workout.dart';

class WorkoutRepository {
  final Directory? _rootOverride;
  WorkoutRepository({Directory? rootOverride}) : _rootOverride = rootOverride;

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

  Future<File> save({required DateTime startedAt, required List<int> fitBytes}) async {
    final dir = await rootDirectory();
    final name = _filenameFor(startedAt);
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(fitBytes, flush: true);
    return file;
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
      workouts.add(PastWorkout(file: e, startedAt: parsed, sizeBytes: stat.size));
    }
    workouts.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return workouts;
  }

  Future<void> delete(File file) async {
    if (await file.exists()) await file.delete();
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
