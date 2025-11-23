import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/remote.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/utils/requirements/remote.dart';

class StatusWidget extends StatefulWidget {
  const StatusWidget({super.key});

  @override
  State<StatusWidget> createState() => _StatusWidgetState();
}

class _StatusWidgetState extends State<StatusWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          spacing: 8,
          children: [
            if (connection.controllerDevices.isEmpty)
              _Status(color: Colors.red, text: 'No connected controllers')
            else
              _Status(
                color: Colors.green,
                text:
                    '${connection.controllerDevices.length == 1 ? 'Controller connected' : '${connection.controllerDevices.length} controllers connected'} ',
              ),
            if (whooshLink.isCompatible(settings.getLastTarget() ?? Target.thisDevice) &&
                settings.getMyWhooshLinkEnabled())
              _Status(
                color: whooshLink.isConnected.value ? Colors.green : Colors.red,
                text: 'MyWhoosh Direct Connect ${whooshLink.isConnected.value ? "connected" : "not connected"}',
              ),

            if (actionHandler is RemoteActions && isAdvertisingPeripheral)
              _Status(
                color: (actionHandler as RemoteActions).isConnected ? Colors.green : Colors.red,
                text: 'Remote ${(actionHandler as RemoteActions).isConnected ? "connected" : "not connected"}',
              ),
            if (settings.getTrainerApp()?.supportsZwiftEmulation == true)
              _Status(
                color: zwiftEmulator.isConnected.value ? Colors.green : Colors.red,
                text: 'Zwift Emulation ${zwiftEmulator.isConnected.value ? "connected" : "not connected"}',
              ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  final Color color;
  final String text;
  const _Status({super.key, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 16),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
