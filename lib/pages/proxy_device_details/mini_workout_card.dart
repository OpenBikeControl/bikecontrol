import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/workout/workout_summary_dialog.dart';
import 'package:bike_control/pages/workout/workouts_list_page.dart' show WorkoutsList;
import 'package:bike_control/services/workout/fit_writer.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/home/your_buttons.dart' show RideSectionHeader;
import 'package:bike_control/widgets/ui/app_theme.dart' show BkComponentThemes;
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart' show bkAccentText, bkCardShadow;
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the Record Activity card off Ride. For the onboarding video,
/// which is about Virtual Shifting. Off everywhere else.
@visibleForTesting
bool debugHideMiniWorkoutCard = false;

class MiniWorkoutCard extends StatefulWidget {
  final ProxyDevice device;
  const MiniWorkoutCard({super.key, required this.device});

  /// Whether the card has anything to show for [device]: a trainer whose
  /// metrics it can record, off the web. Lets a host leave its spacing out
  /// along with the card.
  static bool shows(ProxyDevice device) => !kIsWeb && !debugHideMiniWorkoutCard && _metricsFor(device) != null;

  /// What the workout records: the bridge's live definition, or the trainer's
  /// own virtual shifting definition while the bridge has not composed it.
  static TrainerMetrics? _metricsFor(ProxyDevice device) =>
      TrainerMetrics.fromDefinition(device.emulator.activeDefinition) ??
      TrainerMetrics.fromDefinition(device.fitnessBike);

  @override
  State<MiniWorkoutCard> createState() => _MiniWorkoutCardState();
}

class _MiniWorkoutCardState extends State<MiniWorkoutCard> {
  WorkoutRecorder get _recorder => core.workoutRecorder;

  void _start() {
    final metrics = MiniWorkoutCard._metricsFor(widget.device);
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

    // Through healthRide so the ride also reaches Apple Health, and an
    // automatic ride is released rather than restarted on the next tick.
    final result = core.healthRide.stopRide();
    WakelockPlus.disable();
    if (result.activeDuration.inSeconds < 10) {
      buildToast(title: l10n.miniWorkoutRecordingTooShort);
      return;
    }
    final bytes = FitFileWriter.encode(samples: result.samples, summary: result.summary);
    final file = await core.workoutRepository.save(
      startedAt: result.startedAt,
      fitBytes: bytes,
      summary: result.summary,
    );
    if (!mounted) return;
    await showWorkoutSummaryDialog(context: context, summary: result.summary, fitFile: file);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final metrics = MiniWorkoutCard._metricsFor(widget.device);
    if (metrics == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RideSectionHeader(title: l10n.miniWorkout),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.card,
            borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
            boxShadow: bkCardShadow(context),
          ),
          child: ValueListenableBuilder<WorkoutState>(
            valueListenable: _recorder.state,
            builder: (context, state, _) => _body(context, state, l10n),
          ),
        ),
      ],
    );
  }

  /// What a recording becomes: always a .fit file to share, and on iPhone a
  /// workout in Apple Health while saving rides there is on.
  String _subtitle(AppLocalizations l10n) {
    final health = core.healthRide;
    return health.isSupported && health.isEnabled ? l10n.recordActivitySubtitleHealth : l10n.recordActivitySubtitle;
  }

  void _openPast() => openSheet(
    context: context,
    draggable: true,
    position: OverlayPosition.bottom,
    builder: (_) => const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: WorkoutsList(showHeader: true),
    ),
  );

  Widget _body(BuildContext context, WorkoutState state, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    if (state == WorkoutState.idle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_subtitle(l10n), style: context.typography.small.copyWith(color: cs.mutedForeground)),
          const Gap(14),
          BkPillButton(
            key: const ValueKey('record-activity-start'),
            onPressed: _start,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(LucideIcons.circleDot, size: 18, color: cs.primaryForeground),
                Text(l10n.miniWorkoutStart),
              ],
            ),
          ),
          const Gap(4),
          BkTouchTarget(
            child: Button.ghost(
              key: const ValueKey('record-activity-past'),
              alignment: Alignment.center,
              onPressed: _openPast,
              child: Text(
                l10n.miniWorkoutPastWorkouts,
                style: context.typography.small.copyWith(color: bkAccentText(context), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }
    final recording = state == WorkoutState.recording;
    return Column(
      spacing: 8,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: recording ? cs.destructive : cs.mutedForeground,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              recording ? l10n.miniWorkoutRecording : l10n.miniWorkoutPaused,
              style: context.typography.small.copyWith(fontWeight: FontWeight.w600, color: cs.mutedForeground),
            ),
          ],
        ),
        ValueListenableBuilder<Duration>(
          valueListenable: _recorder.elapsed,
          builder: (_, d, _) => Text(
            _fmtDuration(d),
            style: BkNumerals.gear((context.typography.x3Large.fontSize ?? 30) * 1.6, color: cs.foreground, height: 1),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            if (recording)
              BkIconButton.secondary(
                icon: const Icon(LucideIcons.pause, size: 20),
                label: context.i18n.miniWorkoutPause,
                onPressed: _recorder.pause,
              )
            else
              BkIconButton.primary(
                icon: const Icon(LucideIcons.play, size: 20),
                label: context.i18n.miniWorkoutResume,
                onPressed: _recorder.resume,
              ),
            BkIconButton.destructive(
              icon: const Icon(LucideIcons.square, size: 20),
              label: context.i18n.miniWorkoutStop,
              onPressed: _stopAndSave,
            ),
          ],
        ),
      ],
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
