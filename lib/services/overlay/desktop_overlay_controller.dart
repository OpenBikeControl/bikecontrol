import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:bike_control/services/overlay/desktop_overlay_window.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:multi_window_native/multi_window_native.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// Desktop trainer overlay backed by `multi_window_native`.
///
/// State flows main → overlay via [kStateMethod] broadcasts; user gestures
/// (mode toggle, +/-) flow overlay → main via [kOverlayActionMethod].
class DesktopOverlayController implements TrainerOverlayController {
  static const _minPushIntervalMs = 100; // ~10 Hz

  final ValueNotifier<bool> _showing = ValueNotifier(false);
  @override
  ValueListenable<bool> get isShowing => _showing;

  /// Sub-window id reported back via [kOverlayReadyMethod]. `null` until the
  /// overlay engine has booted and announced itself.
  int? _overlayWindowId;

  FitnessBikeDefinition? _def;
  Listenable? _bound;
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  TrainerOverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Listener ids returned by `registerListener`, used to clean up on hide.
  final List<({String method, String id})> _listenerIds = [];

  @override
  Future<OverlayShowResult> show(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    if (_showing.value) return const OverlayShowResult.ok();

    _registerMainListeners(def);

    final saved = core.settings.getOverlayPosition();
    final argsJson = jsonEncode({
      if (saved != null) ...{'x': saved.dx, 'y': saved.dy},
    });

    try {
      // Args layout matches the multi_window_native convention:
      //   [routeName, argsJson, themeMode]
      await MultiWindowNative.createWindow([
        'trainer-overlay',
        argsJson,
        'light',
      ]);
    } catch (e) {
      _unregisterMainListeners();
      return OverlayShowResult.fail(
        OverlayShowFailure.unknown,
        message: 'Failed to open overlay window: $e',
      );
    }

    _def = def;
    _fields = fields;
    _bind();
    _showing.value = true;
    _push(force: true);
    return const OverlayShowResult.ok();
  }

  @override
  Future<void> hide() async {
    _bound?.removeListener(_onChange);
    _bound = null;
    _def = null;
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
      } catch (_) {}
      _overlayWindowId = null;
    }

    _unregisterMainListeners();
    _showing.value = false;
  }

  @override
  void updateFields(Set<OverlayField> fields) {
    _fields = fields;
    _push(force: true);
  }

  void _registerMainListeners(FitnessBikeDefinition def) {
    _unregisterMainListeners();

    _listenerIds.add((
      method: kOverlayReadyMethod,
      id: MultiWindowNative.registerListener(kOverlayReadyMethod, (call) async {
        try {
          final m = _asMap(call.arguments);
          final wid = (m['windowId'] as num?)?.toInt();
          if (wid != null) _overlayWindowId = wid;
        } catch (_) {}
      }),
    ));

    _listenerIds.add((
      method: kOverlayActionMethod,
      id: MultiWindowNative.registerListener(kOverlayActionMethod, (call) async {
        try {
          final m = _asMap(call.arguments);
          final action = m['action'];
          if (action is! String) return;
          switch (action) {
            case 'toggleMode':
              if (def.trainerMode.value == TrainerMode.ergMode) {
                def.exitErgMode();
              } else {
                def.setManualErgPower(def.ergTargetPower.value ?? 150);
              }
              break;
            case 'primaryDecrement':
              _adjustPrimary(def, increment: false);
              break;
            case 'primaryIncrement':
              _adjustPrimary(def, increment: true);
              break;
          }
        } catch (_) {}
      }),
    ));

    _listenerIds.add((
      method: kOverlayPositionMethod,
      id: MultiWindowNative.registerListener(kOverlayPositionMethod, (call) async {
        try {
          final m = _asMap(call.arguments);
          await core.settings.setOverlayPosition(Offset(
            (m['x'] as num).toDouble(),
            (m['y'] as num).toDouble(),
          ));
        } catch (_) {}
      }),
    ));
  }

  void _unregisterMainListeners() {
    for (final e in _listenerIds) {
      MultiWindowNative.unregisterListener(methodName: e.method, id: e.id);
    }
    _listenerIds.clear();
  }

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
    try {
      await MultiWindowNative.notifyAllWindows(
        kStateMethod,
        jsonEncode(s.toJson()),
      );
    } catch (_) {}
  }
}
