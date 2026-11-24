//INFO: This is a stub - contact me if you need the full implementation.

import 'package:flutter/foundation.dart';
import 'package:prop/emulators/transporter/transporter.dart';

/// Exposes a [BleDefinition] over native BLE peripheral mode.
class BluetoothTransporter extends Transporter {
  BluetoothTransporter({required super.definition, this.advertisementName = 'BikeControl Virtual'});

  final String advertisementName;

  final ValueNotifier<bool> _hasSubscribersNotifier = ValueNotifier<bool>(false);

  /// Flips true once a central subscribes to a notifiable characteristic.
  ValueListenable<bool> get hasSubscribers => _hasSubscribersNotifier;

  Future<void> start({bool advertise = true}) async {}

  Future<void> startAdvertising() async {}

  Future<void> stopAdvertising() async {}

  Future<void> stop() async {}

  @override
  void sendCharacteristicNotification(String characteristicUUID, List<int> data, {int responseCode = 1}) {}

  @override
  void dispose() {}
}

/// The platform refuses the BLE peripheral role (on Android: no
/// BLUETOOTH_ADVERTISE permission).
class BluetoothPeripheralUnauthorizedException implements Exception {
  const BluetoothPeripheralUnauthorizedException();

  @override
  String toString() => 'Bluetooth advertise permission not granted';
}
