import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/services.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// TUNABLE. What a rider can plausibly enter; anything else is a typo.
const ftpRange = (min: 50, max: 1000);
const maxHeartRateRange = (min: 100, max: 230);

/// The rider's FTP, edited where it is shown (Settings, the ride details'
/// power zones). Follows the stored value.
class RideFtpField extends StatelessWidget {
  const RideFtpField({super.key, this.autofocus = false, this.onDone});

  final bool autofocus;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final prefs = core.rides.prefs;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => RideZoneValueField(
        label: AppLocalizations.of(context).ridesFtpTitle,
        unit: 'W',
        current: prefs.ftpWatts,
        range: ftpRange,
        save: prefs.setFtpWatts,
        errorContext: 'RideZones.setFtp',
        autofocus: autofocus,
        onDone: onDone,
      ),
    );
  }
}

/// The rider's max heart rate, edited where it is shown (Settings, the ride
/// details' heart rate zones). Follows the stored value.
class RideMaxHeartRateField extends StatelessWidget {
  const RideMaxHeartRateField({super.key, this.autofocus = false, this.onDone});

  final bool autofocus;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final prefs = core.rides.prefs;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => RideZoneValueField(
        label: AppLocalizations.of(context).ridesMaxHeartRateTitle,
        unit: 'bpm',
        current: prefs.maxHeartRateBpm,
        range: maxHeartRateRange,
        save: prefs.setMaxHeartRateBpm,
        errorContext: 'RideZones.setMaxHeartRate',
        autofocus: autofocus,
        onDone: onDone,
      ),
    );
  }
}

/// One number, edited in place: a compact digits-only field with its unit.
/// Enter or leaving the field saves it when it is in [range] (else the range
/// is shown under the field and nothing is saved); an emptied field unsets
/// it; Escape puts the stored value back.
class RideZoneValueField extends StatefulWidget {
  const RideZoneValueField({
    super.key,
    required this.label,
    required this.unit,
    required this.current,
    required this.range,
    required this.save,
    required this.errorContext,
    this.autofocus = false,
    this.onDone,
  });

  /// Names the field for screen readers (the row's title).
  final String label;
  final String unit;
  final int? current;
  final ({int min, int max}) range;
  final Future<void> Function(int? value) save;
  final String errorContext;
  final bool autofocus;

  /// Called once an edit is through: saved, unchanged, or put back.
  final VoidCallback? onDone;

  /// Fits "1000 W" and "230 bpm".
  static const double width = 112;

  @override
  State<RideZoneValueField> createState() => _RideZoneValueFieldState();
}

class _RideZoneValueFieldState extends State<RideZoneValueField> {
  late final TextEditingController _controller = TextEditingController(text: _format(widget.current));
  final FocusNode _focus = FocusNode();

  /// The value last handed to save (or stored): a second commit of the same
  /// value — Enter, then the focus leaving — saves only once.
  late int? _committed = widget.current;
  bool _invalid = false;

  static String _format(int? value) => value?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(RideZoneValueField old) {
    super.didUpdateWidget(old);
    if (widget.current != old.current) {
      _committed = widget.current;
      // Never overwrite what the rider is typing.
      if (!_focus.hasFocus) _controller.text = _format(widget.current);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Set when the field lets go of the focus itself (after Enter or Escape):
  /// that blur is not another commit.
  bool _releasing = false;

  void _onFocusChange() {
    if (_focus.hasFocus) return;
    if (_releasing) {
      _releasing = false;
      return;
    }
    _commit();
  }

  void _release() {
    if (!_focus.hasFocus) return;
    _releasing = true;
    _focus.unfocus();
  }

  void _submit() {
    if (_commit()) _release();
  }

  void _revert() {
    _controller.text = _format(widget.current);
    if (_invalid) setState(() => _invalid = false);
    _release();
    widget.onDone?.call();
  }

  /// False when the text is not a value in range (and the range is shown).
  bool _commit() {
    final text = _controller.text.trim();
    final value = text.isEmpty ? null : int.tryParse(text);
    if (text.isNotEmpty && (value == null || value < widget.range.min || value > widget.range.max)) {
      setState(() => _invalid = true);
      return false;
    }
    if (_invalid) setState(() => _invalid = false);
    if (value != _committed) {
      _committed = value;
      _save(value);
    } else {
      widget.onDone?.call();
    }
    return true;
  }

  Future<void> _save(int? value) async {
    try {
      await widget.save(value);
    } catch (e, s) {
      _committed = widget.current;
      await recordError(e, s, context: widget.errorContext);
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: AppLocalizations.current.ridesValueSaveFailed);
    }
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: RideZoneValueField.width,
          child: Semantics(
            label: widget.label,
            child: CallbackShortcuts(
              bindings: {const SingleActivator(LogicalKeyboardKey.escape): _revert},
              child: TextField(
                key: const ValueKey('ride-zone-value-field'),
                controller: _controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.end,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                // The row's trailing slot mutes its text; the value is the rider's.
                style: TextStyle(fontFeatures: BkNumerals.tabular, color: cs.foreground),
                features: [InputFeature.trailing(Text(widget.unit).muted())],
                onChanged: (_) {
                  if (_invalid) setState(() => _invalid = false);
                },
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
        ),
        if (_invalid) ...[
          const Gap(4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              l10n.ridesValueRange(widget.range.min, widget.range.max),
              key: const ValueKey('ride-zone-value-error'),
              textAlign: TextAlign.end,
              style: context.typography.xSmall.copyWith(color: cs.destructive),
            ),
          ),
        ],
      ],
    );
  }
}
