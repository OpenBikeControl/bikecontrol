// Crash persistence must never re-enter itself. recordError's listener
// persists every error together with a debugText() bundle, and debugText
// records its own diagnostics-gather timeout through recordError. Once a gather
// hung, every 6 s timeout persisted a new entry, which gathered again and timed
// out again — for the rest of the process. That flooded the support log with
// "debugText.diagnostics" timeouts and left a timer pending that no widget test
// could ever settle.
import 'dart:async';

import 'package:bike_control/main.dart' show installLoggerErrorListener, recordError;
import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/menu.dart' show debugDiagnosticsGatherOverride;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/shared.dart' show Logger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int gathers;
  late List<String> recordedContexts;
  late int logLinesBefore;

  setUp(() {
    core.connection.startLogCapture();
    logLinesBefore = core.connection.lastLogEntries.length;

    // A diagnostics gather that never completes (a stuck interface lookup or
    // platform call), so only debugText's own 6 s timeout ends it.
    gathers = 0;
    debugDiagnosticsGatherOverride = ({bool includeDiscovery = true}) {
      gathers++;
      return Completer<DebugDiagnostics>().future;
    };
    addTearDown(() => debugDiagnosticsGatherOverride = null);

    // The real pipeline stays in place; this only counts what reaches it.
    installLoggerErrorListener();
    final pipeline = Logger.onRecordError!;
    recordedContexts = [];
    Logger.onRecordError = (context, error, stack) {
      recordedContexts.add(context);
      pipeline(context, error, stack);
    };
    addTearDown(() => Logger.onRecordError = pipeline);
  });

  List<String> newLogLinesContaining(String text) => core.connection.lastLogEntries
      .skip(logLinesBefore)
      .map((e) => e.entry)
      .where((entry) => entry.contains(text))
      .toList();

  test('a diagnostics timeout while persisting a crash is recorded once and never starts another gather', () {
    fakeAsync((async) {
      recordError(Exception('original failure'), StackTrace.current, context: 'test.original');
      async.flushMicrotasks();
      expect(gathers, 1, reason: 'the original error is persisted with a full debug text');

      // Ten timeouts' worth of time: the old pipeline gathered again after each.
      async.elapse(const Duration(minutes: 1));

      expect(gathers, 1, reason: 'the timeout recorded inside the persist must not gather again');
      expect(recordedContexts, ['test.original', 'debugText.diagnostics']);
      expect(async.pendingTimers, isEmpty, reason: 'nothing may re-arm once the one timeout has fired');
      // Recorded, not swallowed: each error reaches the support log exactly once.
      expect(newLogLinesContaining('original failure'), hasLength(1));
      expect(newLogLinesContaining('TimeoutException'), hasLength(1));
    });
  });

  test('a later error, recorded after that persist finished, still gets its own diagnostics gather', () {
    fakeAsync((async) {
      recordError(Exception('first failure'), StackTrace.current, context: 'test.first');
      async.elapse(const Duration(seconds: 7));
      expect(gathers, 1);

      recordError(Exception('second failure'), StackTrace.current, context: 'test.second');
      async.flushMicrotasks();
      expect(gathers, 2, reason: 'the guard only covers the persist that is still gathering');

      async.elapse(const Duration(seconds: 7));
      expect(gathers, 2);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
