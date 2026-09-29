import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError, screenshotMode;
import 'package:bike_control/pages/help_center/help_center_page.dart';
import 'package:bike_control/pages/home/chain_state.dart' show LinkStatus;
import 'package:bike_control/pages/home/home_page.dart' show chainProxy;
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/services/shift_feedback/shift_haptics.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/blog_posts_widget.dart';
import 'package:bike_control/widgets/logviewer.dart';
import 'package:bike_control/widgets/home/ampel.dart' show AmpelStyle;
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_switch_row.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show connectionMethodSummary;
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show MaterialPageRoute, showLicensePage;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Settings section: the plan, what BikeControl rides with, what happens
/// during the ride, help, and the app itself.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onUpdate});

  /// Lets the shell refresh Ride after a change made from here.
  final VoidCallback? onUpdate;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final StreamSubscription<BaseDevice> _connectionListener;

  /// Quitting from a row is a mobile idiom; desktop windows close themselves,
  /// and SystemNavigator.pop() does nothing useful there anyway.
  bool get _showsQuit => HostPlatform.isAndroid || HostPlatform.isIOS;

  @override
  void initState() {
    super.initState();
    // The trainer rows (gear settings, overlay) come and go with the trainer.
    _connectionListener = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionListener.cancel();
    super.dispose();
  }

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

  Future<void> _quit() async {
    await core.connection.disconnectAll();
    await core.connection.stop();
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final version = appVersionLabel();
    final app = core.settings.getTrainerApp();
    final proxy = chainProxy();
    final definition = proxy?.fitnessBike;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        const SettingsPlanCard(),
        BkGroupedSection(
          key: const ValueKey('settings-riding-with'),
          header: l10n.settingsSectionRidingWith,
          children: [
            BkGroupedRow(
              key: const ValueKey('settings-trainer-app'),
              icon: LucideIcons.monitor,
              title: l10n.chainAppTitle,
              trailing: Text(app?.name ?? l10n.chainStatusNotSetUp),
              chevron: true,
              onPressed: () => _open(const TrainerConnectionSettingsPage()),
            ),
            BkGroupedRow(
              key: const ValueKey('settings-connection'),
              icon: LucideIcons.wifi,
              title: l10n.connectionSettings,
              trailing: switch (connectionMethodSummary(context)) {
                final summary? => Text(summary),
                null => null,
              },
              chevron: true,
              onPressed: () => _open(const TrainerConnectionSettingsPage()),
            ),
            // Only with a trainer shifting: the gears are its definition's.
            if (proxy != null && definition != null)
              BkGroupedRow(
                key: const ValueKey('settings-gears'),
                icon: LucideIcons.slidersHorizontal,
                title: l10n.gearSettings,
                trailing: Text(l10n.gearsCount(definition.maxGear)),
                chevron: true,
                onPressed: () => _open(GearRatiosEditorPage(definition: definition, device: proxy)),
              ),
          ],
        ),
        DuringRideSection(onOpen: _open),
        BkGroupedSection(
          key: const ValueKey('settings-help'),
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
                icon: LucideIcons.gauge,
                title: l10n.networkTroubleshootingTitle,
                chevron: true,
                onPressed: () => _open(const NetworkTroubleshootingPage()),
              ),
          ],
        ),
        BkGroupedSection(
          key: const ValueKey('settings-app'),
          header: l10n.settingsSectionApp,
          footer: version == null ? null : l10n.version(version),
          children: [
            BkGroupedRow(
              icon: LucideIcons.globe,
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
            if (_showsQuit)
              BkGroupedRow(
                key: const ValueKey('settings-quit'),
                icon: LucideIcons.power,
                title: l10n.chainCloseAndQuit,
                onPressed: _quit,
              ),
          ],
        ),
      ],
    );
  }
}

/// "During the ride": the gear overlay, shift feedback on this device, and
/// saving rides to Apple Health — each only where the platform has it.
class DuringRideSection extends StatefulWidget {
  const DuringRideSection({super.key, this.onOpen});

  /// Pushes a page and refreshes afterwards; a plain push when null.
  final Future<void> Function(Widget page)? onOpen;

  @override
  State<DuringRideSection> createState() => _DuringRideSectionState();
}

class _DuringRideSectionState extends State<DuringRideSection> {
  /// Sound has a backend on every desktop/mobile OS we ship; vibration needs
  /// a haptics engine, so phones and tablets only.
  bool get _showsShiftSound => !kIsWeb;

  bool get _showsShiftHaptics => PlatformShiftHaptics.isSupported;

  /// "Save rides to Apple Health": iOS/iPadOS with Health on the device.
  bool get _showsHealthRide => core.healthRide.isSupported;

  Future<void> _open(Widget page) async {
    if (widget.onOpen case final open?) {
      await open(page);
    } else {
      await context.push(page);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final proxy = chainProxy();
    final rows = <Widget>[
      // The overlay lives on the trainer's page; this row only opens it there.
      if (proxy != null && TrainerOverlayService.isSupportedPlatform)
        BkGroupedRow(
          key: const ValueKey('settings-overlay'),
          icon: LucideIcons.layers,
          title: l10n.overlaySection,
          trailing: Text(core.settings.getOverlayEnabled() ? l10n.statusOn : l10n.statusOff),
          chevron: true,
          onPressed: () => _open(ProxyDeviceDetailsPage(device: proxy, revealOverlaySection: true)),
        ),
      if (_showsShiftHaptics)
        BkSwitchRow(
          icon: LucideIcons.vibrate,
          title: l10n.shiftFeedbackHaptics,
          value: core.shiftFeedback.hapticsEnabled,
          onToggle: () async {
            await core.shiftFeedback.setHapticsEnabled(!core.shiftFeedback.hapticsEnabled);
            if (mounted) setState(() {});
          },
        ),
      if (_showsShiftSound)
        BkSwitchRow(
          icon: LucideIcons.volume2,
          title: l10n.shiftFeedbackSound,
          value: core.shiftFeedback.soundEnabled,
          onToggle: () async {
            await core.shiftFeedback.setSoundEnabled(!core.shiftFeedback.soundEnabled);
            if (mounted) setState(() {});
          },
        ),
      if (_showsHealthRide)
        ListenableBuilder(
          listenable: core.healthRide.changes,
          builder: (context, _) => BkSwitchRow(
            icon: LucideIcons.heartPulse,
            title: l10n.healthRideToggleTitle,
            // The duplicate warning is the one thing worth a second line.
            subtitle: core.healthRide.showsDuplicateHint
                ? l10n.healthRideDuplicateHint(core.healthRide.trainerApp()?.name ?? '')
                : null,
            value: core.healthRide.isEnabled,
            proOnly: true,
            onToggle: () async {
              try {
                await core.healthRide.setEnabled(!core.healthRide.isEnabled);
              } catch (e, s) {
                await recordError(e, s, context: 'Settings.setHealthRideEnabled');
              }
            },
          ),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return BkGroupedSection(
      key: const ValueKey('settings-during-ride'),
      header: l10n.settingsSectionDuringRide,
      children: rows,
    );
  }
}

/// The plan on top of Settings: its name, the way up (Go Pro) or to manage it,
/// and — without Pro on this device — how much of today's virtual shifting
/// trial is left.
class SettingsPlanCard extends StatelessWidget {
  const SettingsPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final iap = IAPManager.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([iap.entitlements, iap.isPurchased]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final cs = Theme.of(context).colorScheme;
        final tier = currentPlanTier();
        final name = planName(context, tier);
        final status = iap.getStatusMessage();
        final tracker = core.bridgeUsageTracker;
        // Virtual shifting is Pro per device; everyone else gets the daily
        // trial of it. Store renders stage a finished setup, not a limit.
        final showMeter = !iap.isProEnabledForCurrentDevice && tracker.dailyLimit > Duration.zero && !screenshotMode;
        return BkTappable(
          key: const ValueKey('settings-plan'),
          onPressed: () => openSubscription(context),
          borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: cs.card,
              borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.currentPlan,
                            style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                          ),
                          Text(name.toUpperCase(), style: BkDisplay.title(context)),
                          if (status.isNotEmpty && status != name)
                            Text(
                              status,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                            ),
                        ],
                      ),
                    ),
                    const Gap(12),
                    if (tier == PlanTier.pro)
                      Button.ghost(
                        onPressed: () => openSubscription(context),
                        child: Text(l10n.manageAction),
                      )
                    else
                      BkPillButton(
                        expand: false,
                        onPressed: () => openSubscription(context),
                        child: Text(l10n.goPro),
                      ),
                  ],
                ),
                if (showMeter) ...[
                  const Gap(12),
                  ValueListenableBuilder<Duration>(
                    valueListenable: tracker.usedTodayListenable,
                    builder: (context, _, _) => _VsTrialMeter(
                      remaining: tracker.remainingToday,
                      limit: tracker.dailyLimit,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Virtual shifting today · 14 min remaining today" over a bar.
class _VsTrialMeter extends StatelessWidget {
  const _VsTrialMeter({required this.remaining, required this.limit});

  final Duration remaining;
  final Duration limit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final minutes = remaining.isNegative ? 0 : remaining.inMinutes;
    final fraction = limit.inSeconds > 0 ? (remaining.inSeconds / limit.inSeconds).clamp(0.0, 1.0) : 0.0;
    final low = fraction <= 0.25;
    final status = BkStatusColors.of(context);
    final remainingText = l10n.bridgeMinutesRemainingToday(minutes);
    return Semantics(
      label: '${l10n.chainTrialBridgeMeter}: $remainingText',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chainTrialBridgeMeter,
                  style: context.typography.small.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                remainingText,
                style: context.typography.xSmall.copyWith(
                  color: low ? AmpelStyle.of(context, LinkStatus.attention).text : cs.mutedForeground,
                ),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: cs.muted,
              color: low ? status.warning : cs.primary,
            ),
          ),
        ],
      ),
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
