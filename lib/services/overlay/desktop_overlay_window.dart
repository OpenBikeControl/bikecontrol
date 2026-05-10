import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart' as dmw;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// Channel name shared between the main window and overlay window.
/// Both sides register on this channel; the main window sends 'state' / 'close'
/// to the overlay; the overlay sends 'hide' / 'toggleMode' / 'positionChanged'
/// to the main window.
const kOverlayChannel = 'bike_control/overlay';

/// Entry point for the overlay sub-window process.
///
/// Called from [main] when [dmw.WindowController.fromCurrentEngine] reports
/// that this engine was spawned as a sub-window whose arguments contain
/// `role == "trainer-overlay"`.
Future<void> runDesktopOverlayWindow(dmw.WindowController self) async {
  await wm.windowManager.ensureInitialized();

  await wm.windowManager.waitUntilReadyToShow(
    const wm.WindowOptions(
      size: Size(220, 140),
      minimumSize: Size(220, 140),
      backgroundColor: Color(0x00000000),
      skipTaskbar: true,
      titleBarStyle: wm.TitleBarStyle.hidden,
      alwaysOnTop: true,
    ),
    () async {
      await wm.windowManager.setHasShadow(false);
      await wm.windowManager.setResizable(false);
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

  // Register the overlay side of the shared bidirectional channel.
  // The main window will send 'state' and 'close' calls through here.
  final channel = dmw.WindowMethodChannel(kOverlayChannel);
  await self.setWindowMethodHandler((call) async {
    switch (call.method) {
      case 'state':
        try {
          final Map<String, dynamic> json = call.arguments is String
              ? jsonDecode(call.arguments as String) as Map<String, dynamic>
              : Map<String, dynamic>.from(call.arguments as Map);
          state.value = TrainerOverlayState.fromJson(json);
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

  // Track window moves to persist position back to the main process.
  wm.windowManager.addListener(_OverlayWindowListener(channel));

  runApp(_OverlayApp(state: state, channel: channel));
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
  final dmw.WindowMethodChannel _channel;
  _OverlayWindowListener(this._channel);

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

class _OverlayApp extends StatelessWidget {
  final ValueListenable<TrainerOverlayState> state;
  final dmw.WindowMethodChannel channel;
  const _OverlayApp({required this.state, required this.channel});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0x00000000),
        child: Center(
          child: TrainerOverlayView(
            state: state,
            onModeToggle: () {
              channel.invokeMethod('toggleMode').catchError((_) {});
            },
            onDragStart: () => wm.windowManager.startDragging(),
            onPrimaryDecrement: () {
              channel.invokeMethod('primaryDecrement').catchError((_) {});
            },
            onPrimaryIncrement: () {
              channel.invokeMethod('primaryIncrement').catchError((_) {});
            },
          ),
        ),
      ),
    );
  }
}
