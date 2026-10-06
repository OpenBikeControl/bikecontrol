import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/services.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// TUNABLE. What a rider can plausibly enter; anything else is a typo.
const ftpRange = (min: 50, max: 1000);
const maxHeartRateRange = (min: 100, max: 230);

/// Asks for the rider's FTP (Settings, or the ride details' power zones).
Future<void> editFtp(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final prefs = core.rides.prefs;
  return editRideZoneValue(
    context,
    title: l10n.ridesFtpTitle,
    body: l10n.ridesFtpBody,
    unit: 'W',
    current: prefs.ftpWatts,
    range: ftpRange,
    save: prefs.setFtpWatts,
    errorContext: 'RideZones.setFtp',
  );
}

/// Asks for the rider's max heart rate (Settings, or the ride details' heart
/// rate zones).
Future<void> editMaxHeartRate(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final prefs = core.rides.prefs;
  return editRideZoneValue(
    context,
    title: l10n.ridesMaxHeartRateTitle,
    body: l10n.ridesMaxHeartRateBody,
    unit: 'bpm',
    current: prefs.maxHeartRateBpm,
    range: maxHeartRateRange,
    save: prefs.setMaxHeartRateBpm,
    errorContext: 'RideZones.setMaxHeartRate',
  );
}

/// One number in a dialog: Save takes it when it is in [range] (else the
/// range is shown), Cancel leaves it, and — once set — Clear unsets it.
/// Clear sits under the field: three actions don't fit a phone's dialog.
@visibleForTesting
Future<void> editRideZoneValue(
  BuildContext context, {
  required String title,
  required String body,
  required String unit,
  required int? current,
  required ({int min, int max}) range,
  required Future<void> Function(int? value) save,
  required String errorContext,
}) async {
  final controller = TextEditingController(text: current?.toString() ?? '');
  // Null: dismissed. A record so "clear" (null value) differs from dismissed.
  final result = await showDialog<({int? value})>(
    context: context,
    builder: (ctx) => _ValueDialog(
      title: title,
      body: body,
      unit: unit,
      controller: controller,
      range: range,
      clearable: current != null,
    ),
  );
  controller.dispose();
  if (result == null) return;
  try {
    await save(result.value);
  } catch (e, s) {
    await recordError(e, s, context: errorContext);
    buildToast(level: LogLevel.LOGLEVEL_ERROR, title: AppLocalizations.current.ridesValueSaveFailed);
  }
}

class _ValueDialog extends StatefulWidget {
  const _ValueDialog({
    required this.title,
    required this.body,
    required this.unit,
    required this.controller,
    required this.range,
    required this.clearable,
  });

  final String title, body, unit;
  final bool clearable;
  final TextEditingController controller;
  final ({int min, int max}) range;

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  bool _invalid = false;

  void _save() {
    final value = int.tryParse(widget.controller.text.trim());
    if (value == null || value < widget.range.min || value > widget.range.max) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop((value: value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.body, style: context.typography.small.copyWith(color: cs.mutedForeground)),
          const Gap(12),
          TextField(
            key: const ValueKey('ride-zone-value-field'),
            controller: widget.controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            style: const TextStyle(fontFeatures: BkNumerals.tabular),
            features: [InputFeature.trailing(Text(widget.unit))],
            onChanged: (_) {
              if (_invalid) setState(() => _invalid = false);
            },
            onSubmitted: (_) => _save(),
          ),
          if (_invalid) ...[
            const Gap(6),
            Text(
              l10n.ridesValueRange(widget.range.min, widget.range.max),
              key: const ValueKey('ride-zone-value-error'),
              style: context.typography.small.copyWith(color: cs.destructive),
            ),
          ],
          if (widget.clearable) ...[
            const Gap(4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BkTouchTarget(
                child: Button.ghost(
                  key: const ValueKey('ride-zone-value-clear'),
                  style: const ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 6)),
                  onPressed: () => Navigator.of(context).pop((value: null)),
                  child: Text(l10n.clear, style: TextStyle(color: cs.destructive)),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        BkTouchTarget(
          child: Button.outline(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        ),
        BkTouchTarget(
          child: Button.primary(
            key: const ValueKey('ride-zone-value-save'),
            onPressed: _save,
            child: Text(l10n.save),
          ),
        ),
      ],
    );
  }
}
