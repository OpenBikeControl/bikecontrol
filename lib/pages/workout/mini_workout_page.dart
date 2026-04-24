import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:bike_control/pages/workout/workout_summary_page.dart';
import 'package:bike_control/services/workout/fit_writer.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MiniWorkoutPage extends StatefulWidget {
  final ProxyDevice device;
  const MiniWorkoutPage({super.key, required this.device});

  @override
  State<MiniWorkoutPage> createState() => _MiniWorkoutPageState();
}

class _MiniWorkoutPageState extends State<MiniWorkoutPage> {
  WorkoutRecorder get _recorder => core.workoutRecorder;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    final metrics = TrainerMetrics.fromDefinition(widget.device.emulator.activeDefinition);
    if (metrics != null && _recorder.state.value == WorkoutState.idle) {
      _recorder.start(metrics);
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _stopAndSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).miniWorkoutConfirmStopTitle),
        content: Text(AppLocalizations.of(ctx).miniWorkoutConfirmStopBody),
        actions: [
          Button.outline(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          Button.primary(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx).miniWorkoutStop),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = _recorder.stop();
    if (result.activeDuration.inSeconds < 10) {
      buildToast(title: AppLocalizations.of(context).miniWorkoutRecordingTooShort);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final bytes = FitFileWriter.encode(samples: result.samples, summary: result.summary);
    final file = await core.workoutRepository.save(startedAt: result.startedAt, fitBytes: bytes);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WorkoutSummaryPage(summary: result.summary, fitFile: file)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = TrainerMetrics.fromDefinition(widget.device.emulator.activeDefinition);
    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () async {
                if (_recorder.state.value != WorkoutState.idle) {
                  await _stopAndSave();
                } else {
                  if (mounted) Navigator.of(context).pop();
                }
              },
            ),
          ],
          title: Text(l10n.miniWorkout),
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 16,
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: _recorder.elapsed,
              builder: (_, d, _) => Text(
                _fmtDuration(d),
                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w700, letterSpacing: -1),
              ),
            ),
            ValueListenableBuilder<WorkoutState>(
              valueListenable: _recorder.state,
              builder: (_, s, _) => Text(
                s == WorkoutState.paused ? l10n.miniWorkoutPaused : l10n.miniWorkoutRecording,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            if (metrics != null) _metricsGrid(metrics),
            if (metrics == null) Text(l10n.miniWorkoutNoTrainerConnected),
            const Gap(24),
            _controls(l10n),
          ],
        ),
      ),
    );
  }

  Widget _metricsGrid(TrainerMetrics m) {
    Widget bindInt(
      ValueListenable<int?> ln, {
      required IconData icon,
      required Color color,
      required String label,
      required String unit,
    }) {
      return ValueListenableBuilder<int?>(
        valueListenable: ln,
        builder: (_, v, _) => MetricCard(icon: icon, iconColor: color, label: label, value: v?.toString(), unit: unit),
      );
    }

    Widget bindDouble(
      ValueListenable<double?> ln, {
      required IconData icon,
      required Color color,
      required String label,
      required String unit,
    }) {
      return ValueListenableBuilder<double?>(
        valueListenable: ln,
        builder: (_, v, _) =>
            MetricCard(icon: icon, iconColor: color, label: label, value: v?.toStringAsFixed(1), unit: unit),
      );
    }

    return Column(
      spacing: 10,
      children: [
        Row(spacing: 10, children: [
          bindInt(m.powerW, icon: LucideIcons.zap, color: const Color(0xFFF59E0B), label: 'POWER', unit: 'W'),
          bindInt(m.heartRateBpm, icon: LucideIcons.heart, color: const Color(0xFFEF4444), label: 'HEART', unit: 'bpm'),
        ]),
        Row(spacing: 10, children: [
          bindInt(m.cadenceRpm, icon: LucideIcons.rotateCw, color: const Color(0xFF8B5CF6), label: 'CADENCE', unit: 'rpm'),
          bindDouble(m.speedKph, icon: LucideIcons.gauge, color: const Color(0xFF0EA5E9), label: 'SPEED', unit: 'km/h'),
        ]),
      ],
    );
  }

  Widget _controls(AppLocalizations l10n) {
    return ValueListenableBuilder<WorkoutState>(
      valueListenable: _recorder.state,
      builder: (_, s, _) => Row(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (s == WorkoutState.recording)
            Button.secondary(
              onPressed: _recorder.pause,
              child: Text(l10n.miniWorkoutPause),
            ),
          if (s == WorkoutState.paused)
            Button.primary(
              onPressed: _recorder.resume,
              child: Text(l10n.miniWorkoutResume),
            ),
          Button.destructive(
            onPressed: _stopAndSave,
            child: Text(l10n.miniWorkoutStop),
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
