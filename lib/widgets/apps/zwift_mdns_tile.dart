import 'package:prop/prop.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:flutter/material.dart';

class ZwiftMdnsTile extends StatefulWidget {
  final VoidCallback onUpdate;

  const ZwiftMdnsTile({super.key, required this.onUpdate});

  @override
  State<ZwiftMdnsTile> createState() => _ZwiftTileState();
}

class _ZwiftTileState extends State<ZwiftMdnsTile> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: core.zwiftMdnsEmulator.isConnected,
      builder: (context, isConnected, _) {
        return ValueListenableBuilder(
          valueListenable: core.zwiftMdnsEmulator.isStarted,
          builder: (context, isStarted, _) {
            return StatefulBuilder(
              builder: (context, setState) {
                return ConnectionMethod(
                  supportedActions: core.zwiftMdnsEmulator.supportedActions,
                  type: ConnectionMethodType.network,
                  isEnabled: core.settings.getZwiftMdnsEmulatorEnabled(),
                  title: context.i18n.enableZwiftControllerNetwork,
                  description: !isStarted
                      ? context.i18n.zwiftControllerDescription
                      : isConnected
                      ? context.i18n.connected
                      : context.i18n.waitingForConnectionKickrBike(core.settings.getTrainerApp()?.name ?? ''),
                  instructionLink: 'INSTRUCTIONS_ZWIFT.md',
                  isStarted: isStarted,
                  isConnected: isConnected,
                  onChange: (start) {
                    core.settings.setZwiftMdnsEmulatorEnabled(start);
                    if (start) {
                      core.zwiftMdnsEmulator.startServer().catchError((e, s) {
                        recordError(e, s, context: 'Zwift mDNS Emulator');
                        core.settings.setZwiftMdnsEmulatorEnabled(false);
                        core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, e.toString()));
                        setState(() {});
                        widget.onUpdate();
                      });
                    } else {
                      core.zwiftMdnsEmulator.stop();
                    }
                    setState(() {});
                  },
                  requirements: [],
                );
              },
            );
          },
        );
      },
    );
  }
}
