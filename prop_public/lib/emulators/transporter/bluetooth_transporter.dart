import 'package:prop/emulators/transporter/transporter.dart';

/// Exposes a [BleDefinition] over native BLE peripheral mode.
///
/// Advertises the definition's services/characteristics, translates incoming
/// GATT requests into calls on the definition's hooks, and routes outgoing
/// notifications via [PeripheralManager].
class BluetoothTransporter extends Transporter {
  BluetoothTransporter({required super.definition});

  @override
  void sendCharacteristicNotification(String characteristicUUID, List<int> data, {int responseCode = 1}) {
    // TODO: implement sendCharacteristicNotification
  }
}
