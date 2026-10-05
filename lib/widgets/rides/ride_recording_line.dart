import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkComponentThemes;
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Ride's recording slot: the status line while a ride records, the manual
/// start while automatic recording is off, nothing otherwise. On a phone it
/// sits right under the Virtual shifting card; on a desktop in the right
/// column under Your buttons ([textActions]).
class RideRecordingSlot extends StatelessWidget {
  const RideRecordingSlot({super.key, this.textActions = false, this.spacing = 0});

  /// Desktop: Verwerfen as a text button instead of the trash icon.
  final bool textActions;

  /// Space above the slot when it shows anything.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rides = core.rides;
    return ListenableBuilder(
      listenable: rides.changes,
      builder: (context, _) {
        final state = rides.recorder.state.value;
        final Widget child;
        if (state != WorkoutState.idle) {
          child = RideRecordingLine(
            key: const ValueKey('ride-status-line'),
            paused: state == WorkoutState.paused,
            elapsed: rides.recorder.elapsed,
            startedAutomatically: rides.detector.startedAutomatically.value,
            onFinish: rides.finish,
            onDiscard: rides.discard,
            textActions: textActions,
          );
        } else if (!rides.autoRecord) {
          child = RideManualStartCard(
            key: const ValueKey('ride-manual-start'),
            canStart: rides.canStartManually,
            onStart: rides.startManual,
          );
        } else {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.only(top: spacing),
          child: child,
        );
      },
    );
  }
}

/// One card-row while a ride records: a pulsing accent dot (a hollow ring
/// while paused), "Recording" and the moving time with how the ride
/// started, Beenden as a secondary pill and Verwerfen behind a confirm.
class RideRecordingLine extends StatelessWidget {
  const RideRecordingLine({
    super.key,
    required this.paused,
    required this.elapsed,
    required this.startedAutomatically,
    required this.onFinish,
    required this.onDiscard,
    this.textActions = false,
  });

  final bool paused;
  final ValueListenable<Duration> elapsed;
  final bool startedAutomatically;
  final VoidCallback onFinish;
  final VoidCallback onDiscard;
  final bool textActions;

  Future<void> _confirmDiscard(BuildContext context) async {
    if (await confirmRideDiscard(context)) onDiscard();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final typography = context.typography;
    final sub = paused ? l10n.ridesResumesOnPedal : (startedAutomatically ? l10n.ridesAutoStarted : null);
    final finish = BkTouchTarget(
      child: Button(
        key: const ValueKey('ride-status-finish'),
        style: BkPillButton.shape(
          const ButtonStyle.secondary().withPadding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
        ),
        alignment: Alignment.center,
        onPressed: onFinish,
        child: Text(l10n.miniWorkoutStop),
      ),
    );
    final discard = textActions
        ? Button.ghost(
            key: const ValueKey('ride-status-discard'),
            onPressed: () => _confirmDiscard(context),
            child: Semantics(
              label: l10n.healthRideDiscard,
              excludeSemantics: true,
              child: Text(l10n.healthRideDiscard, style: TextStyle(color: cs.mutedForeground)),
            ),
          )
        : BkIconButton.ghost(
            key: const ValueKey('ride-status-discard'),
            icon: Icon(LucideIcons.trash2, size: 19, color: cs.mutedForeground),
            label: l10n.healthRideDiscard,
            onPressed: () => _confirmDiscard(context),
          );

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        boxShadow: bkCardShadow(context),
      ),
      child: Row(
        children: [
          _RecordingDot(paused: paused),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  paused ? l10n.miniWorkoutPaused : l10n.miniWorkoutRecording,
                  style: typography.base.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.16),
                ),
                const Gap(2),
                ValueListenableBuilder<Duration>(
                  valueListenable: elapsed,
                  builder: (context, d, _) => Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatRideDuration(d),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.foreground,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (sub != null) TextSpan(text: ' · $sub'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.xSmall.copyWith(color: cs.mutedForeground),
                  ),
                ),
              ],
            ),
          ),
          discard,
          const Gap(2),
          finish,
        ],
      ),
    );
  }
}

/// "Diese Fahrt verwerfen?": true when the rider confirmed.
Future<bool> confirmRideDiscard(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.healthRideDiscardConfirmTitle),
      content: Text(l10n.ridesDiscardBody),
      actions: [
        BkTouchTarget(
          child: Button.secondary(
            alignment: Alignment.center,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
        ),
        BkTouchTarget(
          child: Button.destructive(
            alignment: Alignment.center,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.healthRideDiscardConfirmAction),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// The recording dot: brand accent (red means error here, and recording is
/// not trouble), pulsing outward while recording, a hollow ring while
/// paused, still under reduced motion.
class _RecordingDot extends StatefulWidget {
  const _RecordingDot({required this.paused});

  final bool paused;

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_RecordingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = !widget.paused && !prefersReducedMotion(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!animate && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    return ExcludeSemantics(
      child: SizedBox(
        width: 20,
        height: 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!widget.paused)
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = Curves.easeOutCubic.transform(_pulse.value);
                  if (!_pulse.isAnimating) return const SizedBox.shrink();
                  return Opacity(
                    opacity: 0.6 * (1 - t),
                    child: Container(
                      width: 10 + 10 * t,
                      height: 10 + 10 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 2),
                      ),
                    ),
                  );
                },
              ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.paused ? null : accent,
                border: widget.paused ? Border.all(color: cs.mutedForeground, width: 2) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ride while automatic recording is off: "Aufzeichnung starten" and a line
/// that says why it is needed, with the way to Settings.
class RideManualStartCard extends StatelessWidget {
  const RideManualStartCard({super.key, required this.canStart, required this.onStart});

  final bool canStart;
  final bool Function() onStart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final shell = ShellScope.maybeOf(context);
    final caption = context.typography.small.copyWith(color: cs.mutedForeground);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        boxShadow: bkCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BkPillButton.secondary(
            key: const ValueKey('ride-manual-start-button'),
            onPressed: canStart ? () => onStart() : null,
            leading: const Icon(LucideIcons.circleDot, size: 18),
            child: Text(l10n.miniWorkoutStart),
          ),
          const Gap(4),
          if (!canStart)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.miniWorkoutNoTrainerConnected, style: caption, textAlign: TextAlign.center),
            )
          else
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${l10n.ridesAutoOff} · ', style: caption),
                if (shell != null)
                  // An inline link: padding gives the target its height, the
                  // text stays on the caption's line.
                  BkTappable(
                    key: const ValueKey('ride-manual-settings'),
                    label: l10n.navSettings,
                    onPressed: () => shell.section.value = AppSection.settings,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.navSettings,
                            style: caption.copyWith(color: bkAccentText(context), fontWeight: FontWeight.w600),
                          ),
                          Icon(LucideIcons.chevronRight, size: 14, color: bkAccentText(context)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
