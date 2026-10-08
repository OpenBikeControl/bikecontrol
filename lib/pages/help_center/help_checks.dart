// Help answers that are a sequence of checks, shown as a numbered list —
// shared by the Help Center's answer sheets and the support intake's inline
// self-help.
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// One step of a [HelpCheckList]: a title, a line of explanation, and
/// optionally an external link or an in-app action.
class HelpCheck {
  const HelpCheck({
    required this.title,
    required this.body,
    this.linkLabel,
    this.linkUrl,
    this.actionKey,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String body;
  final String? linkLabel;
  final String? linkUrl;
  final Key? actionKey;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  HelpCheck withAction({Key? key, required String label, required IconData icon, required VoidCallback onPressed}) =>
      HelpCheck(
        title: title,
        body: body,
        linkLabel: linkLabel,
        linkUrl: linkUrl,
        actionKey: key,
        actionLabel: label,
        actionIcon: icon,
        onAction: onPressed,
      );
}

/// "My controller isn't found". The firmware step depends on the controller:
/// Zwift controllers update through Zwift Companion, Di2 and SRAM AXS through
/// their own apps, other brands through their maker's app; gamepads,
/// keyboards and phone steering have no firmware step. [controllerId] is an
/// intake controller id (see `controllerOptions`), or null when unknown.
List<HelpCheck> controllerNotFoundChecks(AppLocalizations l, {required String? controllerId}) {
  final firmwareBody = switch (controllerId) {
    'zwift_click' || 'zwift_click_v2' || 'zwift_play_left' || 'zwift_play_right' || 'zwift_ride' =>
      l.onboardingScanEmptyFirmwareSub,
    'shimano_di2' => l.helpCheckFirmwareDi2Sub,
    'sram_axs' => l.helpCheckFirmwareSramSub,
    'gamepad' || 'hid_keyboard' || 'gyroscope' => null,
    _ => l.helpCheckFirmwareMakerSub,
  };
  final zwift = firmwareBody == l.onboardingScanEmptyFirmwareSub;
  return [
    HelpCheck(title: l.onboardingScanEmptyWakeTitle, body: l.onboardingScanEmptyWakeSub),
    HelpCheck(title: l.onboardingScanEmptyDisconnectTitle, body: l.helpCheckDisconnectSub),
    HelpCheck(title: l.onboardingScanEmptyCloserTitle, body: l.onboardingScanEmptyCloserSub),
    if (firmwareBody != null)
      HelpCheck(
        title: l.onboardingScanEmptyFirmwareTitle,
        body: firmwareBody,
        linkLabel: zwift ? l.zwiftCompanionApp : null,
        linkUrl: zwift ? ZwiftConstants.ZWIFT_COMPANION_URL : null,
      ),
  ];
}

/// "BikeControl shifts, the app doesn't react": the connection to the trainer
/// app first, the gear display second.
List<HelpCheck> appNotReactingChecks(AppLocalizations l) => [
  HelpCheck(title: l.helpCheckAppConnectedTitle, body: l.helpCheckAppConnectedSub),
  HelpCheck(title: l.helpCheckGearOverlayTitle, body: l.helpCheckGearOverlaySub),
];

/// "My buttons stopped working": they worked, now nothing happens. Today's
/// button presses used up first — only when this rider has a daily limit
/// ([commandLimited]: no Base, no Pro) — then a sleeping or dropped
/// controller, then the connection to the trainer app.
List<HelpCheck> buttonsStoppedChecks(AppLocalizations l, {required bool commandLimited}) => [
  if (commandLimited)
    HelpCheck(title: l.helpCheckDailyLimitTitle, body: l.helpCheckDailyLimitSub(IAPManager.dailyCommandLimit)),
  HelpCheck(title: l.helpCheckControllerAwakeTitle, body: l.helpCheckControllerAwakeSub),
  HelpCheck(title: l.helpCheckConnectionMethodTitle, body: l.helpCheckConnectionMethodSub),
];

/// [appNotReactingChecks] with their direct actions: the network test on
/// the connection check and, when a trainer is known ([onOverlay]), the
/// overlay settings on the gear check. The Help Center's answer sheet and the
/// support intake show the same list.
List<HelpCheck> appNotReactingChecksWithActions(
  AppLocalizations l, {
  required VoidCallback onNetworkTest,
  VoidCallback? onOverlay,
}) {
  final [connection, gear] = appNotReactingChecks(l);
  return [
    connection.withAction(
      key: const ValueKey('help-check-network-test'),
      label: l.intakeSelfHelpNetworkAction,
      icon: LucideIcons.radioTower,
      onPressed: onNetworkTest,
    ),
    if (onOverlay != null)
      gear.withAction(
        key: const ValueKey('help-check-overlay-settings'),
        label: l.helpAnswerGearOverlayAction,
        icon: LucideIcons.layers,
        onPressed: onOverlay,
      )
    else
      gear,
  ];
}

/// Numbered checks, in the order to try them.
class HelpCheckList extends StatelessWidget {
  const HelpCheckList({super.key, required this.checks, this.tileColor});

  final List<HelpCheck> checks;

  /// Defaults to the card surface, with a hairline border: the muted body
  /// text only reaches 4.5:1 on card, not on the muted fill.
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < checks.length; i++)
          Container(
            margin: EdgeInsets.only(top: i == 0 ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: tileColor ?? cs.card,
              border: Border.all(color: cs.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: onboardingAccent(context)),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: onboardingOnAccent(context)),
                    child: Text('${i + 1}').xSmall.semiBold,
                  ),
                ),
                const Gap(11),
                Expanded(child: _CheckBody(check: checks[i])),
              ],
            ),
          ),
      ],
    );
  }
}

class _CheckBody extends StatelessWidget {
  const _CheckBody({required this.check});

  final HelpCheck check;

  @override
  Widget build(BuildContext context) {
    final linkUrl = check.linkUrl;
    final linkLabel = check.linkLabel;
    final onAction = check.onAction;
    final actionLabel = check.actionLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Text(check.title).small.semiBold),
        const Gap(2),
        Text(check.body).xSmall.muted,
        if (linkUrl != null && linkLabel != null)
          Button.link(
            onPressed: () => launchUrlString(linkUrl, mode: LaunchMode.externalApplication),
            trailing: const Icon(LucideIcons.externalLink, size: 12),
            child: Text(linkLabel).xSmall,
          ),
        if (onAction != null && actionLabel != null) ...[
          const Gap(8),
          Button.outline(
            key: check.actionKey,
            style: ButtonStyle.outline(size: ButtonSize.small),
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (check.actionIcon != null) ...[Icon(check.actionIcon, size: 14), const Gap(6)],
                Flexible(child: Text(actionLabel)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
