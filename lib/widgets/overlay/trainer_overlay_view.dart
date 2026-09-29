import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/utils/gear_readout.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
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

  /// The gear numeral's design size at 1.0x text. It is the one thing a
  /// rider glances at the overlay for: it grows with the text size and is
  /// never scaled down to make room — the window is sized around it instead.
  static const double gearSize = 36;

  /// Default window width on desktop; wider when the text size needs it.
  static const double defaultWindowWidth = 220;

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(8, 6, 8, 8);

  /// Leading app icon / trailing drag handle beside the numeral.
  static const double _sideSlot = 20;

  /// Hit area of the −/+ buttons; their visible circle is smaller.
  static const double _hit = 44;
  static const double _rowGap = 4;

  /// The widest things the numeral shows: a gear readout, a front/rear
  /// readout and an ERG target.
  static const List<String> _widestReadouts = ['88/88', '2×88', '888 W'];

  static TextStyle _gearStyle(Color? color) =>
      BkNumerals.gear(gearSize, color: color, height: 1.0).copyWith(letterSpacing: -1.0);

  /// The window the overlay needs at [textScaler]: the numeral at full size
  /// plus its side slots, and the readings row (with −/+ when [controls]).
  static Size windowSize(TextScaler textScaler, {bool controls = true}) {
    var numeralWidth = 0.0;
    var numeralHeight = 0.0;
    final style = const Typography.geist().sans.merge(_gearStyle(null));
    for (final readout in _widestReadouts) {
      final painter = TextPainter(
        text: TextSpan(text: readout, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      numeralWidth = numeralWidth > painter.width ? numeralWidth : painter.width;
      numeralHeight = numeralHeight > painter.height ? numeralHeight : painter.height;
      painter.dispose();
    }
    final numeralRow = numeralWidth + 2 * _sideSlot + 8;
    // −, the mode pill with room for one reading, +.
    final readingsRow = controls ? 2 * _hit + 96 : 0.0;
    final inner = numeralRow > readingsRow ? numeralRow : readingsRow;
    final readingsHeight = controls ? _hit : textScaler.scale(20);
    return Size(
      (inner + _padding.horizontal).ceilToDouble(),
      (numeralHeight + _rowGap + readingsHeight + _padding.vertical).ceilToDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final useConstraints = defaultTargetPlatform == TargetPlatform.android;
    final textScaler = MediaQuery.textScalerOf(context);
    return ValueListenableBuilder<TrainerOverlayState>(
      valueListenable: state,
      builder: (context, s, _) {
        final controls = s.fields.contains(OverlayField.controls);
        return Container(
          constraints: useConstraints
              ? BoxConstraints(maxWidth: windowSize(textScaler, controls: controls).width)
              : null,
          decoration: useConstraints
              ? BoxDecoration(
                  color: cs.background.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.border),
                )
              : null,
          padding: _padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _numeralRow(context, cs, s, controls: controls),
              const SizedBox(height: _rowGap),
              _readingsRow(context, cs, s, controls: controls),
            ],
          ),
        );
      },
    );
  }

  /// Row 1: the big numeral (gear in SIM, target watts in ERG), with the app
  /// icon (when there are no −/+) and the drag handle in slim side slots.
  Widget _numeralRow(BuildContext context, ColorScheme cs, TrainerOverlayState s, {required bool controls}) {
    final primary = s.mode == TrainerMode.ergMode
        ? '${s.ergTargetW ?? '--'} W'
        : formatGearReadout(
            currentGear: s.gear,
            maxGear: s.maxGear,
            frontShiftEnabled: s.frontShiftEnabled,
            largeRing: s.frontRingLarge,
          );
    return Row(
      children: [
        SizedBox(
          width: _sideSlot,
          child: controls
              ? null
              : const Align(
                  alignment: Alignment.topLeft,
                  child: Image(image: AssetImage('icon.png'), width: 18, height: 18),
                ),
        ),
        Expanded(
          child: Center(
            child: Text(primary, maxLines: 1, softWrap: false, style: _gearStyle(cs.foreground)),
          ),
        ),
        SizedBox(
          width: _sideSlot,
          child: onDragStart != null
              // Opaque, so the whole slot drags, not just the 14 px icon.
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => onDragStart!(),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Icon(LucideIcons.gripVertical, size: 14, color: cs.mutedForeground),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  /// Row 2: the SIM/ERG pill and the readings, between − and + when
  /// `OverlayField.controls` is on — below the numeral, so the buttons never
  /// take its width. When the row is short of room the readings go first
  /// (gear ratio, then cadence); the gear never does.
  Widget _readingsRow(BuildContext context, ColorScheme cs, TrainerOverlayState s, {required bool controls}) {
    final isErg = s.mode == TrainerMode.ergMode;
    // The overlay engine may run without localizations (older hosts); the
    // buttons are still buttons, just unlabelled, rather than a crash.
    final l10n = AppLocalizations.maybeOf(context);
    final pill = _modePill(context, cs, s.mode);
    final pillWidget = onModeToggle != null
        ? Button.ghost(
            onPressed: onModeToggle,
            style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
            child: pill,
          )
        : pill;

    // In the order they give way: the first is the last to go.
    final readings = <String>[
      if (s.fields.contains(OverlayField.power)) '${s.powerW ?? '--'} W',
      if (s.fields.contains(OverlayField.cadence)) '${s.cadenceRpm ?? '--'} rpm',
      // Gear ratio is meaningless in ERG mode; only show it in SIM.
      if (!isErg && s.fields.contains(OverlayField.gearRatio)) '×${s.gearRatio.toStringAsFixed(2)}',
    ];
    final readingStyle = context.typography.xSmall.copyWith(fontWeight: FontWeight.w600, color: cs.mutedForeground);
    const readingGap = 8.0;

    final middle = LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        double widthOf(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(readingStyle)),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        // Room for the readings once the pill has its place.
        var room = constraints.maxWidth - _pillWidth(context) - readingGap;
        final shown = <String>[];
        for (final reading in readings) {
          final needed = widthOf(reading) + (shown.isEmpty ? 0 : readingGap);
          if (shown.isNotEmpty && needed > room) break;
          shown.add(reading);
          room -= needed;
        }
        return Row(
          mainAxisAlignment: controls ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
          children: [
            pillWidget,
            if (shown.isNotEmpty) ...[
              const SizedBox(width: readingGap),
              // Only the very last reading can still be too wide (a huge text
              // size in the narrowest window); it scales down, the gear doesn't.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: readingGap,
                    children: [for (final reading in shown) Text(reading, style: readingStyle)],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );

    if (!controls) return middle;
    return Row(
      children: [
        _shiftButton(
          cs,
          LucideIcons.minus,
          onPrimaryDecrement,
          label: isErg ? l10n?.a11yDecrease : l10n?.actionShiftDown,
        ),
        Expanded(child: middle),
        _shiftButton(cs, LucideIcons.plus, onPrimaryIncrement, label: isErg ? l10n?.a11yIncrease : l10n?.actionShiftUp),
      ],
    );
  }

  double _pillWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'SIM',
        style: DefaultTextStyle.of(
          context,
        ).style.merge(context.typography.caption.copyWith(fontWeight: FontWeight.w700)),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width + 12;
    painter.dispose();
    return width;
  }

  /// A 44 px hit area around a smaller visible circle, so the buttons are
  /// easy to hit without drawing more attention than the gear.
  Widget _shiftButton(ColorScheme cs, IconData icon, VoidCallback? onPressed, {String? label}) {
    final disabled = onPressed == null;
    return BkTappable(
      onPressed: onPressed,
      label: label,
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(_hit / 2),
      child: SizedBox.square(
        dimension: _hit,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.muted,
              shape: BoxShape.circle,
              border: Border.all(color: cs.border),
            ),
            child: Opacity(
              opacity: disabled ? 0.4 : 1.0,
              child: Icon(icon, size: 18, color: cs.foreground),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modePill(BuildContext context, ColorScheme cs, TrainerMode mode) {
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
        style: context.typography.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.primaryForeground,
        ),
      ),
    );
  }
}
