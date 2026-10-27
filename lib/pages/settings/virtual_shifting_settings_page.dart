import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/self_test_card.dart';
import 'package:bike_control/pages/proxy_device_details/self_test_page.dart';
import 'package:bike_control/services/trainer_self_test/self_test_result.dart';
import 'package:bike_control/pages/proxy_device_details/vs_calibration_page.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/proxy_device_details/shifting_config_picker.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/utils/units.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';

/// Opens the resistance self-test page for [device].
///
/// The way in for everything that offers "run the self-test" (the "Check and
/// calibrate" row below, the support intake, the setup guide's done step). A
/// trainer with no virtual-shifting definition has no self-test to run, so it
/// lands on the trainer's own page, where the connection is.
Future<void> openTrainerSelfTest(BuildContext context, ProxyDevice device) async {
  if (device.fitnessBike == null) {
    await context.push(ProxyDeviceDetailsPage(device: device));
    return;
  }
  await context.push(SelfTestPage(device: device));
}

/// "24 gears · Smoothing on · Custom ratios": what the Settings row says about
/// the trainer's active shifting config.
String virtualShiftingSummary(BuildContext context, FitnessBikeDefinition definition, ProxyDevice device) {
  final l10n = AppLocalizations.of(context);
  final hasCustomRatios = core.shiftingConfigs.activeFor(device.trainerKey).gearRatios != null;
  return [
    l10n.gearsCount(definition.gearRatios.value.length),
    definition.gradeSmoothingEnabled.value ? l10n.smoothingOn : l10n.smoothingOff,
    if (hasCustomRatios) l10n.customRatios,
  ].join(' · ');
}

/// The name of [mode], as the mode picker shows it.
String virtualShiftingModeLabel(AppLocalizations l10n, VirtualShiftingMode mode) => switch (mode) {
  VirtualShiftingMode.targetPower => l10n.targetPowerMode,
  VirtualShiftingMode.trackResistance => l10n.trackResistanceMode,
  VirtualShiftingMode.basicResistance => l10n.basicMode,
};

/// Ride's short form of the summary: the gear count and how the trainer
/// shifts — "24 gears · Track Resistance".
String rideVirtualShiftingSummary(BuildContext context, FitnessBikeDefinition definition) {
  final l10n = AppLocalizations.of(context);
  return [
    l10n.gearsCount(definition.gearRatios.value.length),
    virtualShiftingModeLabel(l10n, definition.virtualShiftingMode.value),
  ].join(' · ');
}

/// Settings → Virtual shifting: how the bridged trainer shifts.
///
/// Shifting config and mode first; then the live drivetrain, directly above
/// Gears, so a change to the gear count, the front derailleur or a preset
/// plays out in view; then the Gears group (ratio curve, presets, gear count,
/// front derailleur, smoothing, cadence filter, and the per-gear steppers one
/// screen deeper) and Physics. Everything applies to the trainer's active
/// shifting config and to the live definition at once.
///
/// Last, "Check and calibrate": the resistance self-test and, right under it,
/// the shifting calibrator, two rows that each open their own page. Both are
/// about how this trainer shifts, so they sit at the end of its shifting
/// settings rather than on its hardware page.
class VirtualShiftingSettingsPage extends StatefulWidget {
  const VirtualShiftingSettingsPage({
    super.key,
    required this.definition,
    required this.device,
  });

  /// The definition the page was opened for. A reconnect (the self-test's
  /// protocol switch causes one) rebuilds it; the page then follows
  /// [ProxyDevice.fitnessBike].
  final FitnessBikeDefinition definition;
  final ProxyDevice device;

  @override
  State<VirtualShiftingSettingsPage> createState() => _VirtualShiftingSettingsPageState();
}

class _VirtualShiftingSettingsPageState extends State<VirtualShiftingSettingsPage> {
  FitnessBikeDefinition get def => widget.device.fitnessBike ?? widget.definition;

  late final StreamSubscription<BaseDevice> _connectionSub;

  @override
  void initState() {
    super.initState();
    // A (dis)connect changes what the prechecks say and, after a reconnect,
    // which definition the settings drive.
    _connectionSub = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
    widget.device.isConnectedListenable.addListener(_onDeviceChanged);
    // After the frame, not during it. Applying the config writes the
    // definition's ValueNotifiers, and the drivetrain above the settings
    // listens to them — marking it dirty mid-build is an error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyActiveConfigToDefinition();
    });
    core.shiftingConfigs.addListener(_onConfigsChanged);
  }

  @override
  void dispose() {
    _connectionSub.cancel();
    widget.device.isConnectedListenable.removeListener(_onDeviceChanged);
    core.shiftingConfigs.removeListener(_onConfigsChanged);
    super.dispose();
  }

  void _onDeviceChanged() {
    if (mounted) setState(() {});
  }

  /// Back from a test, the row shows its result.
  Future<void> _openSelfTest() async {
    await openTrainerSelfTest(context, widget.device);
    if (mounted) setState(() {});
  }

  Future<void> _openCalibrator() async {
    await context.push(VsCalibrationPage(device: widget.device));
    if (mounted) setState(() {});
  }

  /// A config picked, created or edited: the trainer follows it.
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
    def.setCadenceFilterEnabled(cfg.cadenceFilterEnabled);
    def.setDifficultyPct(cfg.difficultyPct);
    def.setRealChainRatio(cfg.realChainRatio);
    def.setVirtualShiftingMode(cfg.mode);
    // The front derailleur belongs to the config too: picking another config
    // brings its rings with it, and the drivetrain above draws them.
    def.setChainringTeeth(cfg.smallChainringTeeth, cfg.largeChainringTeeth);
    def.setFrontShiftEnabled(cfg.frontShiftEnabled);
    def.setGearRatios(cfg.gearRatios ?? FitnessBikeDefinition.defaultGearRatiosFor(def.maxGear));
  }

  Future<void> _update(ShiftingConfig Function(ShiftingConfig) mutate) =>
      updateActiveShiftingConfig(widget.device, mutate);

  /// Reset wipes the rider's own gears for good: ask first.
  Future<void> _confirmReset() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.vsResetTitle),
        content: Text(l10n.vsResetBody),
        actions: [
          Button.outline(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
          Button.destructive(
            key: const ValueKey('vs-reset-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _reset();
  }

  /// Back to the trainer app's gear count, smoothing on, the stock curve and
  /// the default difficulty (the calibrator's result is part of the feel).
  Future<void> _reset() async {
    final app = core.settings.getTrainerApp();
    final targetMaxGear = app?.virtualGearAmount ?? ShiftingConfig.maxGearDefault;
    def.setMaxGear(targetMaxGear);
    def.setGradeSmoothingEnabled(true);
    def.resetGearRatios();
    def.setDifficultyPct(FitnessBikeDefinition.defaultDifficultyPct);
    await _update(
      (c) => c.copyWith(
        maxGear: targetMaxGear,
        gradeSmoothing: true,
        clearGearRatios: true,
        difficultyPct: FitnessBikeDefinition.defaultDifficultyPct,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      headers: [
        BkPageHeader(
          title: l10n.rideVirtualShifting,
          actions: [
            Button.ghost(
              key: const ValueKey('vs-reset'),
              onPressed: _confirmReset,
              child: Text(
                l10n.reset,
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: BkPageColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BkGroupedSection.inset),
                child: Text(
                  l10n.tuneGearsIntro,
                  style: context.typography.small.copyWith(color: cs.mutedForeground),
                ),
              ),
              const Gap(20),
              _shiftingConfig(context),
              const Gap(12),
              VirtualShiftingModeCard(definition: def, device: widget.device),
              const Gap(24),
              _drivetrain(context),
              const Gap(20),
              _gears(context),
              // A smart bike has no chain.
              if (!def.isSmartBike) ...[
                const Gap(24),
                _realChain(context),
              ],
              const Gap(24),
              _physics(context),
              if (!screenshotMode) ...[
                const Gap(24),
                _checkAndCalibrate(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The configs are saved per trainer, so the trainer names the group.
  Widget _shiftingConfig(BuildContext context) {
    return BkGroupedSection(
      header: widget.device.toString(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: ShiftingConfigPicker(trainerKey: widget.device.trainerKey),
        ),
      ],
    );
  }

  /// The live drivetrain with −/+ and the chainring toggle, right above the
  /// settings that change it.
  Widget _drivetrain(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('vs-drivetrain'),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        boxShadow: bkCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.device.isConnected ? BkStatusColors.of(context).success : cs.mutedForeground,
                  shape: BoxShape.circle,
                ),
              ),
              const Gap(6),
              Expanded(
                child: Text(
                  widget.device.toString().toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.caption.copyWith(
                    color: cs.mutedForeground,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const Gap(4),
          DrivetrainControls(definition: def),
        ],
      ),
    );
  }

  Widget _gears(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BkGroupedSection(
      key: const ValueKey('vs-gears'),
      header: l10n.vsGroupGears,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GearRatioCurve(definition: def),
              const Gap(14),
              GearRatioPresetChips(definition: def, device: widget.device),
            ],
          ),
        ),
        GearCountRow(definition: def, device: widget.device),
        _frontDerailleur(context),
        ValueListenableBuilder<bool>(
          valueListenable: def.gradeSmoothingEnabled,
          builder: (context, enabled, _) => _switchRow(
            icon: LucideIcons.waves,
            title: l10n.gradeSmoothing,
            subtitle: l10n.gradeSmoothingDesc,
            value: enabled,
            onChanged: (v) async {
              def.setGradeSmoothingEnabled(v);
              await _update((c) => c.copyWith(gradeSmoothing: v));
            },
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: def.cadenceFilterEnabled,
          builder: (context, enabled, _) => _switchRow(
            icon: LucideIcons.filter,
            title: l10n.cadenceFilter,
            subtitle: l10n.cadenceFilterDesc,
            value: enabled,
            onChanged: (v) async {
              def.setCadenceFilterEnabled(v);
              await _update((c) => c.copyWith(cadenceFilterEnabled: v));
            },
          ),
        ),
        ValueListenableBuilder<List<double>>(
          valueListenable: def.gearRatios,
          builder: (context, ratios, _) => BkGroupedRow(
            key: const ValueKey('vs-per-gear'),
            icon: LucideIcons.slidersHorizontal,
            title: l10n.perGearRatiosTitle,
            subtitle: l10n.perGearRatiosSubtitle,
            chevron: true,
            onPressed: () => openPerGearRatios(context, definition: def, device: widget.device),
          ),
        ),
      ],
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return BkGroupedRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
      onPressed: () => onChanged(!value),
    );
  }

  /// The virtual front derailleur: its switch, and the two rings' teeth once
  /// it is on. Turning it on grows the drivetrain above a second ring.
  Widget _frontDerailleur(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    final enabled = config.frontShiftEnabled;
    final small = config.smallChainringTeeth;
    final large = config.largeChainringTeeth;

    Future<void> toggle(bool v) async {
      def.setFrontShiftEnabled(v);
      await _update((c) => c.copyWith(frontShiftEnabled: v));
    }

    Widget teethRow(String label, int value, {required int min, required int max, required ValueChanged<int> set}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          BkGroupedSection.inset + BkIconTile.size + BkGroupedRow.gap,
          4,
          BkGroupedSection.inset,
          4,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.typography.small)),
            StepperControl(
              value: value.toDouble(),
              step: 1.0,
              min: min.toDouble(),
              max: max.toDouble(),
              format: (v) => v.toStringAsFixed(0),
              onChanged: (v) => set(v.toInt()),
            ),
          ],
        ),
      );
    }

    final steppers = enabled
        ? Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Keep small <= large: the large ring must stay the
                // bigger (harder) one, else the front shift inverts.
                teethRow(
                  l10n.frontShiftSmallRingLabel,
                  small,
                  min: ShiftingConfig.chainringTeethMin,
                  max: large,
                  set: (next) async {
                    def.setChainringTeeth(next, large);
                    await _update((c) => c.copyWith(smallChainringTeeth: next));
                  },
                ),
                teethRow(
                  l10n.frontShiftLargeRingLabel,
                  large,
                  min: small,
                  max: ShiftingConfig.chainringTeethMax,
                  set: (next) async {
                    def.setChainringTeeth(small, next);
                    await _update((c) => c.copyWith(largeChainringTeeth: next));
                  },
                ),
              ],
            ),
          )
        : const SizedBox(width: double.infinity);

    return Column(
      key: const ValueKey('vs-front-derailleur'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _switchRow(
          icon: LucideIcons.circleDot,
          title: l10n.frontShiftEnableLabel,
          subtitle: l10n.frontShiftEnableDesc,
          value: enabled,
          onChanged: toggle,
        ),
        // Under reduced motion the steppers are simply there; otherwise they
        // unfold with the drivetrain's second ring.
        if (prefersReducedMotion(context))
          steppers
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: steppers,
          ),
      ],
    );
  }

  /// Where the rider's real chain sits at the trainer. The physics assume
  /// 34/17; a rider who leaves the chain elsewhere (a 39 ring on a 14 Zwift
  /// Cog) sets it here, and every virtual gear feels like its real one.
  Widget _realChain(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final config = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    final chainring = config.realChainringTeeth;
    final cog = config.realCogTeeth;
    final ratio = NumberFormat('0.00', Localizations.localeOf(context).toString()).format(config.realChainRatio);

    Future<void> set({int? chainring, int? cog}) async {
      def.setRealChainRatio(config.copyWith(realChainringTeeth: chainring, realCogTeeth: cog).realChainRatio);
      await _update((c) => c.copyWith(realChainringTeeth: chainring, realCogTeeth: cog));
    }

    Widget teeth(int value, {required int min, required int max, required ValueChanged<int> onChanged}) =>
        StepperControl(
          value: value.toDouble(),
          step: 1.0,
          min: min.toDouble(),
          max: max.toDouble(),
          format: (v) => v.toStringAsFixed(0),
          onChanged: (v) => onChanged(v.toInt()),
        );

    return BkGroupedSection(
      key: const ValueKey('vs-real-chain'),
      header: l10n.vsGroupRealChain,
      footer: l10n.realChainFooter('$chainring/$cog = $ratio'),
      children: [
        BkGroupedRow(
          key: const ValueKey('vs-real-chainring'),
          icon: LucideIcons.circleDot,
          title: l10n.realChainringLabel,
          trailing: teeth(
            chainring,
            min: ShiftingConfig.chainringTeethMin,
            max: ShiftingConfig.chainringTeethMax,
            onChanged: (next) => set(chainring: next),
          ),
        ),
        BkGroupedRow(
          key: const ValueKey('vs-real-cog'),
          icon: LucideIcons.cog,
          title: l10n.realCogLabel,
          trailing: teeth(
            cog,
            min: ShiftingConfig.realCogTeethMin,
            max: ShiftingConfig.realCogTeethMax,
            onChanged: (next) => set(cog: next),
          ),
        ),
      ],
    );
  }

  /// The resistance self-test, and the calibrator right under it: first "does
  /// the trainer obey?", then "does it feel right?". Each row opens its own
  /// page and says where things stand: the last test result, the difficulty.
  Widget _checkAndCalibrate(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final last = SelfTestResult.tryParse(core.settings.getSelfTestResultJson(widget.device.trainerKey));
    return BkGroupedSection(
      key: const ValueKey('vs-check'),
      header: l10n.vsGroupCheck,
      children: [
        BkGroupedRow(
          key: const ValueKey('vs-self-test'),
          icon: LucideIcons.activity,
          title: l10n.selfTestTitle,
          subtitle: last == null
              ? l10n.selfTestStart
              : l10n.selfTestLastResult(SelfTestCard.verdictTitle(l10n, last.verdict)),
          chevron: true,
          onPressed: _openSelfTest,
        ),
        ValueListenableBuilder<int>(
          valueListenable: def.difficultyPct,
          builder: (context, pct, _) => BkGroupedRow(
            key: const ValueKey('vs-calibrate'),
            icon: LucideIcons.gauge,
            title: l10n.vsCalibrateTitle,
            subtitle: l10n.vsCalibrateRowSubtitle(pct),
            chevron: true,
            onPressed: _openCalibrator,
          ),
        ),
      ],
    );
  }

  Widget _physics(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BkGroupedSection(
      key: const ValueKey('vs-physics'),
      header: l10n.vsGroupPhysics,
      footer: l10n.virtualShiftingPhysicsDesc,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: def.bicycleWeightKg,
          builder: (context, kg, _) {
            final units = unitSystemOf(context);
            final isImp = units == UnitSystem.imperial;
            return BkGroupedRow(
              icon: LucideIcons.bike,
              title: l10n.bikeWeight,
              trailing: StepperControl(
                value: units.fromKg(kg),
                step: isImp ? 1.0 : 0.5,
                min: isImp ? 2.0 : 1.0,
                max: isImp ? 110.0 : 50.0,
                format: (v) => '${v.toStringAsFixed(isImp ? 0 : 1)} ${units.weightSymbol}',
                onChanged: (v) async {
                  final kgValue = units.toKgFromDisplay(v);
                  def.setBicycleWeightKg(kgValue);
                  await _update((c) => c.copyWith(bikeWeightKg: kgValue));
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<double>(
          valueListenable: def.riderWeightKg,
          builder: (context, kg, _) {
            final units = unitSystemOf(context);
            final isImp = units == UnitSystem.imperial;
            return BkGroupedRow(
              icon: LucideIcons.user,
              title: l10n.riderWeight,
              trailing: StepperControl(
                value: units.fromKg(kg),
                step: 1.0,
                min: isImp ? 44.0 : 20.0,
                max: isImp ? 440.0 : 200.0,
                format: (v) => '${v.toStringAsFixed(0)} ${units.weightSymbol}',
                onChanged: (v) async {
                  final kgValue = units.toKgFromDisplay(v);
                  def.setRiderWeightKg(kgValue);
                  await _update((c) => c.copyWith(riderWeightKg: kgValue));
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
