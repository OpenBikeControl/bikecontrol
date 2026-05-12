import 'dart:async';
import 'dart:convert';

// Importing the entry point ensures it is compiled into the app binary.
// `@pragma('vm:entry-point')` only prevents tree-shaking once a file is
// compiled; without an import the secondary engine cannot find `overlayMain`
// and Android logs `Width is zero` followed by `Destroying the overlay
// window service`.
// ignore: unused_import
import 'package:bike_control/services/overlay/overlay_entry_point.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// Custom MethodChannel that bridges overlay→main on Android. Set up by a
/// Kotlin singleton (OverlayActionBridge) because flutter_overlay_window
/// 0.5.0's own overlay→main path doesn't deliver.
const _overlayActionsChannel = MethodChannel('bike_control/overlay_actions');

class AndroidOverlayController implements TrainerOverlayController {
  static const _minPushIntervalMs = 100; // ~10 Hz
  final ValueNotifier<bool> _showing = ValueNotifier(false);
  FitnessBikeDefinition? _def;
  Listenable? _bound;
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  TrainerOverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// `true` once we've registered our MethodCallHandler on the main-side
  /// MethodChannel that receives forwarded actions from the overlay engine.
  /// One-shot: handler is set and then never replaced; it gates dispatch on
  /// `_def != null` so messages received while the overlay is hidden are
  /// silently dropped.
  bool _mainHandlerInstalled = false;

  @override
  ValueListenable<bool> get isShowing => _showing;

  @override
  Future<OverlayShowResult> show(FitnessBikeDefinition def, Set<OverlayField> fields) async {
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
    _installMainHandler();

    // flutter_overlay_window 0.5.0 passes width/height through to
    // WindowManager.LayoutParams as RAW PIXELS (not dp). Compute the surface
    // size from the platform's device pixel ratio so the overlay always
    // matches our widget's dp footprint — otherwise the +/- buttons get
    // clipped on high-density phones (510 px needed for a 170 dp widget on
    // a 3× display).
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    int dpToPx(double dp) => (dp * dpr).round();

    // Android requires a foreground-service notification for SYSTEM_ALERT_WINDOW
    // overlays — we can't suppress it entirely. Use visibilitySecret so it
    // doesn't appear on the lock screen / heads-up, an empty content line, and
    // a minimal title so it sits unobtrusively in the notification shade.
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'BikeControl',
      overlayContent: '',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilitySecret,
      positionGravity: PositionGravity.none,
      width: dpToPx(270),
      height: dpToPx(110),
      startPosition: const OverlayPosition(20, 80),
    );

    // The Kotlin bridge needs to register a handler on the overlay engine,
    // which only becomes available in FlutterEngineCache after showOverlay
    // creates it. Retry a few times because engine attach is async on some
    // OEMs (Oppo / OnePlus) and the cache lookup can race the show call.
    unawaited(_installOverlayHandlerWithRetry());

    _showing.value = true;
    // Send an initial state immediately.
    _push(force: true);
    return const OverlayShowResult.ok();
  }

  Future<void> _installOverlayHandlerWithRetry() async {
    for (var i = 0; i < 10; i++) {
      try {
        final ok = await _overlayActionsChannel
            .invokeMethod<bool>('installOverlayHandler');
        if (ok == true) return;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }
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
    // Tear the overlay-side Kotlin handler down too; the engine itself is
    // disposed by the package, but our handler reference can leak if we
    // forget to clear it.
    try {
      await _overlayActionsChannel.invokeMethod('uninstallOverlayHandler');
    } catch (_) {}
    _showing.value = false;
  }

  /// Set up the main-side MethodCallHandler (idempotent). The Kotlin bridge
  /// invokes "action" on this channel whenever the overlay isolate calls
  /// `MethodChannel('bike_control/overlay_actions').invokeMethod('push', ...)`.
  void _installMainHandler() {
    if (_mainHandlerInstalled) return;
    _mainHandlerInstalled = true;
    _overlayActionsChannel.setMethodCallHandler((call) async {
      if (call.method != 'action') return null;
      final def = _def;
      if (def == null) return null; // overlay hidden — drop
      final action = call.arguments;
      if (action is! String) return null;
      switch (action) {
        case 'primaryDecrement':
          _adjustPrimary(def, increment: false);
          break;
        case 'primaryIncrement':
          _adjustPrimary(def, increment: true);
          break;
      }
      return null;
    });
  }

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
