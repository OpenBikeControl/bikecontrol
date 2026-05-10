import 'dart:convert';

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// The Android overlay isolate's entry point. Runs in a separate Flutter
/// engine launched by `flutter_overlay_window`. State is delivered from the
/// main isolate via `FlutterOverlayWindow.shareData(json)`.
///
/// Uses plain Material widgets — `ShadcnApp` does not produce stable layout
/// constraints inside the overlay engine.
@pragma('vm:entry-point')
void overlayMain() {
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: Center(
          child: ValueListenableBuilder<TrainerOverlayState>(
            valueListenable: _state,
            builder: (context, s, _) => _OverlayCard(state: s),
          ),
        ),
      ),
    );
  }
}

class _OverlayCard extends StatelessWidget {
  final TrainerOverlayState state;
  const _OverlayCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final showPower = s.fields.contains(OverlayField.power);
    final showCadence = s.fields.contains(OverlayField.cadence);
    final showErgTarget =
        s.fields.contains(OverlayField.ergTarget) && s.mode == TrainerMode.ergMode;
    final showRatio = s.fields.contains(OverlayField.gearRatio);

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xEE111114),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2E)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _modePill(s.mode),
              const Spacer(),
              GestureDetector(
                onTap: () => FlutterOverlayWindow.closeOverlay(),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 14, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${s.gear} / ${s.maxGear}',
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
          if (showRatio)
            Center(
              child: Text(
                'ratio ${s.gearRatio.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ),
          const SizedBox(height: 6),
          if (showPower || showCadence || showErgTarget)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (showPower) _metric('${s.powerW ?? '--'} W'),
                if (showCadence) _metric('${s.cadenceRpm ?? '--'} rpm'),
                if (showErgTarget) _metric('tgt ${s.ergTargetW ?? '--'} W'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _modePill(TrainerMode mode) {
    final label = mode == TrainerMode.ergMode ? 'ERG' : 'SIM';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _metric(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
}
