import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// Wraps the app body. When `trainerOverlayMode` is true (set by the desktop
/// controller), the wrapper renders the compact overlay instead of `child`.
class TrainerOverlayHost extends StatelessWidget {
  final Widget child;
  const TrainerOverlayHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: trainerOverlayMode,
      builder: (context, isOverlay, _) {
        if (!isOverlay) return child;
        return _OverlayBody();
      },
    );
  }
}

class _OverlayBody extends StatefulWidget {
  @override
  State<_OverlayBody> createState() => _OverlayBodyState();
}

class _OverlayBodyState extends State<_OverlayBody> {
  late final ValueNotifier<TrainerOverlayState> _state;
  FitnessBikeDefinition? _def;
  Listenable? _bound;

  @override
  void initState() {
    super.initState();
    _state = ValueNotifier(_emptyState());
    _bind();
  }

  void _bind() {
    final proxy = core.connection.proxyDevices.firstOrNull;
    final def = proxy?.emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return;
    _def = def;
    _bound = Listenable.merge([
      def.currentGear,
      def.gearRatio,
      def.trainerMode,
      def.powerW,
      def.cadenceRpm,
      def.ergTargetPower,
    ]);
    _bound!.addListener(_recompute);
    _recompute();
  }

  void _recompute() {
    final def = _def;
    if (def == null) return;
    _state.value = TrainerOverlayState(
      gear: def.currentGear.value,
      maxGear: def.maxGear,
      gearRatio: def.gearRatio.value,
      mode: def.trainerMode.value,
      powerW: def.powerW.value,
      cadenceRpm: def.cadenceRpm.value,
      ergTargetW: def.ergTargetPower.value,
      fields: core.settings.getOverlayFields(),
    );
  }

  @override
  void dispose() {
    _bound?.removeListener(_recompute);
    _state.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0x00000000),
      child: Center(
        child: TrainerOverlayView(
          state: _state,
          onHide: () => TrainerOverlayService.forCurrentPlatform().hide(),
          onModeToggle: () {
            final def = _def;
            if (def == null) return;
            if (def.trainerMode.value == TrainerMode.ergMode) {
              def.exitErgMode();
            } else {
              def.setManualErgPower(def.ergTargetPower.value ?? 150);
            }
          },
          onDragStart: () => wm.windowManager.startDragging(),
        ),
      ),
    );
  }
}
