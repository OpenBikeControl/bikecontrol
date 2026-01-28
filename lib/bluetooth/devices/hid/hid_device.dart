import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:flutter/material.dart' show PopupMenuButton, PopupMenuItem;
import 'package:shadcn_flutter/shadcn_flutter.dart';

class HidDevice extends BaseDevice {
  HidDevice(super.name) : super(availableButtons: [], uniqueId: name!);

  @override
  Future<void> connect() {
    return Future.value(null);
  }

  @override
  Widget showInformation(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(toString()).bold),
            PopupMenuButton(
              itemBuilder: (c) => [
                PopupMenuItem(
                  child: Text('Ignore'),
                  onTap: () {
                    core.connection.disconnect(this, forget: true, persistForget: true);
                    if (core.actionHandler is AndroidActions) {
                      (core.actionHandler as AndroidActions).ignoreHidDevices();
                    } else if (core.mediaKeyHandler.isMediaKeyDetectionEnabled.value) {
                      core.mediaKeyHandler.isMediaKeyDetectionEnabled.value = false;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        if (Platform.isAndroid && !core.settings.getLocalEnabled())
          Warning(
            children: [
              Text(
                'For it to work properly, even when BikeControl is in the background, you need to enable the local connection method in the next tab.',
              ).small,
            ],
          ),
      ],
    );
  }
}
