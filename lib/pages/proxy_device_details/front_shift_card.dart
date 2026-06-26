import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The "Virtual front derailleur" setting: an enable toggle plus small/large
/// chainring steppers and the resulting ratio factor. Reads and writes the
/// active [ShiftingConfig] for [device].
class FrontShiftCard extends StatelessWidget {
  const FrontShiftCard({super.key, required this.device});

  final ProxyDevice device;

  Future<void> _update(ShiftingConfig Function(ShiftingConfig) mutate) async {
    final current = core.shiftingConfigs.activeFor(device.trainerKey);
    await core.shiftingConfigs.upsert(mutate(current));
  }

  @override
  Widget build(BuildContext context) {
    final config = core.shiftingConfigs.activeFor(device.trainerKey);
    final enabled = config.frontShiftEnabled;
    final small = config.smallChainringTeeth;
    final large = config.largeChainringTeeth;
    final factor = large / small;
    final cs = Theme.of(context).colorScheme;
    return SettingTile(
      icon: LucideIcons.bike,
      title: AppLocalizations.of(context).frontShiftEnableLabel,
      subtitle: AppLocalizations.of(context).frontShiftEnableDesc,
      trailing: Switch(
        value: enabled,
        onChanged: (v) async {
          await _update((c) => c.copyWith(frontShiftEnabled: v));
        },
      ),
      child: enabled
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).frontShiftSmallRingLabel,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    StepperControl(
                      value: small.toDouble(),
                      step: 1.0,
                      min: ShiftingConfig.chainringTeethMin.toDouble(),
                      max: ShiftingConfig.chainringTeethMax.toDouble(),
                      format: (v) => v.toStringAsFixed(0),
                      onChanged: (v) async {
                        final next = v.toInt();
                        await _update((c) => c.copyWith(smallChainringTeeth: next));
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).frontShiftLargeRingLabel,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    StepperControl(
                      value: large.toDouble(),
                      step: 1.0,
                      min: small.toDouble(),
                      max: ShiftingConfig.chainringTeethMax.toDouble(),
                      format: (v) => v.toStringAsFixed(0),
                      onChanged: (v) async {
                        final next = v.toInt();
                        await _update((c) => c.copyWith(largeChainringTeeth: next));
                      },
                    ),
                  ],
                ),
                Text(
                  '${factor.toStringAsFixed(2)}×',
                  style: TextStyle(fontSize: 12, color: cs.mutedForeground),
                  textAlign: TextAlign.end,
                ),
              ],
            )
          : null,
    );
  }
}
