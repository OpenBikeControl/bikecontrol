import 'package:flutter/material.dart' hide ConnectionState;
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/apps/rouvy.dart';
import 'package:swift_control/utils/keymap/apps/zwift.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';

class ZwiftRequirement extends PlatformRequirement {
  ZwiftRequirement()
    : super(
        'Pair SwiftControl with Zwift',
      );

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  @override
  Widget? buildDescription() {
    return settings.getLastTarget() == null
        ? null
        : Text(
            'In Zwift on your ${settings.getLastTarget()?.title} go into the Pairing settings and select SwiftControl from the list of available controllers.',
          );
  }

  @override
  Widget? build(BuildContext context, VoidCallback onUpdate) {
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
                  zwiftEmulator.startAdvertising(onUpdate);
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

  @override
  Future<void> getStatus() async {
    status = zwiftEmulator.isConnected.value || screenshotMode;
  }
}
