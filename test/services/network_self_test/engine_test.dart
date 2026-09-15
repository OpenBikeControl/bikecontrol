import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/main.dart' show installLoggerErrorListener;
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/services/network_self_test/network_self_test_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/shared.dart';

/// A context with no-op seams; nothing here is actually read by the inline
/// stub probes used below — the engine only ever passes it through.
NetworkProbeContext _ctx({String platform = 'macos'}) => NetworkProbeContext(
  snapshot: null,
  snapshotError: null,
  emulatorStarted: true,
  trainerAppConnected: false,
  trainerAppConnectedNow: () => false,
  trainerAppName: null,
  backend: ObpMdnsBackend.platformDefault,
  advertisedHostname: null,
  platform: platform,
  resolve: (host) async => const [],
  tcpProbe: (address, port) async {},
  runProcess: (executable, arguments) async => ProcessResult(0, 0, '', ''),
  queryLog: () => const [],
  sleep: (d) async {},
  now: () => DateTime(2026, 8, 21),
  onWatchProgress: (progress) {},
);

NetworkCheck _pass(NetworkCheckId id) => NetworkCheck(id: id, verdict: NetworkVerdict.pass);

void main() {
  tearDown(() {
    Logger.onRecordError = null;
  });

  test('probes run sequentially, in the order given', () async {
    final order = <NetworkCheckId>[];
    final probes = [
      ProbeSpec(
        id: NetworkCheckId.methodListening,
        timeout: const Duration(seconds: 1),
        run: (ctx) async {
          order.add(NetworkCheckId.methodListening);
          return _pass(NetworkCheckId.methodListening);
        },
      ),
      ProbeSpec(
        id: NetworkCheckId.advertisedAddress,
        timeout: const Duration(seconds: 1),
        run: (ctx) async {
          order.add(NetworkCheckId.advertisedAddress);
          return _pass(NetworkCheckId.advertisedAddress);
        },
      ),
      ProbeSpec(
        id: NetworkCheckId.vpn,
        timeout: const Duration(seconds: 1),
        run: (ctx) async {
          order.add(NetworkCheckId.vpn);
          return _pass(NetworkCheckId.vpn);
        },
      ),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);
    final result = await engine.run();

    expect(order, [NetworkCheckId.methodListening, NetworkCheckId.advertisedAddress, NetworkCheckId.vpn]);
    expect(result.checks.map((c) => c.id).toList(), order);
    expect(result.checks.every((c) => c.verdict == NetworkVerdict.pass), isTrue);
  });

  test('a throwing probe becomes unknown and the run continues', () async {
    var secondRan = false;
    final probes = [
      ProbeSpec(
        id: NetworkCheckId.methodListening,
        timeout: const Duration(seconds: 1),
        run: (ctx) async => throw StateError('boom'),
      ),
      ProbeSpec(
        id: NetworkCheckId.advertisedAddress,
        timeout: const Duration(seconds: 1),
        run: (ctx) async {
          secondRan = true;
          return _pass(NetworkCheckId.advertisedAddress);
        },
      ),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);
    final result = await engine.run();

    expect(result.checks[0].id, NetworkCheckId.methodListening);
    expect(result.checks[0].verdict, NetworkVerdict.unknown);
    expect(result.checks[0].detail['error'], contains('boom'));
    expect(secondRan, isTrue, reason: 'a throwing probe must not stop the rest of the run');
    expect(result.checks[1].verdict, NetworkVerdict.pass);
  });

  test('a probe exceeding its timeout becomes unknown with error=timeout', () async {
    final probes = [
      ProbeSpec(
        id: NetworkCheckId.methodListening,
        timeout: const Duration(milliseconds: 50),
        run: (ctx) => Completer<NetworkCheck>().future, // never completes
      ),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);
    final result = await engine.run();

    expect(result.checks, hasLength(1));
    expect(result.checks.single.verdict, NetworkVerdict.unknown);
    expect(result.checks.single.detail['error'], 'timeout');
  });

  test('cancel() before a probe starts yields skipped for it and everything after', () async {
    late NetworkSelfTestEngine engine;
    final probes = [
      ProbeSpec(
        id: NetworkCheckId.methodListening,
        timeout: const Duration(seconds: 1),
        run: (ctx) async {
          engine.cancel();
          return _pass(NetworkCheckId.methodListening);
        },
      ),
      ProbeSpec(
        id: NetworkCheckId.advertisedAddress,
        timeout: const Duration(seconds: 1),
        run: (ctx) async => _pass(NetworkCheckId.advertisedAddress),
      ),
      ProbeSpec(id: NetworkCheckId.vpn, timeout: const Duration(seconds: 1), run: (ctx) async => _pass(NetworkCheckId.vpn)),
    ];
    engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);
    final result = await engine.run();

    expect(result.checks[0].verdict, NetworkVerdict.pass);
    expect(result.checks[1].id, NetworkCheckId.advertisedAddress);
    expect(result.checks[1].verdict, NetworkVerdict.skipped);
    expect(result.checks[2].id, NetworkCheckId.vpn);
    expect(result.checks[2].verdict, NetworkVerdict.skipped);
    expect(result.completed, isFalse);
    expect(result, isNotNull);
  });

  test('cancelWatch() skips only the guided-watch probe and the run continues', () async {
    // Phase 1: the engine's own default probe list (no `probes:` override) —
    // cancelWatch() must reach the guided-watch probe's `isCancelled` seam
    // and skip it, while — unlike cancel() — leaving the rest of the run
    // alone: `completed` stays true.
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx);
    engine.cancelWatch();
    final result = await engine.run();

    final guidedWatch = result.checks.singleWhere((c) => c.id == NetworkCheckId.guidedWatch);
    expect(guidedWatch.verdict, NetworkVerdict.skipped);
    expect(result.completed, isTrue);

    // Phase 2: on this host, guidedWatch is the last probe in the default
    // list, so phase 1 alone can't show a *later* probe still running after
    // a cancelled watch. Windows' spec order does have probes after it —
    // extract that real, wired guided-watch spec plus its next-door
    // neighbour and confirm the neighbour still runs.
    final windowsSpecs = NetworkSelfTestEngine.defaultProbes('windows', watchCancelled: () => true);
    final guidedWatchIndex = windowsSpecs.indexWhere((s) => s.id == NetworkCheckId.guidedWatch);
    expect(guidedWatchIndex, lessThan(windowsSpecs.length - 1), reason: 'need a probe after guidedWatch to prove this');
    final nextId = windowsSpecs[guidedWatchIndex + 1].id;

    var laterRan = false;
    final chainEngine = NetworkSelfTestEngine(
      contextBuilder: _ctx,
      probes: [
        windowsSpecs[guidedWatchIndex],
        ProbeSpec(
          id: nextId,
          timeout: const Duration(seconds: 1),
          run: (ctx) async {
            laterRan = true;
            return _pass(nextId);
          },
        ),
      ],
    );
    final chainResult = await chainEngine.run();

    expect(chainResult.checks[0].verdict, NetworkVerdict.skipped);
    expect(laterRan, isTrue, reason: 'a cancelled watch must not stop the probes after it');
    expect(chainResult.completed, isTrue);
  });

  test('run() is idempotent — a second call returns the same future', () async {
    final probes = [
      ProbeSpec(id: NetworkCheckId.methodListening, timeout: const Duration(seconds: 1), run: (ctx) async => _pass(NetworkCheckId.methodListening)),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);
    final first = engine.run();
    final second = engine.run();
    expect(identical(first, second), isTrue);
    await first;
  });

  test('a thrown probe error is routed through recordError with a per-check context', () async {
    // recordError() calls the idempotent installLoggerErrorListener(), which
    // only actually assigns Logger.onRecordError the first time it runs in
    // this isolate — trip that guard here, before installing the test's own
    // listener below, so a run of this test in isolation (no earlier test
    // in the file to trip it first) doesn't get its listener clobbered by
    // the production one on the very first recordError() call.
    installLoggerErrorListener();
    final contexts = <String>[];
    Logger.onRecordError = (m, e, s) => contexts.add(m);

    final probes = [
      ProbeSpec(
        id: NetworkCheckId.methodListening,
        timeout: const Duration(seconds: 1),
        run: (ctx) async => throw StateError('boom'),
      ),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);
    await engine.run();

    expect(contexts, contains('NetworkSelfTest.methodListening'));
  });

  test('watch progress updates state.watch without clobbering state.running', () async {
    final observedRunning = <NetworkCheckId?>[];
    final observedWatch = <WatchProgress?>[];
    late NetworkSelfTestEngine engine;
    final probes = [
      ProbeSpec(
        id: NetworkCheckId.guidedWatch,
        timeout: const Duration(seconds: 1),
        run: (ctx) async {
          ctx.onWatchProgress(
            const WatchProgress(browsed: true, resolved: false, addressAsks: 0, connected: false, remaining: Duration(seconds: 30)),
          );
          ctx.onWatchProgress(
            const WatchProgress(browsed: true, resolved: true, addressAsks: 1, connected: false, remaining: Duration(seconds: 20)),
          );
          return _pass(NetworkCheckId.guidedWatch);
        },
      ),
    ];
    engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);
    engine.state.addListener(() {
      observedRunning.add(engine.state.value.running);
      observedWatch.add(engine.state.value.watch);
    });
    await engine.run();

    // Every watch-progress tick must still report the probe that is
    // actually running — a naive re-emit that only threads through `watch`
    // would reset `running` to null on each tick instead.
    final tickIndices = observedWatch.indexed.where((e) => e.$2 != null).map((e) => e.$1);
    expect(tickIndices, isNotEmpty);
    for (final i in tickIndices) {
      expect(observedRunning[i], NetworkCheckId.guidedWatch);
    }
    expect(engine.state.value.watch, isNull, reason: 'watch resets once the probe is done');
  });

  test('a watch tick that arrives after the run has finished is dropped', () async {
    void Function(WatchProgress)? capturedOnWatchProgress;
    final probes = [
      ProbeSpec(
        id: NetworkCheckId.guidedWatch,
        timeout: const Duration(seconds: 1),
        run: (ctx) async {
          // Stash the engine-wrapped callback so the test can invoke it
          // itself, after the run below has already finished — simulating a
          // guided-watch tick that arrives late (past its own timeout, or
          // after the whole engine run completed).
          capturedOnWatchProgress = ctx.onWatchProgress;
          return _pass(NetworkCheckId.guidedWatch);
        },
      ),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: _ctx, probes: probes);
    await engine.run();

    final stateBefore = engine.state.value;
    expect(capturedOnWatchProgress, isNotNull);
    capturedOnWatchProgress!(
      const WatchProgress(browsed: true, resolved: true, addressAsks: 5, connected: true, remaining: Duration.zero),
    );

    final stateAfter = engine.state.value;
    expect(identical(stateAfter, stateBefore), isTrue, reason: 'a late tick must not touch state once the run is done');
    expect(stateAfter.watch, isNull);
    expect(stateAfter.running, isNull);
    expect(stateAfter.result, isNotNull);
  });

  test('a throwing contextBuilder still produces a result', () async {
    final probes = [
      ProbeSpec(id: NetworkCheckId.methodListening, timeout: const Duration(seconds: 1), run: (ctx) async => _pass(NetworkCheckId.methodListening)),
    ];
    final engine = NetworkSelfTestEngine(contextBuilder: () => throw StateError('no context'), probes: probes);
    final result = await engine.run();

    expect(result, isNotNull);
    expect(result.checks, hasLength(1));
  });

  group('defaultProbes', () {
    const commonOrder = [
      NetworkCheckId.methodListening,
      NetworkCheckId.advertisedAddress,
      NetworkCheckId.vpn,
      NetworkCheckId.advertisementVisible,
      NetworkCheckId.localNetworkPermission,
      NetworkCheckId.backend,
      NetworkCheckId.multicastLock,
    ];

    test('macos: the seven passives plus the active/watch trio, no Windows shell checks', () {
      final ids = NetworkSelfTestEngine.defaultProbes('macos').map((s) => s.id).toList();
      expect(ids, [...commonOrder, NetworkCheckId.resolveOwnHostname, NetworkCheckId.tcpSelfConnect, NetworkCheckId.guidedWatch]);
    });

    test('android: resolveOwnHostname skipped (platform resolver has no mDNS), tcpSelfConnect/guidedWatch still run', () {
      final androidIds = NetworkSelfTestEngine.defaultProbes('android').map((s) => s.id).toList();
      expect(androidIds, [...commonOrder, NetworkCheckId.tcpSelfConnect, NetworkCheckId.guidedWatch]);

      // Android-only carve-out, not an iOS-style blanket skip: macOS/Windows
      // still run resolveOwnHostname...
      expect(NetworkSelfTestEngine.defaultProbes('macos').map((s) => s.id), contains(NetworkCheckId.resolveOwnHostname));
      expect(NetworkSelfTestEngine.defaultProbes('windows').map((s) => s.id), contains(NetworkCheckId.resolveOwnHostname));

      // ...and iOS still excludes all three active/watch checks.
      final iosIds = NetworkSelfTestEngine.defaultProbes('ios').map((s) => s.id).toList();
      expect(iosIds, isNot(contains(NetworkCheckId.resolveOwnHostname)));
      expect(iosIds, isNot(contains(NetworkCheckId.tcpSelfConnect)));
      expect(iosIds, isNot(contains(NetworkCheckId.guidedWatch)));
    });

    test('ios: resolve/tcp/watch excluded entirely, no Windows shell checks', () {
      final ids = NetworkSelfTestEngine.defaultProbes('ios').map((s) => s.id).toList();
      expect(ids, commonOrder);
    });

    test('windows: every check present, in spec order, Windows shell checks last', () {
      final ids = NetworkSelfTestEngine.defaultProbes('windows').map((s) => s.id).toList();
      expect(ids, [
        ...commonOrder,
        NetworkCheckId.resolveOwnHostname,
        NetworkCheckId.tcpSelfConnect,
        NetworkCheckId.guidedWatch,
        NetworkCheckId.bonjourService,
        NetworkCheckId.bonjourNsp,
        NetworkCheckId.windowsMdnsResolver,
        NetworkCheckId.networkProfile,
        NetworkCheckId.firewallRule,
      ]);
    });

    test('windows: the paired profile/firewall probe shares one memoised process call', () async {
      var runProcessCalls = 0;
      final ctx = NetworkProbeContext(
        snapshot: null,
        snapshotError: null,
        emulatorStarted: true,
        trainerAppConnected: false,
        trainerAppConnectedNow: () => false,
        trainerAppName: null,
        backend: ObpMdnsBackend.platformDefault,
        advertisedHostname: null,
        platform: 'windows',
        resolve: (host) async => const [],
        tcpProbe: (address, port) async {},
        runProcess: (executable, arguments) async {
          runProcessCalls++;
          return ProcessResult(0, 0, '', '');
        },
        queryLog: () => const [],
        sleep: (d) async {},
        now: () => DateTime(2026, 8, 21),
        onWatchProgress: (progress) {},
      );
      final specs = NetworkSelfTestEngine.defaultProbes('windows');
      final profileSpec = specs.singleWhere((s) => s.id == NetworkCheckId.networkProfile);
      final firewallSpec = specs.singleWhere((s) => s.id == NetworkCheckId.firewallRule);

      await profileSpec.run(ctx);
      await firewallSpec.run(ctx);

      expect(runProcessCalls, 1, reason: 'both specs must share the one powershell invocation');
    });
  });
}
