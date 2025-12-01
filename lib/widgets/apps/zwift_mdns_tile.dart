import 'package:flutter/material.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';

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
                  title: context.i18n.enableZwiftControllerNetwork,
                  description: !isStarted
                      ? context.i18n.zwiftControllerDescription
                      : isConnected
                      ? context.i18n.connected
                      : context.i18n.waitingForConnectionKickrBike(core.settings.getTrainerApp()?.name ?? ''),
                  isStarted: isStarted,
                  onChange: (start) {
                    core.settings.setZwiftMdnsEmulatorEnabled(start);
                    if (start) {
                      core.zwiftMdnsEmulator.startServer();
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
