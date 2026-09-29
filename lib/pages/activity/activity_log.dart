import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
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

  ActivityEntry({
    this.button,
    required this.time,
    this.result,
    this.alertMessage,
    this.alertLevel,
    this.buttonTitle,
    this.onTap,
    this.connectionType,
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
  }

  void clear() {
    final old = List.of(_entries);
    _entries.clear();
    _changes.add(ActivityCleared(old));
    hasErrors.value = false;
  }

  void dispose() {
    _tick.cancel();
    _changes.close();
    clock.dispose();
    hasErrors.dispose();
  }
}

/// The fix an error entry offers ("Configure button mapping"), if any.
typedef ActivityFixAction = (String, void Function(BuildContext))? Function(ActivityEntry entry);

/// The activity log: a Clear action, then the entries newest first.
class ActivityLogView extends StatefulWidget {
  const ActivityLogView({super.key, required this.controller, required this.fixAction, this.showTitle = true});

  final ActivityLogController controller;
  final ActivityFixAction fixAction;

  /// Off where the screen's own title already says "Activity".
  final bool showTitle;

  @override
  State<ActivityLogView> createState() => _ActivityLogViewState();
}

class _ActivityLogViewState extends State<ActivityLogView> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late StreamSubscription<ActivityLogChange> _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.changes.listen(_onChange);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _onChange(ActivityLogChange change) {
    final list = _listKey.currentState;
    if (list == null) return;
    switch (change) {
      case ActivityInserted():
        list.insertItem(0, duration: const Duration(milliseconds: 300));
      case ActivityRemoved(:final index, :final entry):
        list.removeItem(
          index,
          (context, animation) => _animatedItem(entry, index, animation),
          duration: const Duration(milliseconds: 200),
        );
      case ActivityCleared(:final entries):
        for (int i = entries.length - 1; i >= 0; i--) {
          final entry = entries[i];
          list.removeItem(
            i,
            (context, animation) => _animatedItem(entry, i, animation),
            duration: const Duration(milliseconds: 200),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.controller.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          children: [
            const Gap(16),
            Expanded(
              child: widget.showTitle
                  ? ColoredTitle(text: AppLocalizations.of(context).activity)
                  : const SizedBox.shrink(),
            ),
            GhostButton(
              onPressed: widget.controller.clear,
              child: Text(AppLocalizations.of(context).clear).xSmall.muted,
            ),
          ],
        ),
        AnimatedList(
          key: _listKey,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          initialItemCount: entries.length,
          itemBuilder: (context, index, animation) {
            return _animatedItem(widget.controller._entries[index], index, animation);
          },
        ),
      ],
    );
  }

  Widget _animatedItem(ActivityEntry entry, int index, Animation<double> animation) {
    final item = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (index > 0)
          Divider(
            color: Theme.of(context).colorScheme.border.withAlpha(160),
            endIndent: 16,
            indent: 16,
            thickness: 0.5,
          ),
        _row(entry),
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

  Widget _row(ActivityEntry entry) {
    final button = entry.button;
    final isError = entry.isError;
    final isSuccess = entry.isSuccess;

    final status = BkStatusColors.of(context);
    final Color rowBg;
    if (isError) {
      rowBg = status.dangerWash;
    } else if (entry.isWarning) {
      rowBg = status.warningWash;
    } else if (isSuccess) {
      rowBg = status.successWash;
    } else if (entry.button == null) {
      rowBg = status.infoWash;
    } else {
      rowBg = Colors.transparent;
    }

    final errorFix = widget.fixAction(entry);

    const size = 14.0;
    final Widget leadingIcon;
    if (button != null) {
      leadingIcon = isError
          ? Icon(LucideIcons.circleX, size: 16, color: status.danger)
          : isSuccess
          ? Icon(LucideIcons.circleCheck, size: 16, color: status.success)
          : ButtonWidget(button: button, size: size - 4);
    } else if (entry.alertLevel == LogLevel.LOGLEVEL_ERROR) {
      leadingIcon = Icon(LucideIcons.circleX, size: 16, color: status.danger);
    } else if (entry.alertLevel == LogLevel.LOGLEVEL_WARNING) {
      leadingIcon = Icon(LucideIcons.triangleAlert, size: 16, color: status.warning);
    } else if (entry.button == null) {
      leadingIcon = Icon(
        entry.connectionType?.activityIcon ?? LucideIcons.bluetooth,
        size: 16,
        color: status.info,
      );
    } else {
      leadingIcon = Icon(LucideIcons.info, size: 16, color: Theme.of(context).colorScheme.mutedForeground);
    }

    return SizedBox(
      width: double.infinity,
      child: Basic(
        padding: const EdgeInsets.all(16),
        leading: Container(
          width: 22,
          height: 24,
          decoration: BoxDecoration(color: rowBg, shape: BoxShape.circle),
          child: Padding(padding: const EdgeInsets.only(top: 2.0), child: leadingIcon),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isError ? Text(entry.message, style: TextStyle(color: status.danger)).small : Text(entry.message).small,
            if (errorFix != null) ...[
              const Gap(4),
              Builder(
                builder: (context) => OutlineButton(
                  onPressed: () => errorFix.$2(context),
                  child: Text(errorFix.$1).xSmall,
                ),
              ),
            ],
            if (entry.onTap != null && entry.buttonTitle != null) ...[
              const Gap(4),
              OutlineButton(onPressed: entry.onTap!, child: Text(entry.buttonTitle!).xSmall),
            ],
          ],
        ),
        // Only the age ticks; the row around it is built once.
        trailing: ValueListenableBuilder(
          valueListenable: widget.controller.clock,
          builder: (context, _, _) => Text(activityAge(context, entry.time)).xSmall.muted,
        ),
      ),
    );
  }
}
