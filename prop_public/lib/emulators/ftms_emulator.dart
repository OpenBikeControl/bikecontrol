//INFO: This is a stub - contact me if you need the full implementation.

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

class FtmsEmulator {
  final ValueNotifier<bool> isStarted = ValueNotifier(false);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<bool> isUnlocked = ValueNotifier(false);
  final ValueNotifier<bool> alreadyUnlocked = ValueNotifier(false);
  final ValueNotifier<bool> waiting = ValueNotifier(false);

  DateTime get connectionDate => DateTime.now();

  bool processCharacteristic(String characteristic, Uint8List bytes) {
    return false;
  }

  void setScanResult(BleDevice scanResult) {}

  Future<void> startServer() async {}

  void stop() {}

  void handleServices(List<BleService> services) {}
}
