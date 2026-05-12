import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/foundation.dart';
import 'package:multi_window_native/multi_window_native.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart' as wm;

// ---------------------------------------------------------------------------
// multi_window_native method-name constants.
// ---------------------------------------------------------------------------

/// Method names broadcast between main and overlay windows via
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
/// Called from [main] when `args.contains(kTrainerOverlayRoute)` on both
/// macOS and Windows (multi_window_native on both platforms).
/// [windowId] is the value from `wm.windowManager.getId()`.
Future<void> runDesktopOverlayWindow(
  int windowId,
  List<String> args,
) async {
  await _runOverlay(windowId, args);
}

// ---------------------------------------------------------------------------
// Shared implementation (multi_window_native)
// ---------------------------------------------------------------------------

Future<void> _runOverlay(int windowId, List<String> args) async {
  // Apply individual window settings rather than going through
  // `waitUntilReadyToShow(WindowOptions(...))`. WindowOptions tries to do
  // several things at once (size + titleBarStyle + backgroundColor + ...);
  // on Windows that wedges the sub-window's render surface. Apply settings
  // one at a time post-engine-boot, matching the package example's pattern.
  try {
    await wm.windowManager.setAlwaysOnTop(true);
    await wm.windowManager.setMinimumSize(const Size(180, 100));
    await wm.windowManager.setSize(const Size(220, 140));
    await wm.windowManager.setHasShadow(false);
    if (Platform.isMacOS) {
      await wm.windowManager.setVisibleOnAllWorkspaces(
        true,
        visibleOnFullScreen: true,
      );
    }
  } catch (e, s) {
    recordError(e, s, context: 'overlay.window.setup');
  }

  final state = ValueNotifier<TrainerOverlayState>(_emptyState());

  final stateListenerId = MultiWindowNative.registerListener(kStateMethod, (call) async {
    try {
      final raw = call.arguments;
      final Map<String, dynamic> json = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      state.value = TrainerOverlayState.fromJson(json);
      // When BikeControl loses focus and regains it on the MAIN window, the
      // overlay sub-window's engine stops scheduling frames automatically.
      WidgetsBinding.instance.scheduleForcedFrame();
    } catch (e, s) {
      recordError(e, s, context: 'overlay.state.decode');
    }
  });

  // Restore the persisted position if main sent one. The plugin's positional
  // ordering of Dart entrypoint args differs between macOS (routeName, theme,
  // argsJson) and Windows (map-iteration order), so locate the JSON payload
  // by content rather than by index.
  Offset? initialPosition;
  for (var i = 1; i < args.length; i++) {
    final raw = args[i];
    if (!raw.startsWith('{')) continue;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final x = (m['x'] as num?)?.toDouble();
      final y = (m['y'] as num?)?.toDouble();
      if (x != null && y != null) {
        initialPosition = Offset(x, y);
        break;
      }
    } catch (e, s) {
      recordError(e, s, context: 'overlay.position.decode');
    }
  }
  if (initialPosition != null) {
    await wm.windowManager.setPosition(initialPosition);
  }

  final overlayListener = _OverlayWindowListener(windowId, stateListenerId);
  wm.windowManager.addListener(overlayListener);

  runApp(
    _OverlayApp(
      state: state,
      onModeToggle: () {
        try {
          MultiWindowNative.notifyAllWindows(kOverlayActionMethod, {
            'windowId': windowId,
            'action': 'toggleMode',
          });
        } catch (e, s) {
          recordError(e, s, context: 'overlay.action.toggleMode');
        }
      },
      onPrimaryDecrement: () {
        try {
          MultiWindowNative.notifyAllWindows(kOverlayActionMethod, {
            'windowId': windowId,
            'action': 'primaryDecrement',
          });
        } catch (e, s) {
          recordError(e, s, context: 'overlay.action.primaryDecrement');
        }
      },
      onPrimaryIncrement: () {
        try {
          MultiWindowNative.notifyAllWindows(kOverlayActionMethod, {
            'windowId': windowId,
            'action': 'primaryIncrement',
          });
        } catch (e, s) {
          recordError(e, s, context: 'overlay.action.primaryIncrement');
        }
      },
    ),
  );

  // Tell main we're alive.
  await MultiWindowNative.notifyAllWindows(kOverlayReadyMethod, {
    'windowId': windowId,
  });

  // Required by the package to avoid black-screen on macOS.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await WidgetsBinding.instance.endOfFrame;
    await MultiWindowNative.notifyUiRendered();
  });
}

class _OverlayWindowListener extends wm.WindowListener {
  final int _windowId;
  final String _stateListenerId;
  _OverlayWindowListener(this._windowId, this._stateListenerId);

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
      } catch (e, s) {
        recordError(e, s, context: 'overlay.window.moved');
      }
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
      } catch (e, s) {
        recordError(e, s, context: 'overlay.window.close.notifyClosed');
      }
      try {
        MultiWindowNative.unregisterListener(
          methodName: kStateMethod,
          id: _stateListenerId,
        );
      } catch (e, s) {
        recordError(e, s, context: 'overlay.window.close.unregisterListener');
      }
      try {
        wm.windowManager.removeListener(this);
      } catch (e, s) {
        recordError(e, s, context: 'overlay.window.close.removeListener');
      }
      try {
        await MultiWindowNative.closeWindow(
          isMainWindow: false,
          windowId: _windowId.toString(),
        );
      } catch (e, s) {
        recordError(e, s, context: 'overlay.window.close.closeWindow');
      }
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
    // macOS supports real window transparency via NSWindow alpha (window_manager
    // sets it in `setVisibleOnAllWorkspaces` flow). Windows can't do real
    // transparency without WS_EX_LAYERED, so keep a dark fill there.
    final backgroundColor = const Color(0xFFFFFFFF);
    return ShadcnApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: backgroundColor,
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
