import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
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

extension on MetricSourceState {
  /// Dot colours per the component spec. Deliberately NOT applied to a
  /// row's text — see [MetricCard]'s doc comment on why the control has
  /// to stay muted regardless of state.
  Color dotColor(ColorScheme cs) => switch (this) {
    MetricSourceState.trainer => cs.mutedForeground,
    MetricSourceState.notConnected => cs.mutedForeground,
    MetricSourceState.connected => const Color(0xFF22C55E),
    MetricSourceState.connecting => const Color(0xFFF59E0B),
    MetricSourceState.waitingForFirstReading => const Color(0xFFF59E0B),
    MetricSourceState.lost => const Color(0xFFEF4444),
  };
}

/// One row of a [MetricCard]'s inline source list — Trainer, or one known
/// sensor. Purely presentational — [MetricCard] renders exactly what it is
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
  /// non-Trainer row — see [MetricCard]'s doc comment on why disconnect
  /// lives there rather than on every connected candidate or as a visible
  /// affordance.
  final Future<void> Function()? onDisconnect;
}

/// One tile of the live-metrics "signals grid" — POWER / HEART / CADENCE /
/// SPEED. The label and value rows are unchanged from before this feature: a
/// rider with no external sensors must see exactly this, pixel for pixel,
/// which is why [sources] defaults to null and — when null, empty, or down
/// to a single entry (nothing left to choose between) — renders nothing
/// extra at all rather than an empty placeholder row.
///
/// The inline source list (when present) is deliberately muted: the accent
/// lives on the label row above, the value stays the hero in foreground
/// colour, and this control must never out-shout it. That is why every
/// row's text stays [ColorScheme.mutedForeground] regardless of
/// [MetricSourceOption.selected] or state — only the dot and the (already
/// subtle) `ButtonStyle.secondary` row background/check mark carry
/// selection.
///
/// Per direct author feedback, the list sits to the RIGHT of the value
/// column when the tile is wide enough for both. Otherwise the tile shows
/// only the current pick under the value, in a compact picker that opens the
/// same list in a popover — see [_sideBySideBreakpoint] and
/// [_MetricSourcePicker].
class MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value; // null → "--"
  final String unit;

  /// Null or empty omits the control entirely — see this class's own doc
  /// comment on why that has to be the default.
  final List<MetricSourceOption>? sources;

  const MetricCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
    this.sources,
  });

  /// Below this content width (i.e. inside this tile's own padding, not the
  /// tile's outer width) the source list collapses into [_MetricSourcePicker]
  /// under the value instead of sitting beside it.
  ///
  /// Measured, not guessed, against this app's own 2×2 signals grid
  /// (`LiveMetricsSection`, and `ProxyDeviceDetailsPage`'s 16px page padding
  /// + 800px content cap around it): a typical phone (~360-430px screen)
  /// gives each tile roughly 145-185px of raw width, and after this card's
  /// own 14px/side padding that is ~90-155px of content — nowhere near
  /// enough for a name+subtitle column beside a value. A desktop window at
  /// (or above) the 800px content cap gives each tile ~395px raw, ~365px of
  /// content — comfortably enough for both side by side. 240px sits
  /// squarely between those two clusters.
  static const double _sideBySideBreakpoint = 240;

  /// Gutter on both sides of the side-by-side divider — `Gap` before it,
  /// matching `Container.padding` after it. Per direct author feedback
  /// ("even more divider padding"): 16, not a new number — `--s-4` on this
  /// project's design-system spacing scale (4 / 8 / 12 / 16 / 20), a
  /// deliberate step up from the previous 8 (`--s-2`) rather than the
  /// tighter 6px this used to sit in before that first widening.
  static const double _dividerGutter = 16;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = sources;
    // A single-entry list (Trainer alone, nothing else to pick between) is
    // just as much "nothing to choose" as null/empty — see this class's own
    // doc comment on the no-external-sensors invariant.
    final hasOptions = options != null && options.length > 1;
    final labelRow = Row(
      key: const Key('metric-card-label-row'),
      spacing: 6,
      children: [
        Icon(icon, size: 14, color: iconColor),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: cs.mutedForeground,
          ),
        ),
      ],
    );
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.border),
        ),
        child: !hasOptions
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [labelRow, _valueRow(cs)],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final valueRow = _valueRow(cs);
                  final list = _sourceList(context, cs, options);
                  if (constraints.maxWidth >= _sideBySideBreakpoint) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The label row moves in here, alongside the value,
                        // rather than sitting in an ancestor `Column` above
                        // this `Row` (the pre-fix layout) — per direct
                        // author feedback ("the list should begin at the
                        // same height as the 'Herz' header itself. Right
                        // now it starts below"): with the label row OUTSIDE
                        // this `Row`, the source list's header (the OTHER
                        // side of this same `Row`) started level with the
                        // VALUE, a full label-row-height + spacing below
                        // the label — measured at 20px in a widget test
                        // before this fix. Putting both the label and the
                        // value in their own `Column` here, as this `Row`'s
                        // left child, makes that `Column`'s top (the label
                        // row's top) and the source list's top (its header)
                        // share this `Row`'s own `CrossAxisAlignment.start`
                        // top edge — verified equal (0px diff) by
                        // `metric_card_test.dart`'s alignment group.
                        //
                        // `Expanded` (flex:1), not left to its own natural
                        // (min) content width, per direct author feedback
                        // ("make the sensors list max 50% width of the
                        // parent card"): the source list's own box below is
                        // now hard-capped at half of `constraints.maxWidth`
                        // (this `LayoutBuilder`'s own content width) rather
                        // than an `Expanded` that just soaked up whatever
                        // the list didn't. Once that cap can leave space
                        // unclaimed on the list's side, something has to
                        // claim it back — this column, exactly like it did
                        // implicitly before, just explicit now.
                        Expanded(
                          child: Column(
                            key: const Key('metric-card-label-value-column'),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [labelRow, valueRow],
                          ),
                        ),
                        const Gap(_dividerGutter),
                        // A real `VerticalDivider` (see the package source)
                        // has NO way to bound its own cross axis (height) —
                        // with no child it hard-codes `height:
                        // double.infinity`, tightened down to whatever this
                        // Row's OWN incoming height happens to be. That is
                        // fine in a normal bounded layout, but this section
                        // always sits inside a `SingleChildScrollView` on
                        // both its real call sites (`LiveMetricsSection`'s
                        // own doc comment), so the incoming height here is
                        // genuinely unbounded — proven by pumping a bare
                        // `VerticalDivider()` here before writing this: it
                        // throws "BoxConstraints forces an infinite height".
                        // `device.dart` hit the identical problem for its
                        // own device-group separator and solved it the same
                        // way: paint the rule as a border instead, sized by
                        // the list's own real (never intrinsic, never
                        // infinite) layout rather than by a widget that
                        // demands unbounded height.
                        //
                        // `ConstrainedBox`, NOT `Expanded`, on this side —
                        // per direct author feedback ("make the sensors
                        // list max 50% width of the parent card"): a long
                        // sensor name/subtitle must not let this side of
                        // the row crowd the value, which is the hero (this
                        // class's own doc comment). `Expanded` here would
                        // hand it every pixel the label/value column didn't
                        // claim, exactly the bug being fixed. Capping at
                        // half of THIS `LayoutBuilder`'s own content width —
                        // not the raw tile width — matches how
                        // `_sideBySideBreakpoint` itself is already measured
                        // (see that constant's own doc comment). The list
                        // still fills whatever room it is given (unchanged
                        // `SizedBox(width: double.infinity)` in
                        // `_sourceList`), so it always sits AT the cap, not
                        // just under it, once there is more than 240px of
                        // content width to divide — `metric_card_test.dart`
                        // measures this directly. Long text degrades exactly
                        // as it already did before this fix: the label row
                        // ellipsizes past one line (`_MetricSourceRow`'s own
                        // `Text.maxLines: 1` / `TextOverflow.ellipsis`), the
                        // subtitle wraps up to two lines before ellipsizing
                        // — neither depends on how wide the cap happens to
                        // land, only on the width it is actually given.
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.5),
                          child: Container(
                            key: const Key('metric-card-source-divider'),
                            padding: const EdgeInsets.only(left: _dividerGutter),
                            decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.border))),
                            child: list,
                          ),
                        ),
                      ],
                    );
                  }
                  // Narrow: half of a phone-width grid leaves ~150px of
                  // content, where an inline list only had room for
                  // truncated names and clipped subtitles. Show just the
                  // current pick, and open the full list on demand.
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      labelRow,
                      valueRow,
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 2,
                        children: [
                          _sourceListHeader(context, cs),
                          _MetricSourcePicker(options: options),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _valueRow(ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 4,
      children: [
        Text(
          value ?? '--',
          // Tabular (fixed-width) digits — restores the design system's own
          // `.mvalue` spec (`font-variant-numeric: tabular-nums`), dropped
          // in the Flutter port. Without it, a changing reading (1 → 11,
          // or a heart rate flickering 98/100) reflows the glyph widths
          // every frame and the whole tile visibly jitters. Scoped to the
          // value only — the unit text below is untouched.
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  /// A vertical list of every option, NOT a toggle/segmented control — the
  /// rider picks a source directly on the tile, and each row carries its
  /// own subtitle explaining what selecting it means (see
  /// [MetricSourceOption.subtitle]). Replaces the horizontally-scrolling
  /// pill row this control used before direct author feedback ("make it a
  /// list instead of a toggle"). [_sourceListHeader] only ever appears
  /// attached to this list — never on a tile with no list at all — since it
  /// is composed in here rather than in [build] alongside the list.
  Widget _sourceList(BuildContext context, ColorScheme cs, List<MetricSourceOption> options) {
    return SizedBox(
      key: const Key('metric-card-source-control'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // Pinned to its own natural (content) height, not `.max` — per
        // direct author feedback ("align the 'Source' list to the top").
        // `_EqualHeightRow` (`live_metrics_section.dart`) can hand this
        // list's ancestor Container a generous, bounded height once a
        // row-mate card grows taller; without `.min` this Column is
        // entitled to claim all of it (`RenderFlex` sizes a `MainAxisSize
        // .max` child to its incoming max whenever that max is finite —
        // see the framework's own `_computeSizes`), which would let the
        // list itself absorb the equalisation slack instead of leaving it
        // as blank space below. `.min` keeps the header level with the
        // value column and pushes any spare height under the last row,
        // where `MainAxisAlignment.start` (this Column's own default,
        // untouched) already puts it.
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          _sourceListHeader(context, cs),
          for (final option in options) _row(cs, option),
        ],
      ),
    );
  }

  /// Per direct author feedback ("add a small 'Source' header"): sits right
  /// above the row list, in the SAME visual register as the tile's own
  /// uppercase label above (bold, tracked-out, muted) but a size and weight
  /// down from it so it reads as clearly subordinate — it must never compete
  /// with the metric label at the top of the tile or the value beside it.
  Widget _sourceListHeader(BuildContext context, ColorScheme cs) {
    return Padding(
      key: const Key('metric-card-source-header'),
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        AppLocalizations.of(context).sensorSourceListHeader,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: cs.mutedForeground.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _row(ColorScheme cs, MetricSourceOption option) {
    return _MetricSourceRow(option: option, dotColor: option.state.dotColor(cs));
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
          // gives this list (see `MetricCard._sourceList`'s `SizedBox`),
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
                        style: TextStyle(
                          fontSize: 12,
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
                        style: TextStyle(fontSize: 10.5, color: cs.mutedForeground),
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

/// The narrow-tile stand-in for [MetricCard._sourceList]: a compact button
/// showing just the current pick (its dot and name) that opens every option
/// — the same [_MetricSourceRow]s, subtitles included — in a popover
/// anchored to the tile.
///
/// The popover closes as soon as a row is picked (or long-pressed to
/// disconnect), and the work runs HERE rather than inside that row: the
/// popover's rows are gone the moment it closes, so only this button, which
/// stays mounted, can carry the busy spinner and the connect-failed toast
/// until the work finishes.
class _MetricSourcePicker extends StatefulWidget {
  const _MetricSourcePicker({required this.options});

  final List<MetricSourceOption> options;

  @override
  State<_MetricSourcePicker> createState() => _MetricSourcePickerState();
}

class _MetricSourcePickerState extends State<_MetricSourcePicker> {
  /// Wide enough for a name plus a two-line subtitle, narrow enough to fit
  /// beside the screen edge on the smallest phones.
  static const double _popoverWidth = 260;

  bool _busy = false;

  Future<void> _runBusy(Future<void> Function() work) async {
    if (mounted) setState(() => _busy = true);
    try {
      await work();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(MetricSourceOption option) => _runBusy(() async {
    try {
      await option.onSelect();
    } catch (e, s) {
      unawaited(recordError(e, s, context: 'MetricSourcePicker'));
      buildToast(level: LogLevel.LOGLEVEL_WARNING, title: AppLocalizations.current.sensorConnectFailed);
    }
  });

  void _open() {
    final cs = Theme.of(context).colorScheme;
    showDropdown(
      context: context,
      alignment: AlignmentDirectional.topStart,
      anchorAlignment: AlignmentDirectional.bottomStart,
      builder: (popoverContext) => MenuPopup(
        children: [
          SizedBox(
            width: _popoverWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 2,
              children: [
                for (final option in widget.options)
                  _MetricSourceRow(
                    dotColor: option.state.dotColor(cs),
                    option: MetricSourceOption(
                      id: option.id,
                      label: option.label,
                      subtitle: option.subtitle,
                      state: option.state,
                      selected: option.selected,
                      onSelect: () async {
                        unawaited(closeOverlay(popoverContext));
                        unawaited(_select(option));
                      },
                      onDisconnect: option.onDisconnect == null
                          ? null
                          : () async {
                              unawaited(closeOverlay(popoverContext));
                              unawaited(_runBusy(() => _disconnectOption(option)));
                            },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = widget.options.firstWhere((o) => o.selected, orElse: () => widget.options.first);
    return Button.outline(
      key: const Key('metric-card-source-picker'),
      style: ButtonStyle.outline().withPadding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
      onPressed: _busy ? null : _open,
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            Container(
              key: const Key('metric-card-source-picker-dot'),
              width: 7,
              height: 7,
              decoration: BoxDecoration(shape: BoxShape.circle, color: current.state.dotColor(cs)),
            ),
            const Gap(8),
            Expanded(
              child: Text(
                current.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.mutedForeground),
              ),
            ),
            const Gap(6),
            if (_busy)
              const SmallProgressIndicator()
            else
              Icon(LucideIcons.chevronsUpDown, size: 14, color: cs.mutedForeground),
          ],
        ),
      ),
    );
  }
}
