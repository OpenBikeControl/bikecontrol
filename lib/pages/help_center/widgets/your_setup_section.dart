// "Your setup" personalized section (Task 9) — rows built from the rider's
// actual configured controllers instead of static links: one help-article
// row per distinct controller (deduped by article URL), a network
// troubleshooting row while a network trainer connection is active, a Zwift
// Click V2 setup-options row while a Click V2 side is known (live or
// remembered), and a muted nudge toward the setup wizard when nothing is
// configured yet.
//
// Content-round addition: three explainer rows answering the questions the
// support-chat corpus actually asks, each opening a `HelpAnswerSheet`
// (help_answer_sheet.dart) instead of a bespoke page — "the gear doesn't
// move" while a trainer app is configured (deep-links to the trainer's own
// Overlay setting when a ProxyDevice is known), "keeps disconnecting" while
// any controller is known (live or remembered), and "isn't found" plus a
// "Run the setup guide" row whenever no controller is connected.
import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/pages/help_center/help_checks.dart';
import 'package:bike_control/pages/help_center/widgets/help_answer_sheet.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/onboarding/onboarding_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/help_article.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/widgets/menu.dart' show debugText;
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class YourSetupSection extends StatelessWidget {
  /// Test seam: replaces the device pool this section reads from — in
  /// production that's `core.connection.controllerDevices` for the
  /// help-article rows and `core.connection.devices` +
  /// `core.connection.offlineControllers` (live + remembered) for the Click
  /// V2 check. `core` is a convenient global in production but awkward to
  /// fake piecemeal in a widget test, so a single override list stands in
  /// for both when provided — see help_center_your_setup_test.dart.
  final List<BaseDevice>? devicesOverride;

  /// Test seam: replaces `core.logic.trainerConnections`.
  final List<TrainerConnection>? connectionsOverride;

  /// Test seam: "Scan again" in the not-found answer. Production returns to
  /// the home screen and starts a controller scan.
  final VoidCallback? onSearchAgain;

  /// Test seam: "Still stuck? Contact support" in the not-found answer, with
  /// the controller BikeControl knows (or null). Production opens the support
  /// chat with the intake answered for that controller not pairing.
  final void Function(String? controllerId)? onContactSupport;

  const YourSetupSection({
    super.key,
    this.devicesOverride,
    this.connectionsOverride,
    this.onSearchAgain,
    this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;

    final knownDevices =
        devicesOverride ?? <BaseDevice>{...core.connection.devices, ...core.connection.offlineControllers}.toList();
    final articleDevices = devicesOverride ?? core.connection.controllerDevices;
    final connections = connectionsOverride ?? core.logic.trainerConnections;

    final app = core.settings.getTrainerApp();
    final articles = <String, HelpArticle>{};
    for (final controller in articleDevices) {
      final article = helpArticleFor(context, controller: controller, app: app);
      if (article != null) articles[article.url] = article;
    }

    final hasNetworkConnection = connections.any(
      (t) => t.type == ConnectionMethodType.network && (t.isStarted.value || t.isConnected.value),
    );
    final hasClickV2 = knownDevices.any((d) => d is ZwiftClickV2 || d is ZwiftClickV2RightSide);
    // Any controller at all, live or remembered. `core.connection.
    // controllerDevices` already excludes the trainer's own ProxyDevice, but
    // `articleDevices` collapses to `devicesOverride` verbatim under the test
    // seam above (bypassing that filtering), so this re-excludes it directly
    // rather than trusting the source to have done so.
    final hasControllers =
        articleDevices.any((d) => d is! ProxyDevice) || core.connection.offlineControllers.isNotEmpty;
    // "Isn't found" is for exactly the rider with no working controller —
    // including one who never got a controller to show up at all, who the
    // old known-controller gate left without it.
    final hasConnectedController = articleDevices.any((d) => d is! ProxyDevice && d.isConnected);
    // The deep-link target for the overlay row below: prefer a connected
    // trainer, else any known one. `devicesOverride` doubles as the proxy
    // source too so tests can supply a fake one the same way they do for the
    // controller rows.
    // The firmware step of "isn't found" depends on the controller; use the
    // first one BikeControl knows, and assume none when it knows none.
    final knownControllerId = knownDevices
        .where((d) => d is! ProxyDevice)
        .map(controllerOptionIdFor)
        .whereType<String>()
        .firstOrNull;
    final proxyPool = (devicesOverride ?? core.connection.devices).whereType<ProxyDevice>();
    final proxy = proxyPool.where((d) => d.isConnected).firstOrNull ?? proxyPool.firstOrNull;

    // Matches the mockup's row padding (`padding:11px 14px`) now that the
    // card itself carries no padding — rows run edge-to-edge and supply
    // their own inset.
    final rowStyle = ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14));

    final rows = <Widget>[
      for (final article in articles.values)
        Button.ghost(
          style: rowStyle,
          onPressed: () => launchUrlString(article.url),
          child: Basic(
            leading: const Icon(LucideIcons.bookOpen, size: 18),
            title: Text(article.label),
            trailing: const Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
          ),
        ),
      // The single most common support question in the corpus: the press
      // registers in BikeControl, but the trainer app's gear never changes.
      // Shown whenever a trainer app is configured, independent of whether a
      // ProxyDevice is currently known — the sheet's body still describes the
      // path in text when there's nothing to deep-link to yet.
      if (app != null)
        Button.ghost(
          key: const ValueKey('help-gear-overlay'),
          style: rowStyle,
          onPressed: () => openHelpAnswerSheet(
            context,
            icon: LucideIcons.eye,
            title: l10n.helpCenterGearOverlayEntry,
            body: l10n.helpAnswerChecksIntro,
            checks: appNotReactingChecksWithActions(
              l10n,
              onNetworkTest: () => context.push(const NetworkTroubleshootingPage()),
              onOverlay: proxy == null
                  ? null
                  : () => context.push(ProxyDeviceDetailsPage(device: proxy, revealOverlaySection: true)),
            ),
            actions: [
              HelpAnswerAction.link(
                id: 'vs-blog',
                icon: LucideIcons.bike,
                label: l10n.helpAnswerGearFallbackAction,
                url: 'https://bikecontrol.app/blog/virtual-shifting-with-and-without-bikecontrol',
              ),
            ],
          ),
          child: Basic(
            leading: const Icon(LucideIcons.eye, size: 18),
            title: Text(l10n.helpCenterGearOverlayEntry),
            trailing: const Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
          ),
        ),
      if (hasNetworkConnection)
        Button.ghost(
          key: const ValueKey('help-network-troubleshoot'),
          style: rowStyle,
          onPressed: () => context.push(const NetworkTroubleshootingPage()),
          child: Basic(
            leading: const Icon(LucideIcons.radioTower, size: 18),
            title: Text(l10n.helpCenterNetworkEntry),
            trailing: const Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
          ),
        ),
      if (hasControllers)
        Button.ghost(
          key: const ValueKey('help-controller-disconnecting'),
          style: rowStyle,
          onPressed: () => openHelpAnswerSheet(
            context,
            icon: LucideIcons.bluetoothOff,
            title: l10n.helpCenterControllerDisconnectingEntry,
            body: l10n.helpAnswerControllerDisconnectingBody,
            actions: [
              HelpAnswerAction.link(
                id: 'clickv2-restart-blog',
                icon: LucideIcons.refreshCw,
                label: l10n.helpAnswerControllerDisconnectingAction,
                url: 'https://bikecontrol.app/blog/zwift-click-v2-with-other-trainer-apps',
              ),
            ],
          ),
          child: Basic(
            leading: const Icon(LucideIcons.bluetoothOff, size: 18),
            title: Text(l10n.helpCenterControllerDisconnectingEntry),
            trailing: const Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
          ),
        ),
      if (!hasConnectedController)
        Button.ghost(
          key: const ValueKey('help-controller-not-found'),
          style: rowStyle,
          onPressed: () => openHelpAnswerSheet(
            context,
            icon: LucideIcons.bluetooth,
            title: l10n.helpCenterControllerNotFoundEntry,
            body: l10n.helpAnswerChecksIntro,
            checks: controllerNotFoundChecks(l10n, controllerId: knownControllerId),
            actions: [
              HelpAnswerAction.navigate(
                id: 'search-again',
                icon: LucideIcons.bluetoothSearching,
                label: l10n.onboardingScanAgain,
                onPressed: onSearchAgain ?? () => _searchAgain(context),
              ),
              HelpAnswerAction.navigate(
                id: 'contact-support',
                icon: LucideIcons.messageCircle,
                label: l10n.helpAnswerStillStuckContactSupport,
                onPressed: () => (onContactSupport ?? (id) => _contactSupport(context, id))(knownControllerId),
              ),
            ],
          ),
          child: Basic(
            leading: const Icon(LucideIcons.bluetoothSearching, size: 18),
            title: Text(l10n.helpCenterControllerNotFoundEntry),
            trailing: const Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
          ),
        ),
      if (!hasConnectedController)
        Button.ghost(
          key: const ValueKey('help-run-setup-guide'),
          style: rowStyle,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const OnboardingPage())),
          child: Basic(
            leading: const Icon(LucideIcons.lightbulb, size: 18),
            title: Text(l10n.helpCenterRunSetupGuide),
            trailing: const Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
          ),
        ),
      if (hasClickV2)
        Button.ghost(
          key: const ValueKey('help-clickv2-onboarding'),
          style: rowStyle,
          onPressed: () => context.push(const ClickV2OnboardingPage()),
          child: Basic(
            leading: const Icon(LucideIcons.slidersHorizontal, size: 18),
            title: Text(l10n.helpCenterClickV2Entry),
            trailing: const Icon(LucideIcons.chevronRight, size: 16).iconMutedForeground,
          ),
        ),
    ];

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Text(l10n.helpCenterNoSetup).muted.small,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(),
          rows[i],
        ],
      ],
    );
  }

  /// Back to the home screen, where the controller scan shows, and scan.
  static void _searchAgain(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    unawaited(
      core.connection.performScanning().catchError((Object e, StackTrace s) {
        recordError(e, s, context: 'Help Center: scan again');
      }),
    );
  }

  static void _contactSupport(BuildContext context, String? controllerId) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SupportChatPage(
            diagnosticPreviewFuture: debugText(),
            initialIntake: IntakeAnswers(
              category: IntakeCategory.controller,
              subcategory: 'device',
              subcategoryValue: controllerId ?? 'other',
              symptom: 'no_pairing',
            ),
            telemetryBuilder: () async => TelemetrySnapshot.general(freetext: await debugText()),
          ),
        ),
      ),
    );
  }
}
