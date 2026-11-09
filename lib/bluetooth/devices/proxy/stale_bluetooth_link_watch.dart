import 'dart:async';

import 'package:flutter/foundation.dart';

/// Spots a trainer app that is still holding on to a Bluetooth connection
/// from before BikeControl restarted on Windows, and can no longer get data
/// through it (GH #451).
///
/// On Windows the phone, not the PC, holds the Bluetooth link to the bridge.
/// When BikeControl closes or crashes, Windows keeps that link up, and on the
/// next start BikeControl publishes the same GATT layout again: the phone sees
/// no disconnect, no Service Changed, and believes it is still subscribed. But
/// its subscriptions belonged to the old process, so nothing reaches it, and
/// BikeControl has no way to drop the link or to notify a client that never
/// subscribed to *this* process. Seen on hardware: MyWhoosh showed
/// "connected" with no data until the rider removed the PC and paired it
/// again — and even after a forced disconnect it stayed on "Pairing in
/// progress" rather than coming back by itself. So the rider has to be told.
///
/// [suspected] turns true when, after the bridge comes up, no trainer app
/// picks it up within [grace] — but only if one has picked it up before
/// ([pairedBefore]), since a first-time rider simply hasn't paired yet. It is
/// armed once per bridge start: an app that connects and later leaves (the
/// rider closed it) is a real disconnect, which the app handles itself.
class StaleBluetoothLinkWatch {
  StaleBluetoothLinkWatch({
    required bool Function() pairedBefore,
    required void Function() onPaired,
    this.grace = const Duration(seconds: 20),
  }) : _pairedBefore = pairedBefore,
       _onPaired = onPaired;

  final bool Function() _pairedBefore;
  final void Function() _onPaired;

  /// How long a trainer app gets to pick the bridge up on its own. A phone
  /// that kept its connection resubscribes within a second or two when it is
  /// going to at all; 20 s also covers one that reconnects from scratch.
  final Duration grace;

  final ValueNotifier<bool> _suspected = ValueNotifier(false);

  /// Whether the trainer app is likely holding a stale connection.
  ValueListenable<bool> get suspected => _suspected;

  Timer? _timer;
  bool _bridgeWasUp = false;

  /// Whether a trainer app has held the bridge since it last came up — the
  /// window is only armed while this is false.
  bool _heldSinceStart = false;

  /// Feed the current state. [bridgeUp]: the Bluetooth bridge is running on
  /// Windows. [appHolds]: a trainer app is subscribed to it.
  void update({required bool bridgeUp, required bool appHolds}) {
    if (!bridgeUp) {
      _bridgeWasUp = false;
      _heldSinceStart = false;
      _reset();
      return;
    }
    final freshStart = !_bridgeWasUp;
    _bridgeWasUp = true;
    if (appHolds) {
      if (!_heldSinceStart) _onPaired();
      _heldSinceStart = true;
      _reset();
      return;
    }
    if (freshStart && _pairedBefore()) {
      _timer?.cancel();
      _timer = Timer(grace, () {
        _timer = null;
        if (!_heldSinceStart) _suspected.value = true;
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _suspected.value = false;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _suspected.dispose();
  }
}
