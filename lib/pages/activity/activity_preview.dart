import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/widgets/home/your_buttons.dart' show RideSectionHeader;
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The latest few activity entries, for Ride's right column in windows too
/// narrow for the permanent activity column. "See all" opens Activity.
/// Before anything has happened, the log's own empty state. Each entry is the
/// same [ActivityRow] the Activity tab shows, error fix links included.
class RideActivityPreview extends StatefulWidget {
  const RideActivityPreview({
    super.key,
    required this.controller,
    required this.onSeeAll,
    required this.fixAction,
    this.maxEntries = 4,
  });

  final ActivityLogController controller;
  final VoidCallback onSeeAll;
  final ActivityFixAction fixAction;
  final int maxEntries;

  @override
  State<RideActivityPreview> createState() => _RideActivityPreviewState();
}

class _RideActivityPreviewState extends State<RideActivityPreview> {
  late StreamSubscription<ActivityLogChange> _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.controller.entries.take(widget.maxEntries).toList();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RideSectionHeader(title: l10n.activity, linkLabel: l10n.rideSeeAll, onLink: widget.onSeeAll),
        if (entries.isEmpty)
          const ActivityEmptyState()
        else
          DecoratedBox(
            decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, entry) in entries.indexed) ...[
                  if (i > 0) const BkGroupedDivider(indent: ActivityRow.textInset),
                  ActivityRow(entry: entry, clock: widget.controller.clock, fix: widget.fixAction(entry)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
