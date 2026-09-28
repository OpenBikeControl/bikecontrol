import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/drivetrain/trainer_drivetrain.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The drivetrain and the two buttons that drive it, side by side: the picture
/// takes the width it needs to stay legible and the shift column takes the rest.
///
/// Stacked, this ran to the height of a whole phone screen for a card that says
/// one number. Beside each other the card is as tall as the taller of the two,
/// which is what lets it sit above the settings it belongs to rather than
/// pushing them off the page.
class DrivetrainControls extends StatelessWidget {
  const DrivetrainControls({
    super.key,
    required this.definition,
    this.compact = false,
    this.dim = false,
  });

  final FitnessBikeDefinition definition;

  /// The home screen's version: a smaller number and no ratio line, for a card
  /// that is one link of a chain rather than the whole page.
  final bool compact;

  /// Paired, but not carrying gears right now — see [TrainerDrivetrain.dim].
  final bool dim;

  double get _gearFontSize => compact ? 30 : 44;

  double get _buttonSize => compact ? 36 : 44;

  double get _gap => compact ? 4 : 6;

  /// Smallest tap target a shift button may have (Android's 48 dp guideline).
  static const double _minTarget = 48;

  /// Equal-width digits. Geist's are proportional by default, so a ratio going
  /// 1.86 → 2.04 is three pixels wider and drags the whole shift column — and
  /// the buttons in it — sideways on an ordinary shift.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Below this the shift column would take so much of the card that the
  /// drivetrain is squeezed into little over half of it, and the picture is the
  /// point. Same breakpoint the ERG side of this card already uses.
  static const double _sideBySideFrom = 600;

  @override
  Widget build(BuildContext context) {
    // The home card's compact form keeps its buttons beside the picture at any
    // width: its column is half as wide, so the drivetrain still gets most of
    // the card, and a chain link has no room to grow taller.
    final stacked = !compact && MediaQuery.sizeOf(context).width < _sideBySideFrom;
    return AnimatedBuilder(
      animation: Listenable.merge([definition.currentGear, definition.gearRatio, definition.gearRatios]),
      builder: (context, _) => stacked ? _stacked(context) : _sideBySide(context),
    );
  }

  Widget _sideBySide(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(child: _picture(context)),
      Gap(compact ? 8 : 12),
      _shiftColumn(context),
    ],
  );

  /// The phone layout: the picture across the full width, the shifter under it.
  Widget _stacked(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TrainerDrivetrain(definition: definition, showGear: false, framed: false, dim: dim),
      const Gap(6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _shiftButton(context, icon: LucideIcons.minus, filled: false, label: context.i18n.actionShiftDown, onTap: definition.shiftDown),
          const Gap(22),
          _gearNumber(context),
          const Gap(22),
          _shiftButton(context, icon: LucideIcons.plus, filled: true, label: context.i18n.actionShiftUp, onTap: definition.shiftUp),
        ],
      ),
      if (definition.frontShiftEnabled) Align(child: _frontRing(context)),
    ],
  );

  Widget _picture(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TrainerDrivetrain(definition: definition, showGear: false, framed: false, dim: dim),
      if (definition.frontShiftEnabled) _frontRing(context),
    ],
  );

  /// Shift down on top, the gear between them, shift up below — the order the
  /// buttons had side by side, stood on end.
  Widget _shiftColumn(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _shiftButton(context, icon: LucideIcons.minus, filled: false, label: context.i18n.actionShiftDown, onTap: definition.shiftDown),
        Gap(_gap),
        _gearNumber(context),
        Gap(_gap),
        _shiftButton(context, icon: LucideIcons.plus, filled: true, label: context.i18n.actionShiftUp, onTap: definition.shiftUp),
      ],
    );
  }

  /// The gear, in a box sized for the highest gear the rider can reach.
  ///
  /// Reserved rather than measured per value, so the buttons above and below
  /// hold their place — otherwise the column jumps outwards on 10 and back on
  /// 9, and the target moves under a thumb already on its way down.
  Widget _gearNumber(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: _gearFontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.5,
      color: cs.foreground,
      // Equal-width digits, so the reserved box is exact for any value of the
      // same length rather than merely close.
      fontFeatures: _tabular,
    );
    final gear = definition.currentGear.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Text('0' * '${definition.maxGear}'.length, style: style),
            ),
            Text('$gear', style: style),
          ],
        ),
        Text(
          // "2.40" on its own says nothing; the word is what makes it a ratio.
          compact ? 'of ${definition.maxGear}' : 'of ${definition.maxGear} · ratio ${_ratio()}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.mutedForeground,
            fontFeatures: _tabular,
          ),
        ),
      ],
    );
  }

  String _ratio() => definition.gearRatio.value.toStringAsFixed(2);

  /// Which chainring the drivetrain is on, and a way to change it.
  ///
  /// The rider already has this on a controller button; having it under the
  /// picture is what makes a virtual front derailleur checkable from the page
  /// that draws one.
  Widget _frontRing(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<FrontRing>(
      valueListenable: definition.frontRing,
      builder: (context, ring, _) {
        final large = ring == FrontRing.large;
        final teeth = large ? definition.largeChainringTeeth : definition.smallChainringTeeth;
        return Button.ghost(
          style: ButtonStyle.ghost().withPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          onPressed: () {
            definition.toggleFrontChainring();
            HapticFeedback.selectionClick();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${large ? 2 : 1}× · ${teeth}T',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: cs.mutedForeground,
                  fontFeatures: _tabular,
                ),
              ),
              const Gap(6),
              Icon(LucideIcons.repeat, size: 13, color: cs.primary),
            ],
          ),
        );
      },
    );
  }

  Widget _shiftButton(
    BuildContext context, {
    required IconData icon,
    required bool filled,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    // The variant's own padding on top of the circle is what stretched this
    // column past the picture beside it, so the padding is only what it takes
    // to make the whole button a 48 px target around the smaller circle.
    final pad = ((_minTarget - _buttonSize) / 2).clamp(2.0, double.infinity);
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: _ghost(cs, pad, icon: icon, filled: filled, onTap: onTap),
    );
  }

  Widget _ghost(ColorScheme cs, double pad, {required IconData icon, required bool filled, required VoidCallback onTap}) {
    return Button.ghost(
      style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.all(pad)),
      onPressed: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: Container(
        width: _buttonSize,
        height: _buttonSize,
        decoration: BoxDecoration(
          color: filled ? cs.primary : cs.muted,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: cs.border, width: 2),
        ),
        child: Icon(
          icon,
          size: compact ? 18 : 22,
          color: filled ? cs.primaryForeground : cs.mutedForeground,
        ),
      ),
    );
  }
}
