import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// The unlock-mode section shown on both Zwift Click V2 pucks: which mode is
/// set, what it costs, and the way back into the explainer that changes it.
///
/// Deliberately not a mode picker. The explainer is the one place the choice is
/// made — it is what applies the follow-on work each mode needs (un-ignoring
/// the left puck, remapping for right-side-only, cancelling the reset timer),
/// none of which a bare dropdown did. But it does have to *name* the current
/// mode: without that the card looked identical before and after a change, and
/// picking a new mode read as having done nothing at all.
class UnlockToggle extends StatefulWidget {
  /// Shown only in unlock-with-Zwift mode — the warnings that mode implies.
  final List<Widget> children;
  const UnlockToggle({super.key, required this.children});

  @override
  State<UnlockToggle> createState() => _UnlockToggleState();
}

class _UnlockToggleState extends State<UnlockToggle> {
  late _UnlockMode _mode = _readMode();

  _UnlockMode _readMode() {
    if (core.settings.getUnlockWithZwift()) return _UnlockMode.zwift;
    if (core.settings.getClickV2RightSideOnly()) return _UnlockMode.rightSideOnly;
    return _UnlockMode.restart;
  }

  /// Whether the puck that unlock-with-Zwift actually unlocks is here. Only a
  /// connected one can be unlocked — [ZwiftClickV2.unlockWarnings], which is
  /// where the "unlock now" action lives, renders nothing without it — and the
  /// right puck never carries that action at all. So when it's missing the
  /// rider is told where unlocking happens rather than shown an empty card.
  bool get _hasConnectedLeftSide => core.connection.devices.whereType<ZwiftClickV2>().any((d) => d.isConnected);

  @override
  Widget build(BuildContext context) {
    final showsUnlockAction = _mode == _UnlockMode.zwift && _hasConnectedLeftSide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          children: [
            Text(context.i18n.unlock_mode).small.semiBold,
            BkIconButton.link(
              icon: Icon(Icons.help_outline),
              label: context.i18n.a11yHelp,
              onPressed: () {
                launchUrlString('https://bikecontrol.app/blog/zwift-click-v2-with-other-trainer-apps');
              },
            ),
            const Spacer(),
            // The explainer that introduced these modes stays reachable after
            // onboarding, so the trade-offs can be re-read later.
            Button.ghost(
              onPressed: () async {
                await context.push(const ClickV2OnboardingPage());
                if (!mounted) return;
                // The page writes the settings directly, so re-read them: the
                // name below and the gated children have to follow the choice.
                setState(() => _mode = _readMode());
              },
              child: Text(context.i18n.clickV2Onboarding_setUpAgain).xSmall,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_mode.title(context)).small,
            Text(_mode.description(context)).xSmall.muted,
          ],
        ),

        if (_mode == _UnlockMode.zwift) ...[
          if (showsUnlockAction)
            ...widget.children
          else
            Text(context.i18n.unlock_zwiftNeedsLeftSide).xSmall.muted,
        ],
      ],
    );
  }
}

/// The three states a Click V2 setup can rest in. Kept here rather than read ad
/// hoc from settings so every card names the same mode the same way.
enum _UnlockMode {
  /// Both pucks, re-unlocked through Zwift every 24 hours.
  zwift,

  /// The right puck alone — nothing to unlock, ever.
  rightSideOnly,

  /// The legacy workaround: the left puck reboots itself every minute.
  restart;

  String title(BuildContext context) => switch (this) {
    _UnlockMode.zwift => context.i18n.unlock_modeZwift,
    _UnlockMode.rightSideOnly => context.i18n.clickV2Onboarding_rightOnlyTitle,
    _UnlockMode.restart => context.i18n.unlock_modeRestart,
  };

  String description(BuildContext context) => switch (this) {
    _UnlockMode.zwift => context.i18n.unlock_modeZwiftDescription,
    _UnlockMode.rightSideOnly => context.i18n.clickV2Onboarding_rightOnlyRecap,
    _UnlockMode.restart => context.i18n.unlock_modeRestartDescription,
  };
}
