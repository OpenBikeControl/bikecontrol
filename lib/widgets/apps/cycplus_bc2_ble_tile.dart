import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class CycplusBc2BluetoothTile extends StatefulWidget {
  final bool small;
  const CycplusBc2BluetoothTile({super.key, required this.small});

  @override
  State<CycplusBc2BluetoothTile> createState() => _CycplusBc2BluetoothTileState();
}

class _CycplusBc2BluetoothTileState extends State<CycplusBc2BluetoothTile> {
  /// Built once: PlatformRequirement carries a mutable `status`.
  final _requirements = core.permissions.getRemoteControlRequirements();

  @override
  Widget build(BuildContext context) {
    final emulator = core.bc2BluetoothEmulator;
    return ValueListenableBuilder(
      valueListenable: emulator.isStarted,
      builder: (context, isStarted, _) {
        return ValueListenableBuilder(
          valueListenable: emulator.isConnected,
          builder: (context, isConnected, _) {
            final appName = shownTrainerAppName(core.settings.getTrainerApp()?.name ?? '');
            return ConnectionMethod(
              small: widget.small,
              trainerConnection: emulator,
              isRecommended: true,
              supportLevel: core.settings.getTrainerApp()?.supportLevel(AppConnectionMethod.cycplusBc2Ble),
              supportedActions: isConnected ? emulator.supportedActions : null,
              isEnabled: core.settings.getBc2BleEnabled(),
              title: context.i18n.connectUsingBluetooth,
              // The steering-device hint shows before switching on too: it
              // decides whether this is the method the rider wants.
              description: isConnected
                  ? context.i18n.connectedTo(appName)
                  : isStarted
                  ? context.i18n.addBikeControlAsSteeringDevice(appName)
                  : '${context.i18n.letsAppConnectOverBluetooth(appName)} '
                        '${context.i18n.addBikeControlAsSteeringDevice(appName)}',
              requirements: _requirements,
              onChange: (value) async {
                if (value) {
                  await core.stopAllBleConnections();
                }
                core.settings.setBc2BleEnabled(value);
                if (!value) {
                  core.bc2BluetoothEmulator.stopServer();
                } else {
                  core.bc2BluetoothEmulator.startServer().catchError((e, s) {
                    recordError(e, s, context: 'BC2 BLE Emulator');
                    core.settings.setBc2BleEnabled(false);
                    buildToast(
                      level: LogLevel.LOGLEVEL_WARNING,
                      title: context.i18n.errorStartingBluetoothServer,
                    );
                  });
                }
              },
            );
          },
        );
      },
    );
  }
}
