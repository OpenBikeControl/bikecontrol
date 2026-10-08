// "Known issues" section body (Task 10) — reuses
// `SupportChatService.fetchOpenIssues()`, the same public-issues fetch the
// support-chat intake screen already uses, so the two surfaces never drift
// into separate issue lists. Each row deep-links to the public issue page
// (`https://bikecontrol.app/issues/<id>`). Issues that carry a
// `helpBlogSlug` are "Blog-derived seeds" (website migration
// 20260517070000_seed_intake_help_issues.sql) — tutorial/help entries meant
// for the support intake form's "Read tutorial" affordance, not incidents —
// so this section excludes them outright rather than listing them (Bug 2;
// this superseded an earlier version that routed them to
// `https://bikecontrol.app/blog/<slug>` instead).
//
// Card ownership (usage-fix round 3): this widget owns its *whole*
// `HelpCenterSectionCard` — header, divider and all — not just the row list.
// `help_center_page.dart` used to wrap a fixed card around this section's
// body, so an empty/failing fetch left a header-only card on screen (a
// "Bekannte Probleme" card with nothing under it). Now an empty result or a
// fetch failure returns `SizedBox.shrink()` for the *entire* section —
// header included — while still funnelling failures through `recordError`
// per house rule. The leading 12px gap that would normally come from the
// page's `Column(spacing: 12)` is folded into this widget's own build
// (rather than left to the page) for the same reason: `Column(spacing:)`
// charges a fixed gap per child regardless of that child's rendered size, so
// a `SizedBox.shrink()` list member would otherwise still leave a phantom
// double-gap between "Your setup" and "Pricing & account". Collapsing both
// the card and its leading gap in one `SizedBox.shrink()` return avoids that
// — see help_center_page.dart's `sections` list for the matching half of
// this (every other section supplies its own leading gap explicitly for the
// same reason).
import 'dart:async';

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/help_center/widgets/help_center_section_card.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class KnownIssuesSection extends StatefulWidget {
  /// Where this section falls in the page's staggered entrance animation —
  /// see `HelpCenterSectionCard.index`. Fixed at the page's call site
  /// regardless of whether this section ends up rendering anything, so the
  /// sections around it never shift their own animation timing.
  final int index;

  /// Test seam: replaces the default `SupportChatService().fetchOpenIssues`
  /// call — see help_center_sections_test.dart.
  final Future<List<SupportIssue>> Function()? fetchIssues;

  const KnownIssuesSection({super.key, required this.index, this.fetchIssues});

  @override
  State<KnownIssuesSection> createState() => _KnownIssuesSectionState();
}

class _KnownIssuesSectionState extends State<KnownIssuesSection> {
  List<SupportIssue> _issues = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final fetch = widget.fetchIssues ?? () => SupportChatService().fetchOpenIssues();
      final issues = await fetch();
      // Blog-derived seeds (helpBlogSlug set) are tutorial content for the
      // support intake form, not incidents — keep them out of this list. See
      // the file header comment for the full story (Bug 2).
      final filtered = issues.where((i) => i.helpBlogSlug == null || i.helpBlogSlug!.isEmpty).toList(growable: false);
      if (!mounted) return;
      setState(() => _issues = filtered);
    } catch (e, s) {
      // Supplementary content — a failed fetch just leaves the section
      // hidden (see build()), but it still must not be swallowed silently.
      recordError(e, s, context: 'KnownIssuesSection._load');
    }
  }

  @override
  Widget build(BuildContext context) {
    // No open issues (or the fetch hasn't resolved / failed): render nothing
    // at all — no header, no divider, no leading gap. See the file header
    // comment for why the gap has to collapse here rather than in the page.
    if (_issues.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    // Matches the mockup's row padding (`padding:11px 14px`) now that the
    // card itself carries no padding — rows run edge-to-edge and supply
    // their own inset.
    final rowStyle = ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: HelpCenterSectionCard(
        index: widget.index,
        icon: LucideIcons.triangleAlert,
        title: context.i18n.helpCenterKnownIssues,
        tone: HelpSectionTone.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _issues.length; i++) ...[
              if (i > 0) const Divider(),
              Button.ghost(
                style: rowStyle,
                onPressed: () => launchUrlString(_urlFor(_issues[i]), mode: LaunchMode.externalApplication),
                child: Basic(
                  leading: const Icon(LucideIcons.triangleAlert, size: 18),
                  title: Text(_issues[i].title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Icon(LucideIcons.externalLink, size: 14, color: cs.mutedForeground),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Blog-derived (helpBlogSlug) issues never reach here — see _load() —
  // so every row still shown always deep-links to the plain issue page.
  String _urlFor(SupportIssue issue) => 'https://bikecontrol.app/issues/${issue.id}';
}
