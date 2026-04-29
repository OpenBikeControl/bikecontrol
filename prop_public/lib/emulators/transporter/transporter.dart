import 'package:prop/emulators/ble_definition.dart';

/// Exposes a [BleDefinition] over a specific wire transport — either a TCP
/// socket with the DirCon wire protocol (`NetworkTransporter`) or a native
/// BLE peripheral (`BluetoothTransporter`).
///
/// The transporter owns the binding to the definition: in the constructor it
/// sets `definition.transporter = this` so the definition can push
/// notifications back through.
abstract class Transporter {
  final BleDefinition definition;

  Transporter({required this.definition});

  /// Push a notification out to the connected client.
  void sendCharacteristicNotification(
    String characteristicUUID,
    List<int> data, {
    int responseCode = 1,
  });

  void dispose() {}
}
