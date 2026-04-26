import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/workout/workout_summary_dialog.dart';
import 'package:bike_control/pages/workout/workouts_list_page.dart';
import 'package:bike_control/services/workout/fit_writer.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MiniWorkoutCard extends StatefulWidget {
  final ProxyDevice device;
  const MiniWorkoutCard({super.key, required this.device});

  @override
  State<MiniWorkoutCard> createState() => _MiniWorkoutCardState();
}

class _MiniWorkoutCardState extends State<MiniWorkoutCard> {
  WorkoutRecorder get _recorder => core.workoutRecorder;

  void _start() {
    final metrics = TrainerMetrics.fromDefinition(widget.device.emulator.activeDefinition);
    if (metrics == null) return;
    WakelockPlus.enable();
    _recorder.start(metrics);
  }

  Future<void> _stopAndSave() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.miniWorkoutConfirmStopTitle),
        content: Text(l10n.miniWorkoutConfirmStopBody),
        actions: [
          Button.outline(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          Button.primary(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.miniWorkoutStop),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = _recorder.stop();
    WakelockPlus.disable();
    if (result.activeDuration.inSeconds < 10) {
      buildToast(title: l10n.miniWorkoutRecordingTooShort);
      return;
    }
    final bytes = FitFileWriter.encode(samples: result.samples, summary: result.summary);
    final file = await core.workoutRepository.save(startedAt: result.startedAt, fitBytes: bytes);
    if (!mounted) return;
    await showWorkoutSummaryDialog(context: context, summary: result.summary, fitFile: file);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final metrics = TrainerMetrics.fromDefinition(widget.device.emulator.activeDefinition);
    if (metrics == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 8,
            children: [
              const Icon(LucideIcons.activity, size: 18),
              Text(l10n.miniWorkout, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          ValueListenableBuilder<WorkoutState>(
            valueListenable: _recorder.state,
            builder: (context, state, _) => _body(context, state, l10n),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WorkoutState state, AppLocalizations l10n) {
    if (state == WorkoutState.idle) {
      return Row(
        spacing: 8,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _gridTile(
            context: context,
            icon: LucideIcons.circle,
            iconColor: Theme.of(context).colorScheme.destructive,
            label: l10n.miniWorkoutStart,
            onTap: _start,
          ),
          _gridTile(
            context: context,
            icon: LucideIcons.list,
            label: l10n.miniWorkoutPastWorkouts,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WorkoutsListPage()),
            ),
          ),
        ],
      );
    }
    return Column(
      spacing: 8,
      children: [
        ValueListenableBuilder<Duration>(
          valueListenable: _recorder.elapsed,
          builder: (_, d, _) => Text(
            _fmtDuration(d),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
        ),
        Text(
          state == WorkoutState.paused ? l10n.miniWorkoutPaused : l10n.miniWorkoutRecording,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.mutedForeground,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            if (state == WorkoutState.recording)
              IconButton.secondary(
                icon: const Icon(LucideIcons.pause, size: 20),
                onPressed: _recorder.pause,
              ),
            if (state == WorkoutState.paused)
              IconButton.primary(
                icon: const Icon(LucideIcons.play, size: 20),
                onPressed: _recorder.resume,
              ),
            IconButton.destructive(
              icon: const Icon(LucideIcons.square, size: 20),
              onPressed: _stopAndSave,
            ),
          ],
        ),
      ],
    );
  }

  Widget _gridTile({
    required BuildContext context,
    required IconData icon,
    Color? iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Button.ghost(
      onPressed: onTap,
      style: ButtonStyle.ghost().copyWith(
        padding: (context, states, value) => const EdgeInsets.all(0),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.muted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Icon(icon, size: 22, color: iconColor),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
