import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multi_window_native/multi_window_native.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart' as wm;

// ---------------------------------------------------------------------------
// Shared channel name (Windows / desktop_multi_window only).
// ---------------------------------------------------------------------------

/// Channel name shared between the main window and overlay window on Windows.
/// Both sides register on this channel; the main window sends 'state' / 'close'
/// to the overlay; the overlay sends 'hide' / 'toggleMode' / 'positionChanged'
/// / 'primaryDecrement' / 'primaryIncrement' to the main window.
const String kOverlayChannel = 'bike_control/overlay';

// ---------------------------------------------------------------------------
// macOS (multi_window_native) method-name constants.
// ---------------------------------------------------------------------------

/// Method names broadcast between main and overlay windows on macOS via
/// `MultiWindowNative.notifyAllWindows` / `registerListener`.
const String kStateMethod = 'trainerOverlay.state';
const String kOverlayActionMethod = 'trainerOverlay.action';
const String kOverlayReadyMethod = 'trainerOverlay.ready';
const String kOverlayPositionMethod = 'trainerOverlay.positionChanged';
const String kOverlayClosedMethod = 'trainerOverlay.closed';

// ---------------------------------------------------------------------------
// Top-level dispatcher: called from main() in the sub-window engine.
// ---------------------------------------------------------------------------

/// Entry point for the overlay sub-window process.
///
/// On **Windows**: called from [main] when
/// [dmw.WindowController.fromCurrentEngine] reports `role == "trainer-overlay"`.
///
/// On **macOS**: called from [main] when `args.contains(kTrainerOverlayRoute)`.
/// [windowId] is only meaningful on macOS (from `wm.windowManager.getId()`);
/// [dmwSelf] is only set on Windows.
Future<void> runDesktopOverlayWindow(
  int windowId,
  List<String> args, {
  dmw.WindowController? dmwSelf,
}) async {
  if (Platform.isWindows) {
    assert(dmwSelf != null,
        'runDesktopOverlayWindow: dmwSelf must be set on Windows');
    await _runWindowsOverlay(dmwSelf!);
  } else {
    await _runMacOSOverlay(windowId, args);
  }
}

// ---------------------------------------------------------------------------
// Windows implementation (desktop_multi_window)
// ---------------------------------------------------------------------------

Future<void> _runWindowsOverlay(dmw.WindowController self) async {
  debugPrint('[overlay-run/win] enter');
  await wm.windowManager.ensureInitialized();

  await wm.windowManager.waitUntilReadyToShow(
    const wm.WindowOptions(
      size: Size(220, 100),
      minimumSize: Size(180, 100),
      backgroundColor: Color(0xFF111114),
      skipTaskbar: false,
      titleBarStyle: wm.TitleBarStyle.hidden,
      alwaysOnTop: true,
    ),
    () async {
      await wm.windowManager.setHasShadow(false);
      await wm.windowManager.setResizable(true);
      await wm.windowManager.show();
    },
  );

  final state = ValueNotifier<TrainerOverlayState>(_emptyState());

  // Register the overlay side of the shared bidirectional channel.
  // The main window sends 'state' and 'close' calls through here.
  final channel = dmw.WindowMethodChannel(kOverlayChannel);
  await self.setWindowMethodHandler((call) async {
    switch (call.method) {
      case 'state':
        try {
          final Map<String, dynamic> json = call.arguments is String
              ? jsonDecode(call.arguments as String) as Map<String, dynamic>
              : Map<String, dynamic>.from(call.arguments as Map);
          state.value = TrainerOverlayState.fromJson(json);
          WidgetsBinding.instance.scheduleForcedFrame();
        } catch (e) {
          if (kDebugMode) debugPrint('overlay state decode failed: $e');
        }
        return null;
      case 'close':
        try {
          await wm.windowManager.close();
        } catch (_) {}
        return null;
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  });

  // Restore persisted position from arguments if provided.
  try {
    final rawArgs = self.arguments;
    if (rawArgs.isNotEmpty) {
      final m = jsonDecode(rawArgs) as Map<String, dynamic>;
      final x = (m['x'] as num?)?.toDouble();
      final y = (m['y'] as num?)?.toDouble();
      if (x != null && y != null) {
        await wm.windowManager.setPosition(Offset(x, y));
      }
    }
  } catch (_) {}

  // Track window moves to persist position back to the main process.
  wm.windowManager.addListener(_WindowsOverlayListener(channel));

  debugPrint('[overlay-run/win] about to runApp');
  runApp(_OverlayApp(
    state: state,
    onModeToggle: () =>
        channel.invokeMethod('toggleMode').catchError((_) {}),
    onPrimaryDecrement: () =>
        channel.invokeMethod('primaryDecrement').catchError((_) {}),
    onPrimaryIncrement: () =>
        channel.invokeMethod('primaryIncrement').catchError((_) {}),
  ));
  debugPrint('[overlay-run/win] runApp returned');
}

class _WindowsOverlayListener extends wm.WindowListener {
  final dmw.WindowMethodChannel _channel;
  _WindowsOverlayListener(this._channel);

  @override
  void onWindowMoved() {
    () async {
      try {
        final pos = await wm.windowManager.getPosition();
        await _channel.invokeMethod('positionChanged', {
          'x': pos.dx,
          'y': pos.dy,
        });
      } catch (_) {}
    }();
  }
}

// ---------------------------------------------------------------------------
// macOS implementation (multi_window_native)
// ---------------------------------------------------------------------------

Future<void> _runMacOSOverlay(int windowId, List<String> args) async {
  debugPrint('[overlay-run/mac] enter, windowId=$windowId');
  // Apply individual window settings rather than going through
  // `waitUntilReadyToShow(WindowOptions(...))`. WindowOptions tries to do
  // several things at once (size + titleBarStyle + backgroundColor + ...);
  // on Windows that wedges the sub-window's render surface. Apply settings
  // one at a time post-engine-boot, matching the package example's pattern.
  try {
    await wm.windowManager.setAlwaysOnTop(true);
    debugPrint('[overlay-run/mac] setAlwaysOnTop done');
    await wm.windowManager.setMinimumSize(const Size(180, 100));
    debugPrint('[overlay-run/mac] setMinimumSize done');
    await wm.windowManager.setHasShadow(false);
    debugPrint('[overlay-run/mac] setHasShadow done');
    await wm.windowManager.setVisibleOnAllWorkspaces(
      true,
      visibleOnFullScreen: true,
    );
  } catch (e) {
    debugPrint('[overlay-run/mac] window setup failed: $e');
  }

  final state = ValueNotifier<TrainerOverlayState>(_emptyState());

  final stateListenerId = MultiWindowNative.registerListener(kStateMethod,
      (call) async {
    try {
      final raw = call.arguments;
      final Map<String, dynamic> json = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      state.value = TrainerOverlayState.fromJson(json);
      // When BikeControl loses focus and regains it on the MAIN window, the
      // overlay sub-window's engine stops scheduling frames automatically.
      WidgetsBinding.instance.scheduleForcedFrame();
    } catch (e) {
      if (kDebugMode) debugPrint('overlay state decode failed: $e');
    }
  });

  // Restore the persisted position if main sends it as part of the args.
  Offset? initialPosition;
  if (args.length > 1) {
    try {
      final m = jsonDecode(args[1]) as Map<String, dynamic>;
      final x = (m['x'] as num?)?.toDouble();
      final y = (m['y'] as num?)?.toDouble();
      if (x != null && y != null) initialPosition = Offset(x, y);
    } catch (_) {}
  }
  if (initialPosition != null) {
    await wm.windowManager.setPosition(initialPosition);
  }

  final overlayListener = _MacOSOverlayListener(windowId, stateListenerId);
  wm.windowManager.addListener(overlayListener);

  debugPrint('[overlay-run/mac] about to runApp');
  runApp(_OverlayApp(
    state: state,
    onModeToggle: () {
      try {
        MultiWindowNative.notifyAllWindows(kOverlayActionMethod, {
          'windowId': windowId,
          'action': 'toggleMode',
        });
      } catch (e) {
        if (kDebugMode) debugPrint('overlay action send failed (toggleMode): $e');
      }
    },
    onPrimaryDecrement: () {
      try {
        MultiWindowNative.notifyAllWindows(kOverlayActionMethod, {
          'windowId': windowId,
          'action': 'primaryDecrement',
        });
      } catch (e) {
        if (kDebugMode) debugPrint('overlay action send failed (primaryDecrement): $e');
      }
    },
    onPrimaryIncrement: () {
      try {
        MultiWindowNative.notifyAllWindows(kOverlayActionMethod, {
          'windowId': windowId,
          'action': 'primaryIncrement',
        });
      } catch (e) {
        if (kDebugMode) debugPrint('overlay action send failed (primaryIncrement): $e');
      }
    },
  ));
  debugPrint('[overlay-run/mac] runApp returned');

  // Tell main we're alive.
  await MultiWindowNative.notifyAllWindows(kOverlayReadyMethod, {
    'windowId': windowId,
  });
  debugPrint('[overlay-run/mac] notified ready');

  // Required by the package to avoid black-screen on macOS.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await WidgetsBinding.instance.endOfFrame;
    await MultiWindowNative.notifyUiRendered();
  });
}

class _MacOSOverlayListener extends wm.WindowListener {
  final int _windowId;
  final String _stateListenerId;
  _MacOSOverlayListener(this._windowId, this._stateListenerId);

  @override
  void onWindowMoved() {
    () async {
      try {
        final pos = await wm.windowManager.getPosition();
        await MultiWindowNative.notifyAllWindows(kOverlayPositionMethod, {
          'windowId': _windowId,
          'x': pos.dx,
          'y': pos.dy,
        });
      } catch (_) {}
    }();
  }

  /// User clicked the close button (or otherwise closed the window
  /// externally). Tell main to mark the overlay as no longer showing,
  /// drop our state-listener registration, then notify the package to
  /// deregister this engine.
  @override
  void onWindowClose() {
    () async {
      try {
        await MultiWindowNative.notifyAllWindows(kOverlayClosedMethod, {
          'windowId': _windowId,
        });
      } catch (_) {}
      try {
        MultiWindowNative.unregisterListener(
          methodName: kStateMethod,
          id: _stateListenerId,
        );
      } catch (_) {}
      try {
        wm.windowManager.removeListener(this);
      } catch (_) {}
      try {
        await MultiWindowNative.closeWindow(
          isMainWindow: false,
          windowId: _windowId.toString(),
        );
      } catch (_) {}
    }();
  }
}

// ---------------------------------------------------------------------------
// Shared UI widget
// ---------------------------------------------------------------------------

TrainerOverlayState _emptyState() => const TrainerOverlayState(
  gear: 0,
  maxGear: 0,
  gearRatio: 1.0,
  mode: TrainerMode.simMode,
  powerW: null,
  cadenceRpm: null,
  ergTargetW: null,
  fields: {OverlayField.power, OverlayField.cadence},
);

class _OverlayApp extends StatelessWidget {
  final ValueListenable<TrainerOverlayState> state;
  final VoidCallback? onModeToggle;
  final VoidCallback? onPrimaryDecrement;
  final VoidCallback? onPrimaryIncrement;

  const _OverlayApp({
    required this.state,
    this.onModeToggle,
    this.onPrimaryDecrement,
    this.onPrimaryIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        // Explicit opaque dark surface. Using `Theme.of(context).colorScheme.background`
        // resolves to near-white under shadcn's light theme, which made the
        // entire sub-window look blank on Windows. A fixed dark colour also
        // saves us from relying on platform transparency (which Win32 doesn't
        // implement without WS_EX_LAYERED).
        backgroundColor: const Color(0xFF111114),
        child: Center(
          child: TrainerOverlayView(
            state: state,
            onModeToggle: onModeToggle,
            onDragStart: () => wm.windowManager.startDragging(),
            onPrimaryDecrement: onPrimaryDecrement,
            onPrimaryIncrement: onPrimaryIncrement,
          ),
        ),
      ),
    );
  }
}
