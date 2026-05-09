import 'dart:async';
import 'dart:convert';

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
// Importing the entry point ensures it is compiled into the app binary.
// `@pragma('vm:entry-point')` only prevents tree-shaking once a file is
// compiled; without an import the secondary engine cannot find `overlayMain`
// and Android logs `Width is zero` followed by `Destroying the overlay
// window service`.
// ignore: unused_import
import 'package:bike_control/services/overlay/overlay_entry_point.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class AndroidOverlayController implements TrainerOverlayController {
  static const _minPushIntervalMs = 100; // ~10 Hz
  final ValueNotifier<bool> _showing = ValueNotifier(false);
  FitnessBikeDefinition? _def;
  Listenable? _bound;
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  TrainerOverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  ValueListenable<bool> get isShowing => _showing;

  @override
  Future<OverlayShowResult> show(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      final ok = await FlutterOverlayWindow.requestPermission();
      if (ok != true) {
        return const OverlayShowResult.fail(OverlayShowFailure.permissionDenied);
      }
    }

    _def = def;
    _fields = fields;
    _bind();

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'BikeControl',
      overlayContent: 'Trainer overlay active',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 360,
      width: 560,
      startPosition: const OverlayPosition(20, 80),
    );

    _showing.value = true;
    // Send an initial state immediately.
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
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
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
    await FlutterOverlayWindow.shareData(jsonEncode(s.toJson()));
  }
}
