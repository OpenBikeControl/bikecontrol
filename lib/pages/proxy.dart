import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ProxyPage extends StatefulWidget {
  final bool isMobile;
  final VoidCallback onUpdate;
  const ProxyPage({
    super.key,
    required this.onUpdate,
    required this.isMobile,
  });

  @override
  State<ProxyPage> createState() => _DevicePageState();
}

class _DevicePageState extends State<ProxyPage> {
  late StreamSubscription<BaseDevice> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = core.connection.connectionStream.listen((state) async {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...core.connection.proxyDevices
            .mapIndexed(
              (index, device) => [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Button.ghost(
                    onPressed: () async {
                      await context.push(ControllerSettingsPage(device: device));
                      widget.onUpdate();
                    },
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        device.showInformation(context, showFull: false),
                        ...device.showAdditionalInformation(context),
                      ],
                    ),
                  ),
                ),
                if (index != core.connection.proxyDevices.length - 1)
                  Divider(
                    thickness: 0.5,
                    indent: 20,
                    endIndent: 20,
                  ),
              ],
            )
            .flatten(),
      ],
    );
  }
}
