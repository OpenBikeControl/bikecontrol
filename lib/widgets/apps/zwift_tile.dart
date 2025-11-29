import 'package:flutter/material.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/apps/zwift.dart';
import 'package:swift_control/widgets/ui/small_progress_indicator.dart';

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
            return SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: core.settings.getZwiftEmulatorEnabled(),
              onChanged: (value) {
                core.settings.setZwiftEmulatorEnabled(value);
                if (!value) {
                  core.zwiftEmulator.stopAdvertising();
                } else if (value) {
                  core.zwiftEmulator.startAdvertising(widget.onUpdate);
                }
                setState(() {});
              },
              title: Text('Enable Zwift Controller'),
              subtitle: Row(
                spacing: 12,
                children: [
                  if (!core.settings.getZwiftEmulatorEnabled())
                    Expanded(
                      child: Text(
                        'Disabled. ${core.settings.getTrainerApp() is Zwift ? 'Virtual shifting and on screen navigation will not work.' : ''}',
                      ),
                    )
                  else ...[
                    Expanded(
                      child: Text(
                        isConnected
                            ? "Connected"
                            : "Waiting for connection. Choose BikeControl in ${core.settings.getTrainerApp()?.name}'s controller pairing menu.",
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
