import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/overlay/desktop_overlay_window.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:multi_window_native/multi_window_native.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// Desktop trainer overlay controller.
///
/// Uses `multi_window_native` (MultiWindowNative.createWindow /
/// notifyAllWindows / registerListener) on both macOS and Windows.
class DesktopOverlayController implements TrainerOverlayController {
  static const _minPushIntervalMs = 100; // ~10 Hz

  final ValueNotifier<bool> _showing = ValueNotifier(false);
  @override
  ValueListenable<bool> get isShowing => _showing;

  FitnessBikeDefinition? _def;
  LiveDefinitionLookup? _liveDef;
  Listenable? _bound;
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  TrainerOverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ---------------------------------------------------------------------------
  // State (multi_window_native)
  // ---------------------------------------------------------------------------

  /// Sub-window id reported back via [kOverlayReadyMethod].
  int? _overlayWindowId;

  /// Listener ids returned by `registerListener`, used to clean up on hide.
  final List<({String method, String id})> _listenerIds = [];

  // ---------------------------------------------------------------------------
  // TrainerOverlayController interface
  // ---------------------------------------------------------------------------

  @override
  Future<OverlayShowResult> show(
    FitnessBikeDefinition def,
    Set<OverlayField> fields, {
    LiveDefinitionLookup? liveDef,
  }) async {
    _liveDef = liveDef;
    if (_showing.value) return const OverlayShowResult.ok();
    return _showOverlay(def, fields);
  }

  @override
  Future<void> hide() async {
    await _hideOverlay();
  }

  @override
  void updateFields(Set<OverlayField> fields) {
    _fields = fields;
    _push(force: true);
  }

  // ---------------------------------------------------------------------------
  // Implementation (multi_window_native)
  // ---------------------------------------------------------------------------

  Future<OverlayShowResult> _showOverlay(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    _registerListeners(def);

    final saved = core.settings.getOverlayPosition();
    final argsJson = jsonEncode({
      if (saved != null) ...{'x': saved.dx, 'y': saved.dy},
    });

    try {
      // Args layout matches the multi_window_native convention:
      //   [routeName, argsJson, themeMode]
      MultiWindowNative.createWindow([
        'trainer-overlay',
        argsJson,
        'light',
      ]);
    } catch (e, s) {
      recordError(e, s, context: 'overlay.controller.createWindow');
      _unregisterListeners();
      return OverlayShowResult.fail(
        OverlayShowFailure.unknown,
        message: 'Failed to open overlay window: $e',
      );
    }

    _def = def;
    _fields = fields;
    _bind();
    _showing.value = true;
    // Initial push happens on the kOverlayReadyMethod handler, once the
    // sub-engine has registered its kStateMethod listener.
    return const OverlayShowResult.ok();
  }

  Future<void> _hideOverlay() async {
    _bound?.removeListener(_onChange);
    _bound = null;
    _def = null;
    _liveDef = null;
    _pushDebounce?.cancel();
    _pushDebounce = null;
    _lastPushed = null;

    final id = _overlayWindowId;
    if (id != null) {
      try {
        await MultiWindowNative.closeWindow(
          isMainWindow: false,
          windowId: id.toString(),
        );
      } catch (e, s) {
        recordError(e, s, context: 'overlay.controller.hide.closeWindow');
      }
      _overlayWindowId = null;
    }

    _unregisterListeners();
    _showing.value = false;
  }

  void _registerListeners(FitnessBikeDefinition def) {
    _unregisterListeners();

    _listenerIds.add((
      method: kOverlayReadyMethod,
      id: MultiWindowNative.registerListener(kOverlayReadyMethod, (call) async {
        try {
          final m = _asMap(call.arguments);
          final wid = (m['windowId'] as num?)?.toInt();
          if (wid != null) _overlayWindowId = wid;
        } catch (e, s) {
          recordError(e, s, context: 'overlay.controller.ready.decode');
        }
        // The sub-engine has just registered its kStateMethod listener.
        // Push the current state now — the original `_push(force: true)`
        // from show() races the engine boot and is dropped.
        _push(force: true);
      }),
    ));

    _listenerIds.add((
      method: kOverlayActionMethod,
      id: MultiWindowNative.registerListener(kOverlayActionMethod,
          (call) async {
        try {
          final m = _asMap(call.arguments);
          final action = m['action'];
          if (action is! String) return;
          // Re-resolve the live definition on every action — the trainer
          // emulator rebinds a new `FitnessBikeDefinition` whenever its
          // transport restarts (e.g. when a trainer app connects), so the
          // `def` captured at show() time can already be stale.
          final live = _liveDef?.call() ?? def;
          switch (action) {
            case 'toggleMode':
              if (live.trainerMode.value == TrainerMode.ergMode) {
                live.exitErgMode();
              } else {
                live.setManualErgPower(live.ergTargetPower.value ?? 150);
              }
              break;
            case 'primaryDecrement':
              _adjustPrimary(live, increment: false);
              break;
            case 'primaryIncrement':
              _adjustPrimary(live, increment: true);
              break;
          }
        } catch (e, s) {
          recordError(e, s, context: 'overlay.controller.action.dispatch');
        }
      }),
    ));

    _listenerIds.add((
      method: kOverlayPositionMethod,
      id: MultiWindowNative.registerListener(kOverlayPositionMethod,
          (call) async {
        try {
          final m = _asMap(call.arguments);
          await core.settings.setOverlayPosition(
            Offset(
              (m['x'] as num).toDouble(),
              (m['y'] as num).toDouble(),
            ),
          );
        } catch (e, s) {
          recordError(e, s, context: 'overlay.controller.positionChanged');
        }
      }),
    ));

    _listenerIds.add((
      method: kOverlayClosedMethod,
      id: MultiWindowNative.registerListener(kOverlayClosedMethod,
          (call) async {
        // The sub-window closed itself (user clicked the traffic-light close
        // button). Clean up local state without trying to close it again.
        _cleanupAfterClose();
      }),
    ));
  }

  /// Cleanup that mirrors `_hideOverlay()` but skips `MultiWindowNative.closeWindow`
  /// — used when the sub-window closed itself.
  void _cleanupAfterClose() {
    if (!_showing.value) return;
    _bound?.removeListener(_onChange);
    _bound = null;
    _def = null;
    _liveDef = null;
    _pushDebounce?.cancel();
    _pushDebounce = null;
    _lastPushed = null;
    _overlayWindowId = null;
    _unregisterListeners();
    _showing.value = false;
  }

  void _unregisterListeners() {
    for (final e in _listenerIds) {
      MultiWindowNative.unregisterListener(methodName: e.method, id: e.id);
    }
    _listenerIds.clear();
  }

  Future<void> _pushOverlay(TrainerOverlayState s) async {
    try {
      await MultiWindowNative.notifyAllWindows(
        kStateMethod,
        jsonEncode(s.toJson()),
      );
    } catch (e, stack) {
      recordError(e, stack, context: 'overlay.controller.state.push');
    }
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is String) return jsonDecode(raw) as Map<String, dynamic>;
    return Map<String, dynamic>.from(raw as Map);
  }

  /// Shift a gear (SIM mode) or step the ERG target power by 5 W.
  void _adjustPrimary(FitnessBikeDefinition def, {required bool increment}) {
    if (def.trainerMode.value == TrainerMode.ergMode) {
      final current = def.ergTargetPower.value ?? 150;
      final next = (current + (increment ? 5 : -5)).clamp(0, 500);
      def.setManualErgPower(next);
    } else {
      if (increment) {
        def.shiftUp();
      } else {
        def.shiftDown();
      }
    }
  }

  void _bind() {
    final def = _def;
    if (def == null) return;
    _bound?.removeListener(_onChange);
    _bound = Listenable.merge([
      def.currentGear,
      def.gearRatio,
      def.trainerMode,
      def.powerW,
      def.cadenceRpm,
      def.ergTargetPower,
    ]);
    _bound!.addListener(_onChange);
  }

  void _onChange() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastPushAt).inMilliseconds;
    if (elapsed >= _minPushIntervalMs) {
      _push();
      return;
    }
    _pushDebounce ??= Timer(
      Duration(milliseconds: _minPushIntervalMs - elapsed),
      () {
        _pushDebounce = null;
        _push();
      },
    );
  }

  Future<void> _push({bool force = false}) async {
    final def = _def;
    if (def == null) return;
    final s = TrainerOverlayState(
      gear: def.currentGear.value,
      maxGear: def.maxGear,
      gearRatio: def.gearRatio.value,
      mode: def.trainerMode.value,
      powerW: def.powerW.value,
      cadenceRpm: def.cadenceRpm.value,
      ergTargetW: def.ergTargetPower.value,
      fields: _fields,
    );
    if (!force && s == _lastPushed) return;
    _lastPushed = s;
    _lastPushAt = DateTime.now();
    await _pushOverlay(s);
  }
}
