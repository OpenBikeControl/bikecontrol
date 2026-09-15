import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:prop/emulators/dircon_emulator.dart';

import 'sensor_hub.dart';
import 'sensor_quantity.dart';
import 'sensor_sink_controller.dart';

/// Keeps a [SensorSinkController] in sync with two things: whether the
/// bridge is running, and whether the rider has selected a source for ANY
/// quantity — heart rate, cadence or power.
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
/// Pulled out of `connection.dart` for the same reason [SensorSinkController]
/// and the binding it feeds are: that file cannot be constructed in a unit
/// test, and this rule is worth one.
class SensorSinkSync {
  SensorSinkSync({required this.hub, required this.isBridgeRunning, required this.sink});

  final SensorHub hub;
  final ValueListenable<bool> isBridgeRunning;
  final SensorSinkController sink;

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
    final mode = !hasSource
        ? SensorSinkMode.none
        : isBridgeRunning.value
        ? SensorSinkMode.bridge
        : SensorSinkMode.standalone;
    return sink.onSinkStateChanged(
      mode: mode,
      // Bluetooth, all three quantities: identical to today's behaviour.
      // Real transport/quantity gating lands in a later task.
      standalone: mode == SensorSinkMode.standalone
          ? const StandaloneRequest(
              transport: RetrofitMode.bluetooth,
              exposed: {SensorQuantity.heartRate, SensorQuantity.cadence, SensorQuantity.power},
            )
          : null,
    );
  }

  void dispose() {
    if (!_started) return;
    isBridgeRunning.removeListener(sync);
    hub.onSelectionChanged = null;
    _started = false;
  }
}
