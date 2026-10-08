import 'dart:async';

import 'package:bike_control/pages/plan/plan_account_page.dart';
import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/help_center/help_center_page.dart';
import 'package:bike_control/pages/home/home_page.dart' show chainProxy;
import 'package:bike_control/pages/changelog_page.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/settings/overlay_settings_page.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/services/shift_feedback/shift_haptics.dart';
import 'package:bike_control/utils/auth/account_session.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/app_version_line.dart';
import 'package:bike_control/widgets/logviewer.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/plan/vs_trial_meter.dart';
import 'package:bike_control/widgets/rides/ride_zone_settings.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_input_dialog.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_switch_row.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show connectionMethodSummary;
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show MaterialPageRoute, showLicensePage;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:bike_control/widgets/ui/bk_brand_band.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, SupabaseClient;

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
            // The trainer app and how it connects are picked on one page:
            // one row, the app below its name, the method on the right.
            BkGroupedRow(
              key: const ValueKey('settings-trainer-app'),
              icon: LucideIcons.monitor,
              title: l10n.settingsTrainerAppConnection,
              subtitle: app?.name ?? l10n.chainStatusNotSetUp,
              trailing: switch (connectionMethodSummary(context)) {
                final summary? => Text(summary),
                null => null,
              },
              chevron: true,
              onPressed: () => _open(const TrainerConnectionSettingsPage()),
            ),
            // Only with a trainer shifting: the settings are its active
            // shifting config's.
            if (proxy != null && definition != null)
              BkGroupedRow(
                key: const ValueKey('settings-vs'),
                icon: LucideIcons.slidersHorizontal,
                title: l10n.rideVirtualShifting,
                subtitle: virtualShiftingSummary(context, definition, proxy),
                chevron: true,
                onPressed: () => _open(VirtualShiftingSettingsPage(definition: definition, device: proxy)),
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
              quietIcon: true,
              title: l10n.helpCenterTitle,
              chevron: true,
              onPressed: () => _open(const HelpCenterPage()),
            ),
            BkGroupedRow(
              icon: LucideIcons.lightbulb,
              quietIcon: true,
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
              quietIcon: true,
              title: l10n.logs,
              chevron: true,
              onPressed: () => _open(LogViewer()),
            ),
            if (!kIsWeb)
              BkGroupedRow(
                icon: LucideIcons.gauge,
                quietIcon: true,
                title: l10n.networkTroubleshootingTitle,
                chevron: true,
                onPressed: () => _open(const NetworkTroubleshootingPage()),
              ),
          ],
        ),
        BkGroupedSection(
          key: const ValueKey('settings-app'),
          header: l10n.settingsSectionApp,
          footerChild: const AppVersionLine(),
          children: [
            BkGroupedRow(
              icon: LucideIcons.globe,
              quietIcon: true,
              title: l10n.language,
              trailing: LanguageSelect(bare: true, onChanged: () => setState(() {})),
            ),
            BkGroupedRow(
              icon: LucideIcons.refreshCw,
              quietIcon: true,
              title: l10n.changelog,
              chevron: true,
              onPressed: () => _open(const ChangelogPage()),
            ),
            BkGroupedRow(
              icon: LucideIcons.star,
              quietIcon: true,
              title: context.i18n.leaveAReview,
              chevron: true,
              onPressed: _review,
            ),
            BkGroupedRow(
              icon: LucideIcons.shieldCheck,
              quietIcon: true,
              title: l10n.license,
              chevron: true,
              onPressed: () => showLicensePage(context: context),
            ),
            if (_showsQuit)
              BkGroupedRow(
                key: const ValueKey('settings-quit'),
                icon: LucideIcons.power,
                quietIcon: true,
                title: l10n.chainCloseAndQuit,
                onPressed: _quit,
              ),
          ],
        ),
      ],
    );
  }
}

/// "During the ride": recording rides automatically and saving them to the
/// Health store, the FTP and max heart rate the rides' zones use, the gear
/// overlay and shift feedback on this device — each only where the platform
/// has it.
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

  @override
  void initState() {
    super.initState();
    core.rides.changes.addListener(_onRidesChanged);
  }

  @override
  void dispose() {
    core.rides.changes.removeListener(_onRidesChanged);
    super.dispose();
  }

  void _onRidesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _guard(String context, Future<Object?> Function() run) async {
    try {
      await run();
    } catch (e, s) {
      await recordError(e, s, context: context);
    }
  }

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
    final definition = proxy?.fitnessBike;
    final rides = core.rides;
    final store = rides.healthStore;
    final rows = <Widget>[
      // Recording comes first: everything after it is about how a ride feels.
      BkSwitchRow(
        key: const ValueKey('settings-auto-record'),
        icon: LucideIcons.circleDot,
        title: l10n.ridesAutoRecordTitle,
        subtitle: l10n.ridesAutoRecordSubtitle,
        value: rides.autoRecord,
        onToggle: () => _guard('Settings.setAutoRecord', () => rides.setAutoRecord(!rides.autoRecord)),
      ),
      if (store != null)
        BkSwitchRow(
          key: const ValueKey('settings-save-to-health'),
          icon: LucideIcons.heart,
          title: l10n.ridesHealthToggle(healthStoreName(store, l10n)),
          // The duplicate warning, else what goes there; or the install.
          subtitle: !rides.healthReady
              ? l10n.ridesHealthConnectNotInstalled
              : rides.showsDuplicateHint
              ? l10n.ridesHealthDuplicateHint(rides.trainerApp()?.name ?? '', healthStoreName(store, l10n))
              : l10n.ridesHealthOnlyRecorded,
          value: rides.savesToHealth,
          onToggle: () => _guard(
            'Settings.setSavesToHealth',
            () => rides.healthReady ? rides.setSavesToHealth(!rides.savesToHealth) : rides.installHealth(),
          ),
        ),
      // What the ride details' zones are measured against; optional, and
      // typed right into the row where there is room for it.
      _ZoneValueRow(
        rowKey: const ValueKey('settings-ftp'),
        icon: LucideIcons.zap,
        title: l10n.ridesFtpTitle,
        body: l10n.ridesFtpBody,
        unit: 'W',
        value: () => core.rides.prefs.ftpWatts,
        field: ({autofocus = false, onDone}) => RideFtpField(autofocus: autofocus, onDone: onDone),
      ),
      _ZoneValueRow(
        rowKey: const ValueKey('settings-max-heart-rate'),
        icon: LucideIcons.heartPulse,
        title: l10n.ridesMaxHeartRateTitle,
        body: l10n.ridesMaxHeartRateBody,
        unit: 'bpm',
        value: () => core.rides.prefs.maxHeartRateBpm,
        field: ({autofocus = false, onDone}) => RideMaxHeartRateField(autofocus: autofocus, onDone: onDone),
      ),
      // The overlay draws the gear of a shifting trainer; without one there
      // is nothing for it to show.
      if (proxy != null && definition != null && TrainerOverlayService.isSupportedPlatform)
        BkGroupedRow(
          key: const ValueKey('settings-overlay'),
          icon: LucideIcons.layers,
          title: l10n.overlaySection,
          trailing: Text(core.settings.getOverlayEnabled() ? l10n.statusOn : l10n.statusOff),
          chevron: true,
          onPressed: () => _open(OverlaySettingsPage(device: proxy, definition: definition)),
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
    ];
    return BkGroupedSection(
      key: const ValueKey('settings-during-ride'),
      header: l10n.settingsSectionDuringRide,
      footer: rides.autoRecord ? null : l10n.ridesAutoRecordOffFooter,
      children: rows,
    );
  }
}

/// The plan on top of Settings: its name, the way up (Go Pro) or to manage it,
/// and — without Pro on this device — how much of today's virtual shifting
/// trial is left. Signed out, "Sign in" sits beside Go Pro, so a rider who
/// bought Pro on another device finds the way to it.
class SettingsPlanCard extends StatelessWidget {
  const SettingsPlanCard({super.key, this.client});

  /// Test seam; null uses the app's Supabase client.
  final SupabaseClient? client;

  @override
  Widget build(BuildContext context) {
    final iap = IAPManager.instance;
    final auth = (client ?? core.supabase).auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) => ListenableBuilder(
        listenable: Listenable.merge([iap.entitlements, iap.isPurchased]),
        builder: (context, _) {
          final signedIn = hasAccount(auth.currentSession?.user);
          final l10n = AppLocalizations.of(context);
          final tier = currentPlanTier();
          final name = planName(context, tier);
          final status = iap.getStatusMessage();
          return BkTappable(
            key: const ValueKey('settings-plan'),
            onPressed: () => openPlanAccount(context),
            borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
            // The plan wears the brand band: white text, a white Go Pro.
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
                boxShadow: bkCardShadow(context),
              ),
              child: BkBrandBand(
                borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                contours: const BkContourPlacement.card(),
                child: Builder(
                  builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    return Column(
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
                                onPressed: () => openPlanAccount(context),
                                child: Text(l10n.manageAction),
                              )
                            else ...[
                              if (!signedIn)
                                Button.ghost(
                                  key: const ValueKey('settings-plan-sign-in'),
                                  onPressed: () => openPlanAccount(context),
                                  child: Text(l10n.signIn),
                                ),
                              BkPillButton(
                                expand: false,
                                onPressed: () => openPlanAccount(context),
                                child: Text(l10n.goPro),
                              ),
                            ],
                          ],
                        ),
                        const VsTrialMeterSlot(gap: 12),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// FTP or max heart rate in Settings. With room (a wide column) the value is
/// typed right into the row, its explanation under the title. In a narrow
/// column that crowds the row into a tall strip, so the row shows the value
/// and opens a small dialog with the explanation and the field.
class _ZoneValueRow extends StatelessWidget {
  const _ZoneValueRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.body,
    required this.unit,
    required this.value,
    required this.field,
  });

  /// Below this row width the field moves into a dialog.
  static const double inlineMinWidth = 520;

  final Key rowKey;
  final IconData icon;
  final String title;
  final String body;
  final String unit;
  final int? Function() value;
  final Widget Function({bool autofocus, VoidCallback? onDone}) field;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= inlineMinWidth) {
          return BkGroupedRow(key: rowKey, icon: icon, title: title, subtitle: body, trailing: field());
        }
        return ListenableBuilder(
          listenable: core.rides.prefs,
          builder: (context, _) {
            final current = value();
            return BkGroupedRow(
              key: rowKey,
              icon: icon,
              title: title,
              trailing: Text(current == null ? '–' : '$current $unit'),
              chevron: true,
              onPressed: () => _openDialog(context),
            );
          },
        );
      },
    );
  }

  Future<void> _openDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        // Saving, Escape and Done all end here; the field also commits as the
        // dialog takes its focus away, so close only once.
        var closed = false;
        void close() {
          if (closed) return;
          closed = true;
          Navigator.of(dialogContext).pop();
        }

        return BkInputDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body).small.muted,
              const Gap(16),
              field(autofocus: true, onDone: close),
            ],
          ),
          actions: [Button.ghost(onPressed: close, child: Text(l10n.done))],
        );
      },
    );
  }
}
