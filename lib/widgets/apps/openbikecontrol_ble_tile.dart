import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zp.pb.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';
import 'package:swift_control/widgets/ui/toast.dart';

class OpenBikeControlBluetoothTile extends StatefulWidget {
  const OpenBikeControlBluetoothTile({super.key});

  @override
  State<OpenBikeControlBluetoothTile> createState() => _OpenBikeProtocolTileState();
}

class _OpenBikeProtocolTileState extends State<OpenBikeControlBluetoothTile> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: core.obpBluetoothEmulator.isStarted,
      builder: (context, isStarted, _) {
        return ValueListenableBuilder(
          valueListenable: core.obpBluetoothEmulator.isConnected,
          builder: (context, isConnected, _) {
            return ConnectionMethod(
              title: 'Connect using Bluetooth',
              description: isConnected != null
                  ? 'Connected to ${isConnected.appId}'
                  : isStarted
                  ? 'Choose BikeControl in the connection screen.'
                  : 'Lets ${core.settings.getTrainerApp()?.name} connect to BikeControl over Bluetooth.',
              requirements: core.permissions.getRemoteControlRequirements(),
              onChange: (value) {
                core.settings.setObpBleEnabled(value);
                if (!value) {
                  core.obpBluetoothEmulator.stopServer();
                } else if (value) {
                  core.obpBluetoothEmulator.startServer().catchError((e) {
                    buildToast(
                      context,
                      level: LogLevel.LOGLEVEL_WARNING,
                      title: 'Error starting OpenBikeControl Bluetooth server.',
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
