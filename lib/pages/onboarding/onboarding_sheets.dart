import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/pages/onboarding/onboarding_app_guides.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/overview_screenshot.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/help_article.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/guided_operation_sheet.dart';
import 'package:bike_control/widgets/menu.dart' show debugText;
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

({String title, String body}) _stepHelp(BuildContext context, OnboardingStep step) => switch (step) {
  OnboardingStep.app => (title: context.i18n.onboardingHelpAppTitle, body: context.i18n.onboardingHelpAppBody),
  OnboardingStep.where => (title: context.i18n.onboardingHelpWhereTitle, body: context.i18n.onboardingHelpWhereBody),
  OnboardingStep.controller => (
    title: context.i18n.onboardingHelpControllerTitle,
    body: context.i18n.onboardingHelpControllerBody,
  ),
  OnboardingStep.virtualShifting => (
    title: context.i18n.onboardingHelpVsTitle,
    body: context.i18n.onboardingHelpVsBody,
  ),
  OnboardingStep.connection => (
    title: context.i18n.onboardingHelpConnectionTitle,
    body: context.i18n.onboardingHelpConnectionBody,
  ),
  // Pro riders have no test-mode limits — answer the question they'd
  // actually have on the final step instead.
  OnboardingStep.done =>
    IAPManager.instance.isPurchased.value
        ? (title: context.i18n.onboardingHelpDoneProTitle, body: context.i18n.onboardingHelpDoneProBody)
        : (title: context.i18n.onboardingHelpDoneTitle, body: context.i18n.onboardingHelpDoneBody),
};

Widget onboardingHelpSheetBody(BuildContext context, {required OnboardingStep step, required VoidCallback onClose}) {
  final h = _stepHelp(context, step);
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  final article = helpArticleFor(
    context,
    controller: core.connection.controllerDevices.where((d) => d.isConnected).firstOrNull,
    app: core.settings.getTrainerApp(),
  );
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StageBadge(
        icon: LucideIcons.lifeBuoy,
        tone: onboardingAccent(context),
        wash: onboardingAccent(context).withValues(alpha: 0.1),
        reduceMotion: reduceMotion,
      ),
      Gap(14),
      Text(context.i18n.onboardingHelpSheetTitle).h4,
      Gap(6),
      Text(context.i18n.onboardingHelpSheetIntro).small.muted,
      Gap(14),
      // Contextual answer for the current step
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: onboardingAccent(context), width: 1.5),
          borderRadius: BorderRadius.circular(12),
          color: onboardingAccent(context).withValues(alpha: 0.06),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(h.title).small.semiBold, Gap(4), Text(h.body).xSmall.muted],
        ),
      ),
      Gap(12),
      _channel(
        context,
        icon: LucideIcons.bookOpen,
        title: context.i18n.onboardingHelpGuides,
        onTap: () => launchUrlString(
          onboardingGuideFor(context, core.settings.getTrainerApp() ?? SupportedApp.supportedApps.first).guideUrl ??
              'https://bikecontrol.app/',
          mode: LaunchMode.externalApplication,
        ),
      ),
      // Every controller + trainer-app combo has its own page on
      // bikecontrol.app (use-<controller>-with-<app>/ — see the sitemap);
      // the bundled markdown is only the fallback when no combo resolves.
      _channel(
        context,
        icon: LucideIcons.wrench,
        title: article != null ? article.label : context.i18n.onboardingHelpTroubleshooting,
        onTap: () {
          if (article != null) {
            launchUrlString(article.url, mode: LaunchMode.externalApplication);
          } else {
            onClose();
            openDrawer(
              context: context,
              position: OverlayPosition.bottom,
              builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md'),
            );
          }
        },
      ),
      // Network is the one connection method with its own guided fix-it flow
      // (mDNS/DirCon discovery) — offer a direct line to it right where the
      // rider is already asking for help, instead of leaving it buried behind
      // the generic troubleshooting article.
      //
      // Gated on any LAN method, not just OpenBikeControl mDNS: MyWhoosh Link
      // and Zwift/Rouvy mDNS fail to be discovered in exactly the same ways,
      // and a rider on one of those was previously offered nothing.
      if (core.logic.hasNetworkMethodEnabled)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BkTouchTarget(
            child: Button.outline(
              alignment: Alignment.center,
              onPressed: () {
                // Dismiss the sheet first, as _openSupportChat does — the page
                // must not open underneath a still-visible sheet. Synchronous,
                // so `context` is still mounted for the push.
                onClose();
                context.push(const NetworkTroubleshootingPage());
              },
              child: Text(context.i18n.networkTroubleshootingTitle),
            ),
          ),
        ),
      _channel(
        context,
        icon: LucideIcons.mail,
        title: context.i18n.onboardingHelpSupport,
        onTap: () => _openSupportChat(context, onClose),
      ),
      Gap(16),
      Align(
        alignment: Alignment.centerRight,
        child: BkTouchTarget(
          child: PrimaryButton(
            alignment: Alignment.center,
            onPressed: onClose,
            child: Text(context.i18n.onboardingHelpBackToSetup),
          ),
        ),
      ),
    ],
  );
}

/// Opens the in-app support chat exactly as `HelpButton` does
/// (lib/widgets/ui/help_button.dart) — screenshot + diagnostics are gathered
/// before the sheet is dismissed and the full-screen chat page is pushed.
/// `SupportChatPage` itself handles the case where there's no authenticated
/// session, so no extra guard is needed here.
Future<void> _openSupportChat(BuildContext context, VoidCallback onClose) async {
  try {
    final screenshot = await captureOverviewScreenshot(context: context);
    // Gather diagnostics in the background so the chat opens immediately; the
    // page awaits this future lazily for the preview and at send time (it
    // resolves once and is reused).
    final debugFuture = debugText();
    if (!context.mounted) return;
    onClose();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupportChatPage(
          diagnosticPreviewFuture: debugFuture,
          initialAttachment: screenshot,
          telemetryBuilder: () async => TelemetrySnapshot.general(freetext: await debugText()),
        ),
      ),
    );
  } catch (e, s) {
    recordError(e, s, context: 'onboarding help sheet support chat');
  }
}

Widget _channel(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Button.card(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18),
          Gap(12),
          Expanded(child: Text(title).small.semiBold),
          Icon(LucideIcons.externalLink, size: 14),
        ],
      ),
    ),
  );
}

Future<void> openOnboardingHelpSheet(BuildContext context, OnboardingStep step) {
  return openSheet<void>(
    context: context,
    position: OverlayPosition.bottom,
    builder: (sheetContext) => _sheetFrame(
      sheetContext,
      onboardingHelpSheetBody(sheetContext, step: step, onClose: () => closeSheet(sheetContext)),
    ),
  );
}

Widget permissionDeniedSheetBody(
  BuildContext context, {
  required VoidCallback onContinueAnyway,
  required VoidCallback onAllow,
}) {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StageBadge(
        icon: LucideIcons.bluetoothOff,
        tone: const Color(0xFFDC2626),
        wash: const Color(0x1ADC2626),
        reduceMotion: reduceMotion,
      ),
      Gap(14),
      Text(context.i18n.onboardingPermissionDeniedTitle).h4,
      Gap(8),
      Text(context.i18n.onboardingPermissionDeniedBody).small.muted,
      Gap(18),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          BkTouchTarget(
            child: GhostButton(
              alignment: Alignment.center,
              onPressed: onContinueAnyway,
              child: Text(context.i18n.onboardingContinueAnyway),
            ),
          ),
          Gap(10),
          BkTouchTarget(
            child: PrimaryButton(
              alignment: Alignment.center,
              onPressed: onAllow,
              child: Text(context.i18n.onboardingAllowBluetooth),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Resolves `true` = "continue anyway", `false` = "allow Bluetooth" (retry),
/// `null` = dismissed (tapped the barrier / system back).
///
/// `openSheet` uses shadcn's overlay-based drawer stack rather than a
/// Navigator route, so `Navigator.of(sheetContext).pop(value)` would not
/// close it or thread a result back through the returned future — use
/// `closeDrawer<T>(sheetContext, value)` instead (`closeSheet` itself always
/// resolves with `null`).
Future<bool?> openPermissionDeniedSheet(BuildContext context) {
  return openSheet<bool>(
    context: context,
    position: OverlayPosition.bottom,
    builder: (sheetContext) => _sheetFrame(
      sheetContext,
      permissionDeniedSheetBody(
        sheetContext,
        onContinueAnyway: () => closeDrawer<bool>(sheetContext, true),
        onAllow: () => closeDrawer<bool>(sheetContext, false),
      ),
    ),
  );
}

/// Width-capped on desktop, like SramGuidedSheet (sram_setup_sheet.dart:81-88).
Widget _sheetFrame(BuildContext context, Widget child) {
  return Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  );
}
