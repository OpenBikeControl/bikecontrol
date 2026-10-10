import 'dart:async';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart' show updateActiveShiftingConfig;
import 'package:bike_control/services/vs_calibration/vs_calibration_session.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkComponentThemes;
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Why a start tap was turned down; shown inline, like the self-test's.
enum _Refusal { disconnected, trainerApp }

enum _View { intro, running, result }

/// Trainer page → "Calibrate shifting feel": tunes how hard virtual shifting
/// rides on this trainer.
///
/// With the trainer app closed, the page drives the trainer itself through
/// three grades ([VsCalibrationSession.grades001Pct]). The rider shifts with
/// their own controller (or the on-screen buttons) to the gear they would ride
/// there and rates the feel; each "too heavy" / "too light" goes onto the
/// trainer at once so the next rating is of the corrected feel. The result is
/// the trainer's difficulty ([FitnessBikeDefinition.setDifficultyPct]),
/// stored on its active shifting config so it follows reconnects and syncs.
///
/// A run owns the trainer until it ends: stopping it, leaving the page or a
/// trainer app connecting puts the difficulty the rider started with back.
class VsCalibrationPage extends StatefulWidget {
  const VsCalibrationPage({super.key, required this.device});

  final ProxyDevice device;

  @override
  State<VsCalibrationPage> createState() => _VsCalibrationPageState();
}

class _VsCalibrationPageState extends State<VsCalibrationPage> {
  _View _view = _View.intro;
  _Refusal? _refusal;

  /// Non-null while a run is on the trainer.
  VsCalibrationSession? _session;
  FitnessBikeDefinition? _runDef;
  int _startPct = FitnessBikeDefinition.defaultDifficultyPct;
  int _startGrade = 0;

  /// True once the current grade has been adjusted at least once, so the
  /// "ride it again" line only appears after a change.
  bool _adjustedHere = false;

  /// True when the result view follows a run and the page left the trainer on
  /// the flat for fine-tuning by feel.
  bool _onFlat = false;

  @override
  void initState() {
    super.initState();
    widget.device.isConnectedListenable.addListener(_onTrainerAppChanged);
  }

  @override
  void dispose() {
    widget.device.isConnectedListenable.removeListener(_onTrainerAppChanged);
    // A run outlives the page unless ended here: the trainer would stay on a
    // calibration grade at a difficulty nobody accepted.
    _abandonRun();
    super.dispose();
  }

  FitnessBikeDefinition? get _def => widget.device.fitnessBike;

  /// A trainer app taking over mid-run would fight the page over the grade, so
  /// the run ends and says why.
  void _onTrainerAppChanged() {
    if (!mounted || _session == null || !widget.device.isConnectedListenable.value) return;
    _abandonRun();
    setState(() {
      _view = _View.intro;
      _refusal = _Refusal.trainerApp;
    });
  }

  void _start() {
    if (!widget.device.isConnected) {
      setState(() => _refusal = _Refusal.disconnected);
      return;
    }
    if (widget.device.isConnectedListenable.value) {
      setState(() => _refusal = _Refusal.trainerApp);
      return;
    }
    final def = _def;
    if (def == null) return;
    _startPct = def.difficultyPct.value;
    _startGrade = def.simGrade.value;
    final session = VsCalibrationSession(startPct: _startPct);
    _runDef = def;
    _session = session;
    def.setCalibrationGrade(session.grade001Pct);
    _wakelock(true);
    setState(() {
      _refusal = null;
      _adjustedHere = false;
      _onFlat = false;
      _view = _View.running;
    });
  }

  void _rate(CalibrationRating rating) {
    final session = _session;
    final def = _runDef;
    if (session == null || def == null || !_owns(def)) return;
    final stepBefore = session.stepIndex;
    session.rate(rating);
    def.setDifficultyPct(session.difficultyPct);
    if (session.isDone) {
      unawaited(_finish(def, session.difficultyPct));
      return;
    }
    if (session.stepIndex != stepBefore) {
      def.setCalibrationGrade(session.grade001Pct);
    }
    setState(() => _adjustedHere = session.stepIndex == stepBefore);
  }

  Future<void> _finish(FitnessBikeDefinition def, int pct) async {
    _session = null;
    _runDef = null;
    _wakelock(false);
    // Fine-tuning happens on the flat, where an over-heavy gear shows most.
    def.setCalibrationGrade(0);
    setState(() {
      _onFlat = true;
      _view = _View.result;
    });
    await _persist(pct);
  }

  void _stop() {
    _abandonRun();
    setState(() => _view = _View.intro);
  }

  /// Ends a run without keeping its result: the difficulty and grade the rider
  /// started with go back on the trainer. Never calls setState (runs from
  /// [dispose] too).
  void _abandonRun() {
    final def = _runDef;
    _session = null;
    _runDef = null;
    if (def == null) return;
    _wakelock(false);
    if (!_owns(def)) return;
    def.setDifficultyPct(_startPct);
    def.setCalibrationGrade(_startGrade);
  }

  /// False once a reconnect has replaced (and disposed) [def].
  bool _owns(FitnessBikeDefinition def) => identical(_def, def);

  Future<void> _setDifficulty(int pct) async {
    _def?.setDifficultyPct(pct);
    setState(() {});
    await _persist(pct);
  }

  Future<void> _persist(int pct) async {
    try {
      await updateActiveShiftingConfig(widget.device, (c) => c.copyWith(difficultyPct: pct));
    } catch (e, s) {
      recordError(e, s, context: 'vs calibration persist');
    }
  }

  void _openManual() => setState(() {
    _refusal = null;
    _onFlat = false;
    _view = _View.result;
  });

  /// The rider pedals for a few minutes with their hands on the bars.
  void _wakelock(bool enable) {
    unawaited(
      WakelockPlus.toggle(
        enable: enable,
      ).catchError((Object e, StackTrace s) => recordError(e, s, context: 'vs calibration wakelock')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final def = _def;
    return Scaffold(
      headers: [BkPageHeader(title: l10n.vsCalibrateTitle)],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: BkPageColumn(
          child: def == null
              ? _notice(context, key: 'vs-cal-refusal', icon: LucideIcons.triangleAlert, message: l10n.vsCalibratePrecheckDisconnected)
              : switch (_view) {
                  _View.intro => _intro(context, l10n, def),
                  _View.running => _running(context, l10n, def, _session!),
                  _View.result => _result(context, l10n, def),
                },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ intro

  Widget _intro(BuildContext context, AppLocalizations l10n, FitnessBikeDefinition def) {
    final cs = Theme.of(context).colorScheme;
    // Zwift-Cog trainers turn the gear ratio into resistance in their own
    // firmware; the difficulty never reaches them, so a run would rate nothing.
    final firmwareShifting = def.controlProtocol == TrainerControlProtocol.zwiftHub;
    // A refusal clears itself once its condition does.
    if (_refusal == _Refusal.disconnected && widget.device.isConnected) {
      _refusal = null;
    } else if (_refusal == _Refusal.trainerApp && !widget.device.isConnectedListenable.value) {
      _refusal = null;
    }
    final refusal = _refusal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: BkGroupedSection.inset),
          child: Text(l10n.vsCalibrateIntro, style: context.typography.small.copyWith(color: cs.mutedForeground)),
        ),
        const Gap(20),
        if (firmwareShifting)
          _notice(context, key: 'vs-cal-firmware', icon: LucideIcons.cpu, message: l10n.vsCalibrateFirmware)
        else ...[
          BkGroupedSection(
            children: [
              BkGroupedRow(icon: LucideIcons.monitorOff, title: l10n.vsCalibrateStepCloseApp),
              BkGroupedRow(icon: LucideIcons.bike, title: l10n.vsCalibrateStepPedal),
              BkGroupedRow(icon: LucideIcons.mountain, title: l10n.vsCalibrateStepRate),
            ],
          ),
          const Gap(20),
          if (refusal != null) ...[
            _notice(
              context,
              key: 'vs-cal-refusal',
              icon: LucideIcons.triangleAlert,
              danger: true,
              message: switch (refusal) {
                _Refusal.disconnected => l10n.vsCalibratePrecheckDisconnected,
                _Refusal.trainerApp => l10n.vsCalibratePrecheckTrainerApp,
              },
            ),
            const Gap(12),
          ],
          Button.primary(key: const ValueKey('vs-cal-start'), onPressed: _start, child: Text(l10n.vsCalibrateStart)),
          const Gap(8),
          Button.ghost(
            key: const ValueKey('vs-cal-manual'),
            onPressed: _openManual,
            child: Text(l10n.vsCalibrateManual),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- running

  Widget _running(BuildContext context, AppLocalizations l10n, FitnessBikeDefinition def, VsCalibrationSession s) {
    final cs = Theme.of(context).colorScheme;
    final total = VsCalibrationSession.grades001Pct.length;
    final gradeName = switch (s.stepIndex) {
      0 => l10n.vsCalibrateGradeFlat,
      1 => l10n.vsCalibrateGradeGentle,
      _ => l10n.vsCalibrateGradeSteady,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Where the rider is in the run: three segments, the label says it.
        ExcludeSemantics(
          child: Row(
            spacing: 6,
            children: [
              for (var i = 0; i < total; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= s.stepIndex ? cs.primary : cs.muted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Gap(12),
        Text(
          l10n.vsCalibrateStepOf(s.stepIndex + 1, total),
          style: context.typography.small.copyWith(color: cs.mutedForeground),
        ),
        const Gap(2),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            '$gradeName · ${l10n.vsCalibratePct(s.grade001Pct ~/ 100)}',
            style: context.typography.x2Large.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
          ),
        ),
        const Gap(20),
        _gearReadout(context, l10n, def),
        const Gap(8),
        _liveMetrics(context, l10n, def),
        const Gap(20),
        Text(l10n.vsCalibrateAsk, style: context.typography.base.copyWith(fontWeight: FontWeight.w600)),
        const Gap(12),
        _ratingButtons(context, l10n),
        if (_adjustedHere) ...[
          const Gap(12),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.vsCalibrateAdjusted(s.difficultyPct),
              style: context.typography.small.copyWith(color: cs.mutedForeground),
            ),
          ),
        ],
        const Gap(24),
        Button.ghost(key: const ValueKey('vs-cal-stop'), onPressed: _stop, child: Text(l10n.vsCalibrateStop)),
      ],
    );
  }

  /// The gear the rider is in, big enough to read from the saddle, with
  /// on-screen shift buttons for a rider without a controller to hand.
  Widget _gearReadout(BuildContext context, AppLocalizations l10n, FitnessBikeDefinition def) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        border: Border.all(color: cs.border),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: def.currentGear,
        builder: (context, gear, _) => Row(
          children: [
            BkIconButton.ghost(
              key: const ValueKey('vs-cal-shift-down'),
              label: l10n.actionShiftDown,
              size: ButtonSize.large,
              icon: const Icon(LucideIcons.minus),
              onPressed: gear > FitnessBikeDefinition.minGear ? def.shiftDown : null,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: l10n.vsCalibrateGear(gear, def.maxGear),
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      Text('$gear', style: BkNumerals.gear(72, color: cs.foreground, height: 1)),
                      Text(
                        l10n.vsCalibrateGear(gear, def.maxGear),
                        style: context.typography.small.copyWith(color: cs.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            BkIconButton.ghost(
              key: const ValueKey('vs-cal-shift-up'),
              label: l10n.actionShiftUp,
              size: ButtonSize.large,
              icon: const Icon(LucideIcons.plus),
              onPressed: gear < def.maxGear ? def.shiftUp : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Cadence and power, and a nudge when the rider stops pedaling: without
  /// cadence a grade has nothing to push against.
  Widget _liveMetrics(BuildContext context, AppLocalizations l10n, FitnessBikeDefinition def) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int?>(
      valueListenable: def.cadenceRpm,
      builder: (context, rpm, _) => ValueListenableBuilder<int?>(
        valueListenable: def.powerW,
        builder: (context, watts, _) {
          final coasting = rpm != null && rpm < 30;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Text(
                '${rpm ?? '--'} rpm · ${watts ?? '--'} W',
                textAlign: TextAlign.center,
                style: context.typography.small.copyWith(
                  color: cs.mutedForeground,
                  fontFeatures: BkNumerals.tabular,
                ),
              ),
              if (coasting)
                _notice(context, key: 'vs-cal-keep-pedaling', icon: LucideIcons.rotateCcw, message: l10n.vsCalibrateKeepPedaling),
            ],
          );
        },
      ),
    );
  }

  /// Three equal answers, heaviest to lightest. Side by side where they fit,
  /// stacked on a phone so each stays a large target for a sweaty thumb.
  Widget _ratingButtons(BuildContext context, AppLocalizations l10n) {
    Widget answer(String key, IconData icon, String label, CalibrationRating rating, {bool primary = false}) {
      // Icon and label centred together, so the three read as one scale.
      final child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Icon(icon, size: 18),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      );
      return primary
          ? Button.primary(key: ValueKey(key), alignment: Alignment.center, onPressed: () => _rate(rating), child: child)
          : Button.outline(key: ValueKey(key), alignment: Alignment.center, onPressed: () => _rate(rating), child: child);
    }

    final buttons = [
      answer('vs-cal-too-heavy', LucideIcons.weight, l10n.vsCalibrateTooHeavy, CalibrationRating.tooHeavy),
      answer('vs-cal-about-right', LucideIcons.check, l10n.vsCalibrateAboutRight, CalibrationRating.aboutRight, primary: true),
      answer('vs-cal-too-light', LucideIcons.feather, l10n.vsCalibrateTooLight, CalibrationRating.tooLight),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 480
          ? Row(spacing: 8, children: [for (final b in buttons) Expanded(child: b)])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: buttons),
    );
  }

  // ----------------------------------------------------------------- result

  Widget _result(BuildContext context, AppLocalizations l10n, FitnessBikeDefinition def) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      key: const ValueKey('vs-cal-result'),
      valueListenable: def.difficultyPct,
      builder: (context, pct, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.vsCalibrateResultTitle, style: context.typography.base.copyWith(fontWeight: FontWeight.w600)),
          ),
          Semantics(
            liveRegion: true,
            child: Text(l10n.vsCalibratePct(pct), style: BkNumerals.gear(72, color: cs.foreground, height: 1.1)),
          ),
          const Gap(8),
          Text(
            _onFlat ? '${l10n.vsCalibrateResultBody} ${l10n.vsCalibrateResultFlat}' : l10n.vsCalibrateResultBody,
            style: context.typography.small.copyWith(color: cs.mutedForeground),
          ),
          const Gap(20),
          BkGroupedSection(
            children: [
              BkGroupedRow(
                icon: LucideIcons.gauge,
                title: l10n.vsCalibrateDifficulty,
                trailing: StepperControl(
                  value: pct.toDouble(),
                  step: VsCalibrationSession.minStepPct.toDouble(),
                  min: FitnessBikeDefinition.minDifficultyPct.toDouble(),
                  max: FitnessBikeDefinition.maxDifficultyPct.toDouble(),
                  format: (v) => l10n.vsCalibratePct(v.round()),
                  onChanged: (v) => _setDifficulty(v.round()),
                ),
              ),
            ],
          ),
          const Gap(8),
          Align(
            alignment: Alignment.centerLeft,
            child: Button.ghost(
              key: const ValueKey('vs-cal-reset'),
              onPressed: pct == FitnessBikeDefinition.defaultDifficultyPct
                  ? null
                  : () => _setDifficulty(FitnessBikeDefinition.defaultDifficultyPct),
              child: Text(l10n.vsCalibrateReset),
            ),
          ),
          const Gap(20),
          Button.primary(
            key: const ValueKey('vs-cal-done'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.done),
          ),
          const Gap(8),
          if (def.controlProtocol != TrainerControlProtocol.zwiftHub)
            Button.outline(key: const ValueKey('vs-cal-again'), onPressed: _start, child: Text(l10n.vsCalibrateAgain)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- helpers

  Widget _notice(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String message,
    bool danger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = danger ? cs.destructive : cs.mutedForeground;
    return Container(
      key: ValueKey(key),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: danger ? cs.destructive : cs.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(icon, size: 16, color: color),
          Expanded(
            child: Text(message, style: context.typography.small.copyWith(color: danger ? cs.destructive : cs.foreground)),
          ),
        ],
      ),
    );
  }
}
