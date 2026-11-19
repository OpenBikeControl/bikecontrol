import 'dart:math' as math;

import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
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

/// A Headwind's page section: what the fan is set to, its speeds to pick by
/// hand, and whether BikeControl drives it from the power or the heart rate —
/// with the ramp it uses spelled out and adjustable, and the live reading
/// that decides the speed right now.
class HeadwindSection extends StatelessWidget {
  const HeadwindSection({super.key, required this.device});

  final WahooKickrHeadwind device;

  static const double _indent = BkGroupedSection.inset + BkIconTile.size + BkGroupedRow.gap;

  Future<void> _run(Future<void> Function() command, String what) async {
    try {
      await command();
    } catch (e, s) {
      recordError(e, s, context: 'HeadwindSection: $what failed');
    }
  }

  Future<void> _setSpeed(int speed) => _run(() => device.setSpeed(speed), 'setSpeed $speed');

  // Turning a follow off leaves the fan at the speed it has.
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
        final followsPower = follow == HeadwindFollow.power;
        final followsHeartRate = follow == HeadwindFollow.heartRate;
        return BkGroupedSection(
          header: l.headwindFan,
          dividerIndent: _indent,
          children: [
            BkGroupedRow(
              key: const ValueKey('headwind-current'),
              icon: LucideIcons.fan,
              title: l.headwindCurrent,
              subtitle: follow == HeadwindFollow.none && mode == HeadwindMode.heartRate
                  ? l.headwindFanOwnHeartRateMode
                  : null,
              trailing: Text(
                headwindStateText(context, mode, speed, follow: follow),
                style: context.typography.base.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Padding(
              key: const ValueKey('headwind-speeds'),
              padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 8, BkGroupedSection.inset, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Text(l.headwindSetSpeed).small.semiBold,
                  Text(l.headwindSetSpeedBody).xSmall.muted,
                  Row(
                    spacing: 6,
                    children: [
                      for (final s in WahooKickrHeadwind.allowedSpeeds)
                        Expanded(
                          child: _SpeedButton(
                            key: ValueKey('headwind-speed-$s'),
                            label: '$s%',
                            selected: follow == HeadwindFollow.none && mode == HeadwindMode.manual && speed == s,
                            onPressed: () => _setSpeed(s),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            BkGroupedRow(
              key: const ValueKey('headwind-heart-rate'),
              icon: LucideIcons.heart,
              title: l.headwindFollowHeartRate,
              subtitle: l.headwindFollowHeartRateBody,
              trailing: Switch(
                value: followsHeartRate,
                onChanged: (on) => _setFollow(on ? HeadwindFollow.heartRate : HeadwindFollow.none),
              ),
              onPressed: () => _setFollow(followsHeartRate ? HeadwindFollow.none : HeadwindFollow.heartRate),
            ),
            if (followsHeartRate) ...[
              _RampExplainer(
                key: const ValueKey('headwind-heart-rate-ramp'),
                start: '${device.startHeartRate.value} bpm',
                full: '${device.fullHeartRate.value} bpm',
                input: device.followInput.value == null ? null : '${device.followInput.value} bpm',
                speed: speed,
                waiting: l.headwindNoHeartRate,
              ),
              _RampStepperRow(
                key: const ValueKey('headwind-start-heart-rate'),
                icon: LucideIcons.heartPulse,
                title: l.headwindStartsAbove,
                value: device.startHeartRate.value,
                step: 5,
                min: WahooKickrHeadwind.minStartHeartRate,
                max: device.fullHeartRate.value - WahooKickrHeadwind.minHeartRateRamp,
                unit: 'bpm',
                onChanged: (v) => _run(() => device.setStartHeartRate(v), 'setStartHeartRate'),
              ),
              _RampStepperRow(
                key: const ValueKey('headwind-full-heart-rate'),
                icon: LucideIcons.gauge,
                title: l.headwindFullPowerAt,
                value: device.fullHeartRate.value,
                step: 5,
                min: device.startHeartRate.value + WahooKickrHeadwind.minHeartRateRamp,
                max: WahooKickrHeadwind.maxFullHeartRate,
                unit: 'bpm',
                onChanged: (v) => _run(() => device.setFullHeartRate(v), 'setFullHeartRate'),
              ),
            ],
            BkGroupedRow(
              key: const ValueKey('headwind-power'),
              icon: LucideIcons.zap,
              title: l.headwindFollowPower,
              subtitle: l.headwindFollowPowerBody,
              trailing: Switch(
                value: followsPower,
                onChanged: (on) => _setFollow(on ? HeadwindFollow.power : HeadwindFollow.none),
              ),
              onPressed: () => _setFollow(followsPower ? HeadwindFollow.none : HeadwindFollow.power),
            ),
            if (followsPower) ...[
              _RampExplainer(
                key: const ValueKey('headwind-power-ramp'),
                start: '${device.startPowerWatts.value} W',
                full: '${device.fullPowerWatts.value} W',
                input: device.followInput.value == null ? null : '${device.followInput.value} W',
                speed: speed,
                waiting: l.headwindNoPower,
              ),
              _RampStepperRow(
                key: const ValueKey('headwind-start-power'),
                icon: LucideIcons.zap,
                title: l.headwindStartsAbove,
                value: device.startPowerWatts.value,
                step: 25,
                min: WahooKickrHeadwind.minStartPowerWatts,
                max: device.fullPowerWatts.value - WahooKickrHeadwind.minPowerRampWatts,
                unit: 'W',
                onChanged: (v) => _run(() => device.setStartPowerWatts(v), 'setStartPowerWatts'),
              ),
              _RampStepperRow(
                key: const ValueKey('headwind-full-power'),
                icon: LucideIcons.gauge,
                title: l.headwindFullPowerAt,
                value: device.fullPowerWatts.value,
                step: 25,
                min: math.max(
                  WahooKickrHeadwind.minFullPowerWatts,
                  device.startPowerWatts.value + WahooKickrHeadwind.minPowerRampWatts,
                ),
                max: WahooKickrHeadwind.maxFullPowerWatts,
                unit: 'W',
                onChanged: (v) => _run(() => device.setFullPowerWatts(v), 'setFullPowerWatts'),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// How a follow turns its input into a fan speed: the live "142 bpm → 60%",
/// a bar showing where that sits on the ramp, and the rule in one sentence.
class _RampExplainer extends StatelessWidget {
  const _RampExplainer({
    super.key,
    required this.start,
    required this.full,
    required this.input,
    required this.speed,
    required this.waiting,
  });

  final String start;
  final String full;
  final String? input;
  final int speed;
  final String waiting;

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    final cs = Theme.of(context).colorScheme;
    final input = this.input;
    return Padding(
      padding: const EdgeInsets.fromLTRB(HeadwindSection._indent, 4, BkGroupedSection.inset, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          if (input != null)
            Text(
              l.headwindRampNow(input, speed),
              key: const ValueKey('headwind-ramp-now'),
              style: context.typography.small.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            )
          else
            Text(waiting, key: const ValueKey('headwind-ramp-waiting')).xSmall.muted,
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: cs.muted),
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: (speed / 100).clamp(0.0, 1.0),
                    child: ColoredBox(color: cs.primary),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Text(start).xSmall.muted,
              const Spacer(),
              Text(full).xSmall.muted,
            ],
          ),
          Text(l.headwindRampExplain(start, full)).xSmall.muted,
        ],
      ),
    );
  }
}

class _RampStepperRow extends StatelessWidget {
  const _RampStepperRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final int value;
  final int step;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return BkGroupedRow(
      icon: icon,
      title: title,
      trailing: StepperControl(
        value: value.toDouble(),
        step: step.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        format: (v) => '${v.round()} $unit',
        onChanged: (v) => onChanged(v.round()),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({super.key, required this.label, required this.selected, required this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(label, maxLines: 1, softWrap: false);
    return selected
        ? Button.primary(
            onPressed: onPressed,
            child: Center(child: child),
          )
        : Button.outline(
            onPressed: onPressed,
            child: Center(child: child),
          );
  }
}
