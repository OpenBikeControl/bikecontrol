import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TrainerOverlayView extends StatelessWidget {
  final ValueListenable<TrainerOverlayState> state;

  /// Called when user requests overlay close.
  final VoidCallback onHide;

  /// On desktop, called to toggle ERG/SIM. Pass `null` to render the mode
  /// pill as a static label (Android overlay isolate cannot reliably handle
  /// taps that bridge isolates).
  final VoidCallback? onModeToggle;

  /// Called when the user starts dragging. Desktop wires this to
  /// `windowManager.startDragging()`. Pass `null` on Android (the package
  /// handles dragging natively).
  final VoidCallback? onDragStart;

  const TrainerOverlayView({
    super.key,
    required this.state,
    required this.onHide,
    this.onModeToggle,
    this.onDragStart,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TrainerOverlayState>(
      valueListenable: state,
      builder: (context, s, _) {
        return Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(
            color: cs.background.withOpacity(0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.border),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(context, cs, s),
              const Spacer(),
              Center(
                child: Text(
                  '${s.gear} / ${s.maxGear}',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: cs.foreground,
                  ),
                ),
              ),
              if (s.fields.contains(OverlayField.gearRatio))
                Center(
                  child: Text(
                    'ratio ${s.gearRatio.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: cs.mutedForeground),
                  ),
                ),
              const Spacer(),
              _metricsRow(context, cs, s),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context, ColorScheme cs, TrainerOverlayState s) {
    final modePill = _modePill(cs, s.mode);
    return Row(
      children: [
        if (onModeToggle != null)
          Button.ghost(onPressed: onModeToggle, child: modePill)
        else
          modePill,
        const Spacer(),
        if (onDragStart != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onDragStart!(),
            child: Icon(Icons.drag_indicator, size: 16, color: cs.mutedForeground),
          ),
        IconButton.ghost(
          icon: const Icon(Icons.close, size: 14),
          onPressed: onHide,
        ),
      ],
    );
  }

  Widget _modePill(ColorScheme cs, TrainerMode mode) {
    final label = mode == TrainerMode.ergMode ? 'ERG' : 'SIM';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cs.primaryForeground,
        ),
      ),
    );
  }

  Widget _metricsRow(BuildContext context, ColorScheme cs, TrainerOverlayState s) {
    final children = <Widget>[];
    if (s.fields.contains(OverlayField.power)) {
      children.add(_metric(cs, '${s.powerW ?? '--'} W'));
    }
    if (s.fields.contains(OverlayField.cadence)) {
      children.add(_metric(cs, '${s.cadenceRpm ?? '--'} rpm'));
    }
    if (s.fields.contains(OverlayField.ergTarget) &&
        s.mode == TrainerMode.ergMode) {
      children.add(_metric(cs, 'tgt ${s.ergTargetW ?? '--'} W'));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    );
  }

  Widget _metric(ColorScheme cs, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.foreground,
      ),
    );
  }
}
