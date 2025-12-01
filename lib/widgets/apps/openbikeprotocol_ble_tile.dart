import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';
import 'package:swift_control/widgets/ui/toast.dart';

class OpenBikeProtocolBluetoothTile extends StatefulWidget {
  const OpenBikeProtocolBluetoothTile({super.key});

  @override
  State<OpenBikeProtocolBluetoothTile> createState() => _OpenBikeProtocolTileState();
}

class _OpenBikeProtocolTileState extends State<OpenBikeProtocolBluetoothTile> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: core.obpBluetoothEmulator.isStarted,
      builder: (context, isStarted, _) {
        return ValueListenableBuilder(
          valueListenable: core.obpBluetoothEmulator.isConnected,
          builder: (context, isConnected, _) {
            return ConnectionMethod(
              title: 'Enable OpenBikeProtocol (Bluetooth)',
              description: isConnected != null
                  ? 'Connected to ${isConnected.appId}'
                  : 'OpenBikeProtocol allows compatible apps to connect directly to your trainer using Bluetooth.',
              requirements: core.permissions.getRemoteControlRequirements(),
              onChange: (value) {
                core.settings.setObpBleEnabled(value);
                if (!value) {
                  core.obpBluetoothEmulator.stopServer();
                } else if (value) {
                  core.obpBluetoothEmulator.startServer().catchError((e) {
                    showToast(
                      context: context,
                      builder: (c, overlay) => buildToast(
                        context,
                        overlay,
                        title: 'Error starting OpenBikeProtocol server.',
                      ),
                    );
                  });
                }
              },
              isStarted: isStarted,
              isConnected: isConnected != null,
            );
          },
        );
      },
    );
  }
}
