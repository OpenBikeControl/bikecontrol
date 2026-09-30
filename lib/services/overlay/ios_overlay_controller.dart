import 'dart:async';

import 'package:bike_control/main.dart';
import 'package:bike_control/services/overlay/ios_pip_controller.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/live_activity_state.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class IosOverlayController implements TrainerOverlayController {
  /// [liveActivities] and [pip] exist so tests can stand in for ActivityKit and
  /// the PiP channel; production always takes the defaults.
  IosOverlayController({LiveActivities? liveActivities, IosPipController? pip})
    : _la = liveActivities ?? LiveActivities(),
      _pip = pip ?? IosPipController();

  static const _appGroupId = 'group.de.jonasbark.swiftcontrol.overlay';
  static const _minPushIntervalMs = 500; // ~2 Hz

  /// Stable name for the one Live Activity BikeControl ever wants — the gear
  /// readout. The plugin hashes it into the activity's `attributes.id`, which
  /// doubles as the prefix the widget extension reads its App Group values
  /// under, so a fixed name also stops every ride from leaking a fresh set of
  /// never-collected `UserDefaults` keys.
  static const _activityName = 'bike-control-gear-overlay';

  /// Custom MethodChannel that delivers Live Activity button taps from
  /// `AppDelegate.swift` (which observes Darwin notifications posted by the
  /// Widget Extension's `AppIntent`s) into the main Flutter engine.
  static const _actionChannel = MethodChannel('bike_control/overlay_actions_ios');

  final ValueNotifier<bool> _showing = ValueNotifier(false);
  final LiveActivities _la;
  String? _activityId;
  final IosPipController _pip;
  bool _pipActive = false;

  /// The `show()` currently talking to ActivityKit, if any. A trainer app that
  /// flaps its connection re-enters `show()` while the previous attempt is
  /// still awaiting `Activity.request`; without this every flap would be
  /// another request against a cap that only the rider rebooting their phone
  /// can clear.
  Future<OverlayShowResult>? _showInFlight;

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
  }) {
    final inFlight = _showInFlight;
    if (inFlight != null) return inFlight;
    final started = _show(def, fields, liveDef: liveDef);
    _showInFlight = started;
    return started.whenComplete(() {
      if (identical(_showInFlight, started)) _showInFlight = null;
    });
  }

  Future<OverlayShowResult> _show(
    FitnessBikeDefinition def,
    Set<OverlayField> fields, {
    LiveDefinitionLookup? liveDef,
  }) async {
    try {
      await _la.init(appGroupId: _appGroupId);
    } catch (e, s) {
      recordError(e, s, context: 'overlay.ios.init');
      _markNotShowing();
      return OverlayShowResult.fail(OverlayShowFailure.systemDisabled, message: 'Live Activities init failed: $e');
    }
    _def = def;
    _liveDef = liveDef;
    _fields = fields;
    _bind();
    _installActionHandler();

    final s = _snapshot(def);
    final String? activity;
    try {
      activity = await _adoptOrStartActivity(_toMap(s));
    } catch (e, st) {
      recordError(e, st, context: 'overlay.ios.createActivity');
      _markNotShowing();
      return OverlayShowResult.fail(OverlayShowFailure.systemDisabled, message: 'Live Activity create failed: $e');
    }
    if (activity == null) {
      _markNotShowing();
      return const OverlayShowResult.fail(
        OverlayShowFailure.systemDisabled,
        message: 'Live Activities are disabled (Low Power Mode or system setting).',
      );
    }
    // hide() may have run during the awaits above and cleared the definition —
    // don't leave the activity we just adopted or requested on screen with
    // nothing feeding it, that is one more orphan holding a slot.
    if (!identical(_def, def)) {
      await _endActivities([activity]);
      _markNotShowing();
      return const OverlayShowResult.fail(OverlayShowFailure.unknown, message: 'Overlay was hidden while starting');
    }
    // ActivityKit's own activity id (not the name we passed in) — that is what
    // updateActivity / endActivity look the activity up by.
    _activityId = activity;

    _showing.value = true;
    try {
      // null pref = automatic device default (iPad / non-Dynamic-Island iPhones);
      // an explicit true opts in everywhere PiP is capable (e.g. DI iPhones), an
      // explicit false opts out. The Live Activity keeps running either way.
      final pref = core.settings.getOverlayUsePip();
      final usePip = pref == null ? await _pip.isSupported() : (pref && await _pip.isCapable());
      // hide() may have run during the awaits above (Live Activity 'stop',
      // trainer disconnect, …) and set _showing=false; only arm PiP if we're
      // still showing, and tear it back down if a hide lands during start().
      if (usePip && _showing.value) {
        await _pip.start(_toMap(s));
        _pipActive = true;
        if (!_showing.value) {
          _pipActive = false;
          await _pip.stop();
        }
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

  /// Nothing is on screen. Say so, rather than leaving the Overlay switch and
  /// the auto-show guard insisting on an overlay the rider cannot see — and
  /// drop the id, which by now points at an activity that is gone.
  void _markNotShowing() {
    _activityId = null;
    _showing.value = false;
  }

  @override
  void updateFields(Set<OverlayField> fields) {
    _fields = fields;
    _push(force: true);
  }

  @override
  void updateOpacity(double opacity) {
    // iOS overlays (Live Activity / PiP) have no adjustable window alpha.
  }

  @override
  Future<void> reassert() async {
    // iOS overlays are a Live Activity / PiP window, not a re-stackable system
    // overlay — the OS owns their elevation. Nothing to re-top.
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
      frontShiftEnabled: def.frontShiftEnabled,
      frontRingLarge: def.frontRing.value == FrontRing.large,
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

  /// Shift a gear (SIM mode) or step the ERG target power (see ErgPowerStepping).
  void _adjustPrimary(FitnessBikeDefinition def, {required bool increment}) {
    if (def.trainerMode.value == TrainerMode.ergMode) {
      def.stepManualErgPower(up: increment);
    } else {
      if (increment) {
        def.shiftUp();
      } else {
        def.shiftDown();
      }
    }
  }

  /// Hands back the ActivityKit id of a live gear activity, reusing whatever
  /// iOS still has rather than asking for another one.
  ///
  /// ActivityKit caps how many Live Activities a target may run at once, and
  /// every one BikeControl abandons — app force-quit mid-ride, Flutter engine
  /// restarted, activity swiped off the Lock Screen — keeps holding its slot.
  /// Because [_activityId] only ever lived in this isolate's memory, each
  /// launch used to mint a brand-new activity and orphan the last one, until
  /// `Activity.request` started throwing `targetMaximumExceeded` and stayed
  /// that way until the rider rebooted the phone. On iOS the Live Activity IS
  /// the gear display, so that silently kills the only readout of the virtual
  /// gear a trainer app can't show.
  Future<String?> _adoptOrStartActivity(Map<String, dynamic> data) async {
    final plan = planLiveActivity(
      trackedId: _activityId,
      existing: await _existingActivities(),
    );
    await _endActivities(plan.end);
    // The sweep just left `plan.adopt` as the only survivor, so that — and not
    // an id we have already ended — is what _push() may write to from here on.
    _activityId = plan.adopt;

    final adopt = plan.adopt;
    if (adopt != null) {
      try {
        // Writes land under the adopted activity's own attributes prefix, so
        // an activity started by a previous launch shows fresh gear data.
        await _la.updateActivity(adopt, data);
        return adopt;
      } catch (e, s) {
        // It went away between the query and the update. Reap it for real and
        // fall through to a fresh request rather than reporting failure.
        recordError(e, s, context: 'overlay.ios.adoptActivity');
        await _endActivities([adopt]);
        _activityId = null;
      }
    }

    try {
      return await _la.createActivity(_activityName, data, removeWhenAppIsKilled: true);
    } catch (e, s) {
      // `Activity.activities` reads empty for a beat after a cold start (the
      // plugin works around the same race in createOrUpdateActivity), so the
      // sweep above can miss orphans that are very much still holding slots.
      // Give iOS that beat, end everything, and ask exactly once more.
      recordError(e, s, context: 'overlay.ios.createActivity.retry');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _endAllActivities();
      return _la.createActivity(_activityName, data, removeWhenAppIsKilled: true);
    }
  }

  Future<Map<String, LiveActivityState>> _existingActivities() async {
    try {
      return await _la.getAllActivities();
    } catch (e, s) {
      recordError(e, s, context: 'overlay.ios.getAllActivities');
      return const {};
    }
  }

  Future<void> _endActivities(Iterable<String> ids) async {
    for (final id in ids) {
      try {
        await _la.endActivity(id);
      } catch (e, s) {
        recordError(e, s, context: 'overlay.ios.endStaleActivity');
      }
    }
  }

  Future<void> _endAllActivities() async {
    try {
      await _la.endAllActivities();
    } catch (e, s) {
      recordError(e, s, context: 'overlay.ios.endAllActivities');
    }
  }
}

/// Which Live Activity to reuse, and which ones have to be ended first.
@immutable
class LiveActivityPlan {
  const LiveActivityPlan({required this.adopt, required this.end});

  /// ActivityKit id of the activity to update in place, or null when a new one
  /// has to be requested.
  final String? adopt;

  /// ActivityKit ids to end. Each of these holds a slot against the per-target
  /// cap for as long as it exists.
  final List<String> end;
}

/// Decides what to do with the Live Activities iOS reports for this app.
///
/// BikeControl only ever wants one, the gear readout. [trackedId] is the
/// activity this isolate started (null after a restart, or once it was ended)
/// and [existing] is what ActivityKit still holds. Anything that isn't the one
/// activity we keep gets ended: an orphan occupies its slot until the device
/// reboots, and a full target is exactly what makes `Activity.request` throw
/// `targetMaximumExceeded`.
@visibleForTesting
LiveActivityPlan planLiveActivity({
  required String? trackedId,
  required Map<String, LiveActivityState> existing,
}) {
  // `dismissed` is already gone from the system. `ended` is still on screen —
  // and still counted — but can no longer be updated, so it is only ever
  // something to reap. `stale` just means the content is out of date, which is
  // what the update we are about to push fixes.
  bool reusable(String id) {
    final state = existing[id];
    return state == LiveActivityState.active || state == LiveActivityState.stale;
  }

  String? adopt;
  if (trackedId != null && reusable(trackedId)) {
    adopt = trackedId;
  } else {
    for (final id in existing.keys) {
      if (reusable(id)) {
        adopt = id;
        break;
      }
    }
  }

  return LiveActivityPlan(
    adopt: adopt,
    end: [
      for (final id in existing.keys)
        if (id != adopt) id,
    ],
  );
}
