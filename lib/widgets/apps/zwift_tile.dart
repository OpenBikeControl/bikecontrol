import 'dart:io';

import 'package:flutter/material.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/widgets/ui/connection_method.dart';

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
        return StatefulBuilder(
          builder: (context, setState) {
            return ConnectionMethod(
              isStarted: core.zwiftEmulator.isAdvertising,
              onChange: (value) {
                core.settings.setZwiftEmulatorEnabled(value);
                if (!value) {
                  core.zwiftEmulator.stopAdvertising();
                } else if (value) {
                  core.zwiftEmulator.startAdvertising(widget.onUpdate);
                }
                setState(() {});
              },
              title: 'Enable Zwift Controller (Bluetooth)',
              description: !core.zwiftEmulator.isAdvertising
                  ? 'Enables BikeControl to act as a Zwift-compatible controller.'
                  : isConnected
                  ? "Connected"
                  : "Waiting for connection. Choose KICKR BIKE PRO in ${core.settings.getTrainerApp()?.name}'s controller pairing menu.",
              requirements: [if (Platform.isAndroid) BluetoothAdvertiseRequirement()],
            );
          },
        );
      },
    );
  }
}
