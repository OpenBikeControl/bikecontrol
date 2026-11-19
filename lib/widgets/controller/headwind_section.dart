import 'dart:math' as math;

import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_motion.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// What the fan is doing right now, in a word or two.
String headwindStateText(
  BuildContext context,
  HeadwindMode mode,
  int speed, {
  HeadwindFollow follow = HeadwindFollow.none,
}) {
  final l = context.i18n;
  switch (follow) {
    case HeadwindFollow.power:
      return l.headwindStatePower(speed);
    case HeadwindFollow.heartRate:
      return l.headwindStateFollowHeartRate(speed);
    case HeadwindFollow.none:
      break;
  }
  return switch (mode) {
    HeadwindMode.unknown => '–',
    HeadwindMode.off => l.headwindStateOff,
    HeadwindMode.heartRate => l.headwindStateHeartRate,
    HeadwindMode.speed => l.headwindStateSpeed,
    HeadwindMode.manual => '$speed%',
  };
}

/// A Headwind's page section, built around one question: what sets the fan?
///
/// The fan's speed leads as the one loud number, with a line saying where it
/// comes from. Under it a Manual | Heart rate | Power track picks the source,
/// and only the chosen source's controls follow: the speeds by hand, or the
/// range BikeControl maps a reading onto.
class HeadwindSection extends StatelessWidget {
  const HeadwindSection({super.key, required this.device});

  final WahooKickrHeadwind device;

  Future<void> _run(Future<void> Function() command, String what) async {
    try {
      await command();
    } catch (e, s) {
      recordError(e, s, context: 'HeadwindSection: $what failed');
    }
  }

  Future<void> _setSpeed(int speed) => _run(() => device.setSpeed(speed), 'setSpeed $speed');

  // Back to Manual leaves the fan at the speed it has.
  Future<void> _setFollow(HeadwindFollow follow) => _run(() => device.setFollow(follow), 'setFollow ${follow.name}');

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    return ListenableBuilder(
      listenable: Listenable.merge([
        device.mode,
        device.speed,
        device.follow,
        device.followInput,
        device.startPowerWatts,
        device.fullPowerWatts,
        device.startHeartRate,
        device.fullHeartRate,
      ]),
      builder: (context, _) {
        final mode = device.mode.value;
        final speed = device.speed.value;
        final follow = device.follow.value;
        final input = device.followInput.value;
        final fanOwnHeartRate = follow == HeadwindFollow.none && mode == HeadwindMode.heartRate;
        final unit = follow == HeadwindFollow.power ? 'W' : 'bpm';

        // The number shows a speed only when one is known: the fan reports
        // it in manual mode, and while following BikeControl sets it.
        final showsSpeed = follow != HeadwindFollow.none || mode == HeadwindMode.manual;
        final caption = switch (follow) {
          HeadwindFollow.none => switch (mode) {
            HeadwindMode.manual => l.headwindSetByHand,
            HeadwindMode.heartRate => l.headwindFanOwnHeartRateMode,
            HeadwindMode.speed => l.headwindStateSpeed,
            HeadwindMode.off => l.headwindStateOff,
            HeadwindMode.unknown => null,
          },
          HeadwindFollow.heartRate => input == null ? l.headwindNoHeartRate : l.headwindFromInput('$input bpm'),
          HeadwindFollow.power => input == null ? l.headwindNoPower : l.headwindFromInput('$input W'),
        };

        return BkGroupedSection(
          header: l.headwindFan,
          children: [
            Padding(
              key: const ValueKey('headwind-current'),
              padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 16, BkGroupedSection.inset, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FanReadout(speed: showsSpeed ? speed : null, caption: caption),
                  const Gap(16),
                  _Segments<HeadwindFollow?>(
                    key: const ValueKey('headwind-source'),
                    label: l.headwindFan,
                    // The fan's own heart-rate mode is none of the three:
                    // the caption names it, and nothing is lit.
                    selected: fanOwnHeartRate ? null : follow,
                    options: [
                      (HeadwindFollow.none, l.headwindModeManual, const ValueKey('headwind-manual')),
                      (HeadwindFollow.heartRate, l.headwindModeHeartRate, const ValueKey('headwind-heart-rate')),
                      (HeadwindFollow.power, l.headwindModePower, const ValueKey('headwind-power')),
                    ],
                    onSelected: (f) => _setFollow(f!),
                  ),
                ],
              ),
            ),
            if (follow == HeadwindFollow.none)
              Padding(
                key: const ValueKey('headwind-speeds'),
                padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 12, BkGroupedSection.inset, 12),
                child: _Segments<int>(
                  label: l.headwindModeManual,
                  selected: mode == HeadwindMode.manual ? speed : null,
                  options: [
                    for (final s in WahooKickrHeadwind.allowedSpeeds) (s, '$s%', ValueKey('headwind-speed-$s')),
                  ],
                  onSelected: _setSpeed,
                ),
              )
            else ...[
              BkGroupedRow(
                key: ValueKey(follow == HeadwindFollow.power ? 'headwind-start-power' : 'headwind-start-heart-rate'),
                title: l.headwindStartsAbove,
                trailing: follow == HeadwindFollow.power
                    ? _stepper(
                        value: device.startPowerWatts.value,
                        step: 25,
                        min: WahooKickrHeadwind.minStartPowerWatts,
                        max: device.fullPowerWatts.value - WahooKickrHeadwind.minPowerRampWatts,
                        unit: unit,
                        onChanged: (v) => _run(() => device.setStartPowerWatts(v), 'setStartPowerWatts'),
                      )
                    : _stepper(
                        value: device.startHeartRate.value,
                        step: 5,
                        min: WahooKickrHeadwind.minStartHeartRate,
                        max: device.fullHeartRate.value - WahooKickrHeadwind.minHeartRateRamp,
                        unit: unit,
                        onChanged: (v) => _run(() => device.setStartHeartRate(v), 'setStartHeartRate'),
                      ),
              ),
              BkGroupedRow(
                key: ValueKey(follow == HeadwindFollow.power ? 'headwind-full-power' : 'headwind-full-heart-rate'),
                title: l.headwindFullPowerAt,
                trailing: follow == HeadwindFollow.power
                    ? _stepper(
                        value: device.fullPowerWatts.value,
                        step: 25,
                        min: math.max(
                          WahooKickrHeadwind.minFullPowerWatts,
                          device.startPowerWatts.value + WahooKickrHeadwind.minPowerRampWatts,
                        ),
                        max: WahooKickrHeadwind.maxFullPowerWatts,
                        unit: unit,
                        onChanged: (v) => _run(() => device.setFullPowerWatts(v), 'setFullPowerWatts'),
                      )
                    : _stepper(
                        value: device.fullHeartRate.value,
                        step: 5,
                        min: device.startHeartRate.value + WahooKickrHeadwind.minHeartRateRamp,
                        max: WahooKickrHeadwind.maxFullHeartRate,
                        unit: unit,
                        onChanged: (v) => _run(() => device.setFullHeartRate(v), 'setFullHeartRate'),
                      ),
              ),
              Padding(
                key: const ValueKey('headwind-range-note'),
                padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 12, BkGroupedSection.inset, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(l.headwindRangeNote).xSmall.muted,
                    // A strap paired only to the fan never reaches
                    // BikeControl; the fan's own mode still works with it.
                    if (follow == HeadwindFollow.heartRate && input == null)
                      Button.ghost(
                        key: const ValueKey('headwind-use-fan-heart-rate'),
                        style: const ButtonStyle.ghost(density: ButtonDensity.compact),
                        onPressed: () => _run(device.setHeartRateMode, 'setHeartRateMode'),
                        child: Text(l.headwindUseFanHeartRateMode, style: TextStyle(color: bkAccentText(context))),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _stepper({
    required int value,
    required int step,
    required int min,
    required int max,
    required String unit,
    required ValueChanged<int> onChanged,
  }) => StepperControl(
    value: value.toDouble(),
    step: step.toDouble(),
    min: min.toDouble(),
    max: max.toDouble(),
    format: (v) => '${v.round()} $unit',
    onChanged: (v) => onChanged(v.round()),
  );
}

/// The fan's speed as the section's one loud number, and what sets it.
class _FanReadout extends StatelessWidget {
  const _FanReadout({required this.speed, required this.caption});

  /// Null when the fan isn't in a mode that reports one.
  final int? speed;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = (context.typography.x2Large.fontSize ?? 24) * 2;
    final speed = this.speed;
    return Semantics(
      container: true,
      label: [if (speed != null) '$speed%', ?caption].join(', '),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Sized for "100%" so the caption never shifts as the fan moves.
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: size * 1.7),
              child: Text(
                speed == null ? '–' : '$speed%',
                key: const ValueKey('headwind-speed-readout'),
                style: BkNumerals.display(
                  size,
                  color: speed == null ? cs.mutedForeground : cs.foreground,
                  fontWeight: FontWeight.w800,
                  height: 0.9,
                ),
              ),
            ),
            if (caption != null) ...[
              const Gap(12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(caption!, key: const ValueKey('headwind-caption')).small.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A segmented track in the SIM/ERG style (DESIGN.md "SIM / ERG control"):
/// a Fill track, the chosen segment in brand blue. Segments share the width.
class _Segments<T> extends StatelessWidget {
  const _Segments({
    super.key,
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final T? selected;
  final List<(T, String, Key)> options;
  final ValueChanged<T> onSelected;

  static bool get _touch =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = context.typography.small.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3);
    return Semantics(
      label: label,
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: _touch ? BkTouchTarget.minSize + 4 : 36,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (value, text, key) in options)
              Expanded(
                child: BkTappable(
                  key: key,
                  onPressed: () {
                    if (value == selected) return;
                    HapticFeedback.selectionClick();
                    onSelected(value);
                  },
                  label: text,
                  selected: value == selected,
                  inMutuallyExclusiveGroup: true,
                  excludeChildSemantics: true,
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: BkMotion.of(context),
                    curve: BkMotion.curve,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: value == selected ? cs.primary : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        text,
                        maxLines: 1,
                        style: style.copyWith(
                          color: value == selected ? cs.primaryForeground : cs.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
