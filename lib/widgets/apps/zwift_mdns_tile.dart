import 'package:flutter/material.dart';
import 'package:swift_control/utils/core.dart';
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
                  title: 'Enable Zwift Controller (Network)',
                  description: !isStarted
                      ? 'Enables BikeControl to act as a Zwift-compatible controller.'
                      : isConnected
                      ? "Connected"
                      : "Waiting for connection. Choose KICKR BIKE PRO in ${core.settings.getTrainerApp()?.name}'s controller pairing menu.",
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
