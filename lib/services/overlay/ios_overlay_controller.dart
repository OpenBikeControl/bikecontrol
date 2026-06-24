import 'dart:async';
import 'dart:math';

import 'package:bike_control/main.dart';
import 'package:bike_control/services/overlay/ios_pip_controller.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class IosOverlayController implements TrainerOverlayController {
  static const _appGroupId = 'group.de.jonasbark.swiftcontrol.overlay';
  static const _minPushIntervalMs = 500; // ~2 Hz

  /// Custom MethodChannel that delivers Live Activity button taps from
  /// `AppDelegate.swift` (which observes Darwin notifications posted by the
  /// Widget Extension's `AppIntent`s) into the main Flutter engine.
  static const _actionChannel =
      MethodChannel('bike_control/overlay_actions_ios');

  final ValueNotifier<bool> _showing = ValueNotifier(false);
  final LiveActivities _la = LiveActivities();
  String? _activityId;
  final IosPipController _pip = IosPipController();
  bool _pipActive = false;

  FitnessBikeDefinition? _def;
  LiveDefinitionLookup? _liveDef;
  Listenable? _bound;
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  TrainerOverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// `true` once we've registered the MethodCallHandler that receives
  /// forwarded actions from the Live Activity. One-shot for the lifetime of
  /// the isolate.
  bool _actionHandlerInstalled = false;

  @override
  ValueListenable<bool> get isShowing => _showing;

  @override
  Future<OverlayShowResult> show(
    FitnessBikeDefinition def,
    Set<OverlayField> fields, {
    LiveDefinitionLookup? liveDef,
  }) async {
    try {
      await _la.init(appGroupId: _appGroupId);
    } catch (e, s) {
      recordError(e, s, context: 'overlay.ios.init');
      return OverlayShowResult.fail(OverlayShowFailure.systemDisabled, message: 'Live Activities init failed: $e');
    }
    _def = def;
    _liveDef = liveDef;
    _fields = fields;
    _bind();
    _installActionHandler();

    final s = _snapshot(def);
    final activityId = _generateId();
    try {
      final result = await _la.createActivity(activityId, _toMap(s));
      if (result == null) {
        return const OverlayShowResult.fail(
          OverlayShowFailure.systemDisabled,
          message: 'Live Activities are disabled (Low Power Mode or system setting).',
        );
      }
      // The package returns ActivityKit's generated activity id (not the
      // string we passed in). updateActivity / endActivity look up the
      // activity by THAT id, so we must store the returned value.
      _activityId = result;
    } catch (e, s) {
      recordError(e, s, context: 'overlay.ios.createActivity');
      return OverlayShowResult.fail(OverlayShowFailure.systemDisabled, message: 'Live Activity create failed: $e');
    }

    _showing.value = true;
    try {
      if (await _pip.isSupported()) {
        await _pip.start(_toMap(s));
        _pipActive = true;
      }
    } catch (e, st) {
      recordError(e, st, context: 'overlay.ios.pip.start');
    }
    return const OverlayShowResult.ok();
  }

  @override
  Future<void> hide() async {
    _bound?.removeListener(_onChange);
    _bound = null;
    _def = null;
    _liveDef = null;
    _pushDebounce?.cancel();
    _pushDebounce = null;
    _lastPushed = null;
    final id = _activityId;
    if (id != null) {
      try {
        await _la.endActivity(id);
      } catch (e, s) {
        recordError(e, s, context: 'overlay.ios.endActivity');
      }
      _activityId = null;
    }
    _showing.value = false;
    if (_pipActive) {
      try {
        await _pip.stop();
      } catch (e, s) {
        recordError(e, s, context: 'overlay.ios.pip.stop');
      }
      _pipActive = false;
    }
  }

  @override
  void updateFields(Set<OverlayField> fields) {
    _fields = fields;
    _push(force: true);
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

  TrainerOverlayState _snapshot(FitnessBikeDefinition def) {
    return TrainerOverlayState(
      gear: def.currentGear.value,
      maxGear: def.maxGear,
      gearRatio: def.gearRatio.value,
      mode: def.trainerMode.value,
      powerW: def.powerW.value,
      cadenceRpm: def.cadenceRpm.value,
      ergTargetW: def.ergTargetPower.value,
      fields: _fields,
    );
  }

  Map<String, dynamic> _toMap(TrainerOverlayState s) => overlayStateToActivityMap(s);

  Future<void> _push({bool force = false}) async {
    final id = _activityId;
    final def = _def;
    // Guard against a race where hide() clears _def/_activityId between a
    // Timer firing and this method executing.
    if (id == null || def == null) return;
    final s = _snapshot(def);
    if (!force && s == _lastPushed) return;
    _lastPushed = s;
    _lastPushAt = DateTime.now();
    try {
      await _la.updateActivity(id, _toMap(s));
      if (_pipActive) {
        await _pip.update(_toMap(s));
      }
    } catch (error, stack) {
      recordError(error, stack, context: 'overlay.ios.updateActivity');
    }
  }

  /// Wire the MethodCallHandler that receives action forwards from the Live
  /// Activity buttons (via `AppDelegate.swift`'s Darwin notification observer).
  /// One-shot for the lifetime of the controller; the handler no-ops while
  /// `_def` is null (overlay hidden).
  void _installActionHandler() {
    if (_actionHandlerInstalled) return;
    _actionHandlerInstalled = true;
    _actionChannel.setMethodCallHandler((call) async {
      if (call.method != 'action') return null;
      final action = call.arguments;
      if (action is! String) return null;

      // Stop applies even when no def is bound (e.g. activity left around
      // after a definition rebind) — handle it first.
      if (action == 'stop') {
        await _stopRide();
        return null;
      }

      // Re-resolve the live FitnessBikeDefinition each call — see comment
      // on LiveDefinitionLookup; the trainer emulator rebinds a fresh def
      // on every transport restart.
      final live = _liveDef?.call() ?? _def;
      if (live == null) return null;
      switch (action) {
        case 'primaryDecrement':
          _adjustPrimary(live, increment: false);
          break;
        case 'primaryIncrement':
          _adjustPrimary(live, increment: true);
          break;
      }
      return null;
    });
  }

  /// Tear everything down when the user taps the close button in the
  /// Dynamic Island: disconnect all BLE / gamepad / proxy devices, stop
  /// scanning, hide the Live Activity, and flip the persisted
  /// `overlay_enabled` flag off so auto-show doesn't immediately re-open
  /// the activity on the next trainer reconnect.
  Future<void> _stopRide() async {
    try {
      await core.connection.disconnectAll();
      await core.connection.stop();
    } catch (e, s) {
      recordError(e, s, context: 'overlay.ios.stop.disconnect');
    }
    try {
      await core.settings.setOverlayEnabled(false);
    } catch (e, s) {
      recordError(e, s, context: 'overlay.ios.stop.persistFlag');
    }
    await hide();
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

  static String _generateId() {
    final rng = Random();
    final buf = StringBuffer('trainer-');
    for (var i = 0; i < 16; i++) {
      buf.write(rng.nextInt(16).toRadixString(16));
    }
    return buf.toString();
  }
}
