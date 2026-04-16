import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TrainerSettingsSection extends StatefulWidget {
  final FitnessBikeDefinition definition;
  const TrainerSettingsSection({super.key, required this.definition});

  @override
  State<TrainerSettingsSection> createState() => _TrainerSettingsSectionState();
}

class _TrainerSettingsSectionState extends State<TrainerSettingsSection> {
  FitnessBikeDefinition get def => widget.definition;

  @override
  void initState() {
    super.initState();
    // Hydrate definition defaults from persisted settings.
    def.setBicycleWeightKg(core.settings.getProxyBikeWeightKg());
    def.setRiderWeightKg(core.settings.getProxyRiderWeightKg());
    def.setGradeSmoothingEnabled(core.settings.getProxyGradeSmoothing());
    def.setVirtualShiftingMode(core.settings.getProxyVirtualShiftingMode());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _vsModeCard(),
        _bikeWeightCard(),
        _riderWeightCard(),
        _gradeSmoothingCard(),
        _gearRatiosCard(),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.border),
        ),
        child: child,
      );

  Widget _vsModeCard() {
    return ValueListenableBuilder<VirtualShiftingMode>(
      valueListenable: def.virtualShiftingMode,
      builder: (context, mode, _) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            _labelBlock(
              title: 'Virtual Shifting Mode',
              subtitle: 'How resistance is computed per gear',
            ),
            RadioGroup<VirtualShiftingMode>(
              value: mode,
              onChanged: (v) async {
                def.setVirtualShiftingMode(v);
                await core.settings.setProxyVirtualShiftingMode(v);
              },
              child: Row(
                spacing: 6,
                children: [
                  _vsRadioCard('Target Power', VirtualShiftingMode.targetPower),
                  _vsRadioCard('Track Resist.', VirtualShiftingMode.trackResistance),
                  _vsRadioCard('Basic', VirtualShiftingMode.basicResistance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vsRadioCard(String label, VirtualShiftingMode value) {
    return Expanded(
      child: RadioCard<VirtualShiftingMode>(
        value: value,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _bikeWeightCard() {
    return ValueListenableBuilder<double>(
      valueListenable: def.bicycleWeightKg,
      builder: (context, kg, _) => _card(
        child: Row(
          children: [
            Icon(LucideIcons.bike, size: 18),
            const Gap(12),
            Expanded(
              child: _labelBlock(
                title: 'Bike Weight',
                subtitle: 'Used for virtual shifting physics',
              ),
            ),
            StepperControl(
              value: kg,
              step: 0.5,
              min: 1.0,
              max: 50.0,
              format: (v) => '${v.toStringAsFixed(1)} kg',
              onChanged: (v) async {
                def.setBicycleWeightKg(v);
                await core.settings.setProxyBikeWeightKg(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _riderWeightCard() {
    return ValueListenableBuilder<double>(
      valueListenable: def.riderWeightKg,
      builder: (context, kg, _) => _card(
        child: Row(
          children: [
            Icon(LucideIcons.user, size: 18),
            const Gap(12),
            Expanded(
              child: _labelBlock(
                title: 'Rider Weight',
                subtitle: 'Used for virtual shifting physics',
              ),
            ),
            StepperControl(
              value: kg,
              step: 1.0,
              min: 20.0,
              max: 200.0,
              format: (v) => '${v.toStringAsFixed(0)} kg',
              onChanged: (v) async {
                def.setRiderWeightKg(v);
                await core.settings.setProxyRiderWeightKg(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradeSmoothingCard() {
    return ValueListenableBuilder<bool>(
      valueListenable: def.gradeSmoothingEnabled,
      builder: (context, enabled, _) => _card(
        child: Row(
          children: [
            Icon(LucideIcons.waves, size: 18),
            const Gap(12),
            Expanded(
              child: _labelBlock(
                title: 'Grade Smoothing',
                subtitle: 'Averages sudden slope changes',
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (v) async {
                def.setGradeSmoothingEnabled(v);
                await core.settings.setProxyGradeSmoothing(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _gearRatiosCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            children: [
              Icon(LucideIcons.cog, size: 18),
              const Gap(12),
              Expanded(
                child: _labelBlock(
                  title: 'Gear Ratios',
                  subtitle: '24-step virtual shifter table',
                ),
              ),
              Button.ghost(
                onPressed: () => context.push(GearRatiosEditorPage(definition: def)),
                trailing: const Icon(LucideIcons.chevronRight, size: 14),
                child: const Text('Customize'),
              ),
            ],
          ),
          GearRatioCurve(definition: def),
        ],
      ),
    );
  }

  Widget _labelBlock({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}
