import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/help_center/help_center_page.dart';
import 'package:bike_control/pages/help_center/help_center_support_context.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/pages/proxy_device_details/control_protocol_section.dart';
import 'package:bike_control/pages/proxy_device_details/need_help_card.dart';
import 'package:bike_control/pages/proxy_device_details/self_test_card.dart';
import 'package:bike_control/pages/settings/overlay_settings_page.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:bike_control/services/overview_screenshot.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/lazy_async.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/menu.dart' show debugText;
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';

/// Devices → Smart Trainer: the trainer's hardware page. Is it connected and
/// how (the connection card, with the WiFi / Bluetooth choice), which control
/// protocol it speaks, and is it healthy (the resistance self-test, Need
/// help?) — plus one link out to its virtual shifting settings, which live in
/// Settings, and the way to disconnect it.
///
/// The gear itself is on Ride; how it shifts and the overlay are in Settings.
class ProxyDeviceDetailsPage extends StatefulWidget {
  final ProxyDevice device;

  /// Scrolls to the resistance self-test after the first frame — the setup
  /// guide's "Run the trainer check" lands here.
  final bool revealSelfTest;

  const ProxyDeviceDetailsPage({
    super.key,
    required this.device,
    this.revealSelfTest = false,
  });

  @override
  State<ProxyDeviceDetailsPage> createState() => _ProxyDeviceDetailsPageState();
}

class _ProxyDeviceDetailsPageState extends State<ProxyDeviceDetailsPage> {
  late StreamSubscription<BaseDevice> _connectionSub;
  final GlobalKey _selfTestKey = GlobalKey();

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
    if (widget.revealSelfTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelfTest());
    }
  }

  void _revealSelfTest() {
    final ctx = _selfTestKey.currentContext;
    if (!mounted || ctx == null) return;
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        duration: prefersReducedMotion(context) ? Duration.zero : const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      ),
    );
  }

  /// The self-test's "Show gear overlay setup": the overlay's own page.
  Future<void> _openOverlaySettings() async {
    final definition = widget.device.fitnessBike;
    if (definition == null) return;
    await context.push(OverlaySettingsPage(device: widget.device, definition: definition));
  }

  Future<void> _openVirtualShiftingSettings() async {
    final definition = widget.device.fitnessBike;
    if (definition == null) return;
    await context.push(VirtualShiftingSettingsPage(definition: definition, device: widget.device));
    if (mounted) setState(() {});
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
        BkPageHeader(title: AppLocalizations.of(context).smartTrainer),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: BkPageColumn(
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
                // remounted when conditional siblings (the FTMS warning above,
                // the protocol and health cards below) appear/disappear on
                // (dis)connect — an unkeyed widget trapped between two
                // toggling siblings lands in the reconciliation middle and is
                // re-inflated, which would reset ConnectionCard's accordion.
                ConnectionCard(key: const ValueKey('connection-card'), device: device),
                SizedBox(height: 12),
              ],
              // How BikeControl talks to this trainer — hardware, so it sits
              // here, next to the self-test that recommends changing it.
              if (device.fitnessBike case final definition?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ControlProtocolSection(
                    key: const ValueKey('control-protocol'),
                    definition: definition,
                    device: device,
                  ),
                ),
              if (!screenshotMode) ...[
                // Checking comes before asking: the self-test answers "does
                // BikeControl control my trainer?" on its own, so it sits
                // above the card that routes to support.
                if (device.fitnessBike != null) ...[
                  KeyedSubtree(
                    key: _selfTestKey,
                    child: SelfTestCard(
                      key: const ValueKey('self-test'),
                      device: device,
                      onShowOverlaySettings: _openOverlaySettings,
                    ),
                  ),
                  SizedBox(height: 12),
                ],
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
              // The one link out: riders who come here for their gears still
              // find them.
              if (device.fitnessBike != null) ...[
                SizedBox(height: 12),
                BkGroupedSection(
                  children: [
                    BkGroupedRow(
                      key: const ValueKey('trainer-vs-settings'),
                      icon: LucideIcons.slidersHorizontal,
                      title: context.i18n.virtualShiftingSettings,
                      chevron: true,
                      onPressed: _openVirtualShiftingSettings,
                    ),
                  ],
                ),
              ],
              SizedBox(height: 32),
              _actions(),
            ],
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
    final screenshot = await captureCurrentScreenScreenshot(context);
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
          Icon(LucideIcons.triangleAlert, color: BkStatusColors.of(context).warning, size: 18),
          Expanded(
            child: Text(
              AppLocalizations.of(context).trainerMissingFtmsWarning(widget.device.name),
              style: context.typography.xSmall.copyWith(color: cs.foreground),
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
