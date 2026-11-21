import 'dart:async';
import 'dart:convert';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
// Importing the entry point ensures it is compiled into the app binary.
// `@pragma('vm:entry-point')` only prevents tree-shaking once a file is
// compiled; without an import the secondary engine cannot find `overlayMain`
// and Android logs `Width is zero` followed by `Destroying the overlay
// window service`.
// ignore: unused_import
import 'package:bike_control/services/overlay/overlay_entry_point.dart';
import 'package:bike_control/services/overlay/overlay_definition_binding.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart' show Size, TextScaler, WidgetsBinding;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// Custom MethodChannel that bridges overlay→main on Android. Set up by a
/// Kotlin singleton (OverlayActionBridge) because flutter_overlay_window
/// 0.5.0's own overlay→main path doesn't deliver.
const _overlayActionsChannel = MethodChannel('bike_control/overlay_actions');

/// Room around the card in the Android overlay window, in dp, for its border.
const double androidOverlayMargin = 16;

/// Fits the overlay window to the card at [cardSize] (dp), plus its margin.
///
/// Only while the window is up. The package starts the overlay engine with
/// the app, long before any overlay is shown, and the card already lays out
/// and reports its size then; the window's channel only exists once the
/// overlay service runs, so resizing earlier fails on every launch. The
/// window is opened at the card's size anyway (see [AndroidOverlayController.show]).
Future<void> resizeAndroidOverlayWindow(Size cardSize) async {
  try {
    if (!await FlutterOverlayWindow.isActive()) return;
    await FlutterOverlayWindow.resizeOverlay(
      (cardSize.width + androidOverlayMargin).ceil(),
      (cardSize.height + androidOverlayMargin).ceil(),
      true,
    );
  } catch (e, s) {
    recordError(e, s, context: 'overlay.android.resize');
  }
}

/// Gives the overlay's foreground-service notification BikeControl's own
/// status-bar icon, words and tap, and a "Hide overlay" button (handled as
/// `hideOverlay` by the main-side handler).
///
/// flutter_overlay_window 0.5.0 builds that notification itself: the launcher
/// icon as the small icon — which Android draws as a filled circle — a bare
/// title, and a tap that opens nothing. Android won't let the overlay run
/// without it, so it is re-posted over the package's (same id, same channel)
/// rather than removed. The service goes foreground after `showOverlay`
/// returns, and until it has there is nothing to replace — hence the retry.
Future<bool> styleAndroidOverlayNotification(
  AppLocalizations l, {
  int attempts = 20,
  Duration retryDelay = const Duration(milliseconds: 100),
}) async {
  Object? lastError;
  StackTrace? lastStack;
  for (var i = 0; i < attempts; i++) {
    try {
      final ok = await _overlayActionsChannel.invokeMethod<bool>('styleOverlayNotification', {
        'title': l.overlayNotificationTitle,
        'text': l.overlayNotificationText,
        'channelName': l.overlayNotificationChannel,
        'hideLabel': l.overlayHide,
      });
      if (ok == true) return true;
    } catch (e, s) {
      lastError = e;
      lastStack = s;
    }
    await Future.delayed(retryDelay);
  }
  if (lastError != null) {
    recordError(lastError, lastStack, context: 'overlay.android.styleNotification');
  }
  return false;
}

class AndroidOverlayController implements TrainerOverlayController {
  static const _minPushIntervalMs = 100; // ~10 Hz
  final ValueNotifier<bool> _showing = ValueNotifier(false);
  late final OverlayDefinitionBinding _binding = OverlayDefinitionBinding(
    onChange: _onChange,
    onSwap: () => _push(force: true),
  );
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  TrainerOverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// `true` once we've registered our MethodCallHandler on the main-side
  /// MethodChannel that receives forwarded actions from the overlay engine.
  /// One-shot: handler is set and then never replaced; it gates dispatch on
  /// a bound definition so messages received while the overlay is hidden are
  /// silently dropped.
  bool _mainHandlerInstalled = false;

  /// Listens from the start, not from the first [show]: the overlay service
  /// can outlive the screen that opened it, and the notification's "Hide
  /// overlay" has to reach a recreated app that hasn't shown anything yet.
  AndroidOverlayController() {
    _installMainHandler();
  }

  @override
  ValueListenable<bool> get isShowing => _showing;

  @override
  Future<OverlayShowResult> show(
    FitnessBikeDefinition def,
    Set<OverlayField> fields, {
    LiveDefinition? liveDef,
  }) async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      final ok = await FlutterOverlayWindow.requestPermission();
      if (ok != true) {
        return const OverlayShowResult.fail(OverlayShowFailure.permissionDenied);
      }
    }

    _fields = fields;
    _binding.attach(def, live: liveDef);
    _installMainHandler();

    // flutter_overlay_window 0.5.0 passes width/height through to
    // WindowManager.LayoutParams as RAW PIXELS (not dp). Compute the surface
    // size from the platform's device pixel ratio so the overlay always
    // matches our widget's dp footprint — otherwise the +/- buttons get
    // clipped on high-density phones (510 px needed for a 170 dp widget on
    // a 3× display).
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    int dpToPx(double dp) => (dp * dpr).round();
    // Sized to what the card shows at the rider's text size (the card is
    // never shrunk to fit). The overlay engine resizes the window whenever
    // the fields or the mode change (see runOverlayApp).
    final overlaySize = TrainerOverlayView.fitWindowSize(
      state: _stateFor(def),
      drag: false,
      textScaler: TextScaler.linear(WidgetsBinding.instance.platformDispatcher.textScaleFactor),
    );

    // Android requires a foreground-service notification for SYSTEM_ALERT_WINDOW
    // overlays — we can't suppress it entirely. Use visibilitySecret so it
    // doesn't appear on the lock screen / heads-up. Its icon, words and tap
    // are replaced right after (see styleAndroidOverlayNotification).
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: AppLocalizations.current.overlayNotificationTitle,
      overlayContent: AppLocalizations.current.overlayNotificationText,
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilitySecret,
      positionGravity: PositionGravity.none,
      width: dpToPx(overlaySize.width + androidOverlayMargin),
      height: dpToPx(overlaySize.height + androidOverlayMargin),
      startPosition: const OverlayPosition(20, 80),
    );

    // The Kotlin bridge needs to register a handler on the overlay engine,
    // which only becomes available in FlutterEngineCache after showOverlay
    // creates it. Retry a few times because engine attach is async on some
    // OEMs (Oppo / OnePlus) and the cache lookup can race the show call.
    unawaited(_installOverlayHandlerWithRetry());
    unawaited(styleAndroidOverlayNotification(AppLocalizations.current));

    // Keep the screen on while the overlay is visible. wakelock_plus only holds
    // the screen on via BikeControl's activity window, which is inert once the
    // activity is backgrounded (the norm during a ride, where only this overlay
    // is on screen), so the flag has to live on the overlay window itself. Same
    // service-attach race as the handler install, hence the retry.
    unawaited(_setKeepScreenOnWithRetry(true));

    _showing.value = true;
    // Send an initial state immediately.
    _push(force: true);
    return const OverlayShowResult.ok();
  }

  Future<void> _installOverlayHandlerWithRetry() async {
    Object? lastError;
    StackTrace? lastStack;
    for (var i = 0; i < 10; i++) {
      try {
        final ok = await _overlayActionsChannel.invokeMethod<bool>('installOverlayHandler');
        if (ok == true) return;
      } catch (e, s) {
        // Expected to fail until the overlay engine is in the FlutterEngineCache;
        // only surface the final attempt's failure.
        lastError = e;
        lastStack = s;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (lastError != null) {
      recordError(lastError, lastStack, context: 'overlay.android.installHandler');
    }
  }

  Future<void> _setKeepScreenOnWithRetry(bool enable) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var i = 0; i < 10; i++) {
      try {
        final ok = await _overlayActionsChannel.invokeMethod<bool>(
          'setOverlayKeepScreenOn',
          {'enable': enable},
        );
        if (ok == true) return;
      } catch (e, s) {
        // Expected to fail until the overlay service's window is attached;
        // only surface the final attempt's failure.
        lastError = e;
        lastStack = s;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (lastError != null) {
      recordError(lastError, lastStack, context: 'overlay.android.keepScreenOn');
    }
  }

  @override
  Future<void> hide() async {
    _binding.detach();
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
    } catch (e, s) {
      recordError(e, s, context: 'overlay.android.uninstallHandler');
    }
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
      // The notification's "Hide overlay" button. Means the same as the
      // Overlay section's switch going off, persisted included — otherwise
      // the next trainer reconnect would put the overlay straight back.
      if (call.arguments == 'hideOverlay') {
        // Persist first: a close that fails must not leave the setting on,
        // or the next trainer reconnect brings the overlay straight back.
        await core.settings.setOverlayEnabled(false);
        try {
          await hide();
        } catch (e, s) {
          recordError(e, s, context: 'overlay.android.hideAction');
        }
        return null;
      }
      // The binding follows the trainer onto the definition each reconnect
      // builds, so this is never a stale one.
      final live = _binding.current;
      if (live == null) return null; // overlay hidden — drop
      final action = call.arguments;
      if (action is! String) return null;
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

  @override
  void updateFields(Set<OverlayField> fields) {
    _fields = fields;
    _push(force: true);
  }

  @override
  void updateOpacity(double opacity) {
    // The Android system overlay window has no adjustable alpha here.
  }

  @override
  Future<void> reassert() async {
    // Only meaningful while our system window is up. Re-adding is handled
    // natively by the already-running overlay foreground service — we cannot
    // close+show here because `showOverlay` uses `startService`, which Android
    // blocks from the background (i.e. while the trainer app is foreground,
    // which is exactly when this fires).
    if (!_showing.value) return;
    try {
      await _overlayActionsChannel.invokeMethod('reassertOverlay');
    } catch (e, s) {
      recordError(e, s, context: 'overlay.android.reassert');
    }
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
    final def = _binding.current;
    if (def == null) return;
    final s = _stateFor(def);
    if (!force && s == _lastPushed) return;
    _lastPushed = s;
    _lastPushAt = DateTime.now();
    await FlutterOverlayWindow.shareData(jsonEncode(s.toJson()));
  }

  TrainerOverlayState _stateFor(FitnessBikeDefinition def) => TrainerOverlayState(
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
