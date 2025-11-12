import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/apps/rouvy.dart';
import 'package:swift_control/utils/keymap/apps/zwift.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';

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
      valueListenable: zwiftEmulator.isConnected,
      builder: (context, isConnected, _) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: settings.getZwiftEmulatorEnabled(),
              onChanged: (value) {
                settings.setZwiftEmulatorEnabled(value);
                if (!value) {
                  zwiftEmulator.stopAdvertising();
                } else if (value) {
                  zwiftEmulator.startAdvertising(widget.onUpdate);
                }
                setState(() {});
              },
              title: Text('Enable Zwift Controller'),
              subtitle: Row(
                spacing: 12,
                children: [
                  if (!settings.getZwiftEmulatorEnabled())
                    Expanded(
                      child: Text(
                        'Disabled. ${settings.getTrainerApp() is Zwift
                            ? 'Virtual shifting and on screen navigation will not work.'
                            : settings.getTrainerApp() is Rouvy
                            ? 'Virtual shifting will not work.'
                            : ''}',
                      ),
                    )
                  else ...[
                    Expanded(
                      child: Text(
                        isConnected
                            ? "Connected"
                            : "Waiting for connection. Choose SwiftControl in ${settings.getTrainerApp()?.name}'s controller pairing menu.",
                      ),
                    ),
                    if (!isConnected) SmallProgressIndicator(),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
