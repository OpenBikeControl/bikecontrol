//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation notices when the process stood still (suspended,
// machine asleep) and tells its listeners how long. The stub never sees one.

import 'dart:async';

class SuspensionWatch {
  SuspensionWatch({
    this.tick = const Duration(seconds: 5),
    this.threshold = const Duration(seconds: 20),
    DateTime Function() now = DateTime.now,
  });

  static final SuspensionWatch instance = SuspensionWatch();

  final Duration tick;
  final Duration threshold;

  DateTime? lastGapEndedAt;
  Duration? lastGap;
  int gapCount = 0;

  bool get isRunning => false;

  void addListener(FutureOr<void> Function(Duration gap) listener) {}

  void removeListener(FutureOr<void> Function(Duration gap) listener) {}

  void start() {}

  void stop() {}

  void check() {}

  String get status => 'not running';

  void reset() {}
}
