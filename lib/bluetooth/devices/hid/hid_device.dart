import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/core.dart';

class HidDevice extends BaseDevice {
  HidDevice(super.name, {super.availableButtons = const []});

  @override
  Future<void> connect() {
    return Future.value(null);
  }

  @override
  Widget showInformation(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(name)),
        PopupMenuButton(
          itemBuilder: (c) => [
            PopupMenuItem(
              child: Text('Ignore'),
              onTap: () {
                core.connection.disconnect(this, forget: true, persistForget: true);
                if (core.actionHandler is AndroidActions) {
                  (core.actionHandler as AndroidActions).ignoreHidDevices();
                } else if (core.connection.isMediaKeyDetectionEnabled.value) {
                  core.connection.isMediaKeyDetectionEnabled.value = false;
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
