import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/activity/news_view.dart';
import 'package:bike_control/pages/activity/rides_view.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Activity section: a segmented control over the session's log and the
/// blog's News — or, [sideBySide] (from 840), the two as panes: the log on
/// the left under the page's own title, News on the right under its header,
/// each scrolling on its own.
class ActivitySection extends StatelessWidget {
  const ActivitySection({super.key, required this.shell, required this.fixAction, this.sideBySide = false});

  final ShellController shell;
  final ActivityFixAction fixAction;
  final bool sideBySide;

  /// The two panes together are no wider than Ride's two columns.
  static const double sideBySideMaxWidth = 1080;

  @override
  Widget build(BuildContext context) {
    if (sideBySide) return _panes(context);
    return ValueListenableBuilder<ActivityTab>(
      valueListenable: shell.activityTab,
      builder: (context, tab, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActivitySegments(shell: shell),
          const Gap(16),
          switch (tab) {
            ActivityTab.log => ActivityLogView(controller: shell.activity, fixAction: fixAction),
            ActivityTab.news => NewsView(controller: shell.news),
            ActivityTab.rides => const RidesView(),
          },
        ],
      ),
    );
  }

  Widget _panes(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The same insets as the other sections' scroll views, split between the
    // panes so each scrolls to the window's edge.
    const outer = 24.0;
    const gutter = 10.0;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: sideBySideMaxWidth + 2 * outer),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              key: const ValueKey('activity-log-pane'),
              child: SingleChildScrollView(
                key: const PageStorageKey('section-activity-log'),
                padding: const EdgeInsets.fromLTRB(outer, 8, gutter, 24),
                child: ActivityLogView(controller: shell.activity, fixAction: fixAction),
              ),
            ),
            Expanded(
              key: const ValueKey('activity-news-pane'),
              child: SingleChildScrollView(
                key: const PageStorageKey('section-activity-news'),
                padding: const EdgeInsets.fromLTRB(gutter, 8, outer, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // News and Rides as caption-height tabs on the log
                    // caption's baseline, so both panes' first cards align.
                    ActivityPaneTabs(shell: shell),
                    ValueListenableBuilder<ActivityTab>(
                      valueListenable: shell.paneTab,
                      builder: (context, tab, _) => tab == ActivityTab.rides
                          ? const Padding(padding: EdgeInsets.only(top: 12), child: RidesView(desktop: true))
                          : NewsView(controller: shell.news, singleColumn: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Activity | News | Rides": a muted track with the chosen segment lifted onto the
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
          // Dark: the track is the card and the chosen segment lifts a step
          // above it; light: a grey track under a white segment.
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? cs.card : cs.muted,
            borderRadius: BorderRadius.circular(12),
          ),
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
              _Segment(
                key: const ValueKey('activity-segment-rides'),
                label: l10n.ridesTab,
                selected: tab == ActivityTab.rides,
                onPressed: () => shell.activityTab.value = ActivityTab.rides,
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
    super.key,
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
            color: selected
                ? (Theme.of(context).brightness == Brightness.dark ? cs.input : cs.card)
                : (_hovered ? bkCardHover(context) : null),
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
