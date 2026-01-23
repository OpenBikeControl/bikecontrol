import 'package:prop/prop.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
          valueListenable: core.obpBluetoothEmulator.connectedApp,
          builder: (context, isConnected, _) {
            return ConnectionMethod(
              supportedActions: isConnected?.supportedActions,
              isEnabled: core.settings.getObpBleEnabled(),
              type: ConnectionMethodType.openBikeControl,
              title: context.i18n.connectUsingBluetooth,
              description: isConnected != null
                  ? context.i18n.connectedTo(
                      "${isConnected.appId}:\n${isConnected.supportedActions.joinToString(transform: (s) => s.title)}",
                    )
                  : isStarted
                  ? context.i18n.chooseBikeControlInConnectionScreen
                  : context.i18n.letsAppConnectOverBluetooth(core.settings.getTrainerApp()?.name ?? ''),
              requirements: core.permissions.getRemoteControlRequirements(),
              onChange: (value) {
                core.settings.setObpBleEnabled(value);
                if (!value) {
                  core.obpBluetoothEmulator.stopServer();
                } else if (value) {
                  core.obpBluetoothEmulator.startServer().catchError((e, s) {
                    recordError(e, s, context: 'OBP BLE Emulator');
                    core.settings.setObpBleEnabled(false);
                    buildToast(
                      context,
                      level: LogLevel.LOGLEVEL_WARNING,
                      title: context.i18n.errorStartingOpenBikeControlBluetoothServer,
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
