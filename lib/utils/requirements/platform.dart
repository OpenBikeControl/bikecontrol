import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/utils/requirements/android.dart';
import 'package:swift_control/utils/requirements/multi.dart';

abstract class PlatformRequirement {
  String name;
  late bool status;

  PlatformRequirement(this.name);

  Future<void> getStatus();

  Future<void> call();

  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return null;
  }
}

Future<List<PlatformRequirement>> getRequirements() async {
  List<PlatformRequirement> list;
  if (kIsWeb) {
    list = [BluetoothTurnedOn(), BluetoothScanning()];
  } else if (Platform.isMacOS) {
    list = [BluetoothTurnedOn(), KeyboardRequirement(), KeymapRequirement(), BluetoothScanning()];
  } else if (Platform.isWindows) {
    list = [BluetoothTurnedOn(), KeyboardRequirement(), KeymapRequirement(), BluetoothScanning()];
  } else if (Platform.isAndroid) {
    list = [BluetoothTurnedOn(), AccessibilityRequirement(), NotificationRequirement(), BluetoothScanning()];
  } else {
    list = [UnsupportedPlatform()];
  }
  await Future.wait(list.map((e) => e.getStatus()));
  return list;
}
