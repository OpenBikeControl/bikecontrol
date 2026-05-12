import 'dart:convert';

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Overlay-side handle to the custom Kotlin bridge that forwards action
/// requests to the main isolate. The Kotlin side
/// (OverlayActionBridge.installOverlayHandler) registers a MethodCallHandler
/// for this channel name on the overlay engine; the main side translates
/// `'push'` into an `'action'` call back to main Dart.
const _overlayActionsChannel = MethodChannel('bike_control/overlay_actions');

void runOverlayApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();
  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  late final ValueNotifier<TrainerOverlayState> _state;

  @override
  void initState() {
    super.initState();
    _state = ValueNotifier(_emptyState());
    FlutterOverlayWindow.overlayListener.listen(_onMessage);
  }

  void _onMessage(dynamic raw) {
    if (raw == null) return;
    try {
      final Map<String, dynamic> json = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      // BasicMessageChannel echoes our own sends back; ignore action requests
      // we just dispatched to the main isolate.
      if (json.containsKey('action')) return;
      _state.value = TrainerOverlayState.fromJson(json);
    } catch (e, s) {
      // Keep last known state on decode failure.
      recordError(e, s, context: 'overlay.android.state.decode');
    }
  }

  static TrainerOverlayState _emptyState() => const TrainerOverlayState(
    gear: 0,
    maxGear: 0,
    gearRatio: 1.0,
    mode: TrainerMode.simMode,
    powerW: null,
    cadenceRpm: null,
    ergTargetW: null,
    fields: {OverlayField.power, OverlayField.cadence},
  );

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0x00000000),
        child: Center(
          child: TrainerOverlayView(
            state: _state,
            // Mode toggle: not exposed (no pill tap on Android).
            onModeToggle: null,
            // flutter_overlay_window provides its own dragging.
            onDragStart: null,
            // Send action requests back to the main isolate, where the
            // controller listens via `FlutterOverlayWindow.overlayListener`.
            onPrimaryDecrement: () {
              _overlayActionsChannel
                  .invokeMethod('push', 'primaryDecrement')
                  .catchError((Object e, StackTrace s) {
                recordError(e, s, context: 'overlay.android.push.primaryDecrement');
                return null;
              });
            },
            onPrimaryIncrement: () {
              _overlayActionsChannel
                  .invokeMethod('push', 'primaryIncrement')
                  .catchError((Object e, StackTrace s) {
                recordError(e, s, context: 'overlay.android.push.primaryIncrement');
                return null;
              });
            },
          ),
        ),
      ),
    );
  }
}
