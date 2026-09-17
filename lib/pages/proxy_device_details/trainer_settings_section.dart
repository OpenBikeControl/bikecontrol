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

  /// Test seam: the connection cycle a protocol change triggers; defaults to
  /// [ProxyDevice.reconnectUpstream].
  final Future<void> Function()? reconnectDevice;

  const TrainerSettingsSection({super.key, required this.definition, required this.device, this.reconnectDevice});

  @override
  State<TrainerSettingsSection> createState() => _TrainerSettingsSectionState();
}

class _TrainerSettingsSectionState extends State<TrainerSettingsSection> {
  FitnessBikeDefinition get def => widget.definition;

  @override
  void initState() {
    super.initState();
    // After the frame, not during it. Applying the config writes the
    // definition's ValueNotifiers, and anything already built that listens to
    // them — the gear hero and its drivetrain sit above this section — would be
    // marked dirty mid-build, which the framework treats as an error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyActiveConfigToDefinition();
    });
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
    // Listening at the Column rather than around the notice alone: the Column
    // spaces its children, so a hidden notice returning SizedBox.shrink would
    // still leave a 10px gap under the protocol card on every healthy trainer.
    return ValueListenableBuilder<ZwiftGearEchoVerdict?>(
      valueListenable: def.gearEchoVerdict,
      builder: (context, verdict, _) {
        final verdictMessage = _gearEchoMessage(verdict);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            ShiftingConfigPicker(trainerKey: widget.device.trainerKey),
            _gearSettingsCard(),
            _bikeWeightCard(),
            _riderWeightCard(),
            if (def.supportedControlProtocols.length > 1) _controlProtocolCard(),
            if (verdictMessage != null) _gearEchoVerdictNotice(verdict, verdictMessage),
          ],
        );
      },
    );
  }

  /// The watchdog's verdict, for the two outcomes that leave the rider stuck.
  ///
  /// A trainer that takes native gear commands and acknowledges none of them
  /// is moved to FTMS by the definition — unless the rider forced a protocol
  /// by hand, which it deliberately leaves alone. That is the right call and
  /// the wrong silence: it pins them to a wire the trainer ignores, and until
  /// this notice the only trace was one line in the support log. A beta tester
  /// found it by cycling transports at random. [fellBackToFtms] is not shown:
  /// it already fixed itself and needs nothing from the rider.
  String? _gearEchoMessage(ZwiftGearEchoVerdict? verdict) => switch (verdict) {
    ZwiftGearEchoVerdict.riderOverrideKept => context.i18n.controlProtocolIgnored,
    ZwiftGearEchoVerdict.noFtmsToFallBackTo => context.i18n.controlProtocolIgnoredNoFallback,
    ZwiftGearEchoVerdict.fellBackToFtms || null => null,
  };

  Widget _gearEchoVerdictNotice(ZwiftGearEchoVerdict? verdict, String message) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.destructive),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Icon(LucideIcons.triangleAlert, size: 15, color: cs.destructive),
              Expanded(
                child: Text(message, style: TextStyle(fontSize: 12, color: cs.destructive)),
              ),
            ],
          ),
          // Only where there is something to undo: with no protocol to fall
          // back to, clearing the override would change nothing.
          if (verdict == ZwiftGearEchoVerdict.riderOverrideKept)
            Button.outline(
              onPressed: _clearProtocolOverride,
              child: Text(context.i18n.controlProtocolUseAuto),
            ),
        ],
      ),
    );
  }

  /// Hands the trainer back to auto-detection, which is what the rider wanted
  /// when they picked a protocol by hand — a wire that works. Mirrors the
  /// select's own onChanged, reconnect included: the trainer latches its
  /// control session at connect time.
  Future<void> _clearProtocolOverride() async {
    final before = def.controlProtocol;
    def.setControlProtocolOverride(null);
    await core.settings.setControlProtocolOverride(widget.device.trainerKey, null);
    if (mounted) setState(() {});
    if (def.controlProtocol != before) {
      await (widget.reconnectDevice ?? widget.device.reconnectUpstream)();
    }
  }

  /// Escape hatch for trainers auto-detection talks to over the wrong wire.
  /// Only rendered when the trainer advertises more than one delivery it can
  /// actually carry — with a single option there is nothing to choose, and
  /// offering the others would hand the rider a path where every write dies.
  ///
  /// On a Zwift-Sync trainer, explicitly picking "Zwift protocol" resolves to
  /// the same delivery as Auto. That inert choice is deliberate: the list is
  /// the supported set, unfiltered, so the rider can always see and re-pick
  /// what they are on.
  Widget _controlProtocolCard() {
    return SettingTile(
      icon: LucideIcons.radio,
      title: context.i18n.controlProtocolLabel,
      subtitle: context.i18n.controlProtocolHint,
      // Full width in the child slot rather than the trailing slot the
      // switches and steppers use: "Auto (recommended)" is ~23 characters in
      // German and would overflow the row on a narrow phone.
      child: Select<TrainerControlProtocol?>(
        value: def.controlProtocolOverride,
        popup: SelectPopup(
          items: SelectItemList(
            children: [
              SelectItemButton<TrainerControlProtocol?>(
                value: null,
                child: Text(context.i18n.controlProtocolAuto),
              ),
              for (final protocol in def.supportedControlProtocols)
                SelectItemButton<TrainerControlProtocol?>(
                  value: protocol,
                  child: Text(_protocolLabel(protocol)),
                ),
            ],
          ),
        ).call,
        itemBuilder: (c, protocol) =>
            Text(protocol == null ? context.i18n.controlProtocolAuto : _protocolLabel(protocol)),
        placeholder: Text(context.i18n.controlProtocolAuto),
        onChanged: (protocol) async {
          final before = def.controlProtocol;
          def.setControlProtocolOverride(protocol);
          await core.settings.setControlProtocolOverride(widget.device.trainerKey, protocol?.name);
          // The override is plain state on the definition, not a listenable —
          // nothing else would repaint the select with the new value.
          if (mounted) setState(() {});
          // The trainer latches its control session to the protocol that was
          // live at connect time, so an effective change only takes hold on a
          // fresh connection — cycle the bridge like the ConnectionCard's
          // manual disconnect/reconnect would. Inert picks (same effective
          // delivery, e.g. forcing zwiftHub on an auto-zwiftHub trainer)
          // skip the cycle.
          if (def.controlProtocol != before) {
            await (widget.reconnectDevice ?? widget.device.reconnectUpstream)();
          }
        },
      ),
    );
  }

  String _protocolLabel(TrainerControlProtocol protocol) => switch (protocol) {
    TrainerControlProtocol.ftms => context.i18n.controlProtocolFtms,
    TrainerControlProtocol.fec => context.i18n.controlProtocolFec,
    TrainerControlProtocol.zwiftHub => context.i18n.controlProtocolZwift,
  };

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
