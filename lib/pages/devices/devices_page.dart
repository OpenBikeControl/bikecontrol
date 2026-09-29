import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/home/home_extras.dart';
import 'package:bike_control/pages/home/home_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/home/accessory_card.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Devices section: the setup chain's cards (controllers, trainer or
/// sensors, trainer app), accessories, and the device options that used to
/// sit under the chain (extra scanning, media keys, phone steering, ignored
/// devices).
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.isMobile, required this.onUpdate, this.reveal});

  final bool isMobile;

  /// Ride's "Show": brings the outstanding cards into view.
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
    final accessories = <BluetoothDevice>[
      ...core.connection.accessories,
      ...core.connection.climbAccessories,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomePage(
          view: HomeView.setup,
          isMobile: widget.isMobile,
          showHelpRow: false,
          onUpdate: _update,
          reveal: widget.reveal,
        ),
        const Gap(10),
        if (accessories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: Text(context.i18n.accessories).xSmall.muted,
          ),
          for (final device in accessories) ...[
            AccessoryCard(
              title: device.displayName(context),
              icon: device.icon,
              connected: device.isConnected,
              onOpen: () async {
                await context.push(ControllerSettingsPage(device: device));
                _update();
              },
            ),
            const Gap(10),
          ],
        ],
        HomeExtras(isMobile: widget.isMobile, onUpdate: _update),
      ],
    );
  }
}
