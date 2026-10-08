import 'dart:async';

import 'package:bike_control/main.dart';
import 'package:bike_control/models/changelog.dart';
import 'package:bike_control/pages/changelog_page.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/changelog/changelog_view.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart' show BkGroupedDivider;
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/colors.dart' show bkAccentText;
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// "What's new" after an update: only the releases since the version the
/// rider last opened, each in full, and one clear way out. "All versions"
/// opens the full changelog.
class ChangelogDialog extends StatelessWidget {
  const ChangelogDialog({super.key, required this.releases, this.currentVersion});

  /// Newest first.
  final List<ChangelogRelease> releases;
  final String? currentVersion;

  /// At most this many releases: someone back after a long time gets the
  /// latest few here and the rest one tap away.
  static const int maxReleases = 3;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.i18n;
    final size = MediaQuery.sizeOf(context);
    final shown = releases.take(maxReleases).toList();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: changelogMaxWidth, maxHeight: size.height * 0.86),
          child: Container(
            decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(l.whatsNew, style: BkDisplay.title(context)),
                      ),
                      Text(
                        l.changelogWhatsNewSince,
                        style: context.typography.small.copyWith(color: cs.mutedForeground),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, r) in shown.indexed) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: BkGroupedDivider(indent: 0),
                            ),
                          ChangelogReleaseFull(
                            key: ValueKey('whats-new-${r.version}'),
                            release: r,
                            isCurrent: currentVersion != null && r.version == currentVersion,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const BkGroupedDivider(indent: 0),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 4,
                    children: [
                      BkPillButton(
                        key: const ValueKey('whats-new-close'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l.gotIt),
                      ),
                      Button.ghost(
                        key: const ValueKey('whats-new-all'),
                        alignment: Alignment.center,
                        onPressed: () {
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          navigator.push(MaterialPageRoute(builder: (_) => const ChangelogPage()));
                        },
                        child: Text(
                          l.changelogAllVersions,
                          style: context.typography.small.copyWith(
                            color: bkAccentText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// After an update, the releases since [lastSeenVersion]. Not on a fresh
  /// install (nothing was seen before — onboarding greets that rider), not
  /// when nothing newer is in the changelog, and never in store renders.
  static Future<void> showIfNeeded(BuildContext context, String currentVersion, String? lastSeenVersion) async {
    if (lastSeenVersion == null || lastSeenVersion == currentVersion || screenshotMode) return;
    try {
      final releases = await ChangelogSource.bundled();
      final since = releasesSince(releases, lastSeenVersion);
      if (since.isEmpty || !context.mounted) return;
      // Not awaited: the version counts as seen once the dialog is up.
      unawaited(
        showDialog<void>(
          context: context,
          useRootNavigator: true,
          routeSettings: const RouteSettings(name: '/changelog'),
          builder: (context) => ChangelogDialog(releases: since, currentVersion: currentVersion),
        ),
      );
    } catch (e, s) {
      recordError(e, s, context: 'ChangelogDialog.showIfNeeded');
    }
  }
}
