import 'dart:async';
import 'dart:math';

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class IosOverlayController implements TrainerOverlayController {
  static const _appGroupId = 'group.de.jonasbark.swiftcontrol.overlay';
  static const _minPushIntervalMs = 500; // ~2 Hz

  final ValueNotifier<bool> _showing = ValueNotifier(false);
  final LiveActivities _la = LiveActivities();
  String? _activityId;

  FitnessBikeDefinition? _def;
  Listenable? _bound;
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  TrainerOverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  ValueListenable<bool> get isShowing => _showing;

  @override
  Future<OverlayShowResult> show(FitnessBikeDefinition def, Set<OverlayField> fields) async {
    try {
      await _la.init(appGroupId: _appGroupId);
    } catch (e) {
      return OverlayShowResult.fail(OverlayShowFailure.systemDisabled, message: 'Live Activities init failed: $e');
    }
    _def = def;
    _fields = fields;
    _bind();

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
      _activityId = activityId;
    } catch (e, s) {
      if (kDebugMode) {
        // print stack trace
        debugPrint('Live Activities create failed: $e');
        debugPrintStack(stackTrace: s);
        print((e as PlatformException).stacktrace);
      }
      return OverlayShowResult.fail(OverlayShowFailure.systemDisabled, message: 'Live Activity create failed: $e');
    }

    _showing.value = true;
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
    final id = _activityId;
    if (id != null) {
      try {
        await _la.endActivity(id);
      } catch (_) {}
      _activityId = null;
    }
    _showing.value = false;
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

  // live_activities routes the map through NSUserDefaults in the App Group,
  // which crashes on null values (NSInvalidArgumentException). Optional Swift
  // fields (Int?) decode missing keys as nil via Codable, so omitting nulls
  // yields the same ContentState.
  Map<String, dynamic> _toMap(TrainerOverlayState s) {
    final m = <String, dynamic>{
      'gear': s.gear,
      'maxGear': s.maxGear,
      'mode': s.mode == TrainerMode.ergMode ? 'erg' : 'sim',
      'showPower': s.fields.contains(OverlayField.power),
      'showCadence': s.fields.contains(OverlayField.cadence),
      'showErgTarget': s.fields.contains(OverlayField.ergTarget),
      'showGearRatio': s.fields.contains(OverlayField.gearRatio),
      'gearRatio': s.gearRatio,
    };
    if (s.powerW != null) m['powerW'] = s.powerW;
    if (s.cadenceRpm != null) m['cadenceRpm'] = s.cadenceRpm;
    if (s.ergTargetW != null) m['ergTargetW'] = s.ergTargetW;
    return m;
  }

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
    } catch (_) {}
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
