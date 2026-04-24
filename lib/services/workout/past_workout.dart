import 'dart:io';

/// Listing-row view of a `.fit` file on disk. Fields are derived from the
/// filename (startedAt) plus `stat()` (sizeBytes) — we don't parse FIT here
/// to keep the list fast. Open-on-tap can do a full parse.
class PastWorkout {
  final File file;
  final DateTime startedAt;
  final int sizeBytes;

  const PastWorkout({
    required this.file,
    required this.startedAt,
    required this.sizeBytes,
  });

  String get fileName => file.path.split(Platform.pathSeparator).last;
}
