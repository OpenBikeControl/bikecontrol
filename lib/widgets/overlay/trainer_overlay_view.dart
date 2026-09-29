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

  static const EdgeInsets _padding = EdgeInsets.all(8);

  /// The drag handle at the end of the row (desktop).
  static const double _dragSlot = 16;

  /// The −/+ circles; the whole circle is the hit area.
  static const double _hit = 44;

  /// Space between the parts of the row.
  static const double _gap = 6;

  /// The hairline between the gear and the mode/readings, with its margins.
  static const double _dividerSlot = 1 + 2 * 8.0;

  /// Space between the mode pill and the readings under it.
  static const double _sideGap = 6;

  /// The widest things the numeral shows: a gear readout, a front/rear
  /// readout and an ERG target.
  static const List<String> _widestReadouts = ['88/88', '2×88', '888 W'];

  /// The widest single reading; the side column always has room for one.
  static const String _widestReading = '8888 rpm';

  static TextStyle _gearStyle(Color? color) =>
      BkNumerals.gear(gearSize, color: color, height: 1.0).copyWith(letterSpacing: -1.0);

  /// Readings are numbers in the display face, a step below the gear.
  static const double _readingSize = 20;
  static TextStyle _readingStyle(Color? color) => BkNumerals.display(_readingSize, color: color, height: 1.0);

  static TextStyle _microStyle(Typography typography, Color? color) =>
      typography.caption.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.1, color: color, height: 1.2);

  static Size _measure(String text, TextStyle style, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  /// The window the overlay needs at [textScaler]: one row of −, the numeral
  /// at full size with its label, +, and the mode pill over one reading.
  static Size windowSize(TextScaler textScaler, {bool controls = true}) {
    const typography = Typography.geist();
    final gearStyle = typography.sans.merge(_gearStyle(null));
    var numeral = Size.zero;
    for (final readout in _widestReadouts) {
      final size = _measure(readout, gearStyle, textScaler);
      numeral = Size(
        numeral.width > size.width ? numeral.width : size.width,
        numeral.height > size.height ? numeral.height : size.height,
      );
    }
    final label = _measure('GEAR', typography.sans.merge(_microStyle(typography, null)), textScaler);
    final reading = _measure(_widestReading, typography.sans.merge(_readingStyle(null)), textScaler);
    final pill = _measure('SIM', typography.sans.merge(_pillTextStyle(typography, null)), textScaler);

    // Room for cadence and the ratio side by side, as the rider usually
    // has them on; power goes first when all three are on.
    final pair =
        _measure('188 rpm', typography.sans.merge(_readingStyle(null)), textScaler).width +
        10 +
        _measure('×8.88', typography.sans.merge(_readingStyle(null)), textScaler).width;
    var side = reading.width > pill.width + 16 ? reading.width : pill.width + 16;
    if (pair > side) side = pair;
    final width =
        (controls ? 2 * (_hit + _gap) : 0) +
        numeral.width +
        _dividerSlot +
        side +
        _gap +
        _dragSlot +
        _padding.horizontal;
    final numeralBlock = numeral.height + label.height;
    final sideBlock = pill.height + 4 + _sideGap + reading.height;
    var height = controls ? _hit : 0.0;
    if (numeralBlock > height) height = numeralBlock;
    if (sideBlock > height) height = sideBlock;
    // + the Android card's hairline border on each side.
    return Size((width + 2).ceilToDouble(), (height + _padding.vertical + 2).ceilToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final useConstraints = defaultTargetPlatform == TargetPlatform.android;
    final textScaler = MediaQuery.textScalerOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<TrainerOverlayState>(
      valueListenable: state,
      builder: (context, s, _) {
        final controls = s.fields.contains(OverlayField.controls);
        final size = windowSize(textScaler, controls: controls);
        return Container(
          constraints: useConstraints ? BoxConstraints(maxWidth: size.width) : null,
          // On Android the overlay floats over the trainer app: a pill in the
          // card colour, nearly opaque. The desktop window paints the card
          // colour itself (it can't be transparent everywhere).
          decoration: useConstraints
              ? BoxDecoration(
                  color: cs.card.withValues(alpha: dark ? 0.94 : 0.95),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cs.border),
                )
              : null,
          padding: _padding,
          child: _row(context, cs, s, controls: controls),
        );
      },
    );
  }

  /// −, the big numeral (gear in SIM, target watts in ERG) with its label, +,
  /// a hairline, then the mode pill over the readings, and the drag handle.
  Widget _row(BuildContext context, ColorScheme cs, TrainerOverlayState s, {required bool controls}) {
    final isErg = s.mode == TrainerMode.ergMode;
    // The overlay engine may run without localizations (older hosts); the
    // buttons are still buttons, just unlabelled, rather than a crash.
    final l10n = AppLocalizations.maybeOf(context);
    final primary = isErg
        ? '${s.ergTargetW ?? '--'} W'
        : formatGearReadout(
            currentGear: s.gear,
            maxGear: s.maxGear,
            frontShiftEnabled: s.frontShiftEnabled,
            largeRing: s.frontRingLarge,
          );
    final microStyle = _microStyle(context.typography, cs.mutedForeground);
    final numeral = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(primary, maxLines: 1, softWrap: false, style: _gearStyle(cs.foreground)),
        // In ERG the numeral carries its own unit; the label keeps its line
        // so the numeral doesn't jump when the mode changes.
        Text(
          isErg ? '' : (l10n?.rideGear.toUpperCase() ?? 'GEAR'),
          maxLines: 1,
          style: microStyle,
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (controls) ...[
          _shiftButton(
            cs,
            LucideIcons.minus,
            onPrimaryDecrement,
            label: isErg ? l10n?.a11yDecrease : l10n?.actionShiftDown,
          ),
          const SizedBox(width: _gap),
        ],
        numeral,
        if (controls) ...[
          const SizedBox(width: _gap),
          _shiftButton(
            cs,
            LucideIcons.plus,
            onPrimaryIncrement,
            label: isErg ? l10n?.a11yIncrease : l10n?.actionShiftUp,
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SizedBox(width: 1, height: 40, child: ColoredBox(color: cs.border)),
        ),
        Expanded(child: _side(context, cs, s)),
        const SizedBox(width: _gap),
        SizedBox(
          width: _dragSlot,
          child: onDragStart != null
              // Opaque, so the whole slot drags, not just the 14 px icon.
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => onDragStart!(),
                  child: Center(
                    child: Icon(LucideIcons.gripVertical, size: 14, color: cs.mutedForeground),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  /// The SIM/ERG pill over the readings. When the column is short of room
  /// the readings go first (gear ratio, then cadence); the gear never does.
  Widget _side(BuildContext context, ColorScheme cs, TrainerOverlayState s) {
    final isErg = s.mode == TrainerMode.ergMode;
    final pill = _modePill(context, cs, s.mode);
    final pillWidget = onModeToggle != null
        ? Button.ghost(
            onPressed: onModeToggle,
            style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
            child: pill,
          )
        : pill;

    // In the order they give way: the first is the last to go.
    final readings = <(String, String)>[
      if (s.fields.contains(OverlayField.power)) ('${s.powerW ?? '--'}', 'W'),
      if (s.fields.contains(OverlayField.cadence)) ('${s.cadenceRpm ?? '--'}', 'rpm'),
      // Gear ratio is meaningless in ERG mode; only show it in SIM.
      if (!isErg && s.fields.contains(OverlayField.gearRatio)) ('×${s.gearRatio.toStringAsFixed(2)}', ''),
    ];
    final valueStyle = _readingStyle(cs.foreground);
    final unitStyle = context.typography.caption.copyWith(color: cs.mutedForeground);
    const readingGap = 10.0;

    Widget reading((String, String) r) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: r.$1, style: valueStyle),
          if (r.$2.isNotEmpty) TextSpan(text: ' ${r.$2}', style: unitStyle),
        ],
      ),
      style: unitStyle,
      maxLines: 1,
      softWrap: false,
    );

    final readingsRow = LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        double widthOf((String, String) r) {
          final painter = TextPainter(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style.merge(unitStyle),
              children: [
                TextSpan(text: r.$1, style: valueStyle),
                if (r.$2.isNotEmpty) TextSpan(text: ' ${r.$2}', style: unitStyle),
              ],
            ),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        var room = constraints.maxWidth;
        final shown = <(String, String)>[];
        for (final r in readings) {
          final needed = widthOf(r) + (shown.isEmpty ? 0 : readingGap);
          if (shown.isNotEmpty && needed > room) break;
          shown.add(r);
          room -= needed;
        }
        if (shown.isEmpty) return const SizedBox.shrink();
        // Only the very last reading can still be too wide (a huge text size
        // in the narrowest window); it scales down, the gear doesn't.
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: readingGap,
              children: [for (final r in shown) reading(r)],
            ),
          ),
        );
      },
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pillWidget,
        if (readings.isNotEmpty) ...[const SizedBox(height: _sideGap), readingsRow],
      ],
    );
  }

  /// A −/+ circle: a quiet fill that doesn't draw more attention than the
  /// gear.
  Widget _shiftButton(ColorScheme cs, IconData icon, VoidCallback? onPressed, {String? label}) {
    final disabled = onPressed == null;
    return BkTappable(
      onPressed: onPressed,
      label: label,
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(_hit / 2),
      child: Container(
        width: _hit,
        height: _hit,
        decoration: BoxDecoration(color: cs.muted, shape: BoxShape.circle),
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Icon(icon, size: 22, color: cs.foreground),
        ),
      ),
    );
  }

  static TextStyle _pillTextStyle(Typography typography, Color? color) =>
      typography.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.7, color: color);

  Widget _modePill(BuildContext context, ColorScheme cs, TrainerMode mode) {
    final label = mode == TrainerMode.ergMode ? 'ERG' : 'SIM';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: _pillTextStyle(context.typography, cs.primaryForeground)),
    );
  }
}
