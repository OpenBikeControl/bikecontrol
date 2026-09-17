import 'dart:async';
import 'dart:io' show Platform, Process;

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_fixes.dart';
import 'package:bike_control/services/network_self_test/network_method_target.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/services/network_self_test/network_self_test_engine.dart';
import 'package:bike_control/services/network_self_test/network_self_test_result.dart';
import 'package:bike_control/services/network_self_test/network_self_test_store.dart';
import 'package:bike_control/services/network_self_test/probes/active_probes.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/logviewer.dart';
import 'package:bike_control/widgets/menu.dart' show debugText;
import 'package:bike_control/widgets/network_check_row.dart';
import 'package:bike_control/widgets/network_test/network_gauge.dart';
import 'package:bike_control/widgets/network_test/network_live_test_card.dart';
import 'package:bike_control/widgets/network_test/network_tokens.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:prop/mdns/service_advertiser.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// `Platform.operatingSystem`-shaped, `kIsWeb`-aware — matches
/// [NetworkProbeContext.platform]'s documented shape. The page is never
/// actually reachable on web (its menu entry is gated), but every probe
/// context still needs a defined value there.
String platformString() => kIsWeb ? 'web' : Platform.operatingSystem;

/// Builds the real [NetworkProbeContext] for production, wiring every seam
/// to `core` or a default implementation (Tasks 5-7).
///
/// [NetworkSelfTestEngine]'s `contextBuilder` contract is synchronous, but
/// gathering [snapshot] itself (a [DebugDiagnostics.gather] call) is not —
/// so the snapshot is gathered once by the caller (the page's default engine
/// factory, below) *before* the engine exists, and handed in here rather
/// than fetched inline.
NetworkProbeContext buildProductionContext({DebugDiagnostics? snapshot, Object? snapshotError}) {
  // The method the selected trainer app actually rides on: OpenBikeControl
  // for MyWhoosh, the Click server for Rouvy, DirCon for Zwift. Reading
  // `core.obpMdnsEmulator` regardless told a connected Rouvy rider the
  // method was "not started".
  final target = currentNetworkMethodTarget();
  return NetworkProbeContext(
    snapshot: snapshot,
    snapshotError: snapshotError,
    emulatorStarted: target.isStarted.value,
    trainerAppConnected: target.isConnected.value,
    trainerAppConnectedNow: () => target.isConnected.value,
    trainerAppName: core.settings.getTrainerApp()?.name,
    backend: target.backend,
    advertisedHostname: target.advertisedHostname,
    methodServerLabel: target.serverLabel,
    methodPreferredPort: target.preferredPort,
    platform: platformString(),
    resolve: defaultResolve,
    tcpProbe: (address, port) => defaultTcpProbe(address, port, label: target.serverLabel),
    runProcess: (executable, arguments) => Process.run(executable, arguments).timeout(const Duration(seconds: 8)),
    queryLog: () {
      final advertiser = ServiceAdvertiser.instance;
      return advertiser is ResponderServiceAdvertiser ? advertiser.recentQueries : const [];
    },
    sleep: (d) => Future<void>.delayed(d),
    now: DateTime.now,
    onWatchProgress: (_) {},
  );
}

/// Guided, step-by-step "why can't my trainer app find BikeControl" page:
/// runs [NetworkSelfTestEngine] and renders its live progress, a one-tap
/// recommended fix, and ways to hand the result to support.
class NetworkTroubleshootingPage extends StatefulWidget {
  /// Test seam: builds the engine the page drives. Defaults to a real
  /// [NetworkSelfTestEngine] over [buildProductionContext] and the
  /// platform's default probes. May be async, like the default is (it
  /// awaits [DebugDiagnostics.gather] before an engine exists) — tests use
  /// that to hold the page in its "starting" state.
  final FutureOr<NetworkSelfTestEngine> Function()? engineFactory;

  const NetworkTroubleshootingPage({super.key, this.engineFactory});

  @override
  State<NetworkTroubleshootingPage> createState() => _NetworkTroubleshootingPageState();
}

class _NetworkTroubleshootingPageState extends State<NetworkTroubleshootingPage> {
  NetworkSelfTestEngine? _engine;

  /// True while [_start] is between "tapped" and "engine exists" — the
  /// production gather is async, so a second Run again / fix tap in that
  /// window would otherwise build a second engine whose stale result could
  /// overwrite the newer one in the store. Every button that leads to
  /// [_start] is disabled while this is set, and [_start] itself bails.
  bool _starting = false;

  /// True from [initState] when the trainer app is already connected — shown
  /// instead of auto-starting, since a working connection has nothing to
  /// troubleshoot. Cleared once the rider taps through anyway.
  bool _showConnectedRefusal = false;

  /// Stamped when a run starts, shown in the header so a screenshot carries
  /// when it was taken.
  DateTime? _startedAt;
  String? _version;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    if (currentNetworkMethodTarget().isConnected.value) {
      _showConnectedRefusal = true;
    } else {
      _start();
    }
  }

  @override
  void dispose() {
    _engine?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (kIsWeb || _starting) return;
    // Whatever is still running belongs to the previous run: stop it before
    // its next probe so it cannot keep emitting into a page that has moved on.
    _engine?.cancel();
    _starting = true;
    _startedAt = DateTime.now();
    unawaited(
      PackageInfo.fromPlatform().then((info) {
        if (mounted) setState(() => _version = info.version);
      }).catchError((Object e, StackTrace s) {
        recordError(e, s, context: 'NetworkTroubleshootingPage.version');
      }),
    );
    // Nothing on screen reads _starting before the first engine or the
    // refusal card exists (the initState auto-start), so no rebuild then.
    if (_engine != null || _showConnectedRefusal) setState(() {});

    final NetworkSelfTestEngine engine;
    try {
      engine = await _buildEngine();
    } catch (e, s) {
      recordError(e, s, context: 'NetworkTroubleshootingPage.engine');
      if (mounted) setState(() => _starting = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _starting = false;
      _showConnectedRefusal = false;
      _engine = engine;
    });
    engine.run().then((result) {
      // Superseded by a later _start() (which cancelled this engine): its
      // result is stale and must not overwrite the newer one in the store.
      if (!identical(_engine, engine)) return;
      NetworkSelfTestStore.save(result);
      if (mounted) setState(() {});
    }).catchError((e, s) {
      recordError(e, s, context: 'NetworkSelfTest.page');
    });
  }

  Future<NetworkSelfTestEngine> _buildEngine() async {
    final factory = widget.engineFactory;
    if (factory != null) return factory();
    DebugDiagnostics? snapshot;
    Object? snapshotError;
    try {
      snapshot = await DebugDiagnostics.gather(includeDiscovery: true);
    } catch (e, s) {
      recordError(e, s, context: 'NetworkTroubleshootingPage.snapshot');
      snapshotError = e;
    }
    // No explicit `probes:` here — the engine's own default construction
    // (see NetworkSelfTestEngine's constructor) is what wires
    // `engine.cancelWatch()` into the guided-watch probe's `isCancelled`
    // seam; a probe list built ahead of time and handed in wouldn't see
    // cancellation at all.
    return NetworkSelfTestEngine(contextBuilder: () => buildProductionContext(snapshot: snapshot, snapshotError: snapshotError));
  }

  Future<void> _runFix(NetworkFixId fix) async {
    if (fix == NetworkFixId.sendToSupport) {
      final result = _engine?.state.value.result;
      if (result != null && mounted) {
        _openSupport(context, result);
      }
      return;
    }
    await runNetworkFix(context, fix);
    // A full re-run: the checks are cheap and the watch row is skippable, so
    // there is no reason to re-verify just the one fixed check.
    await _start();
  }

  /// Hands the result to the chat pinned below the composer, not prefilled
  /// into it: the rider has to say what they see before they can send.
  void _openSupport(BuildContext context, NetworkSelfTestResult result) {
    final debugFuture = debugText();
    // The composer only knows it carries *a* pinned line; what kind — and so
    // what its chip calls it — is this page's knowledge, resolved here.
    final label = context.i18n.supportPinnedNetworkTest;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupportChatPage(
          diagnosticPreviewFuture: debugFuture,
          pinnedContext: 'Network self-test: ${result.toBundleString()}',
          pinnedContextLabel: label,
          telemetryBuilder: () async => TelemetrySnapshot.general(freetext: await debugText()),
        ),
      ),
    );
  }

  /// Fixes that stop the examined method's server are greyed out while a
  /// trainer app is connected through it — they would drop a connection
  /// that works. `runNetworkFix` refuses them too (with a toast) should one
  /// slip through; this is just the visual half of that.
  static const _stopsServer = {NetworkFixId.restartMethod, NetworkFixId.useOsResponderForObc, NetworkFixId.useResponderForObc};

  bool _fixDisabled(NetworkFixId fix) =>
      _starting || (_stopsServer.contains(fix) && currentNetworkMethodTarget().isConnected.value);

  /// Which section of the page a check belongs to. The design groups by where
  /// the problem would be, because that is what tells a rider whether to look
  /// at this machine, their router, or their trainer app.
  static NetworkCheckGroup _groupOf(NetworkCheckId id) => switch (id) {
    NetworkCheckId.methodListening ||
    NetworkCheckId.backend ||
    NetworkCheckId.localNetworkPermission ||
    NetworkCheckId.bonjourService ||
    NetworkCheckId.bonjourNsp ||
    NetworkCheckId.windowsMdnsResolver ||
    NetworkCheckId.networkProfile ||
    NetworkCheckId.firewallRule ||
    NetworkCheckId.multicastLock => NetworkCheckGroup.thisDevice,
    NetworkCheckId.advertisedAddress ||
    NetworkCheckId.vpn ||
    NetworkCheckId.advertisementVisible => NetworkCheckGroup.onTheNetwork,
    NetworkCheckId.resolveOwnHostname || NetworkCheckId.tcpSelfConnect => NetworkCheckGroup.reaching,
    NetworkCheckId.guidedWatch => NetworkCheckGroup.liveTest,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;
    final tokens = NetworkTokens.of(context);
    return Scaffold(
      headers: [
        AppBar(
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
          title: Text(
            l10n.networkTroubleshootingTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          // Only beside the title where there is room for both: on a narrow
          // window the stamp wins the space and the title wraps a character at
          // a time. It moves into the body instead.
          trailing: [if (!_narrow(context)) _runStamp(context)],
          backgroundColor: Theme.of(context).colorScheme.background,
        ),
        const Divider(),
      ],
      child: Container(
        color: tokens.pageBg,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_narrow(context)) ...[
                      Align(alignment: AlignmentDirectional.centerStart, child: _runStamp(context)),
                      const Gap(12),
                    ],
                    _showConnectedRefusal && _engine == null
                        ? _refusalCard(context, l10n)
                        : _engineSection(context, l10n),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One breakpoint for the whole page: below it the design's side-by-side
  /// arrangements stack, because a desktop window's worth of width is exactly
  /// what they assume.
  static bool _narrow(BuildContext context) => MediaQuery.sizeOf(context).width < 640;

  /// When the run happened, on what — a mono stamp, because its only job is to
  /// be read back to support off a screenshot.
  Widget _runStamp(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = [
      if (_startedAt != null) _clock(_startedAt!),
      if (!kIsWeb) _osName(),
      if (_version != null) 'v$_version',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        parts.join(' · '),
        style: Theme.of(context).typography.mono.copyWith(fontSize: 11, color: cs.mutedForeground),
      ),
    );
  }

  /// The name a rider would recognise, not the Dart identifier.
  static String _osName() => switch (Platform.operatingSystem) {
    'macos' => 'macOS',
    'ios' => 'iOS',
    'windows' => 'Windows',
    'android' => 'Android',
    'linux' => 'Linux',
    final other => other,
  };

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  Widget _refusalCard(BuildContext context, AppLocalizations l10n) {
    final app = core.settings.getTrainerApp()?.name ?? '';
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.networkTroubleshootConnectedRefusal(app)),
            const Gap(12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Button.outline(onPressed: _starting ? null : _start, child: Text(l10n.networkTroubleshootRun)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _engineSection(BuildContext context, AppLocalizations l10n) {
    final engine = _engine;
    if (engine == null) {
      // The production engine cannot exist until DebugDiagnostics.gather() has
      // finished — several seconds of mDNS discovery. Rendering nothing for
      // that long reads as a broken page, so the structure appears first and
      // fills in.
      return _skeleton(context, l10n);
    }
    return ValueListenableBuilder<NetworkSelfTestState>(
      valueListenable: engine.state,
      builder: (context, state, _) {
        final result = state.result;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _verdictCard(context, l10n, state),
            ..._groupedSections(context, l10n, state),
            if (result != null) ...[const Gap(18), _footer(context, l10n, result)],
          ],
        );
      },
    );
  }

  /// Shown from the first frame until the engine exists: the same shape the
  /// results will take, with the checks named and waiting.
  Widget _skeleton(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: Center(child: RepaintBoundary(child: SmallProgressIndicator())),
                ),
                const Gap(20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.networkTroubleshootingTitle,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const Gap(3),
                      Text(
                        l10n.networkOverallUnknownBody,
                        style: TextStyle(fontSize: 13, color: cs.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// One card per group, each under a mono rule-label.
  List<Widget> _groupedSections(BuildContext context, AppLocalizations l10n, NetworkSelfTestState state) {
    final done = [
      for (final check in state.checks)
        if (check.verdict != NetworkVerdict.skipped) check,
    ];
    final running = state.running;

    final sections = <Widget>[];
    for (final group in NetworkCheckGroup.values) {
      // The guided watch is the one check the rider participates in, and the
      // only one with a duration. While it runs it takes over its section as a
      // card of its own rather than a row, so the ask and the countdown are
      // the thing on screen.
      final watch = state.watch;
      if (group == NetworkCheckGroup.liveTest && watch != null && running == NetworkCheckId.guidedWatch) {
        sections
          ..add(const Gap(18))
          ..add(_GroupLabel(text: _groupLabel(l10n, group)))
          ..add(const Gap(8))
          ..add(
            NetworkLiveTestCard(
              key: const ValueKey('check-guidedWatch-running'),
              watch: watch,
              appName: core.settings.getTrainerApp()?.name,
              onSkip: _engine?.cancelWatch,
            ),
          );
        continue;
      }
      final rows = <Widget>[
        for (final check in done)
          if (_groupOf(check.id) == group)
            NetworkCheckRow(
              key: ValueKey('check-${check.id.name}'),
              check: check,
              onFix: _runFix,
              isFixDisabled: _fixDisabled,
              watch: check.id == NetworkCheckId.guidedWatch ? state.watch : null,
              onSkipWatch: _engine?.cancelWatch,
            ),
        if (running != null && _groupOf(running) == group)
          NetworkCheckRow(
            key: ValueKey('check-${running.name}-running'),
            check: NetworkCheck(id: running, verdict: NetworkVerdict.unknown),
            running: true,
            watch: running == NetworkCheckId.guidedWatch ? state.watch : null,
            onSkipWatch: _engine?.cancelWatch,
          ),
      ];
      if (rows.isEmpty) continue;
      sections
        ..add(const Gap(18))
        ..add(_GroupLabel(text: _groupLabel(l10n, group)))
        ..add(const Gap(8))
        ..add(_Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _lastWithoutDivider(rows))));
    }
    return sections;
  }

  /// The card draws its own bottom edge, so the final row must not.
  static List<Widget> _lastWithoutDivider(List<Widget> rows) {
    if (rows.isEmpty) return rows;
    final last = rows.removeLast();
    if (last is NetworkCheckRow) {
      rows.add(
        NetworkCheckRow(
          key: last.key,
          check: last.check,
          running: last.running,
          watch: last.watch,
          onFix: last.onFix,
          onSkipWatch: last.onSkipWatch,
          isFixDisabled: last.isFixDisabled,
          showDivider: false,
        ),
      );
    } else {
      rows.add(last);
    }
    return rows;
  }

  static String _groupLabel(AppLocalizations l10n, NetworkCheckGroup group) => switch (group) {
    NetworkCheckGroup.thisDevice => l10n.networkGroupThisDevice,
    NetworkCheckGroup.onTheNetwork => l10n.networkGroupOnTheNetwork,
    NetworkCheckGroup.reaching => l10n.networkGroupReaching,
    NetworkCheckGroup.liveTest => l10n.networkGroupLiveTest,
  };

  /// The design's verdict card: a ring counting what passed, the finding in one
  /// sentence, and the single action that follows from it.
  Widget _verdictCard(BuildContext context, AppLocalizations l10n, NetworkSelfTestState state) {
    final cs = Theme.of(context).colorScheme;
    final tokens = NetworkTokens.of(context);
    final result = state.result;
    final scored = [
      for (final c in state.checks)
        if (c.verdict != NetworkVerdict.skipped) c,
    ];
    final passed = scored.where((c) => c.verdict == NetworkVerdict.pass).length;

    final verdict = result?.verdict;
    final arcColor = switch (verdict) {
      NetworkVerdict.fail => tokens.danger,
      NetworkVerdict.warn => tokens.warn,
      NetworkVerdict.unknown => cs.mutedForeground,
      _ => tokens.ok,
    };

    final narrow = _narrow(context);
    final actions = Column(
      crossAxisAlignment: narrow ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (result != null) ..._recommendedFix(context, l10n, result),
        if (result == null)
          Button.outline(
            key: const ValueKey('network-cancel'),
            onPressed: () => _engine?.cancel(),
            child: Text(l10n.networkTroubleshootCancel),
          )
        else
          Button.outline(
            key: const ValueKey('network-run-again'),
            onPressed: _starting ? null : _start,
            child: Text(l10n.networkTroubleshootRunAgain),
          ),
      ],
    );

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NetworkGauge(passed: passed, total: scored.length, color: arcColor),
            const Gap(20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result == null ? l10n.networkWatchTitle : _overallSentence(l10n, result.verdict),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.01),
                  ),
                  const Gap(3),
                  Text(
                    result == null ? l10n.networkWatchEndsItself : _overallBody(l10n, result.verdict),
                    style: TextStyle(fontSize: 13, color: cs.mutedForeground),
                  ),
                ],
              ),
            ),
            // Beside the sentence when there is room; underneath when there is
            // not. The page is reachable on a phone, where a fixed row of
            // buttons would simply be clipped off the edge.
            if (!narrow) ...[const Gap(16), actions],
          ],
        ),
            if (narrow) ...[const Gap(14), actions],
          ],
        ),
      ),
    );
  }

  /// The design's closing card: one line naming the way out when the checks
  /// have not settled it, and the two things support actually needs.
  ///
  /// Never a `Button.primary`: the loudest thing on this page is the
  /// recommended fix, not the hand-off. A primary "Send to support" was what
  /// riders tapped straight after the run — a third of all support chats
  /// opened with the bare bundle and no description. On a pass the card
  /// says so outright and offers "Get help" rather than a report to send:
  /// there is nothing on this device left to report, what support needs is
  /// what the rider sees in their trainer app.
  Widget _footer(BuildContext context, AppLocalizations l10n, NetworkSelfTestResult result) {
    final cs = Theme.of(context).colorScheme;
    final passed = result.verdict == NetworkVerdict.pass;
    return _Panel(
      key: const ValueKey('network-footer'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        // Deliberately two arrangements rather than one Flex that flips axis:
        // a Flexible keeps flex:1 whichever fit it is given, and a vertical
        // Flex with a flexed child inside this page's SingleChildScrollView is
        // an unbounded-height constraint error, not a layout.
        child: _RowOrColumn(
          narrow: _narrow(context),
          leading: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    passed ? l10n.networkFooterPassTitle : l10n.networkFooterTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const Gap(2),
                  Text(
                    passed ? l10n.networkFooterPassBody : l10n.networkFooterBody,
                    style: TextStyle(fontSize: 13, color: cs.mutedForeground),
                  ),
                ],
              ),
          trailing: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Button.outline(
                  key: const ValueKey('network-copy'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.toBundleString()));
                    buildToast(title: l10n.networkTroubleshootResultsCopied);
                  },
                  child: Text(l10n.networkTroubleshootCopyResults),
                ),
                if (passed)
                  Button.outline(
                    key: const ValueKey('network-get-help'),
                    onPressed: () => _openSupport(context, result),
                    child: Text(l10n.networkFooterGetHelp),
                  )
                else
                  Button.outline(
                    key: const ValueKey('network-send-support'),
                    onPressed: () => _openSupport(context, result),
                    child: Text(l10n.networkTroubleshootSendToSupport),
                  ),
                Button.ghost(
                  onPressed: () => context.push(const LogViewer()),
                  child: Text(l10n.logs),
                ),
              ],
            ),
        ),
      ),
    );
  }

  String _overallSentence(AppLocalizations l10n, NetworkVerdict verdict) {
    return switch (verdict) {
      NetworkVerdict.pass => l10n.networkOverallPass,
      NetworkVerdict.warn => l10n.networkOverallWarn,
      NetworkVerdict.fail => l10n.networkOverallFail,
      NetworkVerdict.unknown => l10n.networkOverallUnknown,
      // overallVerdict() ignores skipped rows entirely and falls back to
      // pass, so this branch is unreachable as an actual overall verdict —
      // kept only so the switch stays exhaustive.
      NetworkVerdict.skipped => l10n.networkOverallPass,
    };
  }

  String _overallBody(AppLocalizations l10n, NetworkVerdict verdict) {
    return switch (verdict) {
      NetworkVerdict.pass || NetworkVerdict.skipped => l10n.networkOverallPassBody,
      NetworkVerdict.warn => l10n.networkOverallWarnBody,
      NetworkVerdict.fail => l10n.networkOverallFailBody,
      NetworkVerdict.unknown => l10n.networkOverallUnknownBody,
    };
  }

  /// The fixes of the first `fail` check (else the first `warn` check), as
  /// up to two buttons — the first `Button.primary`, the rest
  /// `Button.outline`. Empty when nothing failed or warned, or the row that
  /// did carries no fix.
  List<Widget> _recommendedFix(BuildContext context, AppLocalizations l10n, NetworkSelfTestResult result) {
    final target =
        result.checks.firstOrNullWhere((c) => c.verdict == NetworkVerdict.fail) ??
        result.checks.firstOrNullWhere((c) => c.verdict == NetworkVerdict.warn);
    final fixes = target?.fixes.take(2).toList() ?? const <NetworkFixId>[];
    if (fixes.isEmpty) {
      return const [];
    }
    return [
      for (var i = 0; i < fixes.length; i++) ...[
        i == 0
            ? Button.primary(
                key: const ValueKey('network-recommended-fix'),
                onPressed: _fixDisabled(fixes[i]) ? null : () => _runFix(fixes[i]),
                child: Text(networkFixLabel(context, fixes[i])),
              )
            : Button.outline(
                onPressed: _fixDisabled(fixes[i]) ? null : () => _runFix(fixes[i]),
                child: Text(networkFixLabel(context, fixes[i])),
              ),
        const Gap(8),
      ],
    ];
  }

}


/// Where a check would point a rider: at this machine, at their network, or at
/// the hop between BikeControl and the trainer app.
enum NetworkCheckGroup { thisDevice, onTheNetwork, reaching, liveTest }

/// A white card with the design's border, radius and one-step shadow.
class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        border: Border.all(color: cs.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: const Color(0x0F0F1520), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// A mono, letterspaced section heading with a rule running to the right edge —
/// the design's device for separating groups without boxing them.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = NetworkTokens.of(context);
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: Theme.of(context).typography.mono.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: cs.mutedForeground,
          ),
        ),
        const Gap(10),
        Expanded(child: Container(height: 1, color: tokens.hairline)),
      ],
    );
  }
}


/// Side by side when there is room, stacked when there is not.
///
/// Not a `Flex` with a flipped axis: the wide arrangement needs the leading
/// child to take the slack, and the only way to express that is a flexed
/// child — which is exactly what a vertical Flex inside a scroll view cannot
/// have.
class _RowOrColumn extends StatelessWidget {
  const _RowOrColumn({required this.narrow, required this.leading, required this.trailing});

  final bool narrow;
  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [leading, const Gap(12), trailing],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: leading), const Gap(12), trailing],
    );
  }
}
