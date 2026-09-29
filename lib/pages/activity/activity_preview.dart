import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/widgets/home/your_buttons.dart' show RideSectionHeader;
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The latest few activity entries, for Ride's right column in windows too
/// narrow for the permanent activity column. "See all" opens Activity.
/// Nothing at all while the log is empty.
class RideActivityPreview extends StatefulWidget {
  const RideActivityPreview({super.key, required this.controller, required this.onSeeAll, this.maxEntries = 4});

  final ActivityLogController controller;
  final VoidCallback onSeeAll;
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
    if (entries.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final status = BkStatusColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RideSectionHeader(title: l10n.activity, linkLabel: l10n.rideSeeAll, onLink: widget.onSeeAll),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              for (final (i, entry) in entries.indexed) ...[
                if (i > 0) Divider(color: cs.border, indent: 16, endIndent: 16, thickness: 0.5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.small.copyWith(
                            color: entry.isError ? status.danger : cs.foreground,
                          ),
                        ),
                      ),
                      const Gap(8),
                      ValueListenableBuilder(
                        valueListenable: widget.controller.clock,
                        builder: (context, _, _) => Text(
                          activityAge(context, entry.time),
                          style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
