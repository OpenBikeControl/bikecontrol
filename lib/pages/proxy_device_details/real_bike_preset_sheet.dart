import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/bike_drivetrain.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/drivetrain_catalog.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Opens "Like my bike": the rider picks their crank and cassette, and the
/// gears become those real ratios (see [BikeDrivetrain.applyTo]).
Future<void> showRealBikePresetSheet(
  BuildContext context, {
  required FitnessBikeDefinition definition,
  required ProxyDevice device,
}) async {
  await openSheet<void>(
    context: context,
    position: OverlayPosition.bottom,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: RealBikePresetForm(
                initial: device.activeShiftingConfig.bikeDrivetrain,
                onCancel: () => closeSheet(sheetContext),
                onApply: (drivetrain) async {
                  closeSheet(sheetContext);
                  await applyRealBikeDrivetrain(definition, device, drivetrain);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Puts [drivetrain]'s gears on the trainer and stores them in [device]'s
/// active shifting config.
Future<void> applyRealBikeDrivetrain(
  FitnessBikeDefinition definition,
  ProxyDevice device,
  BikeDrivetrain drivetrain,
) async {
  final next = drivetrain.applyTo(device.activeShiftingConfig);
  definition.setMaxGear(next.maxGear);
  if (drivetrain.isDouble &&
      (definition.smallChainringTeeth != next.smallChainringTeeth ||
          definition.largeChainringTeeth != next.largeChainringTeeth)) {
    definition.setChainringTeeth(next.smallChainringTeeth, next.largeChainringTeeth);
  }
  if (definition.frontShiftEnabled != next.frontShiftEnabled) {
    definition.setFrontShiftEnabled(next.frontShiftEnabled);
  }
  definition.setGearRatios(next.gearRatios!);
  await core.shiftingConfigs.upsert(next);
}

/// The sheet's content, without the sheet: what the tests pump.
class RealBikePresetForm extends StatefulWidget {
  const RealBikePresetForm({super.key, this.initial, required this.onApply, required this.onCancel});

  final BikeDrivetrain? initial;
  final ValueChanged<BikeDrivetrain> onApply;
  final VoidCallback onCancel;

  @override
  State<RealBikePresetForm> createState() => _RealBikePresetFormState();
}

class _RealBikePresetFormState extends State<RealBikePresetForm> {
  /// Index into [cranksets], or null for custom rings.
  int? _crank = 0;
  bool _customDouble = true;
  int _customLarge = ShiftingConfig.largeChainringDefault;
  int _customSmall = ShiftingConfig.smallChainringDefault;
  int _customSingle = 42;

  /// A [CassetteOption.id], or null for custom cogs.
  String? _cassette = 'shimano-12-11-34';
  final _cogsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    final crank = cranksets.indexWhere((k) => _sameList(k.chainrings, initial.chainrings));
    if (crank >= 0) {
      _crank = crank;
    } else {
      _crank = null;
      _customDouble = initial.isDouble;
      if (initial.isDouble) {
        _customLarge = initial.chainrings.first;
        _customSmall = initial.chainrings.last;
      } else {
        _customSingle = initial.chainrings.single;
      }
    }
    final cassette = cassettes.where((c) => _sameList(c.cogs, initial.cogs)).firstOrNull;
    _cassette = cassette?.id;
    if (cassette == null) _cogsController.text = initial.cogs.join('-');
  }

  @override
  void dispose() {
    _cogsController.dispose();
    super.dispose();
  }

  static bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<int> get _rings {
    final crank = _crank;
    if (crank != null) return cranksets[crank].chainrings;
    return _customDouble ? [_customLarge, _customSmall] : [_customSingle];
  }

  List<int>? get _cogs {
    final id = _cassette;
    if (id != null) return cassettes.firstWhere((c) => c.id == id).cogs;
    return BikeDrivetrain.parseCogs(_cogsController.text);
  }

  BikeDrivetrain? get _drivetrain {
    final cogs = _cogs;
    return cogs == null ? null : BikeDrivetrain.tryCreate(_rings, cogs);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final drivetrain = _drivetrain;
    final customCogsInvalid = _cassette == null && _cogsController.text.trim().isNotEmpty && drivetrain == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(12),
        Text(l10n.presetRealBike, style: context.typography.xLarge.copyWith(fontWeight: FontWeight.w700)),
        const Gap(6),
        Text(
          l10n.realBikeSheetIntro,
          style: context.typography.small.copyWith(height: 1.45, color: cs.mutedForeground),
        ),
        const Gap(18),
        _label(context, l10n.realBikeCrankset),
        const Gap(8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < cranksets.length; i++)
              _choice(
                key: ValueKey('real-bike-crank-${cranksets[i].label}'),
                label: cranksets[i].label,
                selected: _crank == i,
                onPressed: () => setState(() => _crank = i),
              ),
            _choice(
              key: const ValueKey('real-bike-crank-custom'),
              label: l10n.realBikeCustom,
              selected: _crank == null,
              onPressed: () => setState(() => _crank = null),
            ),
          ],
        ),
        if (_crank == null) ...[
          const Gap(10),
          _customRings(context, l10n),
        ],
        const Gap(18),
        _label(context, l10n.realBikeCassette),
        const Gap(8),
        _cassetteSelect(context, l10n),
        if (_cassette == null) ...[
          const Gap(10),
          Text(l10n.realBikeCustomCogsLabel, style: context.typography.small),
          const Gap(6),
          TextField(
            key: const ValueKey('real-bike-cogs'),
            controller: _cogsController,
            placeholder: const Text('11-12-13-14-15-17-19-21-24-27-30-34'),
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
          ),
          if (customCogsInvalid) ...[
            const Gap(6),
            Text(l10n.realBikeCogsInvalid, style: context.typography.xSmall.copyWith(color: cs.destructive)),
          ],
        ],
        const Gap(18),
        if (drivetrain != null) ...[
          GearRatioCurveView(ratios: drivetrain.ratios, currentGear: (drivetrain.cogs.length / 2).ceil()),
          const Gap(8),
          Text(
            _summary(context, l10n, drivetrain),
            key: const ValueKey('real-bike-summary'),
            textAlign: TextAlign.center,
            style: context.typography.small.copyWith(color: cs.mutedForeground),
          ),
          const Gap(18),
        ],
        Row(
          spacing: 8,
          children: [
            Expanded(child: Button.outline(onPressed: widget.onCancel, child: Text(l10n.cancel))),
            Expanded(
              child: Button.primary(
                key: const ValueKey('real-bike-apply'),
                onPressed: drivetrain == null ? null : () => widget.onApply(drivetrain),
                child: Text(l10n.realBikeApply),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: context.typography.caption.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.mutedForeground,
        ),
      );

  Widget _choice({required Key key, required String label, required bool selected, required VoidCallback onPressed}) =>
      Button(
        key: key,
        style: selected ? ButtonStyle.primary(size: ButtonSize.small) : ButtonStyle.outline(size: ButtonSize.small),
        onPressed: onPressed,
        child: Text(label),
      );

  Widget _customRings(BuildContext context, AppLocalizations l10n) {
    Widget row(String label, int value, ValueChanged<int> onChanged, {Key? key}) => Row(
          key: key,
          children: [
            Expanded(child: Text(label, style: context.typography.small)),
            StepperControl(
              value: value.toDouble(),
              step: 1,
              min: ShiftingConfig.chainringTeethMin.toDouble(),
              max: ShiftingConfig.chainringTeethMax.toDouble(),
              format: (v) => v.toStringAsFixed(0),
              onChanged: (v) => setState(() => onChanged(v.toInt())),
            ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.realBikeTwoRings, style: context.typography.small)),
            Switch(value: _customDouble, onChanged: (v) => setState(() => _customDouble = v)),
          ],
        ),
        if (_customDouble) ...[
          row(l10n.realBikeLargeRing, _customLarge, (v) {
            _customLarge = v;
            if (_customSmall >= v) _customSmall = (v - 1).clamp(ShiftingConfig.chainringTeethMin, v);
          }, key: const ValueKey('real-bike-large')),
          row(l10n.realBikeSmallRing, _customSmall, (v) {
            _customSmall = v;
            if (_customLarge <= v) _customLarge = (v + 1).clamp(v, ShiftingConfig.chainringTeethMax);
          }, key: const ValueKey('real-bike-small')),
        ] else
          row(l10n.realBikeSingleRing, _customSingle, (v) => _customSingle = v, key: const ValueKey('real-bike-single')),
      ],
    );
  }

  Widget _cassetteSelect(BuildContext context, AppLocalizations l10n) {
    const custom = '__custom__';
    String labelFor(String id) {
      if (id == custom) return l10n.realBikeCustom;
      final c = cassettes.firstWhere((c) => c.id == id);
      return '${c.label} · ${l10n.realBikeSpeeds(c.speeds)}';
    }

    final speeds = cassettes.map((c) => c.speeds).toSet().toList()..sort((a, b) => b.compareTo(a));
    return Select<String>(
      key: const ValueKey('real-bike-cassette'),
      value: _cassette ?? custom,
      popup: SelectPopup(
        items: SelectItemList(
          children: [
            for (final s in speeds)
              SelectGroup(
                headers: [SelectLabel(child: Text(l10n.realBikeSpeeds(s)))],
                children: [
                  for (final c in cassettes.where((c) => c.speeds == s))
                    SelectItemButton<String>(value: c.id, child: Text(c.label)),
                ],
              ),
            SelectItemButton<String>(value: custom, child: Text(l10n.realBikeCustom)),
          ],
        ),
      ).call,
      itemBuilder: (context, id) => Text(labelFor(id)),
      onChanged: (id) {
        if (id == null) return;
        setState(() => _cassette = id == custom ? null : id);
      },
    );
  }

  String _summary(BuildContext context, AppLocalizations l10n, BikeDrivetrain d) {
    final fmt = NumberFormat('0.00', Localizations.localeOf(context).toString());
    // Word joiners keep "1,47–4,55" on one line: a line may break after an
    // en dash, which split a range in the narrower locales.
    String range(int ring) => '${fmt.format(ring / d.cogs.last)}\u2060–\u2060${fmt.format(ring / d.cogs.first)}';
    if (!d.isDouble) return l10n.realBikeSummary(d.cogs.length, range(d.chainrings.single));
    return l10n.realBikeSummaryDouble(d.cogs.length, range(d.chainrings.last), range(d.chainrings.first));
  }
}
