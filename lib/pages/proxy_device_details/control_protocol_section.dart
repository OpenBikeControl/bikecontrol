import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// How BikeControl talks to this trainer: the control protocol select (only
/// on trainers that carry more than one) and, under it, the notice when the
/// trainer ignores the gear commands it is sent.
///
/// A property of the trainer's hardware rather than a riding preference, so
/// it sits on the trainer's page next to the self-test that recommends
/// changing it. Builds nothing on a trainer with one protocol and no verdict.
class ControlProtocolSection extends StatefulWidget {
  final FitnessBikeDefinition definition;
  final ProxyDevice device;

  /// Test seam: the connection cycle a protocol change triggers; defaults to
  /// [ProxyDevice.reconnectUpstream].
  final Future<void> Function()? reconnectDevice;

  const ControlProtocolSection({super.key, required this.definition, required this.device, this.reconnectDevice});

  @override
  State<ControlProtocolSection> createState() => _ControlProtocolSectionState();
}

class _ControlProtocolSectionState extends State<ControlProtocolSection> {
  FitnessBikeDefinition get def => widget.definition;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZwiftGearEchoVerdict?>(
      valueListenable: def.gearEchoVerdict,
      builder: (context, verdict, _) {
        final verdictMessage = _gearEchoMessage(verdict);
        final showsSelect = def.supportedControlProtocols.length > 1;
        if (!showsSelect && verdictMessage == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            if (showsSelect) _controlProtocolCard(),
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
                child: Text(message, style: context.typography.xSmall.copyWith(color: cs.destructive)),
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

}
