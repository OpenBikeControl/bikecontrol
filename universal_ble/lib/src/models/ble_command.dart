import 'dart:typed_data';

class BleCommand {
  String service;
  String characteristic;
  Uint8List? writeValue;

  BleCommand({
    required this.service,
    required this.characteristic,
    this.writeValue,
  });
}
