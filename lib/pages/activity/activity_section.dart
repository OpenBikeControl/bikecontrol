import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/activity/news_view.dart';
import 'package:bike_control/pages/activity/rides_view.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/services/blog_news.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Activity section: a segmented control over the session's log, the
/// blog's News and the rides — or, [sideBySide] (from 840), News as a banner
/// across the top with the log and the rides as two titled panes under it,
/// each pane's action in its own title row.
class ActivitySection extends StatelessWidget {
  const ActivitySection({super.key, required this.shell, required this.fixAction, this.sideBySide = false});

  final ShellController shell;
  final ActivityFixAction fixAction;
  final bool sideBySide;

  /// From this content width the log and the rides sit side by side; below
  /// it (a small desktop window) they stack under the banner.
  static const double twoPaneWidth = 760;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NewsBanner(controller: shell.news),
        // The banner hides with nothing to show; the panes then start under
        // the title like any section.
        ValueListenableBuilder(
          valueListenable: shell.news.state,
          builder: (context, state, _) => switch (state) {
            NewsFailed() => const SizedBox.shrink(),
            NewsLoaded(:final posts) when posts.isEmpty => const SizedBox.shrink(),
            _ => const Gap(24),
          },
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final log = Column(
              key: const ValueKey('activity-log-pane'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ActivityPaneTitle(
                  key: const ValueKey('activity-log-title'),
                  title: l10n.activityLogTitle,
                  trailing: ActivityClearButton(controller: shell.activity),
                ),
                ActivityLogView(controller: shell.activity, fixAction: fixAction),
              ],
            );
            final rides = Column(
              key: const ValueKey('activity-rides-pane'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ActivityPaneTitle(
                  key: const ValueKey('activity-rides-title'),
                  title: l10n.ridesTab,
                  trailing: const RidesMenuButton(),
                ),
                const RidesView(desktop: true),
              ],
            );
            // Too narrow for two readable panes: the log over the rides.
            if (constraints.maxWidth < ActivitySection.twoPaneWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [log, const Gap(28), rides],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 20,
              children: [
                Expanded(child: log),
                Expanded(child: rides),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A pane's title beside the other's, from 840: "Log" with Clear, "Rides"
/// with its ⋮ — each action next to what it acts on.
class ActivityPaneTitle extends StatelessWidget {
  const ActivityPaneTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  /// Every pane title is this tall, with or without an action, so the two
  /// panes' first cards line up.
  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BkNumerals.display(
                    (context.typography.x2Large.fontSize ?? 24),
                    color: Theme.of(context).colorScheme.foreground,
                  ),
                ),
              ),
            ),
            ?trailing,
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
