import 'dart:async';

import 'package:flutter/foundation.dart';

import 'broadcast_controller.dart';
import 'sensor_hub.dart';
import 'sensor_quantity.dart';
import 'sensor_sink_controller.dart';

/// Keeps a [SensorSinkController] in sync with three things: whether the
/// bridge is running, whether the rider has selected a source for ANY
/// quantity — heart rate, cadence or power — and whether the Broadcast
/// switch ([BroadcastController.isOn]) is on.
///
/// The second half matters on its own, in two ways. Without it, BikeControl
/// would start advertising itself as a heart rate monitor the moment it
/// launches — before the rider has picked any source and with no reading to
/// send. A monitor that never reports a value reads as broken hardware, not
/// as "nothing chosen yet." And checking heart rate specifically, rather than
/// any quantity, would leave a rider who picked only a cadence or power
/// source with the definition attached nowhere at all — the selection would
/// sit in the hub looking valid while never reaching anything.
///
/// "No source selected" maps to [SensorSinkMode.none], NOT [SensorSinkMode
/// .bridge]. An earlier version of this class folded "no source" into
/// `bridgeRunning: true` because the two looked equivalent — neither stands
/// up a standalone peripheral — but they are not interchangeable: `bridge`
/// actually attaches [SensorDefinition] to the shared trainer-bridge
/// composite, and a value-less definition left attached there forever keeps
/// that composite's `children` non-empty, which stops
/// `ProxyDevice._stopFtmsEmulatorIfUnused` from ever seeing it as unused —
/// the bridge would keep advertising after the trainer disconnected. `none`
/// is genuinely attached nowhere, which is what "nothing selected" means.
///
/// This also doubles as the retry path for a standalone start that failed at
/// launch (e.g. BLE permission not granted yet): [hub]'s
/// `onSelectionChanged` re-syncs on every selection change, not only on
/// bridge transitions, so picking (or re-picking) a source tries again.
///
/// Bridge beats the Broadcast switch, not the other way round: a selection
/// with the bridge running attaches to the shared composite regardless of
/// whether [BroadcastController.isOn] is on — the switch only governs the
/// no-trainer, standalone path. And a standalone stint is never started
/// merely because a source is selected any more: [broadcast] must actually
/// be on ([BroadcastController.wantsStandalone]) or nothing is served at
/// all, which is what keeps a cold launch (Broadcast off by default, see
/// that class's own doc comment) from standing up an unwanted "BikeControl"
/// advertisement the instant a persisted selection loads.
///
/// Pulled out of `connection.dart` for the same reason [SensorSinkController]
/// and the binding it feeds are: that file cannot be constructed in a unit
/// test, and this rule is worth one.
class SensorSinkSync {
  SensorSinkSync({required this.hub, required this.isBridgeRunning, required this.sink, required this.broadcast});

  final SensorHub hub;
  final ValueListenable<bool> isBridgeRunning;
  final SensorSinkController sink;
  final BroadcastController broadcast;

  bool _started = false;

  /// Registers for bridge-state and selection-change updates and performs an
  /// initial sync. Idempotent.
  void start() {
    if (_started) return;
    _started = true;
    isBridgeRunning.addListener(sync);
    hub.onSelectionChanged = sync;
    unawaited(sync());
  }

  /// Recomputes the effective sink mode and applies it to [sink].
  ///
  /// Returns the `Future` (rather than being `void` and firing-and-forgetting
  /// internally) so a test can await one deterministic sync instead of
  /// pumping the event loop after [start].
  Future<void> sync() {
    // ANY quantity counts, not just heart rate: a rider who picks a cadence
    // or power source and never touches heart rate still needs the
    // definition attached somewhere, or that selection silently does
    // nothing. See this class's own doc comment for why "nothing selected"
    // must resolve to `none` rather than `bridge`.
    final hasSource = SensorQuantity.values.any((q) => hub.selectionFor(q) != null);
    // Bridge wins outright — checked first and independent of the Broadcast
    // switch, see this class's own doc comment for why.
    if (hasSource && isBridgeRunning.value) {
      return sink.onSinkStateChanged(mode: SensorSinkMode.bridge);
    }
    // Otherwise standalone only while the rider has explicitly asked for it:
    // [BroadcastController.wantsStandalone] already folds in "is on" AND "has
    // a selection" AND "bridge isn't running", so nothing further to check
    // here beyond handing over its transport and the quantities it selected.
    if (broadcast.wantsStandalone) {
      return sink.onSinkStateChanged(
        mode: SensorSinkMode.standalone,
        standalone: StandaloneRequest(transport: broadcast.transport.value, exposed: broadcast.selectedQuantities),
      );
    }
    return sink.onSinkStateChanged(mode: SensorSinkMode.none);
  }

  void dispose() {
    if (!_started) return;
    isBridgeRunning.removeListener(sync);
    hub.onSelectionChanged = null;
    _started = false;
  }
}
