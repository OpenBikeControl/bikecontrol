import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/utils/requirements/android.dart';
import 'package:swift_control/utils/requirements/ios.dart';
import 'package:swift_control/utils/requirements/multi.dart';

abstract class PlatformRequirement {
  String name;
  String? description;
  late bool status;

  PlatformRequirement(this.name, {this.description});

  Future<void> getStatus();

  Future<void> call(BuildContext context, VoidCallback onUpdate);

  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return null;
  }
}

Future<List<PlatformRequirement>> getRequirements() async {
  List<PlatformRequirement> list;
  if (kIsWeb) {
    list = [BluetoothTurnedOn(), BluetoothScanning()];
  } else if (Platform.isMacOS) {
    list = [BluetoothTurnedOn(), KeyboardRequirement(), BluetoothScanning()];
  } else if (Platform.isIOS) {
    list = [BluetoothTurnedOn(), ConnectRequirement(), BluetoothScanning()];
  } else if (Platform.isWindows) {
    list = [BluetoothTurnedOn(), KeyboardRequirement(), BluetoothScanning()];
  } else if (Platform.isAndroid) {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceInfo = await deviceInfoPlugin.androidInfo;
    list = [
      BluetoothTurnedOn(),
      ConnectRequirement(),
      AccessibilityRequirement(),
      NotificationRequirement(),
      if (deviceInfo.version.sdkInt <= 30)
        LocationRequirement()
      else ...[
        BluetoothScanRequirement(),
        BluetoothConnectRequirement(),
      ],
      BluetoothScanning(),
    ];
  } else {
    list = [UnsupportedPlatform()];
  }
  await Future.wait(list.map((e) => e.getStatus()));
  return list;
}
