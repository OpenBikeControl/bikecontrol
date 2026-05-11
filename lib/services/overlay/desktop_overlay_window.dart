import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/foundation.dart';
import 'package:multi_window_native/multi_window_native.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// Method names broadcast between main and overlay windows via
/// `MultiWindowNative.notifyAllWindows` / `registerListener`. The package's
/// API doesn't allow targeting a specific window, so each side filters by
/// method-name convention:
///   main → overlay: `kStateMethod`
///   overlay → main: `kOverlayActionMethod`, `kOverlayReadyMethod`,
///                   `kOverlayPositionMethod`
const String kStateMethod = 'trainerOverlay.state';
const String kOverlayActionMethod = 'trainerOverlay.action';
const String kOverlayReadyMethod = 'trainerOverlay.ready';
const String kOverlayPositionMethod = 'trainerOverlay.positionChanged';
const String kOverlayClosedMethod = 'trainerOverlay.closed';

/// Entry point for the overlay sub-window process, invoked from `main()` when
/// args contain `kTrainerOverlayRoute`. Configures the secondary window
/// (frameless, transparent, always-on-top, draggable) and runs the overlay UI.
///
/// Communication is via package-level listeners:
/// - listens on `kStateMethod` to receive state updates from main
/// - broadcasts `kOverlayActionMethod` (mode toggle, shift +/-) back to main
/// - broadcasts `kOverlayReadyMethod` once the window is mounted so main knows
///   its windowId
/// - broadcasts `kOverlayPositionMethod` whenever the user drags the window
Future<void> runDesktopOverlayWindow(int windowId, List<String> args) async {
  // Configure the secondary window itself.
  await wm.windowManager.waitUntilReadyToShow(
    const wm.WindowOptions(
      size: Size(220, 100),
      minimumSize: Size(180, 100),
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: wm.TitleBarStyle.hidden,
      alwaysOnTop: true,
    ),
    () async {
      await wm.windowManager.setHasShadow(false);
      await wm.windowManager.setResizable(true);
      if (Platform.isMacOS) {
        await wm.windowManager.setVisibleOnAllWorkspaces(
          true,
          visibleOnFullScreen: true,
        );
      }
      await wm.windowManager.show();
    },
  );

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
      // The ValueNotifier.notifyListeners call still marks the
      // ValueListenableBuilder dirty, but with no scheduled frame, build
      // never runs and the overlay shows stale values. Force a frame.
      WidgetsBinding.instance.scheduleForcedFrame();
    } catch (e) {
      if (kDebugMode) debugPrint('overlay state decode failed: $e');
    }
  });

  // Notify main of our windowId so it can close us later (or filter messages).
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

  final overlayListener = _OverlayWindowListener(windowId, stateListenerId);
  wm.windowManager.addListener(overlayListener);

  runApp(_OverlayApp(state: state, windowId: windowId));

  // Tell main we're alive.
  await MultiWindowNative.notifyAllWindows(kOverlayReadyMethod, {
    'windowId': windowId,
  });

  // Required by the package to avoid black-screen on macOS / Windows.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await WidgetsBinding.instance.endOfFrame;
    await MultiWindowNative.notifyUiRendered();
  });
}

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

class _OverlayApp extends StatelessWidget {
  final ValueListenable<TrainerOverlayState> state;
  final int windowId;
  const _OverlayApp({required this.state, required this.windowId});

  Future<void> _sendAction(String action) async {
    try {
      MultiWindowNative.notifyAllWindows(kOverlayActionMethod, {
        'windowId': windowId,
        'action': action,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('overlay action send failed ($action): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            child: Center(
              child: TrainerOverlayView(
                state: state,
                onModeToggle: () => _sendAction('toggleMode'),
                onDragStart: () => wm.windowManager.startDragging(),
                onPrimaryDecrement: () => _sendAction('primaryDecrement'),
                onPrimaryIncrement: () => _sendAction('primaryIncrement'),
              ),
            ),
          );
        },
      ),
    );
  }
}
