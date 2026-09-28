import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_unlock.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// The unlock post's Zwift Ride V2 section.
const zwiftRideV2HelpUrl = '$zwiftUnlockBlogUrl#zwift-ride-v2';

/// Opens the in-app support chat about the Zwift Ride V2 lock, with the
/// "Zwift Ride V2 lock" intake and the controller's firmware already filled in.
void openZwiftRideV2Support(BuildContext context, BaseDevice device) {
  final answers = rideV2LockIntake(device);
  final firmware = answers.firmware ?? '';
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SupportChatPage(
        initialText: context.i18n.rideV2SupportPrefill(firmware.isEmpty ? '?' : firmware),
        initialIntake: answers,
        telemetryBuilder: () async =>
            TelemetrySnapshot.general(freetext: 'Zwift Ride V2 firmware: ${firmware.isEmpty ? 'unknown' : firmware}'),
      ),
    ),
  );
}

/// "Don't want to unlock every day? Contact support." — shown on the Zwift
/// Ride V2 screens only, never on the Click V2's.
class ZwiftRideV2SupportLine extends StatelessWidget {
  final BaseDevice device;

  /// Runs before support opens, e.g. to close the sheet or toast it sits in.
  final VoidCallback? onBeforeOpen;

  const ZwiftRideV2SupportLine({super.key, required this.device, this.onBeforeOpen});

  @override
  Widget build(BuildContext context) {
    return Button.ghost(
      key: const ValueKey('ride-v2-support-line'),
      onPressed: () {
        onBeforeOpen?.call();
        openZwiftRideV2Support(context, device);
      },
      child: Text(context.i18n.rideV2SupportLine, textAlign: TextAlign.center).xSmall.underline,
    );
  }
}

/// The unlock section on a Zwift Ride V2's device card: how it unlocks, its
/// current lock state with "Unlock now" / "Unlock again", and the way to
/// support. No unlock-mode choice — a Ride V2 always unlocks with Zwift.
class ZwiftRideV2UnlockSection extends StatelessWidget {
  final ZwiftUnlock device;

  const ZwiftRideV2UnlockSection({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;
    return Column(
      key: const ValueKey('ride-v2-unlock-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          children: [
            Text(l10n.unlock_modeZwift).small.semiBold,
            BkIconButton.link(
              icon: const Icon(LucideIcons.circleHelp),
              label: l10n.a11yHelp,
              onPressed: () => launchUrlString(device.unlockHelpUrl),
            ),
          ],
        ),
        Text(l10n.unlock_modeZwiftDescription).xSmall.muted,
        ...device.unlockWarnings(context),
        ZwiftRideV2SupportLine(device: device),
      ],
    );
  }
}

/// Toast for a Zwift Ride V2 that connected while Zwift has it locked. Runs
/// from the connect flow, outside any widget, like [buildToast] itself.
void showZwiftRideV2LockedToast(ZwiftUnlock device) {
  if (screenshotMode) return;
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  final l10n = context.i18n;
  buildToast(
    level: LogLevel.LOGLEVEL_WARNING,
    title: l10n.rideV2LockedToast,
    titleWidget: ZwiftRideV2LockedToastContent(device: device),
    duration: const Duration(seconds: 10),
  );
}

/// The locked toast's body: what to do, and the way to support.
class ZwiftRideV2LockedToastContent extends StatelessWidget {
  final BaseDevice device;

  const ZwiftRideV2LockedToastContent({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Text(context.i18n.rideV2LockedToast),
        ZwiftRideV2SupportLine(device: device),
      ],
    );
  }
}

/// Shows the one-time Zwift Ride V2 explainer the first time a Ride V2 is
/// connected. Returns whether it opened it.
Future<bool> maybeShowZwiftRideV2Explainer(BuildContext context, Iterable<BaseDevice> controllers) async {
  if (screenshotMode || core.settings.getRideV2ExplainerShown()) return false;
  final rideV2 = controllers.firstOrNullWhere((d) => d.isConnected && d is ZwiftUnlock && d.isRideV2);
  if (rideV2 == null) return false;
  unawaited(core.settings.setRideV2ExplainerShown(true));
  await context.push(ZwiftRideV2ExplainerPage(device: rideV2));
  return true;
}

/// The one-time Zwift Ride V2 explainer, in the Click V2 onboarding's visual
/// language — but with nothing to choose: the Ride V2 only unlocks with Zwift.
class ZwiftRideV2ExplainerPage extends StatelessWidget {
  final BaseDevice device;

  const ZwiftRideV2ExplainerPage({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(l10n.rideV2Explainer_title).large.semiBold),
                          BkIconButton.ghost(
                            key: const ValueKey('ride-v2-explainer-close'),
                            icon: const Icon(LucideIcons.x),
                            label: l10n.close,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                      Text(l10n.rideV2Explainer_intro).small.muted,
                      Button.link(
                        onPressed: () => launchUrlString(zwiftRideV2HelpUrl),
                        trailing: const Icon(LucideIcons.externalLink, size: 14),
                        child: Text(l10n.clickV2Onboarding_whyLink),
                      ),
                    ],
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 180,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: _RideV2Hero(),
                          ),
                        ),
                        const Gap(12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 12,
                            children: [
                              Text(l10n.rideV2Explainer_heading).large.semiBold,
                              _row(
                                context,
                                LucideIcons.circleCheck,
                                l10n.rideV2Explainer_row2,
                                BkStatusColors.of(context).success,
                              ),
                              _row(context, LucideIcons.clock, l10n.rideV2Explainer_row3, cs.mutedForeground),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: Button.primary(
                      key: const ValueKey('ride-v2-explainer-got-it'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Center(child: Text(l10n.rideV2Explainer_gotIt)),
                    ),
                  ),
                ),
                const Gap(4),
                Center(
                  child: ZwiftRideV2SupportLine(
                    device: device,
                    onBeforeOpen: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const Gap(12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Icon(icon, size: 16, color: color),
        Expanded(child: Text(text).small),
      ],
    );
  }
}

/// The Ride's contour with a padlock badge — the Click V2 explainer's hero,
/// for the Ride.
class _RideV2Hero extends StatelessWidget {
  const _RideV2Hero();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Same treatment as the Click V2 hero: tint in dark mode, leave the
    // source art alone in light mode.
    final colorFilter = Theme.of(context).brightness == Brightness.dark
        ? ColorFilter.mode(cs.primary, BlendMode.srcIn)
        : null;
    return Stack(
      alignment: Alignment.center,
      children: [
        SvgPicture.asset('assets/contours/zwift_play_both.svg', fit: BoxFit.contain, colorFilter: colorFilter),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.card,
            shape: BoxShape.circle,
            border: Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Icon(LucideIcons.lock, size: 18, color: cs.primary),
        ),
      ],
    );
  }
}
