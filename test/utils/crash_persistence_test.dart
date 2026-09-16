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

/// A gather whose time limit never fires, standing in for an await in
/// debugText that has no limit of its own.
class _IgnoresTimeLimit implements Future<DebugDiagnostics> {
  final _never = Completer<DebugDiagnostics>().future;

  @override
  Future<DebugDiagnostics> timeout(Duration timeLimit, {FutureOr<DebugDiagnostics> Function()? onTimeout}) => this;

  @override
  Future<R> then<R>(FutureOr<R> Function(DebugDiagnostics value) onValue, {Function? onError}) =>
      _never.then(onValue, onError: onError);

  @override
  Future<DebugDiagnostics> catchError(Function onError, {bool Function(Object error)? test}) =>
      _never.catchError(onError, test: test);

  @override
  Future<DebugDiagnostics> whenComplete(FutureOr<void> Function() action) => _never.whenComplete(action);

  @override
  Stream<DebugDiagnostics> asStream() => _never.asStream();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int gathers;
  late List<String> recordedContexts;
  late int logLinesBefore;

  setUp(() {
    core.connection.startLogCapture();
    logLinesBefore = core.connection.lastLogEntries.length;

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

  /// Routes this test's diagnostics gathers through [gather], counting them.
  void gatherVia(Future<DebugDiagnostics> Function() gather) {
    final previous = debugDiagnosticsGatherOverride;
    addTearDown(() => debugDiagnosticsGatherOverride = previous);
    gathers = 0;
    debugDiagnosticsGatherOverride = ({bool includeDiscovery = true}) {
      gathers++;
      return gather();
    };
  }

  /// Records [message] through the real pipeline. Its listener prints every
  /// error with a stack trace, so that output is kept for failing runs only.
  /// Everything the record sets off later (timeouts, nested records) runs in
  /// this zone too.
  void record(String message, {required String context}) {
    runZoned(
      () => recordError(Exception(message), StackTrace.current, context: context),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => printOnFailure(line)),
    );
  }

  List<String> newLogLinesContaining(String text) => core.connection.lastLogEntries
      .skip(logLinesBefore)
      .map((e) => e.entry)
      .where((entry) => entry.contains(text))
      .toList();

  // Each test advances fake time before its first expectation. A failed
  // expectation then can't leave a persist mid-gather, holding the guard for
  // the tests after it.
  group('with a diagnostics gather that never completes', () {
    setUp(() => gatherVia(() => Completer<DebugDiagnostics>().future));

    test('a diagnostics timeout while persisting a crash is recorded once and never starts another gather', () {
      fakeAsync((async) {
        record('original failure', context: 'test.original');
        async.flushMicrotasks();
        final gathersOnRecord = gathers;
        // Ten timeouts' worth of time: the old pipeline gathered again after each.
        async.elapse(const Duration(minutes: 1));

        expect(gathersOnRecord, 1, reason: 'the original error is persisted with a full debug text');
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
        record('first failure', context: 'test.first');
        async.elapse(const Duration(seconds: 7));
        final gathersAfterFirst = gathers;

        record('second failure', context: 'test.second');
        async.flushMicrotasks();
        final gathersOnSecond = gathers;
        async.elapse(const Duration(seconds: 7));

        expect(gathersAfterFirst, 1);
        expect(gathersOnSecond, 2, reason: 'the guard only covers the persist that is still gathering');
        expect(gathers, 2);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('with a debug text that never returns', () {
    setUp(() => gatherVia(_IgnoresTimeLimit.new));

    test('the persist stops waiting, records that once, and frees the guard for the next error', () {
      fakeAsync((async) {
        record('stalled failure', context: 'test.stalled');
        async.elapse(const Duration(minutes: 1));
        final contextsAfterFirst = [...recordedContexts];

        record('next failure', context: 'test.next');
        async.flushMicrotasks();
        final gathersOnNext = gathers;
        async.elapse(const Duration(minutes: 1));

        expect(contextsAfterFirst, ['test.stalled', 'persistCrash.debugText']);
        expect(gathersOnNext, 2, reason: 'a debug text that never returns must not hold the guard for good');
        expect(recordedContexts, ['test.stalled', 'persistCrash.debugText', 'test.next', 'persistCrash.debugText']);
        expect(async.pendingTimers, isEmpty);
        expect(newLogLinesContaining('TimeoutException'), hasLength(2));
      });
    });
  });

  // test/flutter_test_config.dart fakes the gather for every test. The first
  // test records the way any widget test does; flutter_test fails it if a
  // timeout is still pending at the end. The second test depends on running
  // after the first: if the first had abandoned a gather, the guard would
  // still be set and this error would get no gather at all.
  group('under the shared test harness', () {
    testWidgets('a widget test that records an error ends with nothing pending', (tester) async {
      record('recorded by a widget test', context: 'test.widget');
      await tester.pump();

      expect(recordedContexts, ['test.widget']);
      expect(newLogLinesContaining('recorded by a widget test'), hasLength(1));
    });

    testWidgets('the next test still gathers diagnostics for its own error', (tester) async {
      // The real gather is only reached if the harness is missing, and then
      // the first test has already failed.
      final harnessGather = debugDiagnosticsGatherOverride ?? DebugDiagnostics.gather;
      gatherVia(() => harnessGather(includeDiscovery: false));
      record('recorded by the next test', context: 'test.next');
      await tester.pump();

      expect(gathers, 1, reason: 'an earlier test must not leave the crash pipeline unable to gather');
      expect(recordedContexts, ['test.next']);
    });
  });
}
