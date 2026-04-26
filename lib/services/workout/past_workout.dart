import 'dart:io';

import 'workout_summary.dart';

/// Listing-row view of a `.fit` file on disk. Fields are derived from the
/// filename (startedAt) plus `stat()` (sizeBytes) — we don't parse FIT here
/// to keep the list fast. [summary] is hydrated from a sidecar JSON written
/// alongside the FIT at save time; older workouts without a sidecar leave
/// it null.
class PastWorkout {
  final File file;
  final DateTime startedAt;
  final int sizeBytes;
  final WorkoutSummary? summary;

  const PastWorkout({
    required this.file,
    required this.startedAt,
    required this.sizeBytes,
    this.summary,
  });

  String get fileName => file.path.split(Platform.pathSeparator).last;
}
