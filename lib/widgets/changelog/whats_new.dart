import 'dart:io' show Platform;

import 'package:bike_control/main.dart' show recordError, screenshotMode;
import 'package:bike_control/models/changelog.dart';
import 'package:bike_control/pages/changelog_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/rate_app.dart';
import 'package:bike_control/widgets/changelog/changelog_view.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkStatusColors;
import 'package:bike_control/widgets/ui/bk_grouped_section.dart' show BkGroupedDivider;
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

const whatsNewBlogUrl = 'https://bikecontrol.app/blog';

/// "What's new" after an update: a banner at the top of the app instead of a
/// dialog riders click away before reading. It stays until the rider opens it
/// or dismisses it, across launches, and opens [WhatsNewPage].
abstract final class WhatsNew {
  /// The update the banner announces (version, updated from); null hides it.
  static final ValueNotifier<(String version, String since)?> pending = ValueNotifier(null);

  /// At launch, before the last-seen version is overwritten. Not on a fresh
  /// install (onboarding greets that rider), not when the changelog has
  /// nothing newer than [lastSeenVersion], never in store renders.
  static Future<void> checkAtLaunch(String currentVersion, String? lastSeenVersion) async {
    if (screenshotMode) return;
    try {
      if (lastSeenVersion != null && lastSeenVersion != currentVersion) {
        final since = releasesSince(await ChangelogSource.bundled(), lastSeenVersion);
        if (since.isNotEmpty) {
          // Two updates in a row without opening it: keep the older "since",
          // so the page still shows everything the rider missed.
          final previous = core.settings.getWhatsNewPending();
          final from = previous != null && previous.$1 == lastSeenVersion ? previous.$2 : lastSeenVersion;
          await core.settings.setWhatsNewPending((currentVersion, from));
        }
      }
      final stored = core.settings.getWhatsNewPending();
      if (stored != null && stored.$1 == currentVersion) {
        pending.value = stored;
      } else if (stored != null) {
        await core.settings.setWhatsNewPending(null);
      }
    } catch (e, s) {
      recordError(e, s, context: 'WhatsNew.checkAtLaunch');
    }
  }

  /// Opened or closed: the banner is done for this update.
  static Future<void> dismiss() async {
    pending.value = null;
    try {
      await core.settings.setWhatsNewPending(null);
    } catch (e, s) {
      recordError(e, s, context: 'WhatsNew.dismiss');
    }
  }

  static Future<void> open(BuildContext context) async {
    final update = pending.value;
    if (update == null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    await dismiss();
    await navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        settings: const RouteSettings(name: '/whats-new'),
        builder: (_) => WhatsNewPage(currentVersion: update.$1, sinceVersion: update.$2),
      ),
    );
  }
}

/// The strip under the top bar while an update's notes are unread.
class WhatsNewBanner extends StatelessWidget {
  const WhatsNewBanner({super.key, this.horizontalMargin = 16});

  final double horizontalMargin;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: WhatsNew.pending,
      builder: (context, update, _) {
        if (update == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final l = context.i18n;
        final accent = cs.primary;
        return Padding(
          key: const ValueKey('whats-new-banner'),
          padding: EdgeInsets.fromLTRB(horizontalMargin, 4, horizontalMargin, 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: cs.card,
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              boxShadow: bkCardShadow(context),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Expanded(
                  child: Button.ghost(
                    key: const ValueKey('whats-new-banner-open'),
                    style: const ButtonStyle.ghost().withPadding(padding: const EdgeInsets.fromLTRB(12, 10, 8, 10)),
                    alignment: AlignmentDirectional.centerStart,
                    onPressed: () => WhatsNew.open(context),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(LucideIcons.sparkles, size: 18, color: bkAccentText(context)),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l.whatsNewBannerTitle(update.$1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.typography.small.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                l.whatsNewBannerBody,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.typography.xSmall.copyWith(
                                  color: bkAccentText(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(LucideIcons.chevronRight, size: 18, color: cs.mutedForeground),
                      ],
                    ),
                  ),
                ),
                IconButton.ghost(
                  key: const ValueKey('whats-new-banner-dismiss'),
                  icon: Semantics(
                    label: l.a11yDismiss,
                    child: Icon(LucideIcons.x, size: 18, color: cs.mutedForeground),
                  ),
                  onPressed: WhatsNew.dismiss,
                ),
                const Gap(4),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The update's notes, full screen: the releases since the version the rider
/// came from, the blog for the longer story, and a plea for a store rating.
class WhatsNewPage extends StatefulWidget {
  const WhatsNewPage({super.key, required this.currentVersion, required this.sinceVersion, this.releases});

  final String currentVersion;
  final String sinceVersion;

  /// Skips loading the bundled changelog (tests, renders).
  final List<ChangelogRelease>? releases;

  /// At most this many releases: someone back after a long time gets the
  /// latest few here and the rest under "All versions".
  static const int maxReleases = 3;

  /// Whether this platform has a store to rate in.
  @visibleForTesting
  static bool Function() canRate = () => !kIsWeb && !Platform.isLinux;

  @override
  State<WhatsNewPage> createState() => _WhatsNewPageState();
}

class _WhatsNewPageState extends State<WhatsNewPage> {
  List<ChangelogRelease>? _releases;

  @override
  void initState() {
    super.initState();
    _releases = widget.releases;
    if (_releases == null) _load();
  }

  Future<void> _load() async {
    try {
      final releases = releasesSince(await ChangelogSource.bundled(), widget.sinceVersion);
      if (mounted) setState(() => _releases = releases);
    } catch (e, s) {
      recordError(e, s, context: 'WhatsNewPage.load');
      if (mounted) setState(() => _releases = const []);
    }
  }

  Future<void> _rate() async {
    try {
      await requestAppRating();
    } catch (e, s) {
      recordError(e, s, context: 'whats new rate');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    final releases = _releases?.take(WhatsNewPage.maxReleases).toList();
    return Scaffold(
      headers: [BkPageHeader(title: l.whatsNew, columnWidth: changelogMaxWidth)],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: BkPageColumn(
          maxWidth: changelogMaxWidth,
          child: releases == null
              ? const SizedBox(height: 200)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, r) in releases.indexed) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: BkGroupedDivider(indent: 0),
                        ),
                      ChangelogReleaseFull(
                        key: ValueKey('whats-new-${r.version}'),
                        release: r,
                        isCurrent: r.version == widget.currentVersion,
                      ),
                    ],
                    const Gap(28),
                    _LinkRow(
                      key: const ValueKey('whats-new-blog'),
                      icon: LucideIcons.newspaper,
                      label: l.whatsNewBlogLink,
                      external: true,
                      onPressed: () => launchUrlString(whatsNewBlogUrl, mode: LaunchMode.externalApplication),
                    ),
                    _LinkRow(
                      key: const ValueKey('whats-new-all'),
                      icon: LucideIcons.history,
                      label: l.changelogAllVersions,
                      onPressed: () => Navigator.of(
                        context,
                      ).pushReplacement(MaterialPageRoute(builder: (_) => const ChangelogPage())),
                    ),
                    if (WhatsNewPage.canRate()) ...[
                      const Gap(28),
                      _HelpCard(onRate: _rate),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.external = false,
  });

  final IconData icon;
  final bool external;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = bkAccentText(context);
    return Button.ghost(
      style: const ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10)),
      alignment: AlignmentDirectional.centerStart,
      onPressed: onPressed,
      leading: Icon(icon, size: 18, color: accent),
      trailing: Icon(external ? LucideIcons.arrowUpRight : LucideIcons.chevronRight, size: 16, color: accent),
      child: Text(
        label,
        style: context.typography.base.copyWith(color: accent, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// "BikeControl needs your help": one person builds it, ratings bring riders.
class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.onRate});

  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.i18n;
    return Container(
      key: const ValueKey('whats-new-help'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
        boxShadow: bkCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(LucideIcons.star, size: 20, color: BkStatusColors.of(context).warning),
                ),
            ],
          ),
          const Gap(14),
          Semantics(
            header: true,
            child: Text(
              l.whatsNewHelpTitle,
              style: context.typography.large.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
          ),
          const Gap(6),
          Text(
            l.whatsNewHelpBody,
            style: context.typography.small.copyWith(color: cs.mutedForeground, height: 1.45),
          ),
          const Gap(18),
          BkPillButton(
            key: const ValueKey('whats-new-rate'),
            onPressed: onRate,
            child: Text(l.whatsNewRateAction),
          ),
        ],
      ),
    );
  }
}
