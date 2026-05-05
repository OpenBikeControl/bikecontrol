import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/proxy_device_details/shifting_config_picker.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/units.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TrainerSettingsSection extends StatefulWidget {
  final FitnessBikeDefinition definition;
  final ProxyDevice device;
  const TrainerSettingsSection({super.key, required this.definition, required this.device});

  @override
  State<TrainerSettingsSection> createState() => _TrainerSettingsSectionState();
}

class _TrainerSettingsSectionState extends State<TrainerSettingsSection> {
  FitnessBikeDefinition get def => widget.definition;

  @override
  void initState() {
    super.initState();
    _applyActiveConfigToDefinition();
    core.shiftingConfigs.addListener(_onConfigsChanged);
  }

  @override
  void dispose() {
    core.shiftingConfigs.removeListener(_onConfigsChanged);
    super.dispose();
  }

  void _onConfigsChanged() {
    if (!mounted) return;
    _applyActiveConfigToDefinition();
    setState(() {});
  }

  void _applyActiveConfigToDefinition() {
    final cfg = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    def.setMaxGear(cfg.maxGear);
    def.setBicycleWeightKg(cfg.bikeWeightKg);
    def.setRiderWeightKg(cfg.riderWeightKg);
    def.setGradeSmoothingEnabled(cfg.gradeSmoothing);
    def.setVirtualShiftingMode(cfg.mode);
    def.setGearRatios(cfg.gearRatios ?? FitnessBikeDefinition.defaultGearRatiosFor(def.maxGear));
  }

  Future<void> _updateActive(ShiftingConfig Function(ShiftingConfig) mutate) async {
    final current = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    await core.shiftingConfigs.upsert(mutate(current));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        ShiftingConfigPicker(trainerKey: widget.device.trainerKey),
        _gearSettingsCard(),
        _bikeWeightCard(),
        _riderWeightCard(),
      ],
    );
  }

  Widget _bikeWeightCard() {
    return ValueListenableBuilder<double>(
      valueListenable: def.bicycleWeightKg,
      builder: (context, kg, _) {
        final units = unitSystemOf(context);
        final isImp = units == UnitSystem.imperial;
        return SettingTile(
          icon: LucideIcons.bike,
          title: context.i18n.bikeWeight,
          subtitle: context.i18n.virtualShiftingPhysicsDesc,
          trailing: StepperControl(
            value: units.fromKg(kg),
            step: isImp ? 1.0 : 0.5,
            min: isImp ? 2.0 : 1.0,
            max: isImp ? 110.0 : 50.0,
            format: (v) => '${v.toStringAsFixed(isImp ? 0 : 1)} ${units.weightSymbol}',
            onChanged: (v) async {
              final kgValue = units.toKgFromDisplay(v);
              def.setBicycleWeightKg(kgValue);
              await _updateActive((c) => c.copyWith(bikeWeightKg: kgValue));
            },
          ),
        );
      },
    );
  }

  Widget _riderWeightCard() {
    return ValueListenableBuilder<double>(
      valueListenable: def.riderWeightKg,
      builder: (context, kg, _) {
        final units = unitSystemOf(context);
        final isImp = units == UnitSystem.imperial;
        return SettingTile(
          icon: LucideIcons.user,
          title: context.i18n.riderWeight,
          subtitle: context.i18n.virtualShiftingPhysicsDesc,
          trailing: StepperControl(
            value: units.fromKg(kg),
            step: 1.0,
            min: isImp ? 44.0 : 20.0,
            max: isImp ? 440.0 : 200.0,
            format: (v) => '${v.toStringAsFixed(0)} ${units.weightSymbol}',
            onChanged: (v) async {
              final kgValue = units.toKgFromDisplay(v);
              def.setRiderWeightKg(kgValue);
              await _updateActive((c) => c.copyWith(riderWeightKg: kgValue));
            },
          ),
        );
      },
    );
  }

  Widget _gearSettingsCard() {
    return ValueListenableBuilder<List<double>>(
      valueListenable: def.gearRatios,
      builder: (context, ratios, _) => ValueListenableBuilder<bool>(
        valueListenable: def.gradeSmoothingEnabled,
        builder: (context, smoothing, _) {
          final cs = Theme.of(context).colorScheme;
          final hasCustomRatios = core.shiftingConfigs.activeFor(widget.device.trainerKey).gearRatios != null;
          final parts = [
            context.i18n.gearsCount(ratios.length),
            smoothing ? context.i18n.smoothingOn : context.i18n.smoothingOff,
            if (hasCustomRatios) context.i18n.customRatios,
          ];
          return SettingTile(
            icon: LucideIcons.cog,
            title: context.i18n.gearSettings,
            subtitle: parts.join(' · '),
            trailing: Icon(LucideIcons.chevronRight, size: 16, color: cs.mutedForeground),
            onTap: () => context.push(GearRatiosEditorPage(definition: def, device: widget.device)),
            child: GearRatioCurve(definition: def),
          );
        },
      ),
    );
  }
}
