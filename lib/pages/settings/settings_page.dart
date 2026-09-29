import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/help_center/help_center_page.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/blog_posts_widget.dart';
import 'package:bike_control/widgets/logviewer.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show MaterialPageRoute, showLicensePage;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Settings section: the plan, what BikeControl rides with, help, and the
/// app itself (language, blog, changelog, review, license, version).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onUpdate});

  /// Lets the shell refresh Ride after a change made from here.
  final VoidCallback? onUpdate;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _open(Widget page) async {
    await context.push(page);
    widget.onUpdate?.call();
    if (mounted) setState(() {});
  }

  Future<void> _review() async {
    try {
      await openStoreReview();
    } catch (e, s) {
      recordError(e, s, context: 'settings leave a review');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final version = appVersionLabel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        BkGroupedSection(
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([IAPManager.instance.entitlements, IAPManager.instance.isPurchased]),
              builder: (context, _) {
                final tier = currentPlanTier();
                return BkGroupedRow(
                  key: const ValueKey('settings-plan'),
                  icon: LucideIcons.crown,
                  title: l10n.currentPlan,
                  subtitle: IAPManager.instance.getStatusMessage(),
                  trailing: Text(planName(context, tier)),
                  chevron: true,
                  onPressed: () => openSubscription(context),
                );
              },
            ),
          ],
        ),
        BkGroupedSection(
          header: l10n.settingsSectionRidingWith,
          children: [
            BkGroupedRow(
              icon: LucideIcons.link2,
              title: l10n.connectionSettings,
              chevron: true,
              onPressed: () => _open(const TrainerConnectionSettingsPage()),
            ),
          ],
        ),
        BkGroupedSection(
          header: l10n.troubleshootingGuide,
          children: [
            BkGroupedRow(
              icon: LucideIcons.lifeBuoy,
              title: l10n.helpCenterTitle,
              chevron: true,
              onPressed: () => _open(const HelpCenterPage()),
            ),
            BkGroupedRow(
              icon: LucideIcons.lightbulb,
              title: l10n.onboardingMenuEntry,
              chevron: true,
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(fullscreenDialog: true, builder: (_) => OnboardingPage()),
                );
                widget.onUpdate?.call();
              },
            ),
            BkGroupedRow(
              icon: LucideIcons.code,
              title: l10n.logs,
              chevron: true,
              onPressed: () => _open(LogViewer()),
            ),
            if (!kIsWeb)
              BkGroupedRow(
                icon: LucideIcons.wifi,
                title: l10n.networkTroubleshootingTitle,
                chevron: true,
                onPressed: () => _open(const NetworkTroubleshootingPage()),
              ),
          ],
        ),
        BkGroupedSection(
          header: l10n.settingsSectionApp,
          footer: version == null ? null : l10n.version(version),
          children: [
            BkGroupedRow(
              icon: LucideIcons.languages,
              title: l10n.language,
              trailing: LanguageSelect(bare: true, onChanged: () => setState(() {})),
            ),
            BkGroupedRow(
              icon: LucideIcons.rss,
              title: l10n.blogTab,
              chevron: true,
              onPressed: () => _open(const BlogPage()),
            ),
            BkGroupedRow(
              icon: LucideIcons.refreshCw,
              title: l10n.changelog,
              chevron: true,
              onPressed: () => openDrawer(
                context: context,
                position: OverlayPosition.bottom,
                builder: (c) => MarkdownPage(assetPath: 'CHANGELOG.md'),
              ),
            ),
            BkGroupedRow(
              icon: LucideIcons.star,
              title: context.i18n.leaveAReview,
              chevron: true,
              onPressed: _review,
            ),
            BkGroupedRow(
              icon: LucideIcons.shieldCheck,
              title: l10n.license,
              chevron: true,
              onPressed: () => showLicensePage(context: context),
            ),
          ],
        ),
      ],
    );
  }
}

/// The BikeControl blog, opened from Settings → App.
class BlogPage extends StatelessWidget {
  const BlogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [BkPageHeader(title: AppLocalizations.of(context).blogTab)],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const BlogPostsWidget(showHeader: false, maxPosts: 10),
          ),
        ),
      ),
    );
  }
}
