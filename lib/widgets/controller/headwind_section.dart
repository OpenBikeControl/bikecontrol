import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// What the fan is doing right now, in a word or two.
String headwindStateText(BuildContext context, HeadwindMode mode, int speed) {
  final l = context.i18n;
  return switch (mode) {
    HeadwindMode.unknown => '–',
    HeadwindMode.off => l.headwindStateOff,
    HeadwindMode.heartRate => l.headwindStateHeartRate,
    HeadwindMode.speed => l.headwindStateSpeed,
    HeadwindMode.manual => '$speed%',
  };
}

/// A Headwind's page section: what the fan is set to, its speeds to pick by
/// hand, and whether it follows the heart rate — so it can be driven straight
/// from the app, not only from a controller's buttons.
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

  // Leaving heart-rate mode holds the fan at the speed it last had by hand.
  Future<void> _setFollowHeartRate(bool follow) => follow
      ? _run(device.setHeartRateMode, 'setHeartRateMode')
      : _setSpeed(WahooKickrHeadwind.allowedSpeeds.contains(device.speed.value) ? device.speed.value : 0);

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    return ListenableBuilder(
      listenable: Listenable.merge([device.mode, device.speed]),
      builder: (context, _) {
        final mode = device.mode.value;
        final speed = device.speed.value;
        final followsHeartRate = mode == HeadwindMode.heartRate;
        return BkGroupedSection(
          header: l.headwindFan,
          dividerIndent: _indent,
          children: [
            BkGroupedRow(
              key: const ValueKey('headwind-current'),
              icon: LucideIcons.fan,
              title: l.headwindCurrent,
              trailing: Text(
                headwindStateText(context, mode, speed),
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
                            selected: mode == HeadwindMode.manual && speed == s,
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
              trailing: Switch(value: followsHeartRate, onChanged: _setFollowHeartRate),
              onPressed: () => _setFollowHeartRate(!followsHeartRate),
            ),
          ],
        );
      },
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
