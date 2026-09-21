import 'dart:async';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/services/trainer_self_test/self_test_engine.dart';
import 'package:bike_control/services/trainer_self_test/self_test_harness.dart';
import 'package:bike_control/services/trainer_self_test/self_test_result.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/widgets/menu.dart' show debugText;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart' show VirtualShiftingMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Why a start tap was turned down. Both are states the rider can fix in a few
/// seconds, so they are shown inline on the card instead of as a toast.
enum _Refusal { disconnected, trainerApp }

/// Guided "does this trainer actually obey us?" test on the trainer page.
///
/// Owns everything around [SelfTestEngine] that the engine deliberately does
/// not: the prechecks, the screen wakelock, persisting the verdict per trainer
/// and the three visual states (idle → running → verdict).
class SelfTestCard extends StatefulWidget {
  /// Which smart-trainer symptom the support form opens on for [verdict].
  ///
  /// Every failing verdict is a resistance complaint, so it preselects the one
  /// the rider would have picked anyway. A pass is not: the trainer did what it
  /// was told, and whatever brought the rider to support is something else —
  /// pinning "No resistance change" there would put a wrong symptom on their
  /// ticket. See [smartTrainerSymptoms] for the values.
  @visibleForTesting
  static String intakeSymptomFor(SelfTestVerdict verdict) =>
      verdict == SelfTestVerdict.pass ? 'other' : 'no_resistance_change';

  final ProxyDevice device;

  /// Test seam: builds the engine; defaults to [SelfTestEngine] over a
  /// [FitnessBikeHarness] for [device].
  final SelfTestEngine Function()? engineFactory;

  /// Wired by the page to its overlay-section reveal; used by the PASS CTA.
  final VoidCallback? onShowOverlaySettings;

  /// Test seam: the connection cycle a protocol switch triggers; defaults to
  /// [ProxyDevice.reconnectUpstream].
  final Future<void> Function()? reconnectDevice;

  const SelfTestCard({super.key, required this.device, this.engineFactory, this.onShowOverlaySettings, this.reconnectDevice});

  @override
  State<SelfTestCard> createState() => _SelfTestCardState();
}

class _SelfTestCardState extends State<SelfTestCard> {
  /// Non-null from the moment a run starts. [SelfTestEngine.run] is
  /// single-shot, so "Run again" builds a fresh one rather than reusing this.
  SelfTestEngine? _engine;
  _Refusal? _refusal;

  /// True from the "Stop test" tap until the aborted verdict lands — disables
  /// the button so a second tap can't race the engine's own cancel → restore
  /// → finish sequence. Reset by [_start] for the next run.
  bool _stopping = false;

  @override
  void dispose() {
    // A run outlives the page unless we stop it: the engine would keep writing
    // ERG targets and gears at a trainer nobody is watching.
    _engine?.cancel();
    _wakelock(false);
    super.dispose();
  }

  Future<void> _start() async {
    // Prechecks read the device, not the harness: with no upstream link there
    // is no harness worth building, and the trainer-app check is about who owns
    // the trainer right now — both live on ProxyDevice.
    //
    // Both branches also clear _engine: [_body] only renders [_idle] (where
    // _refusal is actually shown) when _engine is null, so a "Run again" tap
    // that refuses while a finished verdict engine is still attached would
    // otherwise leave the verdict view on screen with the refusal invisible
    // behind it — a silent no-op from the rider's point of view.
    if (!widget.device.isConnected) {
      setState(() {
        _refusal = _Refusal.disconnected;
        _engine = null;
      });
      return;
    }
    if (widget.device.isConnectedListenable.value) {
      setState(() {
        _refusal = _Refusal.trainerApp;
        _engine = null;
      });
      return;
    }
    final engine = _buildEngine();
    if (engine == null) {
      return;
    }
    setState(() {
      _refusal = null;
      _engine = engine;
      _stopping = false;
    });
    _wakelock(true);
    SelfTestResult? result;
    try {
      result = await engine.run();
    } catch (e, s) {
      recordError(e, s, context: 'self-test card run');
      // Back to idle rather than stranding the rider on a "running" card that
      // will never reach a verdict.
      if (mounted) {
        setState(() => _engine = null);
      }
    } finally {
      _wakelock(false);
    }
    // Persisting is its own try/catch, outside the run's: a failing prefs
    // write must not discard a verdict that already reached the UI through
    // the engine's own state, and must not reset _engine and strand the rider
    // back on idle when the run itself actually succeeded.
    //
    // An aborted run measured nothing — persisting it would put "Test
    // stopped" in the support bundle in place of the last real verdict.
    if (result != null && result.verdict != SelfTestVerdict.aborted) {
      try {
        await core.settings.setSelfTestResultJson(widget.device.trainerKey, result.toJsonString());
      } catch (e, s) {
        recordError(e, s, context: 'self-test result persist');
      }
    }
  }

  SelfTestEngine? _buildEngine() {
    final factory = widget.engineFactory;
    if (factory != null) {
      return factory();
    }
    // FitnessBikeHarness dereferences device.fitnessBike; the page only shows
    // the card when that is non-null, but a rebuild can race a disconnect.
    return widget.device.fitnessBike == null ? null : SelfTestEngine(harness: FitnessBikeHarness(widget.device));
  }

  /// Keeps the screen awake for the ~1 minute the rider has to keep pedaling.
  /// Fire-and-forget like the mini-workout recorder, but a refused toggle is
  /// reported instead of surfacing as an unhandled async error.
  void _wakelock(bool enable) {
    unawaited(
      WakelockPlus.toggle(
        enable: enable,
      ).catchError((Object e, StackTrace s) => recordError(e, s, context: 'self-test wakelock')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.engineFactory == null && widget.device.fitnessBike == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 8,
            children: [
              const Icon(LucideIcons.gauge, size: 18),
              Text(l10n.selfTestTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          _body(context, l10n),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    final engine = _engine;
    if (engine == null) {
      return _idle(context, l10n);
    }
    return ValueListenableBuilder<SelfTestState>(
      valueListenable: engine.state,
      builder: (context, state, _) {
        final result = state.result;
        if (result != null) {
          return _verdict(context, l10n, result);
        }
        return _running(context, l10n, engine, state);
      },
    );
  }

  Widget _idle(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final last = SelfTestResult.tryParse(core.settings.getSelfTestResultJson(widget.device.trainerKey));
    // A refusal is sticky until acted on, but its underlying condition can
    // clear itself without another tap (rider reconnects, closes the trainer
    // app) — a build that sees this must not go on showing a stale warning.
    if (_refusal == _Refusal.disconnected && widget.device.isConnected) {
      _refusal = null;
    } else if (_refusal == _Refusal.trainerApp && !widget.device.isConnectedListenable.value) {
      _refusal = null;
    }
    final refusal = _refusal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(l10n.selfTestIntro, style: TextStyle(fontSize: 13, color: cs.mutedForeground)),
        if (last != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
              decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(999)),
              child: Text(
                l10n.selfTestLastResult(_verdictTitle(l10n, last.verdict)),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.mutedForeground),
              ),
            ),
          ),
        if (refusal != null)
          _notice(
            context,
            icon: LucideIcons.triangleAlert,
            message: switch (refusal) {
              _Refusal.disconnected => l10n.selfTestPrecheckDisconnected,
              _Refusal.trainerApp => l10n.selfTestPrecheckTrainerApp,
            },
            color: cs.destructive,
          ),
        Button.primary(onPressed: _start, child: Text(l10n.selfTestStart)),
      ],
    );
  }

  Widget _running(BuildContext context, AppLocalizations l10n, SelfTestEngine engine, SelfTestState state) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(
          _phaseLabel(l10n, state.phase),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        ValueListenableBuilder<int?>(
          valueListenable: engine.harness.powerW,
          // Live power is the one signal that tells the rider the test is
          // watching them — and, during the staircase, what it is aiming at.
          builder: (context, power, _) => Text(
            '${power ?? '--'} W${state.currentErgTarget == null ? '' : ' → ${state.currentErgTarget} W'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
        ),
        Text(
          l10n.selfTestPedalPrompt,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: cs.mutedForeground),
        ),
        // Informational, not a fault: the test runs fine without cadence, it
        // just scores the sweep on power alone. Saying so beats leaving the
        // rider to wonder why nothing on screen mentions rpm.
        if (state.cadenceless)
          _notice(context, icon: LucideIcons.info, message: l10n.selfTestNoCadence, color: cs.mutedForeground),
        if (state.pausedForCadence)
          _notice(context, icon: LucideIcons.rotateCw, message: l10n.selfTestKeepPedaling, color: cs.destructive),
        Button.outline(
          onPressed: _stopping ? null : () => _stopRun(engine),
          child: Text(l10n.selfTestCancel),
        ),
      ],
    );
  }

  /// Disables the Stop button immediately so a second tap can't race the
  /// engine's own cancel → restore → aborted-verdict sequence; [_start]
  /// clears it again for the next run.
  void _stopRun(SelfTestEngine engine) {
    setState(() => _stopping = true);
    engine.cancel();
  }

  Widget _verdict(BuildContext context, AppLocalizations l10n, SelfTestResult result) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(
          _verdictTitle(l10n, result.verdict),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        Text(
          _verdictBody(l10n, result.verdict),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: cs.mutedForeground),
        ),
        // The shift phase was scored without the "did the rider hold cadence"
        // cross-check, which is a caveat on the verdict above — so it is shown
        // with the verdict, not just while the test was running.
        if (result.cadenceless)
          _notice(context, icon: LucideIcons.info, message: l10n.selfTestNoCadence, color: cs.mutedForeground),
        ..._verdictCtas(context, l10n, result),
        Button.primary(onPressed: _start, child: Text(l10n.selfTestRerun)),
      ],
    );
  }

  /// Verdict-specific calls to action, rendered above the always-present
  /// "Run again" button.
  ///
  /// `ergOkVsFail` gets all three CTAs stacked: try the other virtual-
  /// shifting mode first, then the other control protocol (secondary — the
  /// mode switch is the more likely fix once ERG has already proven the
  /// trainer takes power targets at all), then the report option for a rider
  /// who'd rather just tell us.
  ///
  /// `noControl` leads with the protocol CTA instead — nothing proved this
  /// trainer takes commands over its current delivery, so a different wire
  /// is the more promising thing to try before asking the rider to report
  /// it. Both verdict-specific CTAs (with or without a protocol to offer)
  /// still sit above support, never noData: a data dropout isn't a control-
  /// protocol problem, so there is nothing to switch to.
  List<Widget> _verdictCtas(BuildContext context, AppLocalizations l10n, SelfTestResult result) {
    final harness = _engine?.harness;
    final otherProtocol = harness == null ? null : _otherProtocol(harness.supportedProtocolNames, result.protocol);
    return switch (result.verdict) {
      // A pass gets the support option too, secondary to the overlay. It is the
      // one result that proves the trainer does what it is told, which is what
      // separates a hardware fault from a BikeControl one on whatever the rider
      // reports next — and several riders whose trainers passed had something
      // else to tell us and no way to attach the evidence.
      SelfTestVerdict.pass => [
        Button.primary(
          onPressed: () => widget.onShowOverlaySettings?.call(),
          child: Text(l10n.selfTestCtaOverlay),
        ),
        Button.outline(onPressed: () => _openSupport(context, result), child: Text(l10n.selfTestCtaReport)),
      ],
      SelfTestVerdict.ergOkVsFail => [
        Button.primary(onPressed: _switchModeAndRerun, child: Text(l10n.selfTestCtaSwitchMode)),
        if (otherProtocol != null) _protocolCta(l10n, otherProtocol, primary: false),
        Button.outline(onPressed: () => _openSupport(context, result), child: Text(l10n.selfTestCtaReport)),
      ],
      // Shifting already works, so the overlay is worth offering here too —
      // the rider's setup is usable today. The protocol swap is what buys
      // them ERG on top, and stays secondary for that reason.
      SelfTestVerdict.vsOkErgFail => [
        Button.primary(onPressed: () => widget.onShowOverlaySettings?.call(), child: Text(l10n.selfTestCtaOverlay)),
        if (otherProtocol != null) _protocolCta(l10n, otherProtocol, primary: false),
        Button.outline(onPressed: () => _openSupport(context, result), child: Text(l10n.selfTestCtaReport)),
      ],
      SelfTestVerdict.noControl => [
        if (otherProtocol != null) _protocolCta(l10n, otherProtocol, primary: true),
        Button.outline(onPressed: () => _openSupport(context, result), child: Text(l10n.selfTestCtaReport)),
      ],
      SelfTestVerdict.noData => [
        Button.outline(onPressed: () => _openSupport(context, result), child: Text(l10n.selfTestCtaReport)),
      ],
      SelfTestVerdict.aborted => const [],
    };
  }

  /// Builds the "try the other protocol" CTA; only ever called once
  /// [otherProtocol] has already been established non-null by the caller.
  Widget _protocolCta(AppLocalizations l10n, String otherProtocol, {required bool primary}) {
    final label = Text(l10n.selfTestCtaTryProtocol(_protocolDisplayName(l10n, otherProtocol)));
    return primary
        ? Button.primary(onPressed: () => _switchProtocolAndRerun(otherProtocol), child: label)
        : Button.outline(onPressed: () => _switchProtocolAndRerun(otherProtocol), child: label);
  }

  /// ERG_OK_VS_FAIL CTA: flip between the two virtual-shifting modes the
  /// self-test exercises and try again. Reads and writes through the current
  /// engine's harness — never [widget.device.fitnessBike] directly — so the
  /// fake-backed tests can drive and observe it without a real trainer
  /// definition attached.
  Future<void> _switchModeAndRerun() async {
    final harness = _engine?.harness;
    if (harness != null) {
      final next = _nextVsMode(harness);
      if (next != null) {
        harness.setVsMode(next);
        await _persistVsMode(next);
      }
    }
    await _start();
  }

  /// The mode to try next: the other of {targetPower, trackResistance}
  /// (basicResistance is never proposed — the self-test doesn't distinguish
  /// it from targetPower). Switching *to* trackResistance is offered
  /// unconditionally — this CTA only shows once ERG has already proven the
  /// trainer takes power targets, and simulated-grade support is close to
  /// universal alongside that. Switching back *to* targetPower is guarded by
  /// the harness's own support check.
  static String? _nextVsMode(SelfTestHarness harness) {
    if (harness.vsModeName == 'targetPower') {
      return 'trackResistance';
    }
    return harness.supportsPowerTarget ? 'targetPower' : null;
  }

  /// Mirrors the settings-UI path (`TrainerSettingsSection`'s virtual-
  /// shifting-mode radio, via `_updateActive`): the CTA's own mode switch
  /// must stick the same way a manual pick in settings does, or the rider's
  /// next connect quietly reverts to whatever the active [ShiftingConfig] on
  /// disk still says. Only the mode field changes — everything else on the
  /// active config carries over untouched.
  ///
  /// Wrapped in its own try/catch, like the verdict persistence in [_start]:
  /// a failing prefs write must not block the rerun that needs to happen
  /// regardless, and must not go unreported.
  Future<void> _persistVsMode(String modeName) async {
    try {
      final current = core.shiftingConfigs.activeFor(widget.device.trainerKey);
      await core.shiftingConfigs.upsert(current.copyWith(mode: VirtualShiftingMode.values.byName(modeName)));
    } catch (e, s) {
      recordError(e, s, context: 'self-test mode-switch persist');
    }
  }

  /// NO_CONTROL / ERG_OK_VS_FAIL CTA: force the other control-protocol
  /// delivery this trainer supports and try again. Reads and writes through
  /// the current engine's harness, same as [_switchModeAndRerun] — the
  /// harness itself (not this card) is what persists the override, since
  /// unlike virtual-shifting mode it lives in [core.settings], not a
  /// [ShiftingConfig].
  Future<void> _switchProtocolAndRerun(String protocol) async {
    _engine?.harness.setProtocol(protocol);
    // The trainer only honors the new delivery on a fresh connection (it
    // latches its control session at connect time) — cycle the bridge the way
    // the ConnectionCard's manual disconnect/reconnect does, then rerun on
    // the rebuilt definition. [ProxyDevice.reconnectUpstream] itself waits
    // for the definition to come back.
    try {
      await (widget.reconnectDevice ?? widget.device.reconnectUpstream)();
    } catch (e, s) {
      recordError(e, s, context: 'self-test protocol switch reconnect');
    }
    await _start();
  }

  /// The first protocol this trainer supports other than the one the
  /// just-finished run actually used — null when there is nothing else to
  /// offer (a single-protocol trainer).
  static String? _otherProtocol(List<String> supportedProtocolNames, String currentProtocol) {
    for (final name in supportedProtocolNames) {
      if (name != currentProtocol) {
        return name;
      }
    }
    return null;
  }

  /// Mirrors `TrainerSettingsSection._protocolLabel`: the three protocols the
  /// settings picker knows about get their translated name; anything else
  /// (a name this build doesn't recognize) falls back to the raw value
  /// rather than crashing.
  static String _protocolDisplayName(AppLocalizations l10n, String name) {
    return switch (name) {
      'ftms' => l10n.controlProtocolFtms,
      'fec' => l10n.controlProtocolFec,
      'zwiftHub' => l10n.controlProtocolZwift,
      _ => name,
    };
  }

  /// NO_CONTROL / ERG_OK_VS_FAIL / NO_DATA CTA: hands the verdict to support
  /// pinned below the composer (the rider still has to describe what they
  /// see before they can send), with the intake mirroring what the
  /// smart-trainer branch itself would have produced for a "no resistance
  /// change" report.
  void _openSupport(BuildContext context, SelfTestResult result) {
    final debugFuture = debugText();
    // The composer only knows it carries *a* pinned line; what kind — and so
    // what its chip calls it — is this card's knowledge, resolved here.
    final label = AppLocalizations.of(context).supportPinnedResistanceTest;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupportChatPage(
          diagnosticPreviewFuture: debugFuture,
          pinnedContext: 'Resistance self-test: ${result.toBundleString()}',
          pinnedContextLabel: label,
          // Matches what the intake form itself produces for this branch
          // (smart-trainer answers go into subcategoryValue with subcategory
          // 'issue').
          initialIntake: IntakeAnswers(
            category: IntakeCategory.smartTrainer,
            subcategory: 'issue',
            subcategoryValue: SelfTestCard.intakeSymptomFor(result.verdict),
          ),
          telemetryBuilder: () async => TelemetrySnapshot.general(freetext: await debugText()),
        ),
      ),
    );
  }

  static String _verdictBody(AppLocalizations l10n, SelfTestVerdict verdict) {
    return switch (verdict) {
      SelfTestVerdict.pass => l10n.selfTestVerdictPassBody,
      SelfTestVerdict.ergOkVsFail => l10n.selfTestVerdictErgOkBody,
      SelfTestVerdict.vsOkErgFail => l10n.selfTestVerdictVsOkErgFailBody,
      SelfTestVerdict.noControl => l10n.selfTestVerdictNoControlBody,
      SelfTestVerdict.noData => l10n.selfTestVerdictNoDataBody,
      SelfTestVerdict.aborted => l10n.selfTestVerdictAbortedBody,
    };
  }

  Widget _notice(BuildContext context, {required IconData icon, required String message, required Color color}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Icon(icon, size: 15, color: color),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  /// [SelfTestPhase.idle] only shows in the frame between the start tap and the
  /// engine's first emit, and [SelfTestPhase.done] never reaches here (a done
  /// state always carries a result), so both fall back to the opening phase.
  static String _phaseLabel(AppLocalizations l10n, SelfTestPhase phase) {
    return switch (phase) {
      SelfTestPhase.ergStaircase => l10n.selfTestPhaseErg,
      SelfTestPhase.shiftSweep => l10n.selfTestPhaseShift,
      _ => l10n.selfTestPhaseBaseline,
    };
  }

  static String _verdictTitle(AppLocalizations l10n, SelfTestVerdict verdict) {
    return switch (verdict) {
      SelfTestVerdict.pass => l10n.selfTestVerdictPassTitle,
      SelfTestVerdict.ergOkVsFail => l10n.selfTestVerdictErgOkTitle,
      SelfTestVerdict.vsOkErgFail => l10n.selfTestVerdictVsOkErgFailTitle,
      SelfTestVerdict.noControl => l10n.selfTestVerdictNoControlTitle,
      SelfTestVerdict.noData => l10n.selfTestVerdictNoDataTitle,
      SelfTestVerdict.aborted => l10n.selfTestVerdictAbortedTitle,
    };
  }
}
