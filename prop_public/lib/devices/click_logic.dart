//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation decodes the Zwift Click/Play pairing pages and
// drives the periodic RESET recovery. This stub keeps the static surface so
// the app compiles.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

/// Where the right puck's keep-awake has got to, for the app to show.
enum ClickKeepAwakeStatus {
  /// No right puck connected, so there is nothing to keep awake.
  idle,

  /// Working, but with no left puck in range.
  waitingForLeftSide,

  /// Running.
  active,

  /// The last attempt failed; the loop keeps retrying.
  failed,
}

class ClickLogic {
  static final _resettingDevices = <String>{};

  /// Whether a left puck is currently in range. Supplied by the app.
  static bool Function()? isLeftSideNearby;

  /// Where the right puck's keep-awake has got to.
  static final keepAwakeStatus = ValueNotifier<ClickKeepAwakeStatus>(ClickKeepAwakeStatus.idle);

  /// Nudges a pending keep-awake to start now.
  static void startKeepAwakeIfPending() {}

  /// Forgets the right puck and clears the status.
  static void forgetKeepAwake() {}

  static bool isResetting(String deviceId) => _resettingDevices.contains(deviceId);

  static void clearResetting(String deviceId) => _resettingDevices.remove(deviceId);

  /// Invoked right before a RESET command is sent.
  static void Function(String deviceId)? onResetSent;

  static void processData(Uint8List bytes, {required String deviceId, required List<BleService> services}) {}

  static Future<void> setupHandshake(List<BleService> services, String deviceId, {required bool isRight}) async {}

  static void resetTimer() {}
}
