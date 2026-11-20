import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The state a [MetricSourceOption]'s dot encodes.
///
/// Deliberately separate from any concept in `SensorHub`: the hub only knows
/// "resolved" and "dropped out", but a row also has to tell "connecting"
/// (this quantity's selection, not yet registered — the BLE handshake is
/// still in flight, or a persisted pick waiting for its sensor to come back
/// into range) apart from "waiting for first reading" (registered, so the
/// link is up, there is just nothing on it yet) even though the hub reports
/// both as dropped-out. See `_candidateState` (live_metrics_section.dart)
/// for how each value is derived.
enum MetricSourceState {
  /// The trainer itself is the metric's source — the default, quiet state.
  /// Always shown on the Trainer row, regardless of selection.
  trainer,

  /// A source that is registered in the hub — by construction, currently
  /// linked over BLE (see `SensorHub.register`'s doc comment) — whether or
  /// not it is this quantity's active selection.
  connected,

  /// This quantity's active selection, but not yet registered: a connect is
  /// in flight, or a persisted pick is waiting for its sensor to come back
  /// into range.
  connecting,

  /// This quantity's active selection, registered, but has never produced a
  /// reading.
  waitingForFirstReading,

  /// This quantity's active selection, registered, and has reported before,
  /// but its most recent reading is stale — the hub has fallen back to the
  /// trainer.
  lost,

  /// A known sensor that has never registered and is not this quantity's
  /// selection — nothing to read, tap to connect it.
  notConnected,
}

extension MetricSourceStateColor on MetricSourceState {
  /// Dot colours per the component spec. Deliberately NOT applied to a
  /// row's text — see [SignalRow]'s doc comment on why the control has
  /// to stay muted regardless of state.
  Color dotColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = BkStatusColors.of(context);
    return switch (this) {
      MetricSourceState.trainer => cs.mutedForeground,
      MetricSourceState.notConnected => cs.mutedForeground,
      MetricSourceState.connected => status.success,
      MetricSourceState.connecting => status.warning,
      MetricSourceState.waitingForFirstReading => status.warning,
      MetricSourceState.lost => status.danger,
    };
  }
}

/// One row of a [SignalRow]'s inline source list — Trainer, or one known
/// sensor. Purely presentational — [SignalRow] renders exactly what it is
/// given; deciding WHICH options exist, in what order, what their state is,
/// and what their [subtitle] says (`core.sensors` and `core.connection`) is
/// `live_metrics_section.dart`'s job.
class MetricSourceOption {
  const MetricSourceOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.state,
    required this.selected,
    required this.onSelect,
    this.onDisconnect,
  });

  /// `'trainer'`, or the underlying sensor's `SensorSource.id` — this row's
  /// [Key] suffix and its identity for the rider's current pick.
  final String id;

  /// The source's identity: "Trainer", or the sensor's own
  /// `SensorSource.displayName`. Always rendered in the same muted style
  /// regardless of [state] or [selected] — only the dot carries state, and
  /// only the row's own background/check mark carries selection.
  final String label;

  /// The plain-English "what does this row mean" line underneath [label] —
  /// the entire point of this control being a list rather than a toggle.
  /// Precomputed by the caller rather than derived here from [state] alone:
  /// the one state that needs two different sentences depending on context
  /// (`MetricSourceState.connecting`, for a real in-flight BLE handshake
  /// versus a persisted pick with no live candidate at all) only the caller
  /// can tell apart.
  final String subtitle;

  final MetricSourceState state;

  /// Whether this is the quantity's current pick — drives the row's
  /// `SelectedButton` styling and its check mark.
  final bool selected;

  /// Tapping this row. For Trainer this just clears the selection; for a
  /// not-yet-registered sensor, selecting IS the connect request — see
  /// `LiveMetricsSection._select`'s doc comment for the load-bearing
  /// ordering. Wrapped in a [LoadingWidget] so a real BLE connect shows a
  /// spinner in place of the row without this card needing to know that is
  /// happening.
  final Future<void> Function() onSelect;

  /// Long-press to disconnect. Only set on the selected, connected,
  /// non-Trainer row — see [SignalRow]'s doc comment on why disconnect
  /// lives there rather than on every connected candidate or as a visible
  /// affordance.
  final Future<void> Function()? onDisconnect;
}

/// One line of the Sensors page's signal list — POWER / HEART / CADENCE /
/// SPEED: the reading, where it comes from right now, and (when there is
/// anything to choose between) the list of sources to pick from.
///
/// The source list folds away under the row on phones and opens with a tap
/// on the row; from [expandedBreakpoint] up there is room to leave it open.
class SignalRow extends StatefulWidget {
  const SignalRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.sourceLabel,
    required this.sourceDotColor,
    this.replaced = false,
    this.sources,
  });

  final IconData icon;
  final String label;

  /// Null → "--".
  final String? value;
  final String unit;

  /// Where the value comes from right now: the trainer's name, a sensor's
  /// name, or "No source".
  final String sourceLabel;
  final Color sourceDotColor;

  /// A sensor stands in for the trainer's own reading.
  final bool replaced;

  /// Null, empty or a single entry: nothing to choose between, no list.
  final List<MetricSourceOption>? sources;

  /// From this width up the source list stays open.
  static const double expandedBreakpoint = 560;

  @override
  State<SignalRow> createState() => _SignalRowState();
}

class _SignalRowState extends State<SignalRow> {
  /// The rider's own open/closed choice; null until they tap.
  bool? _expanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = widget.sources;
    final hasOptions = options != null && options.length > 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = hasOptions && (_expanded ?? constraints.maxWidth >= SignalRow.expandedBreakpoint);
        final header = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(9)),
                child: Icon(widget.icon, size: 16, color: cs.mutedForeground),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.small.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (widget.replaced) ...[
                          const Gap(6),
                          _ReplacedTag(key: const Key('signal-row-replaced')),
                        ],
                      ],
                    ),
                    const Gap(2),
                    Row(
                      children: [
                        Container(
                          key: const Key('signal-row-source-dot'),
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.sourceDotColor),
                        ),
                        const Gap(6),
                        Flexible(
                          child: Text(
                            widget.sourceLabel,
                            key: const Key('signal-row-source'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Text(
                widget.value ?? '--',
                // Tabular digits: a changing reading must not reflow the row.
                style: context.typography.large.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Gap(4),
              Text(
                widget.unit,
                style: context.typography.xSmall.copyWith(fontWeight: FontWeight.w600, color: cs.mutedForeground),
              ),
              if (hasOptions) ...[
                const Gap(6),
                Icon(
                  expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 16,
                  color: cs.mutedForeground,
                ),
              ],
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasOptions)
              Button(
                key: const Key('signal-row-header'),
                style: const ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
                onPressed: () => setState(() => _expanded = !expanded),
                child: header,
              )
            else
              header,
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(52, 0, 12, 10),
                child: Column(
                  key: const Key('metric-card-source-control'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    for (final option in options)
                      _MetricSourceRow(option: option, dotColor: option.state.dotColor(context)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "REPLACED": a sensor stands in for the trainer's own reading.
class _ReplacedTag extends StatelessWidget {
  const _ReplacedTag({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(
        AppLocalizations.of(context).sensorReplacedTag.toUpperCase(),
        style: context.typography.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4, color: cs.primary),
      ),
    );
  }
}

/// One row's own widget, rather than a bare method: disconnect (long press)
/// needs its own bracketed busy state, exactly like `LoadingWidget` gives
/// the tap/select path — a bare fire-and-forget `Future` here has nothing
/// that flips before the awaited work starts, so nothing signals "still
/// busy" to anything driving frames off it (`flutter_test`'s
/// `pumpAndSettle` included: with no state change until the very end, it
/// finds nothing scheduled and returns before the disconnect has actually
/// finished). Bracketing with [_disconnecting] fixes both that and gives the
/// rider the same busy affordance connecting already has.
/// Runs [option]'s disconnect for a fire-and-forget gesture. The owner has
/// already recorded the failure, so all that's left is telling the rider.
Future<void> _disconnectOption(MetricSourceOption option) async {
  try {
    await option.onDisconnect!();
  } catch (_) {
    buildToast(level: LogLevel.LOGLEVEL_WARNING, title: AppLocalizations.current.sensorDisconnectFailed);
  }
}

class _MetricSourceRow extends StatefulWidget {
  const _MetricSourceRow({required this.option, required this.dotColor});

  final MetricSourceOption option;
  final Color dotColor;

  @override
  State<_MetricSourceRow> createState() => _MetricSourceRowState();
}

class _MetricSourceRowState extends State<_MetricSourceRow> {
  bool _disconnecting = false;

  Future<void> _runDisconnect() async {
    setState(() => _disconnecting = true);
    try {
      await _disconnectOption(widget.option);
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final cs = Theme.of(context).colorScheme;
    return LoadingWidget(
      futureCallback: option.onSelect,
      onErrorCallback: (context, error) =>
          buildToast(level: LogLevel.LOGLEVEL_WARNING, title: AppLocalizations.of(context).sensorConnectFailed),
      renderChild: (isLoading, tap) {
        final busy = isLoading || _disconnecting;
        return SelectedButton(
          key: Key('metric-card-source-option-${option.id}'),
          value: option.selected,
          enabled: !busy,
          onChanged: (_) => tap?.call(),
          onLongPressUp: option.onDisconnect == null || busy ? null : () => unawaited(_runDisconnect()),
          style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          selectedStyle: ButtonStyle.secondary().withPadding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          // Forces the row to claim the full width its container already
          // gives this list (see `SignalRow`'s `SizedBox`),
          // rather than shrinking to its own content — otherwise the
          // selected row's background tint would only ever cover the text,
          // reading as a pill rather than a list row.
          child: SizedBox(
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    key: Key('metric-card-source-dot-${option.id}'),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: widget.dotColor),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.xSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.mutedForeground,
                        ),
                      ),
                      const Gap(2),
                      // The point of this whole redesign — see
                      // `MetricSourceOption.subtitle`'s doc comment. Allowed
                      // to wrap to two lines rather than ellipsizing: a
                      // truncated explanation would defeat the purpose.
                      Text(
                        option.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.caption.copyWith(color: cs.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const Gap(6),
                if (busy)
                  const Padding(padding: EdgeInsets.only(top: 2), child: SmallProgressIndicator())
                else if (option.selected)
                  // The unambiguous "this one" mark — selection is never
                  // conveyed by the row background tint alone, since that is
                  // deliberately subtle (see this class's own doc comment on
                  // why every row's text has to stay muted).
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.check, size: 14, color: cs.mutedForeground),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
