//INFO: This is a stub - contact me if you need the full implementation.
//
// FAKE placeholder UUIDs / values; the frame encoding is stubbed.

import 'dart:math';
import 'dart:typed_data';

enum Bc2Lever { plus, minus }

class CycplusBc2Emulator {
  static const String SERVICE_UUID = '00000000-0000-0000-0000-0000000000b1';
  static const String TX_CHARACTERISTIC_UUID = '00000000-0000-0000-0000-0000000000b2';
  static const String RX_CHARACTERISTIC_UUID = '00000000-0000-0000-0000-0000000000b3';

  CycplusBc2Emulator({Random? random});

  Uint8List connectFrame() => Uint8List(0);

  Uint8List press(Bc2Lever lever, {bool long = false}) => Uint8List(0);

  Uint8List release(Bc2Lever lever) => Uint8List(0);

  bool isPressed(Bc2Lever lever) => false;

  void reset() {}
}
