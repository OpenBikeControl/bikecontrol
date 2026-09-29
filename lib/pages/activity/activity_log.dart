import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:bike_control/widgets/ui/connection_method.dart'
    show ConnectionMethodType, ConnectionMethodTypeActivityIcon;
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One line of the activity log: a controller press and what it did, or an
/// alert the app raised.
class ActivityEntry {
  final ControllerButton? button;
  final DateTime time;
  final ActionResult? result;
  final String? alertMessage;
  final LogLevel? alertLevel;
  final String? buttonTitle;
  final VoidCallback? onTap;
  final ConnectionMethodType? connectionType;

  /// The controller the press came from, for the row's second line.
  final String? deviceName;

  ActivityEntry({
    this.button,
    required this.time,
    this.result,
    this.alertMessage,
    this.alertLevel,
    this.buttonTitle,
    this.onTap,
    this.connectionType,
    this.deviceName,
  });

  bool get isAlert => alertMessage != null;
  bool get isError => result is Error || result is NotHandled || alertLevel == LogLevel.LOGLEVEL_ERROR;
  bool get isSuccess => result is Success;
  bool get isWarning => alertLevel == LogLevel.LOGLEVEL_WARNING;

  String get message => alertMessage ?? result?.message ?? '';
}

/// The clock the activity log stamps its entries with and ages them by ("just
/// now", "5s ago"). Tests on a fake clock point it there, so the ages they
/// film don't depend on how fast the machine ran.
@visibleForTesting
DateTime Function() activityLogClock = DateTime.now;

/// Now, on the activity log's clock.
DateTime activityNow() => activityLogClock();

/// How long ago [time] was, the way the activity log words it.
String activityAge(BuildContext context, DateTime time) {
  final l10n = AppLocalizations.of(context);
  final ago = activityLogClock().difference(time);
  if (ago.inSeconds < 2) return l10n.justNow;
  if (ago.inSeconds < 60) return l10n.secondsAgo('${ago.inSeconds}');
  return l10n.minutesAgo('${ago.inMinutes}');
}

/// A change to the log, for the views showing it to animate.
sealed class ActivityLogChange {}

class ActivityInserted extends ActivityLogChange {}

class ActivityRemoved extends ActivityLogChange {
  ActivityRemoved(this.index, this.entry);
  final int index;
  final ActivityEntry entry;
}

class ActivityCleared extends ActivityLogChange {
  ActivityCleared(this.entries);
  final List<ActivityEntry> entries;
}

/// The last [maxEntries] entries of the session, shared by every view that
/// shows them (the Activity section and Ride's activity column).
class ActivityLogController {
  ActivityLogController() {
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_entries.isNotEmpty) clock.value = activityLogClock();
    });
  }

  static const maxEntries = 30;

  final List<ActivityEntry> _entries = [];
  List<ActivityEntry> get entries => List.unmodifiable(_entries);

  /// Whether the log is empty, for the views' empty state and Clear.
  final ValueNotifier<bool> isEmpty = ValueNotifier(true);

  /// Ticks while the log has entries, so each entry's age ("5s ago")
  /// refreshes on its own instead of the whole screen rebuilding.
  final ValueNotifier<DateTime> clock = ValueNotifier(activityLogClock());

  /// Whether the log holds an error, for the Activity item's marker.
  final ValueNotifier<bool> hasErrors = ValueNotifier(false);

  final StreamController<ActivityLogChange> _changes = StreamController.broadcast(sync: true);
  Stream<ActivityLogChange> get changes => _changes.stream;

  late final Timer _tick;

  void insert(ActivityEntry entry) {
    _entries.insert(0, entry);
    _changes.add(ActivityInserted());
    if (_entries.length > maxEntries) {
      final removed = _entries.removeLast();
      _changes.add(ActivityRemoved(_entries.length, removed));
    }
    hasErrors.value = _entries.any((e) => e.isError);
    isEmpty.value = false;
  }

  void clear() {
    final old = List.of(_entries);
    _entries.clear();
    _changes.add(ActivityCleared(old));
    hasErrors.value = false;
    isEmpty.value = true;
  }

  void dispose() {
    _tick.cancel();
    _changes.close();
    clock.dispose();
    hasErrors.dispose();
    isEmpty.dispose();
  }
}

/// The fix an error entry offers ("Configure button mapping"), if any.
typedef ActivityFixAction = (String, void Function(BuildContext))? Function(ActivityEntry entry);

/// Whether [entry] belongs under "Last minute" rather than "Earlier".
bool activityInLastMinute(ActivityEntry entry) =>
    activityLogClock().difference(entry.time) < const Duration(minutes: 1);

/// The activity log as a grouped list: "Last minute", then "Earlier", newest
/// first, with a note on how much it keeps. Entries grow in and out as they
/// come and go (they just appear with reduced motion).
///
/// [showHeader] adds the "Activity" title with its Clear action — for Ride's
/// activity column. The Activity section puts Clear in the page's own header
/// ([ActivityClearButton]).
class ActivityLogView extends StatefulWidget {
  const ActivityLogView({super.key, required this.controller, required this.fixAction, this.showHeader = true});

  final ActivityLogController controller;
  final ActivityFixAction fixAction;
  final bool showHeader;

  @override
  State<ActivityLogView> createState() => _ActivityLogViewState();
}

class _ActivityLogViewState extends State<ActivityLogView> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late StreamSubscription<ActivityLogChange> _sub;

  /// The entries as last built, so a removal animates the row it removes.
  List<ActivityEntry> _shown = const [];

  @override
  void initState() {
    super.initState();
    _shown = widget.controller.entries;
    _sub = widget.controller.changes.listen(_onChange);
    // Entries move from "Last minute" to "Earlier" as they age.
    widget.controller.clock.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.clock.removeListener(_onTick);
    _sub.cancel();
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _onChange(ActivityLogChange change) {
    final list = _listKey.currentState;
    final previous = _shown;
    _shown = widget.controller.entries;
    if (list != null) {
      switch (change) {
        case ActivityInserted():
          list.insertItem(0, duration: const Duration(milliseconds: 300));
        case ActivityRemoved(:final index, :final entry):
          list.removeItem(
            index,
            (context, animation) => _animated(entry, index, animation, removing: true),
            duration: const Duration(milliseconds: 200),
          );
        case ActivityCleared(:final entries):
          for (int i = entries.length - 1; i >= 0; i--) {
            final entry = entries[i];
            list.removeItem(
              i,
              (context, animation) => _animated(entry, i, animation, removing: true, all: previous),
              duration: const Duration(milliseconds: 200),
            );
          }
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final empty = _shown.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.activity,
                      style: context.typography.large.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                ActivityClearButton(controller: widget.controller),
              ],
            ),
          ),
        if (empty) const ActivityEmptyState(),
        AnimatedList(
          key: _listKey,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          initialItemCount: _shown.length,
          itemBuilder: (context, index, animation) => _animated(_shown[index], index, animation),
        ),
        if (!empty)
          Padding(
            padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 10, BkGroupedSection.inset, 0),
            child: Text(
              l10n.activityFooter(ActivityLogController.maxEntries),
              style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
            ),
          ),
      ],
    );
  }

  /// One entry in its place in the grouped list: a group header above the
  /// first entry of a group, and the group's card drawn around the entries
  /// entry by entry, so rows can come and go one at a time.
  Widget _animated(
    ActivityEntry entry,
    int index,
    Animation<double> animation, {
    bool removing = false,
    List<ActivityEntry>? all,
  }) {
    final entries = all ?? _shown;
    final recent = activityInLastMinute(entry);
    bool sameGroup(int i) => i >= 0 && i < entries.length && activityInLastMinute(entries[i]) == recent;
    // A removed row is drawn alone: its neighbours have already moved on.
    final first = removing || !sameGroup(index - 1);
    final last = removing || !sameGroup(index + 1);
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    const radius = Radius.circular(BkComponentThemes.cardRadius);

    final item = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (first && !removing)
          Padding(
            padding: EdgeInsets.fromLTRB(BkGroupedSection.inset, index == 0 ? 0 : 20, BkGroupedSection.inset, 6),
            child: Semantics(
              header: true,
              child: Text(
                (recent ? l10n.activityLastMinute : l10n.activityEarlier).toUpperCase(),
                style: context.typography.caption.copyWith(
                  color: cs.mutedForeground,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.card,
            borderRadius: BorderRadius.vertical(top: first ? radius : Radius.zero, bottom: last ? radius : Radius.zero),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!first) const BkGroupedDivider(indent: ActivityRow.textInset),
              ActivityRow(entry: entry, clock: widget.controller.clock, fix: widget.fixAction(entry)),
            ],
          ),
        ),
      ],
    );
    // With reduced motion an entry simply appears (and goes) in place,
    // instead of growing open and pushing the list down.
    if (prefersReducedMotion(context)) return item;
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: item,
      ),
    );
  }
}

/// "Clear" for the activity log, in accent; disabled while there is nothing
/// to clear.
class ActivityClearButton extends StatelessWidget {
  const ActivityClearButton({super.key, required this.controller});

  final ActivityLogController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isEmpty,
      builder: (context, empty, _) => Button.ghost(
        key: const ValueKey('activity-clear'),
        onPressed: empty ? null : controller.clear,
        child: Text(
          AppLocalizations.of(context).clear,
          style: context.typography.small.copyWith(
            color: empty ? Theme.of(context).colorScheme.mutedForeground : bkAccentText(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// What the log says before anything has happened.
class ActivityEmptyState extends StatelessWidget {
  const ActivityEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('activity-empty'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          BkIconTile(icon: LucideIcons.activity, color: cs.mutedForeground),
          const Gap(4),
          Text(
            l10n.activityEmptyTitle,
            textAlign: TextAlign.center,
            style: context.typography.small.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            l10n.activityEmptyBody,
            textAlign: TextAlign.center,
            style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
          ),
        ],
      ),
    );
  }
}

/// One entry of the activity log: a glyph for what it was (a shift, a press
/// that worked, an error, a connection), what happened, which button on which
/// controller, and how long ago. An error reads in red, with its fix as a
/// link under it.
class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.entry, required this.clock, this.fix});

  final ActivityEntry entry;

  /// Ticks the age.
  final ValueListenable<DateTime> clock;

  final (String, void Function(BuildContext))? fix;

  static const double _glyph = 28;
  static const double textInset = BkGroupedSection.inset + _glyph + 12;

  /// "Plus · Zwift Play", or the transport of a connection alert.
  String? _subtitle(AppLocalizations l10n) {
    if (entry.button case final button?) {
      return [button.displayName, ?entry.deviceName].join(' · ');
    }
    return switch (entry.connectionType) {
      ConnectionMethodType.network => l10n.onboardingMethodNetwork,
      ConnectionMethodType.bluetooth => l10n.onboardingMethodBluetooth,
      ConnectionMethodType.local => l10n.onboardingMethodLocal,
      _ => null,
    };
  }

  Widget _leading(BuildContext context) {
    final status = BkStatusColors.of(context);
    final cs = Theme.of(context).colorScheme;
    final button = entry.button;
    final (IconData? icon, Color color, Color wash) = switch (entry) {
      _ when entry.isError => (LucideIcons.circleX, status.danger, status.dangerWash),
      _ when entry.isWarning => (LucideIcons.triangleAlert, status.warning, status.warningWash),
      _ when button != null && entry.isSuccess && _shiftGlyph(entry) == null => (
        LucideIcons.check,
        status.success,
        status.successWash,
      ),
      _ when button == null && entry.connectionType != null => (
        entry.connectionType!.activityIcon,
        status.info,
        status.infoWash,
      ),
      _ when button == null => (LucideIcons.info, status.info, status.infoWash),
      _ => (null, cs.foreground, cs.muted),
    };
    final shift = _shiftGlyph(entry);
    return ExcludeSemantics(
      child: Container(
        width: _glyph,
        height: _glyph,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
        child: icon != null
            ? Icon(icon, size: 15, color: color)
            : shift != null
            ? Icon(shift, size: 14, color: cs.foreground)
            : ButtonWidget(button: button!, size: 16),
      ),
    );
  }

  /// + / − for a shift that went through.
  static IconData? _shiftGlyph(ActivityEntry entry) {
    if (!entry.isSuccess) return null;
    return switch (entry.button?.action) {
      InGameAction.shiftUp => LucideIcons.plus,
      InGameAction.shiftDown => LucideIcons.minus,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final status = BkStatusColors.of(context);
    final subtitle = _subtitle(l10n);
    final fix = this.fix;
    final accent = bkAccentText(context);

    Widget link(String label, VoidCallback onPressed) => Button.ghost(
      style: const ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 6)),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Flexible(
            child: Text(
              label,
              style: context.typography.small.copyWith(color: accent, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 14, color: accent),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 10, BkGroupedSection.inset, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _leading(context),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(
                  entry.message,
                  style: context.typography.small.copyWith(color: entry.isError ? status.danger : cs.foreground),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle, style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
                if (fix != null) Builder(builder: (context) => link(fix.$1, () => fix.$2(context))),
                if (entry.onTap != null && entry.buttonTitle != null) link(entry.buttonTitle!, entry.onTap!),
              ],
            ),
          ),
          const Gap(8),
          // Only the age ticks; the row around it is built once.
          ValueListenableBuilder(
            valueListenable: clock,
            builder: (context, _, _) => Text(
              activityAge(context, entry.time),
              style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}
