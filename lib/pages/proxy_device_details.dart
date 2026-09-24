import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/help_center/help_center_page.dart';
import 'package:bike_control/pages/help_center/help_center_support_context.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/pages/proxy_device_details/gear_hero_card.dart';
import 'package:bike_control/pages/proxy_device_details/live_metrics_section.dart';
import 'package:bike_control/pages/proxy_device_details/mini_workout_card.dart';
import 'package:bike_control/pages/proxy_device_details/need_help_card.dart';
import 'package:bike_control/pages/proxy_device_details/overlay_settings_section.dart';
import 'package:bike_control/pages/proxy_device_details/self_test_card.dart';
import 'package:bike_control/pages/proxy_device_details/trainer_settings_section.dart';
import 'package:bike_control/pages/proxy_device_details/virtual_shifting_pro_notice.dart';
import 'package:bike_control/services/overview_screenshot.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/lazy_async.dart';
import 'package:bike_control/widgets/menu.dart' show debugText;
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ProxyDeviceDetailsPage extends StatefulWidget {
  final ProxyDevice device;

  /// Scrolls to the Overlay section after the first frame. Used by the home
  /// screen's gear-overlay step so its button lands the rider directly on the
  /// "Show overlay during ride" switch.
  final bool revealOverlaySection;

  const ProxyDeviceDetailsPage({super.key, required this.device, this.revealOverlaySection = false});

  @override
  State<ProxyDeviceDetailsPage> createState() => _ProxyDeviceDetailsPageState();
}

class _ProxyDeviceDetailsPageState extends State<ProxyDeviceDetailsPage> {
  late StreamSubscription<BaseDevice> _connectionSub;
  final GlobalKey _overlaySectionKey = GlobalKey();
  final GlobalKey _settingsSectionKey = GlobalKey();

  /// Mirrors the persisted flag so the x tap hides the card in the same
  /// frame instead of waiting on the prefs write; read once at init because
  /// the flag only ever flips here.
  late bool _needHelpDismissed = core.settings.getNeedHelpCardDismissed();

  void _onEmulatorStateChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.device.isStartedListenable.addListener(_onEmulatorStateChanged);
    widget.device.onChange.addListener(_onEmulatorStateChanged);
    widget.device.isConnectedListenable.addListener(_onEmulatorStateChanged);
    widget.device.retrofitMode.addListener(_onEmulatorStateChanged);
    _connectionSub = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
    if (widget.revealOverlaySection) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealOverlaySection());
    }
  }

  /// Scrolls the Overlay section into view. No-op when the section isn't in
  /// the tree (e.g. the VS session ended before the hint's button was tapped,
  /// so the settings section isn't rendered).
  void _revealOverlaySection() {
    final ctx = _overlaySectionKey.currentContext;
    if (!mounted || ctx == null) return;
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      ),
    );
  }

  @override
  void dispose() {
    _connectionSub.cancel();
    widget.device.isStartedListenable.removeListener(_onEmulatorStateChanged);
    widget.device.onChange.removeListener(_onEmulatorStateChanged);
    widget.device.isConnectedListenable.removeListener(_onEmulatorStateChanged);
    widget.device.retrofitMode.removeListener(_onEmulatorStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(
            AppLocalizations.of(context).smartTrainer,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          trailing: [
            IconButton.ghost(
              icon: Icon(LucideIcons.x, size: 22, color: Theme.of(context).colorScheme.mutedForeground),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          backgroundColor: Theme.of(context).colorScheme.background,
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _deviceCard(),
                SizedBox(height: 12),
                if (_ftmsMissingWarning() case final w?) ...[
                  w,
                  SizedBox(height: 12),
                ],

                if (!screenshotMode) ...[
                  // Stable keys keep these persistent stateful cards from being
                  // remounted when conditional siblings (FTMS warning above;
                  // gear/settings/VS-notice below) appear/disappear on
                  // (dis)connect — an unkeyed widget trapped between two
                  // toggling siblings lands in the reconciliation middle and is
                  // re-inflated, which would reset ConnectionCard's accordion.
                  ConnectionCard(key: const ValueKey('connection-card'), device: device),
                  SizedBox(height: 12),
                  // Keyed for the same reason: dismissing it toggles a sibling
                  // right next to ConnectionCard.
                  if (!_needHelpDismissed) ...[
                    NeedHelpCard(
                      key: const ValueKey('need-help'),
                      onOpenHelp: _routeToHelpCenter,
                      onDismiss: _dismissNeedHelp,
                    ),
                    SizedBox(height: 12),
                  ],
                ],
                _gearSection(),
                SizedBox(height: 20),
                if (!IAPManager.instance.isProEnabledForCurrentDevice &&
                    widget.device.fitnessBike != null &&
                    !screenshotMode) ...[
                  ValueListenableBuilder<Duration>(
                    valueListenable: core.bridgeUsageTracker.usedTodayListenable,
                    builder: (context, used, _) {
                      final remaining = core.bridgeUsageTracker.dailyLimit - used;
                      final clamped = remaining.isNegative ? Duration.zero : remaining;
                      return VirtualShiftingProNotice(
                        trainerAppName:
                            core.settings.getTrainerApp()?.name ?? AppLocalizations.of(context).yourTrainerApp,
                        remainingToday: clamped,
                      );
                    },
                  ),
                  SizedBox(height: 26),
                ],
                // The live readout duplicates the watts/rpm already on the
                // device card above it, and on a store board it pushes the
                // Virtual Shifting settings — the thing that board is about —
                // off the bottom of the phone.
                if (!screenshotMode) ...[
                  LiveMetricsSection(
                    key: const ValueKey('live-metrics'),
                    device: device,
                    hideWhenDeviceHasNoMetrics: true,
                  ),
                  SizedBox(height: 20),
                ],
                if (!screenshotMode && device.fitnessBike != null) ...[
                  SelfTestCard(
                    key: const ValueKey('self-test'),
                    device: device,
                    onShowOverlaySettings: _revealOverlaySection,
                  ),
                  SizedBox(height: 20),
                ],
                if (!debugHideMiniWorkoutCard) ...[
                  MiniWorkoutCard(key: const ValueKey('mini-workout'), device: device),
                  SizedBox(height: 20),
                ],
                _settingsSection(),
                SizedBox(height: 32),
                _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _dismissNeedHelp() async {
    setState(() => _needHelpDismissed = true);
    try {
      await core.settings.setNeedHelpCardDismissed(true);
    } catch (e, s) {
      recordError(e, s, context: 'need-help card dismiss persist');
    }
  }

  /// The "Need help?" CTA: routes into the Help Center's "Your setup"
  /// section — the gear overlay, controller-disconnect and network-test
  /// explainers these riders usually need — instead of straight into a
  /// support chat. The same rich diagnostic payload the chat used to get up
  /// front (a screenshot, trainer-specific telemetry) still rides along via
  /// [HelpCenterSupportContext], so it isn't lost if the rider continues
  /// from there into "Tell us what's wrong". The composer is deliberately
  /// left empty — no prefilled label — a fixed origin marker still reaches
  /// support, folded into the telemetry's freetext below, so a chat that
  /// started from this card is recognisable as such.
  Future<void> _routeToHelpCenter() async {
    final device = widget.device;
    // Cheap, local (RepaintBoundary → PNG) — unlike debugText() below, worth
    // paying up front rather than deferring.
    final screenshot = await captureOverviewScreenshot(context: context);
    if (!mounted) return;
    // Lazy + memoized: the Help Center is now an intermediate stop the rider
    // can bounce off without ever opening the chat, so debugText() (a real
    // mDNS discovery scan) must not run just because this button was tapped
    // — only if the rider actually continues into "Tell us what's wrong".
    // memoizeAsync also means that first call is the *only* gather: the
    // composer's diagnostic preview and every send-time telemetry attachment
    // share it rather than each re-gathering their own. The full debugText
    // (gathered here) already carries this trainer's services &
    // characteristics, the diagnostics block and the log buffer, so we
    // attach it instead of just the services snippet.
    final buildSnapshot = memoizeAsync(() async {
      final debug = await debugText();
      return TelemetrySnapshot.fromDevice(device: device, freetextOverride: 'needHelp\n$debug');
    });
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HelpCenterPage(
          focus: HelpCenterFocus.yourSetup,
          launchContext: HelpCenterSupportContext(
            telemetryBuilder: buildSnapshot,
            initialAttachment: screenshot,
          ),
        ),
      ),
    );
  }

  Widget? _ftmsMissingWarning() {
    final supportsVS = widget.device.fitnessBike?.supportsVirtualShiftingMode(VirtualShiftingMode.targetPower) == true;
    if (supportsVS || !widget.device.isConnected || widget.device.isStarting.value) return null;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          Expanded(
            child: Text(
              AppLocalizations.of(context).trainerMissingFtmsWarning(widget.device.name),
              style: TextStyle(fontSize: 12, color: cs.foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: widget.device.showInformation(context, showFull: true),
    );
  }

  Widget _gearSection() {
    final def = widget.device.fitnessBike;
    if (def == null) return const SizedBox.shrink();
    // No Edit affordance on a store board: it points at the settings section,
    // which that board already shows in full right below the card.
    return GearHeroCard(
      definition: def,
      onEditSettings: screenshotMode ? null : _revealSettingsSection,
    );
  }

  /// Scrolls the Virtual Shifting settings into view — the destination of the
  /// gear card's Edit, which is on the same page rather than behind a push.
  void _revealSettingsSection() {
    final ctx = _settingsSectionKey.currentContext;
    if (!mounted || ctx == null) return;
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.05,
      ),
    );
  }

  Widget _settingsSection() {
    final def = widget.device.fitnessBike;
    if (def == null) return const SizedBox.shrink();
    return Column(
      key: _settingsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(
          AppLocalizations.of(context).virtualShiftingSettings,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        TrainerSettingsSection(definition: def, device: widget.device),
        KeyedSubtree(
          key: _overlaySectionKey,
          child: OverlaySettingsSection(definition: def, device: widget.device),
        ),
      ],
    );
  }

  Widget _actions() {
    final device = widget.device;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        LoadingWidget(
          futureCallback: () async {
            await core.settings.setAutoConnect(device.trainerKey, false);
            await core.connection.disconnect(device, forget: false, persistForget: false);
            if (mounted) Navigator.of(context).pop();
          },
          renderChild: (isLoading, tap) => Button(
            style: ButtonStyle.outline(),
            onPressed: tap,
            leading: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.bluetoothOff, size: 18),
            child: Text(AppLocalizations.of(context).disconnectAndForgetForThisSession),
          ),
        ),
        LoadingWidget(
          futureCallback: () async {
            await core.settings.setAutoConnect(device.trainerKey, false);
            await core.connection.disconnect(device, forget: true, persistForget: true);
            if (mounted) Navigator.of(context).pop();
          },
          renderChild: (isLoading, tap) => Button(
            style: ButtonStyle.destructive(),
            onPressed: tap,
            leading: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.trash2, size: 18),
            child: Text(AppLocalizations.of(context).disconnectAndForget),
          ),
        ),
      ],
    );
  }
}
