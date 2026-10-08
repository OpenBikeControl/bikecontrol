import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/services/network_self_test/probes/guided_watch_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/mdns/mdns_responder.dart';

const _defaultWindow = Duration(seconds: 3);
const _defaultTick = Duration(seconds: 1);

/// A context with no-op seams; every field can be overridden per test.
///
/// `now` defaults to a fake clock that advances by exactly [_defaultTick] on
/// every call — since [ctx]'s `sleep` never actually waits, this is what
/// makes the watch loop's "window elapsed" exit deterministic instead of
/// looping forever.
NetworkProbeContext ctx({
  ObpMdnsBackend backend = ObpMdnsBackend.platformDefault,
  String? advertisedHostname = 'BikeControl.local',
  List<MdnsQueryLogEntry> Function()? queryLog,
  bool Function()? trainerAppConnectedNow,
  WatchProgressCallback? onWatchProgress,
  String platform = 'macos',
}) {
  var nowCalls = 0;
  final base = DateTime(2026, 8, 21);
  return NetworkProbeContext(
    snapshot: null,
    snapshotError: null,
    emulatorStarted: true,
    trainerAppConnected: false,
    trainerAppConnectedNow: trainerAppConnectedNow ?? () => false,
    trainerAppName: null,
    backend: backend,
    advertisedHostname: advertisedHostname,
    platform: platform,
    resolve: (host) async => const [],
    tcpProbe: (address, port) async {},
    runProcess: (executable, arguments) async => ProcessResult(0, 0, '', ''),
    queryLog: queryLog ?? () => const [],
    sleep: (d) async {},
    now: () => base.add(_defaultTick * nowCalls++),
    onWatchProgress: onWatchProgress ?? (progress) {},
  );
}

MdnsQueryLogEntry _entry(List<String> questions, {int count = 1}) => MdnsQueryLogEntry(
  at: DateTime(2026, 8, 21),
  source: '192.168.1.50',
  sourcePort: 5353,
  wantsUnicast: false,
  questions: questions,
  answeredUnicast: false,
  answeredMulticast: true,
  count: count,
);

/// Builds a `queryLog` closure driven by a scripted list of "snapshots" — one
/// per tick the watch is expected to observe, in growing order. Once the
/// script is exhausted, further calls keep returning the last snapshot
/// unchanged (steady state — no more new asks), so tests don't need to guess
/// the exact number of ticks the watch loop runs before the window elapses.
List<MdnsQueryLogEntry> Function() _scriptedLog(List<List<MdnsQueryLogEntry>> snapshots) {
  var call = 0;
  return () {
    final index = call < snapshots.length ? call : snapshots.length - 1;
    call++;
    return snapshots[index];
  };
}

void main() {
  group('guidedWatchCheck', () {
    test('pass: connects immediately, before any query is observed', () async {
      final progress = <WatchProgress>[];
      final check = await guidedWatchCheck(
        ctx(trainerAppConnectedNow: () => true, onWatchProgress: progress.add),
        window: _defaultWindow,
        tick: _defaultTick,
      );
      expect(check.id, NetworkCheckId.guidedWatch);
      expect(check.verdict, NetworkVerdict.pass);
      expect(progress, isNotEmpty);
      expect(progress.first.connected, isTrue);
    });

    test('fail: >= 3 address asks and never connects, useOsResponderForObc under platformDefault', () async {
      final entry = _entry(const ['A BikeControl.local']);
      var calls = 0;
      List<MdnsQueryLogEntry> queryLog() {
        // The responder mutates the same folded entry in place; each repeat
        // bumps `count` without a new entry appearing in the list.
        if (calls > 0) entry.count++;
        calls++;
        return [entry];
      }

      final check = await guidedWatchCheck(
        ctx(backend: ObpMdnsBackend.platformDefault, queryLog: queryLog),
        window: _defaultWindow,
        tick: _defaultTick,
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.detail['addressAsks'], isNotNull);
      expect(int.parse(check.detail['addressAsks']!), greaterThanOrEqualTo(3));
      expect(check.fixes, contains(NetworkFixId.useOsResponderForObc));
    });

    test('fail: no query arrives at all, switchToLocal', () async {
      final check = await guidedWatchCheck(ctx(queryLog: () => const []), window: _defaultWindow, tick: _defaultTick);
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.detail['hint'], 'no query arrived');
      expect(check.fixes, contains(NetworkFixId.switchToLocal));
    });

    // The trainer app never even searched: most often it is not allowed to
    // use the local network, or is on another Wi-Fi. Using the Local method
    // instead is one way out, but the cause is in the trainer app's settings.
    group('no query arrived', () {
      test('on a Mac, offers the Local Network settings first, where the trainer app is switched on', () async {
        final check = await guidedWatchCheck(ctx(platform: 'macos'), window: _defaultWindow, tick: _defaultTick);
        expect(check.fixes, [NetworkFixId.openAppLocalNetworkSettings, NetworkFixId.switchToLocal]);
      });

      for (final platform in ['windows', 'android', 'linux']) {
        test('on $platform, there is no such settings page to open', () async {
          final check = await guidedWatchCheck(ctx(platform: platform), window: _defaultWindow, tick: _defaultTick);
          expect(check.verdict, NetworkVerdict.fail);
          expect(check.fixes, [NetworkFixId.switchToLocal]);
        });
      }
    });

    test('warn: browsed but never resolved', () async {
      final browse = _entry(const ['PTR _openbikecontrol._tcp.local']);
      final check = await guidedWatchCheck(
        ctx(queryLog: _scriptedLog([const [], [browse]])),
        window: _defaultWindow,
        tick: _defaultTick,
      );
      expect(check.verdict, NetworkVerdict.warn);
    });

    test('warn: browsed and resolved but no address asks and never connected', () async {
      final browse = _entry(const ['PTR _openbikecontrol._tcp.local']);
      final resolve = _entry(const ['SRV BikeControl._openbikecontrol._tcp.local']);
      final check = await guidedWatchCheck(
        ctx(queryLog: _scriptedLog([const [], [browse], [browse, resolve]])),
        window: _defaultWindow,
        tick: _defaultTick,
      );
      expect(check.verdict, NetworkVerdict.warn);
      expect(check.detail['note'], 'found and resolved, never connected');
    });

    test('skipped: cancelled mid-watch', () async {
      final check = await guidedWatchCheck(
        ctx(),
        window: _defaultWindow,
        tick: _defaultTick,
        isCancelled: () => true,
      );
      expect(check.verdict, NetworkVerdict.skipped);
      expect(check.detail['reason'], 'skipped');
    });

    test('pass: osResponder backend, connects', () async {
      final check = await guidedWatchCheck(
        ctx(backend: ObpMdnsBackend.osResponder, trainerAppConnectedNow: () => true),
        window: _defaultWindow,
        tick: _defaultTick,
      );
      expect(check.verdict, NetworkVerdict.pass);
    });

    // The system mDNS service (Android NSD) is the recommended setting, and
    // under it the queries never reach BikeControl — so the watch can see
    // nothing go wrong. Counting that as a warning told every rider on the
    // recommended setting "something on this network could interfere".
    test('pass with a note: osResponder backend, never connects — nothing to observe is not a warning', () async {
      for (final platform in ['android', 'windows', 'macos']) {
        final check = await guidedWatchCheck(
          ctx(backend: ObpMdnsBackend.osResponder, platform: platform),
          window: _defaultWindow,
          tick: _defaultTick,
        );
        expect(check.verdict, NetworkVerdict.pass, reason: platform);
        expect(check.detail['note'], contains('TCP accept'));
        expect(check.detail['connected'], 'false');
        expect(check.fixes, isEmpty);
      }
    });

    test('count increase on an existing entry (no new list entry) still counts as a new ask', () async {
      final entry = _entry(const ['AAAA BikeControl.local'], count: 1);
      var calls = 0;
      List<MdnsQueryLogEntry> queryLog() {
        // Same object every call: the list never grows, only `count` climbs
        // — exactly how the responder folds repeated identical queries.
        if (calls > 0) entry.count++;
        calls++;
        return [entry];
      }

      final check = await guidedWatchCheck(ctx(queryLog: queryLog), window: _defaultWindow, tick: _defaultTick);
      expect(check.verdict, NetworkVerdict.fail);
      expect(int.parse(check.detail['addressAsks']!), greaterThanOrEqualTo(3));
    });

    // Regressions for the identity-based fold correlation: the real
    // responder (MdnsResponder._recordQuery) folds an exact repeat by
    // REMOVING the existing entry instance and RE-APPENDING it at the end of
    // the log, so list *position* is not a stable correlation key across
    // ticks — only the entry *instance* is stable. These logs always carry
    // more than one entry so a fold actually reshuffles positions, unlike
    // the single-entry tests above (which happen to pass even under a
    // position-keyed implementation, since there is nothing to shift past).
    group('identity-based fold correlation (multi-entry logs)', () {
      // Each `queryLog` closure below mutates lazily — only from the SECOND
      // call onward — so the very first call (the watch's baseline read)
      // observes the true pre-fold state. Pre-building a static list of
      // snapshots would not do this correctly: since the entries are shared
      // mutable objects (the whole point — identity must survive the fold),
      // mutating one "ahead of time" would already be visible on the
      // baseline snapshot too, because it is the same instance.

      test(
        'an unrelated entry folding past an A entry does not inflate addressAsks (position != identity)',
        () async {
          // Baseline: `other` sits in front of `address`. When `other` folds
          // it is removed and re-appended at the tail, so `address` slides
          // into `other`'s old (now vacated) slot — a position-keyed
          // implementation would compare `address`'s unchanged count against
          // whatever count previously lived at that slot (`other`'s) and
          // wrongly see growth.
          final other = _entry(const ['PTR _airplay._tcp.local'], count: 1);
          final address = _entry(const ['A BikeControl.local'], count: 5);
          var calls = 0;
          List<MdnsQueryLogEntry> queryLog() {
            if (calls == 0) {
              calls++;
              return [other, address];
            }
            if (calls == 1) {
              other.count++; // `other` folds; `address` stays untouched.
              calls++;
            }
            return [address, other]; // same instances, `other` moved to the tail.
          }

          final progress = <WatchProgress>[];
          final check = await guidedWatchCheck(
            ctx(queryLog: queryLog, onWatchProgress: progress.add),
            window: _defaultWindow,
            tick: _defaultTick,
          );

          expect(progress, isNotEmpty);
          expect(progress.every((p) => p.addressAsks == 0), isTrue);
          expect(check.detail['addressAsks'], isNull);
        },
      );

      test('a baseline browse entry that keeps folding is still classified as browsed', () async {
        // `browse` already exists at watch start (a continuous browser was
        // running before the button was pressed) and keeps folding — it
        // must not be dismissed as "not new" just because it was present at
        // baseline; a fold during the watch is fresh activity.
        final browse = _entry(const ['PTR _openbikecontrol._tcp.local'], count: 1);
        final other = _entry(const ['TXT unrelated.local'], count: 1);
        var calls = 0;
        List<MdnsQueryLogEntry> queryLog() {
          if (calls == 0) {
            calls++;
            return [browse, other];
          }
          if (calls == 1) {
            browse.count++; // `browse` folds during the watch; moved to the tail.
            calls++;
          }
          return [other, browse];
        }

        final check = await guidedWatchCheck(
          ctx(queryLog: queryLog),
          window: _defaultWindow,
          tick: _defaultTick,
        );

        expect(check.verdict, NetworkVerdict.warn);
        expect(check.detail['hint'], isNot('no query arrived'));
        expect(check.fixes, isNot(contains(NetworkFixId.switchToLocal)));
      });

      test('a baseline address-ask entry that keeps folding amid other traffic still reaches the fail threshold', () async {
        // `address` starts in front of `other`; every fold removes it and
        // re-appends it at the tail, so by the last tick the two have
        // swapped relative order entirely while `other` never changes.
        final address = _entry(const ['A BikeControl.local'], count: 1);
        final other = _entry(const ['PTR _airplay._tcp.local'], count: 1);
        var calls = 0;
        List<MdnsQueryLogEntry> queryLog() {
          if (calls == 0) {
            calls++;
            return [address, other];
          }
          address.count++; // folds again every subsequent tick.
          calls++;
          return [other, address];
        }

        final check = await guidedWatchCheck(
          ctx(queryLog: queryLog),
          window: _defaultWindow,
          tick: _defaultTick,
        );

        expect(check.verdict, NetworkVerdict.fail);
        expect(int.parse(check.detail['addressAsks']!), greaterThanOrEqualTo(3));
        expect(check.fixes, contains(NetworkFixId.useOsResponderForObc));
      });
    });
  });
}
