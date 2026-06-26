import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/utils/gear_readout.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TrainerOverlayView extends StatelessWidget {
  final ValueListenable<TrainerOverlayState> state;

  /// On desktop, called to toggle ERG/SIM. Pass `null` to render the mode
  /// pill as a static label.
  final VoidCallback? onModeToggle;

  /// Called when the user starts dragging. Desktop wires this to
  /// `windowManager.startDragging()`. Pass `null` on Android (the package
  /// handles dragging natively).
  final VoidCallback? onDragStart;

  /// Called when the user taps the − button next to the primary value.
  /// In SIM mode this should shift down a gear; in ERG mode it should
  /// decrement target watts. Required when `OverlayField.controls` is in
  /// `state.fields`; otherwise unused.
  final VoidCallback? onPrimaryDecrement;

  /// Called when the user taps the + button next to the primary value.
  final VoidCallback? onPrimaryIncrement;

  const TrainerOverlayView({
    super.key,
    required this.state,
    this.onModeToggle,
    this.onDragStart,
    this.onPrimaryDecrement,
    this.onPrimaryIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final useConstraints = defaultTargetPlatform == TargetPlatform.android;
    return ValueListenableBuilder<TrainerOverlayState>(
      valueListenable: state,
      builder: (context, s, _) {
        return Container(
          constraints: useConstraints
              ? BoxConstraints(maxWidth: s.fields.contains(OverlayField.controls) ? 230 : 160)
              : null,
          decoration: useConstraints
              ? BoxDecoration(
                  color: cs.background.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.border),
                )
              : null,
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _primaryRow(context, cs, s),
              const SizedBox(height: 2),
              _bottomRow(context, cs, s),
            ],
          ),
        );
      },
    );
  }

  /// Row 1: big primary value (gear in SIM, target watts in ERG). When
  /// `OverlayField.controls` is enabled, − and + buttons flank the primary
  /// and the row is bigger; otherwise a small app icon sits on the leading
  /// edge. Drag handle is always trailing.
  Widget _primaryRow(BuildContext context, ColorScheme cs, TrainerOverlayState s) {
    final isErg = s.mode == TrainerMode.ergMode;
    final primary = isErg
        ? '${s.ergTargetW ?? '--'} W'
        : formatGearReadout(
            currentGear: s.gear,
            maxGear: s.maxGear,
            frontShiftEnabled: s.frontShiftEnabled,
            largeRing: s.frontRingLarge,
          );
    final showControls = s.fields.contains(OverlayField.controls);

    final primaryText = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        primary,
        style: TextStyle(
          fontSize: showControls ? 36 : 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          color: cs.foreground,
          height: 1.0,
        ),
      ),
    );

    final primaryBlock = showControls
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _shiftButton(cs, Icons.remove, onPrimaryDecrement),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: primaryText,
              ),
              _shiftButton(cs, Icons.add, onPrimaryIncrement),
            ],
          )
        : primaryText;

    return SizedBox(
      height: showControls ? 48 : 36,
      child: Row(
        children: [
          if (!showControls)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Image(
                image: AssetImage('icon.png'),
                width: 18,
                height: 18,
              ),
            ),
          Expanded(child: Center(child: primaryBlock)),
          if (onDragStart != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => onDragStart!(),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.drag_indicator, size: 14, color: cs.mutedForeground),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shiftButton(ColorScheme cs, IconData icon, VoidCallback? onPressed) {
    final disabled = onPressed == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: cs.muted,
          shape: BoxShape.circle,
          border: Border.all(color: cs.border),
        ),
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Icon(icon, size: 22, color: cs.foreground),
        ),
      ),
    );
  }

  Widget _modePill(ColorScheme cs, TrainerMode mode) {
    final label = mode == TrainerMode.ergMode ? 'ERG' : 'SIM';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: cs.primaryForeground,
        ),
      ),
    );
  }

  /// Row 2: SIM/ERG pill, then power · cadence · (in SIM mode also gear-ratio
  /// if opted in). The pill is always shown so the user can see the mode at
  /// a glance; the metrics part hides cleanly when nothing is selected.
  Widget _bottomRow(BuildContext context, ColorScheme cs, TrainerOverlayState s) {
    final isErg = s.mode == TrainerMode.ergMode;
    final pill = _modePill(cs, s.mode);
    final pillWidget = onModeToggle != null
        ? Button.ghost(
            onPressed: onModeToggle,
            style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
            child: pill,
          )
        : pill;

    final metrics = <Widget>[];
    if (s.fields.contains(OverlayField.power)) {
      metrics.add(_metric(cs, '${s.powerW ?? '--'} W'));
    }
    if (s.fields.contains(OverlayField.cadence)) {
      metrics.add(_metric(cs, '${s.cadenceRpm ?? '--'} rpm'));
    }
    // Gear ratio is meaningless in ERG mode; only show it in SIM.
    if (!isErg && s.fields.contains(OverlayField.gearRatio)) {
      metrics.add(_metric(cs, '×${s.gearRatio.toStringAsFixed(2)}'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          pillWidget,
          ...metrics,
        ],
      ),
    );
  }

  Widget _metric(ColorScheme cs, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: cs.mutedForeground,
      ),
    );
  }
}
