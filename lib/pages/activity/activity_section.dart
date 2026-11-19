import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/activity/news_view.dart';
import 'package:bike_control/pages/activity/rides_view.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/services/blog_news.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Activity section, one page at every width: the blog's newest posts
/// as a banner, then the session's log and the saved rides — side by side
/// where there is room, stacked on a phone — each under its own title with
/// its action beside it.
class ActivitySection extends StatelessWidget {
  const ActivitySection({super.key, required this.shell, required this.fixAction});

  final ShellController shell;
  final ActivityFixAction fixAction;

  /// From this content width the log and the rides sit side by side; below
  /// it (a phone, a small window) they stack under the banner.
  static const double twoPaneWidth = 760;

  @override
  Widget build(BuildContext context) => _panes(context);

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
