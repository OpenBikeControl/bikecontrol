import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/activity/news_view.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Activity section: a segmented control over the session's log and the
/// blog's News.
class ActivitySection extends StatelessWidget {
  const ActivitySection({super.key, required this.shell, required this.fixAction});

  final ShellController shell;
  final ActivityFixAction fixAction;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActivityTab>(
      valueListenable: shell.activityTab,
      builder: (context, tab, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActivitySegments(shell: shell),
          const Gap(16),
          switch (tab) {
            ActivityTab.log => ActivityLogView(controller: shell.activity, fixAction: fixAction, showHeader: false),
            ActivityTab.news => NewsView(controller: shell.news),
          },
        ],
      ),
    );
  }
}

/// "Activity | News": a muted track with the chosen segment lifted onto the
/// card surface. News carries a dot while a recent post is unread.
class ActivitySegments extends StatelessWidget {
  const ActivitySegments({super.key, required this.shell});

  final ShellController shell;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([shell.activityTab, shell.news.hasUnread]),
      builder: (context, _) {
        final tab = shell.activityTab.value;
        final unread = shell.news.hasUnread.value;
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(12)),
          child: Row(
            spacing: 3,
            children: [
              _Segment(
                label: l10n.activity,
                selected: tab == ActivityTab.log,
                onPressed: () => shell.activityTab.value = ActivityTab.log,
              ),
              _Segment(
                label: l10n.activityTabNews,
                spokenLabel: unread ? l10n.a11yTabHasNewPosts(l10n.activityTabNews) : null,
                selected: tab == ActivityTab.news,
                dot: unread,
                onPressed: () => shell.activityTab.value = ActivityTab.news,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.dot = false,
    this.spokenLabel,
  });

  final String label;
  final String? spokenLabel;
  final bool selected;
  final bool dot;
  final VoidCallback onPressed;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = widget.selected;
    final radius = BorderRadius.circular(9);
    return Expanded(
      child: BkTappable(
        onPressed: widget.onPressed,
        label: widget.spokenLabel ?? widget.label,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        excludeChildSemantics: true,
        borderRadius: radius,
        onHover: (hovered) => setState(() => _hovered = hovered),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // A 48 dp target on touch; a desktop pill is shorter.
          constraints: BoxConstraints(minHeight: isCompactWindow(context) ? 48 : 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? cs.card : (_hovered ? bkCardHover(context).withValues(alpha: 0.5) : null),
            borderRadius: radius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.foreground : cs.mutedForeground,
                  ),
                ),
              ),
              if (widget.dot) NavDot(key: const ValueKey('news-segment-dot'), color: bkAccentText(context)),
            ],
          ),
        ),
      ),
    );
  }
}
