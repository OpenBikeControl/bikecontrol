import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The "Virtual front derailleur" setting: an enable toggle plus small/large
/// chainring steppers and the resulting ratio factor. Persists to the active
/// [ShiftingConfig] for [device] AND applies to the live [definition] so the
/// change takes effect immediately (mirroring the other cards on this page —
/// otherwise the gear settings only apply after a reconnect/mode-switch).
class FrontShiftCard extends StatelessWidget {
  const FrontShiftCard({super.key, required this.device, required this.definition});

  final ProxyDevice device;
  final FitnessBikeDefinition definition;

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
          definition.setFrontShiftEnabled(v);
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
                      // Keep small <= large: the large ring must stay the bigger
                      // (harder) one, else the front shift inverts or no-ops.
                      max: large.toDouble(),
                      format: (v) => v.toStringAsFixed(0),
                      onChanged: (v) async {
                        final next = v.toInt();
                        definition.setChainringTeeth(next, large);
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
                        definition.setChainringTeeth(small, next);
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
