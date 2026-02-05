import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

class RemoteKeyboardPairingWidget extends StatefulWidget {
  const RemoteKeyboardPairingWidget({super.key});

  @override
  State<RemoteKeyboardPairingWidget> createState() => _PairWidgetState();
}

class _PairWidgetState extends State<RemoteKeyboardPairingWidget> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: core.remoteKeyboardPairing.isStarted,
      builder: (context, isStarted, child) {
        return ValueListenableBuilder(
          valueListenable: core.remoteKeyboardPairing.isConnected,
          builder: (context, isConnected, child) {
            return ConnectionMethod(
              supportedActions: null,
              isEnabled: core.logic.isRemoteKeyboardControlEnabled,
              isStarted: isStarted,
              showTroubleshooting: true,
              type: ConnectionMethodType.bluetooth,
              instructionLink: 'https://youtube.com/shorts/qalBSiAz7wg',
              title: AppLocalizations.of(context).actAsBluetoothKeyboard,
              description: AppLocalizations.of(context).bluetoothKeyboardExplanation,
              isConnected: isConnected,
              requirements: core.permissions.getRemoteControlRequirements(),
              onChange: (value) async {
                core.settings.setRemoteKeyboardControlEnabled(value);
                if (!value) {
                  core.remoteKeyboardPairing.stopAdvertising();
                } else {
                  core.remoteKeyboardPairing.startAdvertising().catchError((e) {
                    core.settings.setRemoteControlEnabled(false);
                    core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, e.toString()));
                  });
                }
                setState(() {});
              },
            );
          },
        );
      },
    );
  }
}
