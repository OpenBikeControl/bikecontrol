//INFO: This is a stub - contact me if you need the full implementation.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Uint8List;

class ClickEmulator {
  final ValueNotifier<bool> isStarted = ValueNotifier(false);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  /// Called with the controller's answer to a relayed unlock challenge.
  void Function(Uint8List authResponse)? onAuthResponse;

  /// Relays an unlock challenge to the connected app. No-op in the stub.
  void sendChallenge(List<int> challenge) {}

  void clearChallenge() {}

  Future<void> startServer(bool hello, {String? name}) async {
    isStarted.value = true;
  }

  void stop() {
    isStarted.value = false;
    isConnected.value = false;
  }

  void writeNotification(List<int> bytes) {}
}
