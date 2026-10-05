import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/controller_settings.dart';
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
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
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
    final l10n = AppLocalizations.of(context);
    final accessories = <BluetoothDevice>[
      ...core.connection.accessories,
      ...core.connection.climbAccessories,
    ];
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
        if (accessories.isNotEmpty)
          BkGroupedSection(
            key: const ValueKey('devices-accessories'),
            header: l10n.accessories,
            children: [
              for (final device in accessories)
                BkGroupedRow(
                  // They are not links in the chain (nothing about a fan
                  // decides whether the rider can shift), but they have to be
                  // here: every accessory the scanner finds is connected
                  // automatically, including a neighbour's, and its page is
                  // the only way onto the ignore list.
                  key: ValueKey('devices-accessory-${device.uniqueId}'),
                  icon: device.icon,
                  title: device.displayName(context),
                  trailing: BkStatusDot(
                    label: device.isConnected ? l10n.connected : l10n.notConnected,
                    tone: device.isConnected ? BkStatusTone.success : BkStatusTone.neutral,
                  ),
                  chevron: true,
                  onPressed: () async {
                    await context.push(ControllerSettingsPage(device: device));
                    _update();
                  },
                ),
            ],
          ),
        if (widget.isMobile) Gap(MediaQuery.viewPaddingOf(context).bottom + 8),
      ],
    );
  }
}

/// "Share sensors": the broadcast of heart rate, power and cadence to the
/// trainer app, Pro. Its live readings ride along while it is on.
class ShareSensorsSection extends StatelessWidget {
  const ShareSensorsSection({super.key, this.onUpdate});

  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final broadcast = core.connection.broadcast;
    final isOn = broadcast?.isOn ?? const _Off();
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
                  title: l10n.sensorsBroadcastTitle,
                  subtitle: l10n.devicesShareSensorsSubtitle,
                  badge: IAPManager.instance.isProEnabledForCurrentDevice ? null : const ProBadge(),
                  trailing: Text(on ? l10n.statusOn : l10n.statusOff),
                  chevron: true,
                  onPressed: () async {
                    await context.push(const SensorsPage());
                    onUpdate?.call();
                  },
                ),
                if (on && quantities.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BkGroupedSection.inset + BkIconTile.size + BkGroupedRow.gap,
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
    return ValueListenableBuilder<ScreenRecordingState>(
      valueListenable: core.screenRecording.state,
      builder: (context, recording, _) {
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
              proOnly: !IAPManager.instance.hasPurchasedBefore50RVC,
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
          if (ignored.isNotEmpty)
            BkGroupedRow(
              key: const ValueKey('devices-ignored'),
              icon: LucideIcons.eyeOff,
              quietIcon: true,
              title: l10n.ignoredDevices,
              trailing: Text('${ignored.length}'),
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
