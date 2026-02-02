//INFO: This is a stub - contact me if you need the full implementation.

import 'package:flutter/foundation.dart';

class ClickEmulator {
  final ValueNotifier<bool> isStarted = ValueNotifier(false);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  Future<void> startServer() async {
    isStarted.value = true;
  }

  void stop() {
    isStarted.value = false;
    isConnected.value = false;
  }

  void writeNotification(List<int> bytes) {}
}
