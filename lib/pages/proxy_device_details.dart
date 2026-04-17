import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/pages/proxy_device_details/gear_hero_card.dart';
import 'package:bike_control/pages/proxy_device_details/live_metrics_section.dart';
import 'package:bike_control/pages/proxy_device_details/trainer_settings_section.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ProxyDeviceDetailsPage extends StatefulWidget {
  final ProxyDevice device;
  const ProxyDeviceDetailsPage({super.key, required this.device});

  @override
  State<ProxyDeviceDetailsPage> createState() => _ProxyDeviceDetailsPageState();
}

class _ProxyDeviceDetailsPageState extends State<ProxyDeviceDetailsPage> {
  late StreamSubscription<BaseDevice> _connectionSub;

  void _onEmulatorStateChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.device.emulator.isStarted.addListener(_onEmulatorStateChanged);
    widget.device.emulator.isConnected.addListener(_onEmulatorStateChanged);
    _connectionSub = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionSub.cancel();
    widget.device.emulator.isStarted.removeListener(_onEmulatorStateChanged);
    widget.device.emulator.isConnected.removeListener(_onEmulatorStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

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
          title: const Text(
            'Smart Trainer',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          trailing: [
            IconButton.ghost(
              icon: Icon(LucideIcons.x, size: 22, color: Theme.of(context).colorScheme.mutedForeground),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          backgroundColor: Theme.of(context).colorScheme.background,
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
              spacing: 20,
              children: [
                _deviceCard(),
                ConnectionCard(device: device),
                _gearSection(),
                LiveMetricsSection(device: device),
                _settingsSection(),
                _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deviceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: widget.device.showInformation(context, showFull: true),
    );
  }

  Widget _gearSection() {
    final def = widget.device.emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return const SizedBox.shrink();
    return GearHeroCard(definition: def);
  }

  Widget _settingsSection() {
    final def = widget.device.emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        const Text(
          'Trainer Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        TrainerSettingsSection(definition: def),
      ],
    );
  }

  Widget _actions() {
    final device = widget.device;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        LoadingWidget(
          futureCallback: () async {
            await core.connection.disconnect(device, forget: false, persistForget: false);
            if (mounted) Navigator.of(context).pop();
          },
          renderChild: (isLoading, tap) => Button(
            style: ButtonStyle.outline(),
            onPressed: tap,
            leading: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.bluetoothOff, size: 18),
            child: const Text('Disconnect'),
          ),
        ),
        LoadingWidget(
          futureCallback: () async {
            await core.connection.disconnect(device, forget: true, persistForget: true);
            if (mounted) Navigator.of(context).pop();
          },
          renderChild: (isLoading, tap) => Button(
            style: ButtonStyle.destructive(),
            onPressed: tap,
            leading: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.trash2, size: 18),
            child: const Text('Disconnect & forget'),
          ),
        ),
      ],
    );
  }
}
