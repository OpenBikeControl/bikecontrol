import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_sensor_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/pages/proxy_device_details/live_metrics_section.dart';
import 'package:bike_control/services/sensors/broadcast_controller.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The no-trainer path's own page: the Broadcast switch, the transport choice
/// and the signals grid behind the Sensors chain card.
///
/// Same scaffold shape as `ProxyDeviceDetailsPage`, so a rider moving between
/// a trainer's page and this one meets the same header in the same place.
/// The consequence (Broadcast) sits directly above its cause (the sources
/// picked in the grid) — spec Decision 7 — and speaks the home screen's
/// status vocabulary (tile + Ampel + status line) so the card reads like the
/// chain card that opened it.
class SensorsPage extends StatefulWidget {
  const SensorsPage({super.key});

  @override
  State<SensorsPage> createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage> {
  late final StreamSubscription<BaseDevice> _connectionSub;

  /// The exact controller this state subscribed to, so [dispose] unhooks
  /// from the SAME instance even if `core.connection.broadcast` is swapped
  /// meanwhile (tests reassign it per case; production never does).
  BroadcastController? _broadcast;

  @override
  void initState() {
    super.initState();
    _broadcast = core.connection.broadcast;
    _broadcast?.isOn.addListener(_rebuild);
    _broadcast?.transport.addListener(_rebuild);
    core.connection.standaloneClientConnected.addListener(_rebuild);
    // The switch is enabled iff anything is selected — the grid below is
    // where that changes, and it rebuilds only itself.
    core.sensors.selectionVersion.addListener(_rebuild);
    // Nearby straps appearing/vanishing decide whether the empty panel shows
    // — same trigger the grid uses for its candidate lists.
    _connectionSub = core.connection.connectionStream.listen((_) => _rebuild());
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connectionSub.cancel();
    core.sensors.selectionVersion.removeListener(_rebuild);
    core.connection.standaloneClientConnected.removeListener(_rebuild);
    _broadcast?.transport.removeListener(_rebuild);
    _broadcast?.isOn.removeListener(_rebuild);
    super.dispose();
  }

  bool get _isOn => _broadcast?.isOn.value ?? false;
  bool get _hasSelection => _broadcast?.selectedSourceIds.isNotEmpty ?? false;

  /// "Nothing to pick from at all": no source registered with the hub, no
  /// strap in BLE range, and no Apple Health on this platform. The grid
  /// renders its tiles regardless; this decides whether the "Looking for
  /// sensors…" panel sits above them.
  bool get _noCandidates =>
      core.sensors.sources.isEmpty &&
      core.connection.devices.whereType<BleSensorDevice>().isEmpty &&
      core.connection.healthKitSource == null;

  /// The switch's tap. ON is Pro-gated ahead of everything else — the same
  /// gate the grid's selection uses — then hands to the controller, which
  /// connects every selected source and rolls back on failure so the switch
  /// never lies (spec, Error handling). The controller records the error
  /// itself; this site only explains it to the rider.
  Future<void> _setBroadcast(bool on) async {
    final broadcast = _broadcast;
    if (broadcast == null) return;
    if (!on) {
      try {
        await broadcast.turnOff();
      } catch (e, s) {
        await recordError(e, s, context: 'SensorsPage.turnOff');
      }
      return;
    }
    if (!IAPManager.instance.isProEnabledForCurrentDevice) {
      final granted = await IAPManager.instance.ensureProForFeature(
        context,
        featureName: AppLocalizations.current.sensorsBroadcastTitle,
      );
      if (!granted) {
        // Nothing changed — snap the switch back to the controller's state.
        _rebuild();
        return;
      }
    }
    try {
      await broadcast.turnOn();
    } catch (e, s) {
      // Already recorded (with the original stack) inside `turnOn`; recorded
      // again here so this catch is never a silent one, and the rider gets
      // told.
      await recordError(e, s, context: 'SensorsPage.turnOn');
      if (!mounted) return;
      buildToast(level: LogLevel.LOGLEVEL_WARNING, title: AppLocalizations.of(context).sensorConnectFailed);
      _rebuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.i18n;
    final isOn = _isOn;
    final hasSelection = _hasSelection;

    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(
            l10n.sensorsPageTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          backgroundColor: theme.colorScheme.background,
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BroadcastCard(
                  isOn: isOn,
                  hasSelection: hasSelection,
                  clientName: core.connection.standaloneClientName,
                  transport: _broadcast?.transport.value ?? RetrofitMode.bluetooth,
                  onChanged: _setBroadcast,
                  onTransport: (mode) => _broadcast?.setTransport(mode),
                ),
                const Gap(18),
                _SectionHeader(l10n.sensorsSignalsHeader),
                const Gap(8),
                if (_noCandidates) ...[
                  const _EmptyPanel(key: Key('sensors-empty')),
                  const Gap(10),
                ],
                const LiveMetricsSection(device: null),
                if (!isOn && hasSelection) ...[
                  const Gap(12),
                  Text(
                    l10n.sensorsOffHint,
                    key: const Key('sensors-off-hint'),
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: theme.colorScheme.mutedForeground),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Broadcast card: radio tile with Ampel, eyebrow, title, status line and
/// the switch; below, the Bluetooth / Network choice with one line of
/// explanation for whichever is picked.
class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({
    required this.isOn,
    required this.hasSelection,
    required this.clientName,
    required this.transport,
    required this.onChanged,
    required this.onTransport,
  });

  final bool isOn;
  final bool hasSelection;
  final String? clientName;
  final RetrofitMode transport;
  final ValueChanged<bool> onChanged;
  final ValueChanged<RetrofitMode> onTransport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.i18n;
    final status = isOn ? LinkStatus.ready : LinkStatus.off;
    final client = clientName;

    return Card(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TileWithAmpel(
                status: status,
                pulse: isOn,
                child: Icon(LucideIcons.radio, size: 22, color: theme.colorScheme.foreground),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.sensorsBroadcastEyebrow.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                    Text(
                      l10n.sensorsBroadcastTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    StatusLine(
                      status: status,
                      label: !hasSelection
                          ? l10n.sensorsBroadcastPickSource
                          : isOn
                          ? l10n.sensorsBroadcastLive
                          : l10n.sensorsStatusOff,
                      meta: isOn && client != null ? l10n.sensorsClientConnected(client) : null,
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Switch(
                key: const Key('sensors-broadcast-switch'),
                value: isOn,
                enabled: hasSelection,
                onChanged: hasSelection ? onChanged : null,
              ),
            ],
          ),
          const Gap(12),
          _TransportControl(transport: transport, onChanged: onTransport),
          const Gap(10),
          Text(
            switch (transport) {
              RetrofitMode.wifi => l10n.sensorsTransportNetworkHint,
              _ => l10n.sensorsTransportBluetoothHint,
            },
            style: TextStyle(fontSize: 12.5, height: 1.4, color: theme.colorScheme.mutedForeground),
          ),
        ],
      ),
    );
  }
}

/// Two-segment Bluetooth / Network control: a muted track with the chosen
/// segment lifted onto the card surface.
class _TransportControl extends StatelessWidget {
  const _TransportControl({required this.transport, required this.onChanged});

  final RetrofitMode transport;
  final ValueChanged<RetrofitMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.i18n;

    Widget segment({required Key key, required RetrofitMode mode, required IconData icon, required String label}) {
      final selected = transport == mode;
      return Expanded(
        child: SelectedButton(
          key: key,
          value: selected,
          onChanged: (_) => onChanged(mode),
          style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7)),
          // The chosen segment lifts onto the card surface — a white pill on
          // the muted track, the same picture the design kit draws.
          selectedStyle: ButtonStyle.ghost()
              .withPadding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7))
              .withBorderRadius(borderRadius: BorderRadius.circular(8))
              .withBackgroundColor(color: theme.colorScheme.card, hoverColor: theme.colorScheme.card),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground),
              const Gap(6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: theme.colorScheme.muted, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          segment(
            key: const Key('sensors-transport-bluetooth'),
            mode: RetrofitMode.bluetooth,
            icon: LucideIcons.bluetooth,
            label: l10n.sensorsTransportBluetooth,
          ),
          const Gap(3),
          segment(
            key: const Key('sensors-transport-network'),
            mode: RetrofitMode.wifi,
            icon: LucideIcons.wifi,
            label: l10n.sensorsTransportNetwork,
          ),
        ],
      ),
    );
  }
}

/// SIGNALS — the same small-caps header the grid's source lists wear.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.mutedForeground,
        ),
      ),
    );
  }
}

/// "Looking for sensors…" — shown above the grid while there is nothing to
/// pick from at all. Dashed, like the home chain's optional card at rest: a
/// slot that will fill itself, not a problem.
class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.i18n;

    return DashedContainer(
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.mutedForeground.withAlpha(110),
      strokeWidth: 5,
      gap: 4,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: theme.colorScheme.muted, borderRadius: BorderRadius.circular(10)),
              child: Icon(LucideIcons.bluetooth, size: 17, color: theme.colorScheme.mutedForeground),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.sensorsEmptyTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const Gap(3),
                  Text(
                    l10n.sensorsEmptyBody,
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: theme.colorScheme.mutedForeground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
