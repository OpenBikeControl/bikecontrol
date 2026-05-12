import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:bike_control/services/overlay/desktop_overlay_window.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/utils/core.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/foundation.dart';
import 'package:multi_window_native/multi_window_native.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// Desktop trainer overlay controller.
///
/// On **Windows** it uses `desktop_multi_window` (WindowController.create /
/// WindowMethodChannel). On **macOS** it uses `multi_window_native`
/// (MultiWindowNative.createWindow / notifyAllWindows / registerListener).
class DesktopOverlayController implements TrainerOverlayController {
  static const _minPushIntervalMs = 100; // ~10 Hz

  final ValueNotifier<bool> _showing = ValueNotifier(false);
  @override
  ValueListenable<bool> get isShowing => _showing;

  FitnessBikeDefinition? _def;
  Listenable? _bound;
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  TrainerOverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ---------------------------------------------------------------------------
  // Windows state (desktop_multi_window)
  // ---------------------------------------------------------------------------

  /// Sub-window controller on Windows. Null until the overlay is shown.
  dmw.WindowController? _dmwWindow;

  /// Channel to communicate with the overlay sub-window on Windows.
  final _dmwChannel = dmw.WindowMethodChannel(
    kOverlayChannel,
    mode: dmw.ChannelMode.bidirectional,
  );

  // ---------------------------------------------------------------------------
  // macOS state (multi_window_native)
  // ---------------------------------------------------------------------------

  /// Sub-window id reported back via [kOverlayReadyMethod] on macOS.
  int? _overlayWindowId;

  /// Listener ids returned by `registerListener`, used to clean up on hide.
  final List<({String method, String id})> _macListenerIds = [];

  // ---------------------------------------------------------------------------
  // TrainerOverlayController interface
  // ---------------------------------------------------------------------------

  @override
  Future<OverlayShowResult> show(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    if (_showing.value) return const OverlayShowResult.ok();

    if (Platform.isWindows) {
      return _showWindows(def, fields);
    } else {
      return _showMacOS(def, fields);
    }
  }

  @override
  Future<void> hide() async {
    if (Platform.isWindows) {
      await _hideWindows();
    } else {
      await _hideMacOS();
    }
  }

  @override
  void updateFields(Set<OverlayField> fields) {
    _fields = fields;
    _push(force: true);
  }

  // ---------------------------------------------------------------------------
  // Windows implementation
  // ---------------------------------------------------------------------------

  Future<OverlayShowResult> _showWindows(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    // Register the main-window side of the shared channel BEFORE creating the
    // sub-window so that any calls from the overlay land here immediately.
    _registerWindowsHandlers(def);

    final saved = core.settings.getOverlayPosition();
    final argsJson = jsonEncode({
      'role': 'trainer-overlay',
      if (saved != null) ...{'x': saved.dx, 'y': saved.dy},
    });

    try {
      final controller = await dmw.WindowController.create(
        dmw.WindowConfiguration(
          arguments: argsJson,
          hiddenAtLaunch: true,
        ),
      );
      _dmwWindow = controller;
      await controller.show();
    } catch (e) {
      _unregisterWindowsHandlers();
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

  Future<void> _hideWindows() async {
    _bound?.removeListener(_onChange);
    _bound = null;
    _def = null;
    _pushDebounce?.cancel();
    _pushDebounce = null;
    _lastPushed = null;

    final w = _dmwWindow;
    if (w != null) {
      try {
        await w.invokeMethod<void>('close');
      } catch (_) {}
      _dmwWindow = null;
    }

    _unregisterWindowsHandlers();
    _showing.value = false;
  }

  void _registerWindowsHandlers(FitnessBikeDefinition def) {
    _dmwChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'toggleMode':
          if (def.trainerMode.value == TrainerMode.ergMode) {
            def.exitErgMode();
          } else {
            def.setManualErgPower(def.ergTargetPower.value ?? 150);
          }
          return null;
        case 'primaryDecrement':
          _adjustPrimary(def, increment: false);
          return null;
        case 'primaryIncrement':
          _adjustPrimary(def, increment: true);
          return null;
        case 'positionChanged':
          try {
            final m = Map<String, dynamic>.from(call.arguments as Map);
            await core.settings.setOverlayPosition(Offset(
              (m['x'] as num).toDouble(),
              (m['y'] as num).toDouble(),
            ));
          } catch (_) {}
          return null;
        default:
          return null;
      }
    });
  }

  void _unregisterWindowsHandlers() {
    try {
      _dmwChannel.setMethodCallHandler(null);
    } catch (_) {}
  }

  Future<void> _pushWindows(TrainerOverlayState s) async {
    final w = _dmwWindow;
    if (w == null) return;
    try {
      await w.invokeMethod<void>('state', jsonEncode(s.toJson()));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // macOS implementation (multi_window_native)
  // ---------------------------------------------------------------------------

  Future<OverlayShowResult> _showMacOS(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    _registerMacOSListeners(def);

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
    } catch (e) {
      _unregisterMacOSListeners();
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

  Future<void> _hideMacOS() async {
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

    _unregisterMacOSListeners();
    _showing.value = false;
  }

  void _registerMacOSListeners(FitnessBikeDefinition def) {
    _unregisterMacOSListeners();

    _macListenerIds.add((
      method: kOverlayReadyMethod,
      id: MultiWindowNative.registerListener(kOverlayReadyMethod, (call) async {
        try {
          final m = _asMap(call.arguments);
          final wid = (m['windowId'] as num?)?.toInt();
          if (wid != null) _overlayWindowId = wid;
        } catch (_) {}
        // The sub-engine has just registered its kStateMethod listener.
        // Push the current state now — the original `_push(force: true)`
        // from show() races the engine boot and is dropped.
        _push(force: true);
      }),
    ));

    _macListenerIds.add((
      method: kOverlayActionMethod,
      id: MultiWindowNative.registerListener(kOverlayActionMethod,
          (call) async {
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

    _macListenerIds.add((
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
        } catch (_) {}
      }),
    ));

    _macListenerIds.add((
      method: kOverlayClosedMethod,
      id: MultiWindowNative.registerListener(kOverlayClosedMethod,
          (call) async {
        // The sub-window closed itself (user clicked the traffic-light close
        // button). Clean up local state without trying to close it again.
        _cleanupAfterMacOSClose();
      }),
    ));
  }

  /// Cleanup that mirrors `_hideMacOS()` but skips `MultiWindowNative.closeWindow`
  /// — used when the sub-window closed itself.
  void _cleanupAfterMacOSClose() {
    if (!_showing.value) return;
    _bound?.removeListener(_onChange);
    _bound = null;
    _def = null;
    _pushDebounce?.cancel();
    _pushDebounce = null;
    _lastPushed = null;
    _overlayWindowId = null;
    _unregisterMacOSListeners();
    _showing.value = false;
  }

  void _unregisterMacOSListeners() {
    for (final e in _macListenerIds) {
      MultiWindowNative.unregisterListener(methodName: e.method, id: e.id);
    }
    _macListenerIds.clear();
  }

  Future<void> _pushMacOS(TrainerOverlayState s) async {
    try {
      await MultiWindowNative.notifyAllWindows(
        kStateMethod,
        jsonEncode(s.toJson()),
      );
    } catch (_) {}
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

    if (Platform.isWindows) {
      await _pushWindows(s);
    } else {
      await _pushMacOS(s);
    }
  }
}
