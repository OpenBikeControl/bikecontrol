import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:flutter/foundation.dart';

import 'network_check.dart';
import 'network_probe_context.dart';
import 'network_self_test_result.dart';
import 'probes/active_probes.dart';
import 'probes/guided_watch_probe.dart';
import 'probes/passive_probes.dart';
import 'probes/windows_probes.dart';

/// Immutable snapshot of [NetworkSelfTestEngine], rebuilt on every
/// transition and pushed through [NetworkSelfTestEngine.state].
@immutable
class NetworkSelfTestState {
  /// Completed checks so far, in run order.
  final List<NetworkCheck> checks;

  /// The probe currently in flight; null when idle or done.
  final NetworkCheckId? running;

  /// Live progress pushed by the guided-watch probe while it is the one
  /// running; null the rest of the time.
  final WatchProgress? watch;

  /// Non-null once the run has finished (whether completed or cancelled).
  final NetworkSelfTestResult? result;

  const NetworkSelfTestState({this.checks = const [], this.running, this.watch, this.result});
}

/// One probe's entry point, sharing a single signature across every check —
/// passive, active or shell-based — so the engine can run them uniformly.
typedef ProbeRunner = Future<NetworkCheck> Function(NetworkProbeContext ctx);

/// Binds a [NetworkCheckId] to the function that produces it and the
/// deadline the engine enforces around that call.
class ProbeSpec {
  final NetworkCheckId id;
  final Duration timeout;
  final ProbeRunner run;

  const ProbeSpec({required this.id, required this.timeout, required this.run});
}

/// Runs the network self-test's probes one at a time, containing whatever
/// each one does — a throw, a hang, cancellation — so a single flaky check
/// never keeps the rest of the suite from reporting.
///
/// Pure orchestration: it owns no UI. [contextBuilder] is called exactly
/// once, at the start of [run], to gather the one snapshot every probe reads
/// — probes themselves stay pure functions over that context (see
/// [NetworkProbeContext]).
class NetworkSelfTestEngine {
  NetworkSelfTestEngine({required NetworkProbeContext Function() contextBuilder, List<ProbeSpec>? probes, DateTime Function()? now})
    : _contextBuilder = contextBuilder,
      _now = now ?? DateTime.now {
    // Built here, not in the initializer list, because the default probe
    // list needs a closure over `this` (to read `_watchCancelled` live on
    // every guided-watch poll) — instance members aren't reachable from an
    // initializer list. An explicitly supplied `probes` list bypasses this
    // wiring entirely, which is fine: only the engine's own default
    // guided-watch probe answers to `cancelWatch()`.
    _probes = probes ?? defaultProbes(Platform.operatingSystem, watchCancelled: () => _watchCancelled);
  }

  final NetworkProbeContext Function() _contextBuilder;
  final DateTime Function() _now;
  late final List<ProbeSpec> _probes;

  final ValueNotifier<NetworkSelfTestState> _state = ValueNotifier(const NetworkSelfTestState());

  ValueListenable<NetworkSelfTestState> get state => _state;

  Future<NetworkSelfTestResult>? _runFuture;
  bool _cancelled = false;

  /// Set by [cancelWatch]; read by the default guided-watch probe's
  /// `isCancelled` seam on its next poll tick.
  bool _watchCancelled = false;

  final List<NetworkCheck> _checks = [];
  NetworkCheckId? _running;
  WatchProgress? _watch;
  NetworkSelfTestResult? _result;

  /// Runs every probe, once. A repeat call returns the first run's result —
  /// in flight or already finished — so a second tap can't start a second,
  /// overlapping sweep; a genuine re-test needs a fresh engine.
  Future<NetworkSelfTestResult> run() => _runFuture ??= _run();

  /// Ends the run before its next probe starts; whatever is already in
  /// flight is left to finish (or hit its own timeout) on its own.
  void cancel() {
    _cancelled = true;
  }

  /// Skips only the guided-watch probe (a "press the button" step the rider
  /// may not want to do right now), leaving the rest of the run untouched —
  /// unlike [cancel], which abandons everything still to come. Only takes
  /// effect on the engine's own default probe list (see the constructor);
  /// an explicitly supplied `probes` list never sees it.
  void cancelWatch() {
    _watchCancelled = true;
  }

  Future<NetworkSelfTestResult> _run() async {
    final ctx = _buildContext();

    for (final spec in _probes) {
      if (_cancelled) {
        _checks.add(NetworkCheck(id: spec.id, verdict: NetworkVerdict.skipped));
        _running = null;
        _watch = null;
        _emit();
        continue;
      }
      _running = spec.id;
      _watch = null;
      _emit();
      _checks.add(await _runOne(spec, ctx));
      _running = null;
      _watch = null;
      _emit();
    }

    _result = NetworkSelfTestResult(
      at: _now(),
      platform: ctx.platform,
      obcBackend: ctx.backend.name,
      hostname: ctx.advertisedHostname,
      checks: List.unmodifiable(_checks),
      completed: !_cancelled,
    );
    _emit();
    return _result!;
  }

  /// Calls [_contextBuilder] exactly once, wraps a throw there (a snapshot
  /// gather that failed unexpectedly) into a context that degrades the same
  /// way a missing snapshot already does (every probe sees `snapshot: null`
  /// and reports `unknown`) rather than aborting the whole suite, and wraps
  /// [NetworkProbeContext.onWatchProgress] so a live tick from the
  /// guided-watch probe also lands in [state] — the only probe that reports
  /// progress mid-flight instead of only on completion.
  NetworkProbeContext _buildContext() {
    NetworkProbeContext built;
    try {
      built = _contextBuilder();
    } catch (e, s) {
      recordError(e, s, context: 'NetworkSelfTest.contextBuilder');
      built = _fallbackContext(e);
    }
    return NetworkProbeContext(
      snapshot: built.snapshot,
      snapshotError: built.snapshotError,
      emulatorStarted: built.emulatorStarted,
      trainerAppConnected: built.trainerAppConnected,
      trainerAppConnectedNow: built.trainerAppConnectedNow,
      trainerAppName: built.trainerAppName,
      backend: built.backend,
      advertisedHostname: built.advertisedHostname,
      platform: built.platform,
      resolve: built.resolve,
      tcpProbe: built.tcpProbe,
      runProcess: built.runProcess,
      queryLog: built.queryLog,
      sleep: built.sleep,
      now: built.now,
      onWatchProgress: (progress) {
        built.onWatchProgress(progress);
        // A tick that arrives after the guided-watch probe's own timeout
        // fires, or after the whole run has finished, must not resurrect
        // dead state — only the probe that is both still running and
        // actually the guided-watch one gets to push a tick through.
        if (_result != null || _running != NetworkCheckId.guidedWatch) {
          return;
        }
        _watch = progress;
        _emit();
      },
    );
  }

  NetworkProbeContext _fallbackContext(Object error) => NetworkProbeContext(
    snapshot: null,
    snapshotError: error,
    emulatorStarted: false,
    trainerAppConnected: false,
    trainerAppConnectedNow: () => false,
    trainerAppName: null,
    backend: ObpMdnsBackend.platformDefault,
    advertisedHostname: null,
    platform: Platform.operatingSystem,
    resolve: (host) async => const [],
    tcpProbe: (address, port) async {},
    runProcess: (executable, arguments) async => throw UnsupportedError('no context'),
    queryLog: () => const [],
    sleep: (d) => Future<void>.delayed(d),
    now: DateTime.now,
    onWatchProgress: (progress) {},
  );

  Future<NetworkCheck> _runOne(ProbeSpec spec, NetworkProbeContext ctx) async {
    try {
      return await spec.run(ctx).timeout(spec.timeout);
    } on TimeoutException {
      return NetworkCheck(id: spec.id, verdict: NetworkVerdict.unknown, detail: const {'error': 'timeout'});
    } catch (e, s) {
      recordError(e, s, context: 'NetworkSelfTest.${spec.id.name}');
      return NetworkCheck(id: spec.id, verdict: NetworkVerdict.unknown, detail: {'error': e.toString()});
    }
  }

  void _emit() {
    _state.value = NetworkSelfTestState(checks: List.unmodifiable(_checks), running: _running, watch: _watch, result: _result);
  }

  /// The default, platform-filtered probe list (static, for the page).
  ///
  /// Order matches the spec: the seven passive checks, the two active
  /// checks (skipped entirely on iOS — the nsd backend never learns its own
  /// hostname there, and a throwaway TCP/guided-watch probe adds nothing on
  /// a platform that never resolves it), the guided watch, then the four
  /// Windows-only shell checks (skipped entirely off Windows, rather than
  /// left to self-skip, so the list itself already reflects what actually
  /// ran on this platform).
  ///
  /// `resolveOwnHostname` additionally sits out Android on its own: it
  /// resolves through the platform DNS resolver, which never does mDNS
  /// there, so it fails almost every run even when discovery genuinely
  /// works — a false negative that single-handedly flips `overallVerdict`
  /// to fail. `tcpSelfConnect` and `guidedWatch` don't share that flaw and
  /// keep running, so real Android discovery problems still get caught.
  static List<ProbeSpec> defaultProbes(String platform, {bool Function()? watchCancelled}) {
    // The paired profile+firewall probe pays for one `powershell.exe`
    // start-up; both ProbeSpecs below share that single call via this
    // memoised future rather than invoking it twice.
    Future<({NetworkCheck profile, NetworkCheck firewall})>? windowsShared;
    Future<({NetworkCheck profile, NetworkCheck firewall})> sharedWindowsChecks(NetworkProbeContext ctx) =>
        windowsShared ??= windowsNetworkProfileAndFirewallChecks(ctx);

    return [
      ProbeSpec(id: NetworkCheckId.methodListening, timeout: const Duration(seconds: 1), run: (ctx) async => methodListeningCheck(ctx)),
      ProbeSpec(id: NetworkCheckId.advertisedAddress, timeout: const Duration(seconds: 1), run: (ctx) async => advertisedAddressCheck(ctx)),
      ProbeSpec(id: NetworkCheckId.vpn, timeout: const Duration(seconds: 1), run: (ctx) async => vpnCheck(ctx)),
      ProbeSpec(id: NetworkCheckId.advertisementVisible, timeout: const Duration(seconds: 1), run: (ctx) async => advertisementVisibleCheck(ctx)),
      ProbeSpec(
        id: NetworkCheckId.localNetworkPermission,
        timeout: const Duration(seconds: 1),
        run: (ctx) async => localNetworkPermissionCheck(ctx),
      ),
      ProbeSpec(id: NetworkCheckId.backend, timeout: const Duration(seconds: 1), run: (ctx) async => backendCheck(ctx)),
      ProbeSpec(id: NetworkCheckId.multicastLock, timeout: const Duration(seconds: 1), run: (ctx) async => multicastLockCheck(ctx)),
      if (platform != 'ios' && platform != 'android') ...[
        ProbeSpec(id: NetworkCheckId.resolveOwnHostname, timeout: const Duration(seconds: 4), run: resolveOwnHostnameCheck),
      ],
      if (platform != 'ios') ...[
        ProbeSpec(id: NetworkCheckId.tcpSelfConnect, timeout: const Duration(seconds: 6), run: tcpSelfConnectCheck),
        ProbeSpec(
          id: NetworkCheckId.guidedWatch,
          timeout: const Duration(seconds: 65),
          run: (ctx) => guidedWatchCheck(ctx, isCancelled: watchCancelled),
        ),
      ],
      if (platform == 'windows') ...[
        ProbeSpec(id: NetworkCheckId.bonjourService, timeout: const Duration(seconds: 10), run: bonjourServiceCheck),
        ProbeSpec(id: NetworkCheckId.bonjourNsp, timeout: const Duration(seconds: 10), run: bonjourNspCheck),
        ProbeSpec(id: NetworkCheckId.windowsMdnsResolver, timeout: const Duration(seconds: 10), run: windowsMdnsResolverCheck),
        ProbeSpec(
          id: NetworkCheckId.networkProfile,
          timeout: const Duration(seconds: 10),
          run: (ctx) async => (await sharedWindowsChecks(ctx)).profile,
        ),
        ProbeSpec(
          id: NetworkCheckId.firewallRule,
          timeout: const Duration(seconds: 10),
          run: (ctx) async => (await sharedWindowsChecks(ctx)).firewall,
        ),
      ],
    ];
  }
}
