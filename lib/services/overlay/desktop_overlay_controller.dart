import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:bike_control/services/overlay/desktop_overlay_window.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/utils/core.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class DesktopOverlayController implements TrainerOverlayController {
  static const _minPushIntervalMs = 100; // ~10 Hz

  final ValueNotifier<bool> _showing = ValueNotifier(false);
  @override
  ValueListenable<bool> get isShowing => _showing;

  dmw.WindowController? _window;

  FitnessBikeDefinition? _def;
  Listenable? _bound;
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  TrainerOverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Channel to communicate with the overlay sub-window.
  /// The name must match [kOverlayChannel] in desktop_overlay_window.dart.
  final _channel = dmw.WindowMethodChannel(
    kOverlayChannel,
    mode: dmw.ChannelMode.bidirectional,
  );

  @override
  Future<OverlayShowResult> show(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    if (_showing.value) return const OverlayShowResult.ok();

    // Register the main-window side of the shared channel BEFORE creating the
    // sub-window so that any calls from the overlay land here immediately.
    _registerParentHandlers(def);

    try {
      final controller = await dmw.WindowController.create(
        dmw.WindowConfiguration(
          arguments: jsonEncode({'role': 'trainer-overlay'}),
          hiddenAtLaunch: true,
        ),
      );
      _window = controller;
      await controller.show();
    } catch (e) {
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

    final w = _window;
    if (w != null) {
      try {
        await w.invokeMethod<void>('close');
      } catch (_) {}
      _window = null;
    }

    // Unregister our side of the channel.
    try {
      await _channel.setMethodCallHandler(null);
    } catch (_) {}

    _showing.value = false;
  }

  @override
  void updateFields(Set<OverlayField> fields) {
    _fields = fields;
    _push(force: true);
  }

  void _registerParentHandlers(FitnessBikeDefinition def) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'hide':
          await hide();
          return null;
        case 'toggleMode':
          if (def.trainerMode.value == TrainerMode.ergMode) {
            def.exitErgMode();
          } else {
            def.setManualErgPower(def.ergTargetPower.value ?? 150);
          }
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
    final w = _window;
    final def = _def;
    if (w == null || def == null) return;

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
      await w.invokeMethod<void>('state', jsonEncode(s.toJson()));
    } catch (_) {}
  }
}
