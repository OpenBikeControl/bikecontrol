import 'package:bike_control/main.dart' show recordError;
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/sensor_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';

import 'sensor_quantity.dart';

/// Where [SensorSinkController] should currently be serving [SensorDefinition]
/// from.
enum SensorSinkMode {
  /// Attached to the shared bridge composite.
  bridge,

  /// Served by its own standalone emulator.
  standalone,

  /// Attached nowhere — no source is selected, so there is nothing to serve.
  ///
  /// Deliberately distinct from [bridge] rather than folded into it: a
  /// [SensorDefinition] left attached to the bridge composite with nothing to
  /// publish keeps that composite's `children` non-empty forever, which stops
  /// the bridge's own "nothing is using me any more" shutdown check
  /// (`ProxyDevice._stopFtmsEmulatorIfUnused`) from ever firing — the bridge
  /// would keep advertising after the trainer disconnects. `none` genuinely
  /// detaches/stops, so an unrelated composite can tell it is truly unused.
  none,
}

/// What a standalone stint should look like. Value-equal so the controller
/// can tell "same as running" from "needs a restart": the transport
/// snapshots the definition's services when it starts, never mid-session.
class StandaloneRequest {
  const StandaloneRequest({required this.transport, required this.exposed});

  final RetrofitMode transport;
  final Set<SensorQuantity> exposed;

  @override
  bool operator ==(Object other) =>
      other is StandaloneRequest && other.transport == transport && setEquals(other.exposed, exposed);

  @override
  int get hashCode => Object.hash(transport, Object.hashAllUnordered(exposed));
}

/// Decides where the sensor services are served from.
///
/// There is one process-wide GATT server and one advertisement, so the sink
/// is never attached in two places at once: it rides the bridge's composite,
/// owns a standalone emulator, or — when nothing is selected — sits in
/// neither. Callbacks rather than concrete emulator types keep the decision
/// testable without a BLE stack.
class SensorSinkController {
  SensorSinkController({
    required this.definition,
    required this.attach,
    required this.detach,
    required this.startStandalone,
    required this.stopStandalone,
  });

  final SensorDefinition definition;
  final Future<void> Function(SensorDefinition) attach;
  final Future<void> Function(SensorDefinition) detach;
  final Future<void> Function(SensorDefinition, RetrofitMode transport) startStandalone;
  final Future<void> Function() stopStandalone;

  bool _attached = false;
  bool _standalone = false;
  SensorSinkMode? _lastMode;
  StandaloneRequest? _lastStandalone;

  /// Serialises transitions. Sink state flaps, and a second call arriving
  /// while the first is suspended at an `await` would sail past the
  /// idempotency guard — leaving the sink attached AND standalone, which is
  /// the one thing this class exists to prevent.
  Future<void> _inFlight = Future<void>.value();

  bool get attachedToComposite => _attached;
  bool get standaloneRunning => _standalone;

  /// The mode/standalone request from the last transition actually applied.
  /// Distinct from [attachedToComposite]/[standaloneRunning] (which alone
  /// can't tell `none` from "not yet synced") — lets a test assert exactly
  /// what a caller (e.g. `SensorSinkSync`) computed and handed over.
  SensorSinkMode? get lastMode => _lastMode;
  StandaloneRequest? get lastRequest => _lastStandalone;

  Future<void> onSinkStateChanged({required SensorSinkMode mode, StandaloneRequest? standalone}) {
    assert(
      mode != SensorSinkMode.standalone || standalone != null,
      'standalone must be provided when mode is SensorSinkMode.standalone',
    );
    _inFlight = _inFlight.then((_) => _apply(mode, standalone));
    return _inFlight;
  }

  Future<void> _apply(SensorSinkMode mode, StandaloneRequest? standalone) async {
    if (_lastMode == mode && (mode != SensorSinkMode.standalone || _lastStandalone == standalone)) return;
    // Entering a transition means there is no known-good state any more: the
    // branches below mutate (`detach`, `_attached = false`) BEFORE the fallible
    // await, so a throw can leave the sink half torn down. Nulling the guard
    // here means any later call — for any target — retries instead of being
    // swallowed as a no-op and leaving the sink served nowhere.
    _lastMode = null;
    try {
      if (mode == SensorSinkMode.bridge) {
        if (_standalone) {
          await stopStandalone();
          _standalone = false;
        }
        // Before attach: CompositeBleDefinition.attach() diffs serviceUUIDs
        // before/after to decide whether the transport needs restarting to
        // advertise the change. Retracting first means that diff — and
        // whatever it (re)advertises — never includes CSC/Cycling Power in
        // the first place, rather than leaking them in and never correcting
        // it (see SensorDefinition.exposeServices's doc comment for the
        // defect this fixes).
        definition.exposeServices(heartRate: true, cadence: false, power: false);
        await attach(definition);
        _attached = true;
        _lastStandalone = null;
      } else if (mode == SensorSinkMode.standalone) {
        final request = standalone!;
        if (_attached) {
          await detach(definition);
          _attached = false;
        }
        // A running stint with a different transport or service set cannot be
        // patched in place — the transport already snapshotted the old
        // services (see SensorDefinition.exposeServices). Stop, then start.
        if (_standalone && _lastStandalone != request) {
          await stopStandalone();
          _standalone = false;
        }
        if (!_standalone) {
          // Before startStandalone: StandaloneSensorLifecycle.start attaches
          // this definition to its own composite and immediately starts the
          // transport, advertising whatever serviceUUIDs says at that moment —
          // exposing first means a rider whose trainer just dropped sees
          // cadence/power come back on this very first advertisement, not
          // lost until some later event.
          definition.exposeServices(
            heartRate: request.exposed.contains(SensorQuantity.heartRate),
            cadence: request.exposed.contains(SensorQuantity.cadence),
            power: request.exposed.contains(SensorQuantity.power),
          );
          await startStandalone(definition, request.transport);
          _standalone = true;
        }
        _lastStandalone = request;
      } else {
        // SensorSinkMode.none: served nowhere.
        if (_attached) {
          await detach(definition);
          _attached = false;
        }
        if (_standalone) {
          await stopStandalone();
          _standalone = false;
        }
        _lastStandalone = null;
      }
      _lastMode = mode;
    } catch (e, s) {
      await recordError(e, s, context: 'SensorSinkController');
    }
  }
}
