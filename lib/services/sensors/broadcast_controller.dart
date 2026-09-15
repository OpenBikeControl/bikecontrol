import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:prop/emulators/dircon_emulator.dart';

import 'package:bike_control/main.dart';
import 'package:bike_control/utils/settings/settings.dart';

import 'sensor_hub.dart';
import 'sensor_quantity.dart';

/// The Broadcast switch for the no-trainer path. Owns the one decision that
/// costs anything — connecting sources (a HealthKit workout session, strap
/// links) and standing up the standalone advertisement — so nothing runs
/// until the rider asks, and everything stops when they say so.
///
/// `isOn` is deliberately NOT persisted: a ride is an explicit act. The
/// transport is.
class BroadcastController {
  BroadcastController({
    required this.hub,
    required Settings settings,
    required this.connectSource,
    required this.disconnectSource,
    required this.isBridgeRunning,
    required this.isStandaloneRunning,
  }) : _settings = settings,
       _transport = ValueNotifier(settings.getSensorsTransport());

  final SensorHub hub;
  final Settings _settings;
  final Future<void> Function(String sourceId) connectSource;
  final Future<void> Function(String sourceId) disconnectSource;
  final ValueListenable<bool> isBridgeRunning;

  /// Whether the standalone sink is actually up (`SensorSinkController
  /// .standaloneRunning`). The sink swallows a start failure into
  /// `recordError`, so `onChanged` returning is not proof of anything —
  /// [turnOn] asks this afterwards and rolls back if nothing is serving.
  final bool Function() isStandaloneRunning;

  final _isOn = ValueNotifier<bool>(false);
  final ValueNotifier<RetrofitMode> _transport;
  bool _resumeAfterBridge = false;
  bool _started = false;
  VoidCallback? _previousSelectionHook;
  VoidCallback? _chainedSelectionHook;

  /// Re-syncs the sink to this controller's state. Awaited by [turnOn] so
  /// the standalone start it triggers has finished (or failed) before the
  /// switch reports success — see [isStandaloneRunning].
  Future<void> Function()? onChanged;

  /// Source ids this controller has actually asked to connect — this
  /// controller's own notion of "connected" (consent it granted via
  /// [connectSource]), independent of `hub.sources` (which only means
  /// "registered with the hub for readings" and, in practice, is populated
  /// well before — or entirely without ever going through — [connectSource]).
  /// Survives a bridge episode untouched so resume can skip redundant
  /// reconnects; cleared per-id only on an explicit [disconnectSource] call
  /// (rollback, [turnOff], or a deselection).
  final Set<String> _connectedIds = {};

  ValueListenable<bool> get isOn => _isOn;
  ValueListenable<RetrofitMode> get transport => _transport;
  Set<String> get selectedSourceIds => {for (final q in SensorQuantity.values) if (hub.selectionFor(q) case final id?) id};
  Set<SensorQuantity> get selectedQuantities => {for (final q in SensorQuantity.values) if (hub.selectionFor(q) != null) q};
  bool get wantsStandalone => _isOn.value && selectedSourceIds.isNotEmpty && !isBridgeRunning.value;

  /// Registers for bridge-state and selection-change updates. Idempotent —
  /// mirrors `SensorSinkSync.start`, since a second call would otherwise
  /// double-add the bridge listener and clobber [_previousSelectionHook]
  /// with the wrapper this controller installed on the first call.
  void start() {
    if (_started) return;
    _started = true;
    isBridgeRunning.addListener(_onBridgeChanged);
    // Chain, don't replace: SensorSinkSync already owns hub.onSelectionChanged.
    _previousSelectionHook = hub.onSelectionChanged;
    _chainedSelectionHook = () {
      _previousSelectionHook?.call();
      unawaited(
        _onSelectionChanged().catchError(
          (Object e, StackTrace s) => recordError(e, s, context: 'BroadcastController.selection'),
        ),
      );
    };
    hub.onSelectionChanged = _chainedSelectionHook;
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    isBridgeRunning.removeListener(_onBridgeChanged);
    // Only restore the previous hook if nothing has replaced this
    // controller's wrapper since — otherwise a later owner's hook would be
    // clobbered by our now-stale reference to whatever preceded us.
    if (identical(hub.onSelectionChanged, _chainedSelectionHook)) {
      hub.onSelectionChanged = _previousSelectionHook;
    }
  }

  Future<void> turnOn() async {
    final ids = selectedSourceIds.toList();
    if (ids.isEmpty || _isOn.value) return;
    final newlyConnected = <String>[]; // only what THIS call connected — rollback scope
    try {
      for (final id in ids) {
        if (_connectedIds.contains(id)) continue; // e.g. resumed after a bridge episode — still registered
        await connectSource(id);
        _connectedIds.add(id);
        newlyConnected.add(id);
      }
    } catch (e, s) {
      await recordError(e, s, context: 'BroadcastController.turnOn');
      // Each rollback disconnect gets its own try/catch: a source that
      // refuses to disconnect must not mask the original connect failure or
      // stop the rest of the rollback — the switch never lies about what's
      // actually connected.
      for (final id in newlyConnected) {
        try {
          await disconnectSource(id);
        } catch (rollbackError, rollbackStack) {
          await recordError(rollbackError, rollbackStack, context: 'BroadcastController.rollback');
        }
        _connectedIds.remove(id);
      }
      rethrow;
    }
    _isOn.value = true;
    await onChanged?.call();
    // With the bridge running the sources ride on the trainer's own
    // advertisement; otherwise the standalone sink has to have come up, or
    // the switch would read "Live" with nothing advertised.
    if (!isBridgeRunning.value && !isStandaloneRunning()) {
      await turnOff();
      throw StateError('standalone sink did not start');
    }
  }

  Future<void> turnOff() async {
    if (!_isOn.value) return;
    _isOn.value = false;
    await onChanged?.call(); // sink stops first, then the sources
    for (final id in _connectedIds.toList()) {
      await disconnectSource(id);
      _connectedIds.remove(id);
    }
  }

  Future<void> setTransport(RetrofitMode mode) async {
    if (mode == RetrofitMode.proxy) throw ArgumentError('proxy is not a sensor transport');
    _transport.value = mode;
    await _settings.setSensorsTransport(mode);
    await onChanged?.call();
  }

  Future<void> _onSelectionChanged() async {
    if (!_isOn.value) return;
    final ids = selectedSourceIds;
    if (ids.isEmpty) {
      await turnOff();
      return;
    }
    // Drop sources the rider no longer wants...
    for (final id in _connectedIds.toList()) {
      if (!ids.contains(id)) {
        await disconnectSource(id);
        _connectedIds.remove(id);
      }
    }
    // ...and serve a newly selected one now; already-connected ones are a no-op.
    for (final id in ids) {
      if (!_connectedIds.contains(id)) {
        await connectSource(id);
        _connectedIds.add(id);
      }
    }
    await onChanged?.call();
  }

  void _onBridgeChanged() {
    if (isBridgeRunning.value) {
      _resumeAfterBridge = _isOn.value;
      if (_isOn.value) {
        _isOn.value = false;
        unawaited(
          onChanged?.call().catchError(
            (Object e, StackTrace s) => recordError(e, s, context: 'BroadcastController.bridgeStarted'),
          ),
        );
      }
    } else if (_resumeAfterBridge) {
      _resumeAfterBridge = false;
      unawaited(turnOn().catchError((Object e, StackTrace s) => recordError(e, s, context: 'BroadcastController.resume')));
    }
  }
}
