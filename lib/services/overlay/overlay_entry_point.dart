import 'dart:convert';

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
      _state.value = TrainerOverlayState.fromJson(json);
    } catch (e) {
      // Keep last known state on decode failure.
      if (kDebugMode) debugPrint('overlay decode failed: $e');
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
            onHide: () => FlutterOverlayWindow.closeOverlay(),
            // No mode toggle: cannot reach the main isolate from here cheaply.
            onModeToggle: null,
            // flutter_overlay_window provides its own dragging.
            onDragStart: null,
          ),
        ),
      ),
    );
  }
}
