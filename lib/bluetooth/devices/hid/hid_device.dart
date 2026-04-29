import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:flutter/material.dart' show PopupMenuButton, PopupMenuItem;
import 'package:shadcn_flutter/shadcn_flutter.dart';

class HidDevice extends BaseDevice {
  HidDevice(super.name, {String? uniqueId})
    : super(
        availableButtons: [],
        uniqueId: uniqueId ?? name!,
        supportsLongPress: false,
        icon: LucideIcons.gamepad2,
      );

  @override
  Future<void> connect() {
    isConnected = true;
    return Future.value(null);
  }

  @override
  Widget showInformation(BuildContext context, {required bool showFull, Widget? footer}) {
    return Row(
      children: [
        Expanded(child: super.showInformation(context, showFull: true, footer: footer)),
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
                  core.settings.setMediaKeyDetectionEnabled(false);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    return [
      if (Platform.isAndroid && !core.settings.getLocalEnabled())
        Warning(
          children: [
            Text(
              AppLocalizations.of(context).androidAccessibilityHint,
            ).xSmall,
          ],
        ),
    ];
  }
}
