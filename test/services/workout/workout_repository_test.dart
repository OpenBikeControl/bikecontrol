import 'dart:io';

import 'package:bike_control/services/workout/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('workout-repo-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('empty directory yields empty list', () async {
    final repo = WorkoutRepository(rootOverride: tmp);
    expect(await repo.list(), isEmpty);
  });

  test('writeAndList finds the file, parses timestamp from filename', () async {
    final repo = WorkoutRepository(rootOverride: tmp);
    final saved = await repo.save(
      startedAt: DateTime.utc(2026, 4, 24, 10, 5, 7),
      fitBytes: [1, 2, 3, 4],
    );
    expect(await saved.exists(), isTrue);
    final list = await repo.list();
    expect(list, hasLength(1));
    expect(list.first.startedAt, DateTime.utc(2026, 4, 24, 10, 5, 7));
  });

  test('delete removes file', () async {
    final repo = WorkoutRepository(rootOverride: tmp);
    final saved = await repo.save(
      startedAt: DateTime.utc(2026, 4, 24, 10, 5, 7),
      fitBytes: [9, 9],
    );
    await repo.delete(saved);
    expect(await saved.exists(), isFalse);
    expect(await repo.list(), isEmpty);
  });

  test('list ignores non-fit files', () async {
    final repo = WorkoutRepository(rootOverride: tmp);
    await File('${tmp.path}/notes.txt').writeAsString('nope');
    await repo.save(startedAt: DateTime.utc(2026, 4, 24, 11), fitBytes: [0]);
    final list = await repo.list();
    expect(list, hasLength(1));
  });
}
