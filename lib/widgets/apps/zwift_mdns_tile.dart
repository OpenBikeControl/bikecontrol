import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:flutter/material.dart';
import 'package:prop/prop.dart';

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
                final isRouvy = core.settings.getTrainerApp() is Rouvy;
                return ConnectionMethod(
                  trainerConnection: core.zwiftMdnsEmulator,
                  isRecommended: true,
                  supportLevel: core.settings.getTrainerApp()?.supportLevel(AppConnectionMethod.zwiftMdns),
                  isEnabled: core.settings.getZwiftMdnsEmulatorEnabled(),
                  title: context.i18n.connectDirectlyOverNetwork,
                  description: !isStarted
                      ? context.i18n.zwiftControllerDescription
                      : isConnected
                      ? context.i18n.connected
                      : isRouvy
                      ? context.i18n
                            .waitingForConnectionKickrBike(core.settings.getTrainerApp()?.name ?? '')
                            .replaceAll('KICKR BIKE PRO', 'BikeControl')
                      : context.i18n.waitingForConnectionKickrBike(core.settings.getTrainerApp()?.name ?? ''),
                  instructionLink: 'INSTRUCTIONS_ZWIFT.md',
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
