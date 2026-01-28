import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:flutter/material.dart';
import 'package:prop/prop.dart';

class ZwiftTile extends StatefulWidget {
  final VoidCallback onUpdate;

  const ZwiftTile({super.key, required this.onUpdate});

  @override
  State<ZwiftTile> createState() => _ZwiftTileState();
}

class _ZwiftTileState extends State<ZwiftTile> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: core.zwiftEmulator.isConnected,
      builder: (context, isConnected, _) {
        return ValueListenableBuilder(
          valueListenable: core.zwiftEmulator.isStarted,
          builder: (context, isStarted, _) {
            return StatefulBuilder(
              builder: (context, setState) {
                return ConnectionMethod(
                  supportedActions: core.zwiftEmulator.supportedActions,
                  isEnabled: core.settings.getZwiftBleEmulatorEnabled(),
                  type: ConnectionMethodType.bluetooth,
                  instructionLink: 'INSTRUCTIONS_ZWIFT.md',
                  isStarted: isStarted,
                  isConnected: isConnected,
                  onChange: (value) {
                    core.settings.setZwiftBleEmulatorEnabled(value);
                    if (!value) {
                      core.zwiftEmulator.stopAdvertising();
                    } else if (value) {
                      core.zwiftEmulator.startAdvertising(widget.onUpdate).catchError((e, s) {
                        recordError(e, s, context: 'Zwift BLE Emulator');
                        core.zwiftEmulator.cleanup();
                        core.zwiftEmulator.isStarted.value = false;
                        core.settings.setZwiftBleEmulatorEnabled(false);
                        core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, e.toString()));
                      });
                    }
                    setState(() {});
                  },
                  title: context.i18n.enableZwiftControllerBluetooth,
                  description: !isStarted
                      ? context.i18n.zwiftControllerDescription
                      : isConnected
                      ? context.i18n.connected
                      : context.i18n.waitingForConnectionKickrBike(core.settings.getTrainerApp()?.name ?? ''),
                  requirements: core.permissions.getRemoteControlRequirements(),
                );
              },
            );
          },
        );
      },
    );
  }
}
