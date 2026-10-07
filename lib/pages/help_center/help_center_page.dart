// The Help Center page: a persistent, scrollable page of sections, replacing
// the old help-button dropdown. Guides & videos, Your setup, Known issues,
// Pricing & account, and Contact & community all live here as separate
// section widgets — see each one's own file for its history. (Design round
// 1 dropped the standalone Troubleshooting section — "Get help" from the
// feedback prompt and the guides/known-issues/support sections here now
// cover that ground — and replaced the blog link in "Guides & videos" with
// a direct Tutorials link.)
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'dart:async';

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/help_center/help_center_support_context.dart';
import 'package:bike_control/pages/help_center/widgets/contact_community_section.dart';
import 'package:bike_control/pages/help_center/widgets/guides_videos_section.dart';
import 'package:bike_control/pages/help_center/widgets/help_center_section_card.dart';
import 'package:bike_control/pages/help_center/widgets/known_issues_section.dart';
import 'package:bike_control/pages/help_center/widgets/pricing_faq_section.dart';
import 'package:bike_control/pages/help_center/widgets/your_setup_section.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';

/// A section the page can be asked to land the rider on directly, e.g. from a
/// "check your setup" hint elsewhere in the app.
enum HelpCenterFocus { yourSetup }

class HelpCenterPage extends StatefulWidget {
  final HelpCenterFocus? focus;

  /// Trainer-specific support payload gathered by whichever entry point
  /// pushed this page (currently only the trainer-feedback buttons on the
  /// smart-trainer details page — see help_center_support_context.dart) so
  /// that [ContactCommunitySection]'s "Tell us what's wrong" row can carry
  /// it into [SupportChatPage] instead of gathering a fresh, generic one.
  /// Null for every other entry point (the help button, "Get help" from the
  /// sentiment prompt), which keeps that previous generic behaviour.
  final HelpCenterSupportContext? launchContext;

  const HelpCenterPage({super.key, this.focus, this.launchContext});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final GlobalKey _yourSetupKey = GlobalKey();
  bool _yourSetupExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.focus == HelpCenterFocus.yourSetup) {
      _yourSetupExpanded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealYourSetup());
    }
  }

  /// Scrolls the "Your setup" section into view. No-op when the section
  /// isn't in the tree yet (first frame raced the layout).
  void _revealYourSetup() {
    final ctx = _yourSetupKey.currentContext;
    if (!mounted || ctx == null) return;
    try {
      unawaited(
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.1,
        ),
      );
    } catch (e, s) {
      recordError(e, s, context: 'HelpCenterPage._revealYourSetup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;

    // Every section after the first supplies its own 12px leading gap via an
    // explicit `Padding` rather than the `Column` below applying a uniform
    // `spacing:` — `Column(spacing:)` charges a fixed gap per child
    // regardless of that child's rendered size, so if KnownIssuesSection
    // collapses to `SizedBox.shrink()` (no open issues — see its own file),
    // a shared `spacing:` would still leave a phantom gap where its card
    // used to be. KnownIssuesSection folds this same top-12 gap into its own
    // conditional build, so the two approaches agree on spacing either way.
    const sectionGap = EdgeInsets.only(top: 12);
    // The how-to article "Guides & videos" lists; "Your setup" skips it so
    // the same link isn't shown twice on the page.
    final guidesArticle = guidesSectionArticle(context);
    final sections = <Widget>[
      HelpCenterSectionCard(
        index: 0,
        icon: LucideIcons.bookOpen,
        title: l10n.helpCenterGuides,
        tone: HelpSectionTone.neutral,
        child: const GuidesVideosSection(),
      ),
      // The ValueKey moves to a KeyedSubtree wrapping the whole card now
      // that there's no nested focus frame to carry it — see
      // help_center_page_test.dart's scroll-into-view assertions, which
      // find this section by that key and read its rect.
      Padding(
        padding: sectionGap,
        child: KeyedSubtree(
          key: const ValueKey('help-your-setup'),
          child: HelpCenterSectionCard(
            key: _yourSetupKey,
            index: 1,
            icon: LucideIcons.settings2,
            title: l10n.helpCenterYourSetup,
            microLabel: l10n.helpCenterYourSetupMicroLabel,
            focused: _yourSetupExpanded,
            child: YourSetupSection(
              excludedArticleUrls: {if (guidesArticle != null) guidesArticle.url},
            ),
          ),
        ),
      ),
      // Owns its whole card (header included) and renders nothing at all —
      // not even its own leading gap — when there are no open issues or the
      // fetch fails. See known_issues_section.dart's file header comment.
      const KnownIssuesSection(key: ValueKey('help-known-issues'), index: 2),
      Padding(
        padding: sectionGap,
        child: HelpCenterSectionCard(
          index: 3,
          icon: LucideIcons.creditCard,
          title: l10n.helpCenterPricingFaq,
          subtitle: l10n.helpCenterPricingFaqSubtitle,
          tone: HelpSectionTone.neutral,
          child: const PricingFaqSection(key: ValueKey('help-pricing-account')),
        ),
      ),
      Padding(
        padding: sectionGap,
        child: HelpCenterSectionCard(
          index: 4,
          icon: LucideIcons.users,
          title: l10n.helpCenterContact,
          child: ContactCommunitySection(launchContext: widget.launchContext),
        ),
      ),
    ];

    return Scaffold(
      headers: [
        BkPageHeader(title: l10n.helpCenterTitle),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: BkPageColumn(
          child: Column(
            // No `spacing:` here — each section beyond the first supplies
            // its own leading gap (see `sectionGap` above) so a hidden
            // KnownIssuesSection doesn't leave a phantom one behind.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sections,
          ),
        ),
      ),
    );
  }
}
