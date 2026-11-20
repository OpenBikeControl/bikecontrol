import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_sensor_device.dart';
import 'package:bike_control/pages/proxy_device_details/live_metrics_section.dart' show quantityTitle;
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/pages/sensors/sensors_page.dart';
import 'package:bike_control/services/screen_recording/screen_recording_service.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ignored_devices_dialog.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_switch_row.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Devices section: the setup chain as grouped rows (controllers, the
/// smart trainer or sensors, the trainer app), then sharing sensors, the
/// other ways in (phone steering, media remotes, ignored devices) and any
/// accessories.
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.isMobile, required this.onUpdate, this.reveal});

  final bool isMobile;

  /// Ride's "Show": brings the outstanding rows into view.
  final ChainRevealController? reveal;

  /// Lets the shell refresh Ride after a change here.
  final VoidCallback onUpdate;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  late final StreamSubscription<BaseDevice> _connectionListener;

  @override
  void initState() {
    super.initState();
    _connectionListener = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionListener.cancel();
    super.dispose();
  }

  void _update() {
    widget.onUpdate();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        HomePage(
          view: HomeView.setup,
          isMobile: widget.isMobile,
          showHelpRow: false,
          onUpdate: _update,
          reveal: widget.reveal,
        ),
        // In sensors-only mode the sensors already sit in the trainer's slot.
        if (!core.settings.getSensorsOnlyMode()) ShareSensorsSection(onUpdate: _update),
        OtherInputsSection(onUpdate: _update),
        if (widget.isMobile) Gap(MediaQuery.viewPaddingOf(context).bottom + 8),
      ],
    );
  }
}

/// "Sensors": where heart rate, power and cadence come from — the trainer, or
/// a sensor that replaces its reading. Without a trainer it is also the
/// switch that sends them to the trainer app (Pro), with the live readings
/// riding along while that is on.
class ShareSensorsSection extends StatelessWidget {
  const ShareSensorsSection({super.key, this.onUpdate});

  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final broadcast = core.connection.broadcast;
    final isOn = broadcast?.isOn ?? const _Off();
    final trainer = sensorsTrainer();
    return ValueListenableBuilder<bool>(
      valueListenable: isOn,
      builder: (context, on, _) {
        final quantities = broadcast?.selectedQuantities ?? const <SensorQuantity>{};
        return BkGroupedSection(
          key: const ValueKey('devices-sensors'),
          header: l10n.sensorsChainEyebrow,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BkGroupedRow(
                  key: const ValueKey('devices-share-sensors'),
                  icon: LucideIcons.heartPulse,
                  title: l10n.sensorsPageTitle,
                  subtitle: _summary(context, l10n, trainer),
                  badge: IAPManager.instance.isProEnabledForCurrentDevice ? null : const ProBadge(),
                  // With a trainer there is nothing to switch: the bridge
                  // carries the values.
                  trailing: trainer == null ? Text(on ? l10n.statusOn : l10n.statusOff) : null,
                  chevron: true,
                  onPressed: () async {
                    await context.push(const SensorsPage());
                    onUpdate?.call();
                  },
                ),
                if (trainer == null && on && quantities.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BkGroupedSection.inset + BkIconTile.defaultSize + BkGroupedRow.gap,
                      0,
                      BkGroupedSection.inset,
                      12,
                    ),
                    child: SensorChips(quantities: quantities),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// "From KICKR CORE · Heart rate: Polar H10" — the trainer first, then every
/// value a sensor replaces. Without a trainer just the sensors, or what the
/// row is for while nothing is picked.
String _summary(BuildContext context, AppLocalizations l10n, ProxyDevice? trainer) {
  final replaced = [
    for (final q in const [SensorQuantity.power, SensorQuantity.heartRate, SensorQuantity.cadence])
      if (core.sensors.selectionFor(q) case final id?)
        if (_sourceName(id) case final name?) l10n.sensorsSummaryReplaced(quantityTitle(l10n, q), name),
  ];
  if (trainer != null) return [l10n.sensorsSummaryFrom(trainer.displayName(context)), ...replaced].join(' · ');
  return replaced.isEmpty ? l10n.devicesShareSensorsSubtitle : replaced.join(' · ');
}

/// A picked source's name, whether it is linked yet or only nearby.
String? _sourceName(String id) {
  for (final source in core.sensors.sources) {
    if (source.id == id) return source.displayName;
  }
  for (final device in core.connection.devices.whereType<BleSensorDevice>()) {
    if (device.source.id == id) return device.source.displayName;
  }
  final healthKit = core.connection.healthKitSource;
  return healthKit?.id == id ? healthKit!.displayName : null;
}

class _Off implements ValueListenable<bool> {
  const _Off();

  @override
  bool get value => false;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// The other ways a press gets in: the phone's own motion sensors, Bluetooth
/// media remotes, and the devices the rider told BikeControl to ignore.
class OtherInputsSection extends StatefulWidget {
  const OtherInputsSection({super.key, required this.onUpdate});

  final VoidCallback onUpdate;

  @override
  State<OtherInputsSection> createState() => _OtherInputsSectionState();
}

class _OtherInputsSectionState extends State<OtherInputsSection> {
  bool get _showsMediaKeys => HostPlatform.isMacOS || HostPlatform.isWindows || HostPlatform.isIOS;

  bool get _showsPhoneSteering => HostPlatform.isAndroid || HostPlatform.isIOS;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ignored = core.settings.getIgnoredDevices();
    return ListenableBuilder(
      listenable: Listenable.merge([core.screenRecording.state, core.connection.disconnectedForSession]),
      builder: (context, _) {
        final recording = core.screenRecording.state.value;
        // Controllers disconnected for this session are listed there too,
        // with Reconnect.
        final held = ignored.length + core.connection.disconnectedForSession.value.length;
        final rows = <Widget>[
          // A recording in progress has to be visible somewhere.
          if (recording == ScreenRecordingState.recording)
            BkGroupedRow(
              leading: BkIconTile(icon: LucideIcons.circle, color: BkStatusColors.of(context).danger),
              title: l10n.screenRecordingStarted,
            ),
          if (_showsPhoneSteering)
            BkSwitchRow(
              icon: LucideIcons.smartphone,
              title: l10n.devicesPhoneSteering,
              value: core.settings.getPhoneSteeringEnabled(),
              onToggle: () {
                final enable = !core.settings.getPhoneSteeringEnabled();
                core.settings.setPhoneSteeringEnabled(enable);
                core.connection.toggleGyroscopeSteering(enable);
                widget.onUpdate();
                if (mounted) setState(() {});
              },
            ),
          if (_showsMediaKeys)
            ValueListenableBuilder<bool>(
              valueListenable: core.mediaKeyHandler.isMediaKeyDetectionEnabled,
              builder: (context, value, _) => BkSwitchRow(
                icon: LucideIcons.music,
                title: l10n.devicesMediaRemotes,
                value: value,
                onToggle: () {
                  final enabled = !value;
                  core.mediaKeyHandler.isMediaKeyDetectionEnabled.value = enabled;
                  core.settings.setMediaKeyDetectionEnabled(enabled);
                },
              ),
            ),
          if (held > 0)
            BkGroupedRow(
              key: const ValueKey('devices-ignored'),
              icon: LucideIcons.eyeOff,
              quietIcon: true,
              title: l10n.ignoredDevices,
              trailing: Text('$held'),
              chevron: true,
              onPressed: () async {
                await showDialog(context: context, builder: (_) => const IgnoredDevicesDialog());
                widget.onUpdate();
                if (mounted) setState(() {});
              },
            ),
        ];
        if (rows.isEmpty) return const SizedBox.shrink();
        return BkGroupedSection(
          key: const ValueKey('devices-other-inputs'),
          header: l10n.devicesOtherInputs,
          children: rows,
        );
      },
    );
  }
}
