import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';

class HidDevice extends BaseDevice {
  HidDevice(super.name, {super.availableButtons = const []});

  @override
  Future<void> connect() {
    return Future.value(null);
  }

  @override
  Widget showInformation(BuildContext context) {
    return Text(name);
  }
}
