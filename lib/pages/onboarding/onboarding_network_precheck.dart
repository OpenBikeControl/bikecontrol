// The connection step's background network check: the network self-test's
// checks (without the live watch), run as soon as a network method is up, so
// a problem that would keep the trainer app from finding BikeControl shows
// before the rider waits for it.
import 'dart:io' show Platform;

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/network_troubleshooting_page.dart' show buildProductionContext;
import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_self_test_engine.dart';
import 'package:bike_control/services/network_self_test/network_self_test_result.dart';
import 'package:bike_control/services/network_self_test/network_self_test_store.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/network_check_row.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Whether the connection step's "Finish setup" can be pressed.
bool onboardingConnectionCanFinish({required bool hasNoConnectionMethod, required bool networkBlocking}) =>
    !hasNoConnectionMethod && !networkBlocking;

enum NetworkPrecheckPhase { idle, checking, done }

class OnboardingNetworkPrecheck extends ChangeNotifier {
  OnboardingNetworkPrecheck({
    Future<NetworkSelfTestEngine> Function()? engineFactory,
    String? platform,
    Future<void> Function(NetworkSelfTestResult result)? onResult,
  }) : _engineFactory = engineFactory ?? _defaultEngine,
       _platform = platform ?? (kIsWeb ? 'web' : Platform.operatingSystem),
       _onResult = onResult ?? NetworkSelfTestStore.save;

  final Future<NetworkSelfTestEngine> Function() _engineFactory;
  final String _platform;
  final Future<void> Function(NetworkSelfTestResult result) _onResult;

  NetworkSelfTestEngine? _engine;
  int _seq = 0;
  bool _disposed = false;

  NetworkPrecheckPhase _phase = NetworkPrecheckPhase.idle;
  NetworkPrecheckPhase get phase => _phase;

  List<NetworkCheck> _failures = const [];

  /// The failed checks that hold the step.
  List<NetworkCheck> get failures => _failures;

  bool _continued = false;

  /// The rider chose to go on despite [failures].
  bool get continuedAnyway => _continued;

  /// Whether the step is held: a check failed and the rider hasn't chosen to
  /// continue anyway. Nothing holds it while checking.
  bool get blocking => _phase == NetworkPrecheckPhase.done && _failures.isNotEmpty && !_continued;

  /// The self-test's probes minus the live watch, which waits for the rider
  /// to act in their trainer app.
  static List<ProbeSpec> backgroundProbes(String platform) =>
      NetworkSelfTestEngine.defaultProbes(platform).where((s) => s.id != NetworkCheckId.guidedWatch).toList();

  static Future<NetworkSelfTestEngine> _defaultEngine() async {
    DebugDiagnostics? snapshot;
    Object? snapshotError;
    try {
      snapshot = await DebugDiagnostics.gather(includeDiscovery: true);
    } catch (e, s) {
      recordError(e, s, context: 'OnboardingNetworkPrecheck.snapshot');
      snapshotError = e;
    }
    final platform = kIsWeb ? 'web' : Platform.operatingSystem;
    return NetworkSelfTestEngine(
      contextBuilder: () => buildProductionContext(snapshot: snapshot, snapshotError: snapshotError),
      probes: backgroundProbes(platform),
    );
  }

  /// Checks that fail without meaning the trainer app can't connect: Android
  /// can't resolve its own advertised hostname even when everything works.
  bool _holds(NetworkCheck check) {
    if (check.verdict != NetworkVerdict.fail) return false;
    if (_platform == 'android' && check.id == NetworkCheckId.resolveOwnHostname) return false;
    return true;
  }

  /// Runs (or re-runs) the check. A run already in flight is cancelled.
  Future<void> run() async {
    if (_disposed) return;
    _engine?.cancel();
    _engine = null;
    final seq = ++_seq;
    _continued = false;
    _failures = const [];
    _phase = NetworkPrecheckPhase.checking;
    notifyListeners();

    final NetworkSelfTestEngine engine;
    try {
      engine = await _engineFactory();
    } catch (e, s) {
      recordError(e, s, context: 'OnboardingNetworkPrecheck.engine');
      if (!_disposed && seq == _seq) {
        _phase = NetworkPrecheckPhase.idle;
        notifyListeners();
      }
      return;
    }
    if (_disposed || seq != _seq) {
      engine.cancel();
      return;
    }
    _engine = engine;
    try {
      final result = await engine.run();
      if (_disposed || seq != _seq) return;
      await _onResult(result);
      if (_disposed || seq != _seq) return;
      _failures = result.checks.where(_holds).toList(growable: false);
      _phase = NetworkPrecheckPhase.done;
      notifyListeners();
    } catch (e, s) {
      recordError(e, s, context: 'OnboardingNetworkPrecheck.run');
      if (!_disposed && seq == _seq) {
        _phase = NetworkPrecheckPhase.idle;
        notifyListeners();
      }
    }
  }

  void continueAnyway() {
    if (_disposed) return;
    _continued = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _engine?.cancel();
    super.dispose();
  }
}

/// The connection step's view of [OnboardingNetworkPrecheck]: a compact line
/// while checking or once passed; a card with each failed check and its fixes
/// while a failure holds the step.
class OnboardingNetworkPrecheckCard extends StatelessWidget {
  const OnboardingNetworkPrecheckCard({
    super.key,
    required this.precheck,
    required this.appName,
    required this.onFix,
  });

  final OnboardingNetworkPrecheck precheck;
  final String appName;
  final void Function(NetworkFixId fix) onFix;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: precheck,
      builder: (context, _) {
        final status = BkStatusColors.of(context);
        final scheme = Theme.of(context).colorScheme;
        switch (precheck.phase) {
          case NetworkPrecheckPhase.idle:
            return const SizedBox.shrink();
          case NetworkPrecheckPhase.checking:
            return _line(
              context,
              const SizedBox(width: 14, height: 14, child: SmallProgressIndicator()),
              Text(context.i18n.onboardingNetworkChecking).xSmall.muted,
            );
          case NetworkPrecheckPhase.done:
            if (precheck.failures.isEmpty) {
              return _line(
                context,
                Icon(LucideIcons.circleCheck, size: 15, color: status.success),
                Text(context.i18n.onboardingNetworkCheckPassed).xSmall.muted,
              );
            }
            if (precheck.continuedAnyway) {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.triangleAlert, size: 15, color: status.warning),
                    const Gap(8),
                    Expanded(child: Text(context.i18n.onboardingNetworkContinuedNote(appName)).xSmall),
                    const Gap(8),
                    Button.link(
                      onPressed: precheck.run,
                      child: Text(context.i18n.onboardingNetworkRecheck).xSmall,
                    ),
                  ],
                ),
              );
            }
            return Container(
              key: const ValueKey('onboarding-network-precheck-failed'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: status.dangerWash,
                border: Border.all(color: status.danger, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.circleX, size: 17, color: status.danger),
                      const Gap(9),
                      Expanded(child: Text(context.i18n.onboardingNetworkCheckFailedTitle).small.semiBold),
                    ],
                  ),
                  const Gap(4),
                  Text(context.i18n.onboardingNetworkCheckFailedBody(appName)).xSmall.muted,
                  for (final check in precheck.failures) ...[
                    const Gap(10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(color: scheme.card, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(networkCheckTitle(context, check.id)).small.semiBold,
                          if ((networkCheckHint(context, check) ?? networkCheckSummary(context, check)) case final text?)
                            Text(text).xSmall.muted,
                          for (final fix in check.fixes.where((f) => f != NetworkFixId.sendToSupport)) ...[
                            const Gap(8),
                            Button.outline(
                              style: ButtonStyle.outline(size: ButtonSize.small),
                              onPressed: () => onFix(fix),
                              child: Text(networkFixLabel(context, fix)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const Gap(12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Button.outline(
                        onPressed: precheck.run,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.refreshCw, size: 14),
                            const Gap(6),
                            Text(context.i18n.onboardingNetworkRecheck),
                          ],
                        ),
                      ),
                      Button.ghost(
                        onPressed: precheck.continueAnyway,
                        child: Text(context.i18n.onboardingNetworkContinueAnyway),
                      ),
                    ],
                  ),
                ],
              ),
            );
        }
      },
    );
  }

  Widget _line(BuildContext context, Widget leading, Widget text) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(children: [leading, const Gap(8), Expanded(child: text)]),
  );
}
