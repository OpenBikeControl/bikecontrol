import 'package:bike_control/pages/onboarding/widgets/onboarding_headline.dart';
import 'dart:async';

import 'package:bike_control/pages/onboarding/onboarding_app_guides.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Where the done step stands, in the order a rider has to fix things.
enum OnboardingDoneState {
  /// Something can shift: controller paired, app connected, and a bridged
  /// trainer (if any) picked up by the app.
  ready,

  /// The app (and any trainer) is fine; only the controller is missing.
  noController,

  /// The trainer app hasn't connected to BikeControl yet.
  waitingForApp,

  /// The trainer app is connected, but hasn't picked up the bridged trainer.
  waitingForTrainerPickup,
}

OnboardingDoneState onboardingDoneState({
  required bool hasController,
  required bool appConnected,
  required bool hasTrainer,
  required bool trainerAppConnected,
}) {
  if (!appConnected) return OnboardingDoneState.waitingForApp;
  if (hasTrainer && !trainerAppConnected) return OnboardingDoneState.waitingForTrainerPickup;
  if (!hasController) return OnboardingDoneState.noController;
  return OnboardingDoneState.ready;
}

/// The done step's footer. Starting to ride is the primary action — the rider
/// just finished setting up, and the plan options are there for when they
/// want them, not in the way of the one thing they came to do.
List<Widget> onboardingDoneFooter(
  BuildContext context, {
  required OnboardingDoneState state,
  required bool showPlanOptions,
  required VoidCallback onStartRiding,
  required VoidCallback onSeePlanOptions,
}) => [
  PrimaryButton(
    alignment: Alignment.center,
    onPressed: onStartRiding,
    child: Text(switch (state) {
      OnboardingDoneState.ready => context.i18n.onboardingDoneStartRiding,
      OnboardingDoneState.noController => context.i18n.onboardingDonePairLater,
      OnboardingDoneState.waitingForApp ||
      OnboardingDoneState.waitingForTrainerPickup => context.i18n.onboardingDoneFinishLater,
    }),
  ),
  if (showPlanOptions)
    GhostButton(
      alignment: Alignment.center,
      onPressed: onSeePlanOptions,
      child: Text(context.i18n.onboardingSeeProOptions),
    ),
];

/// Ready means something can actually shift: a controller is paired, the
/// trainer app is connected, and a bridged trainer has been picked up.
bool onboardingDoneReady({
  required bool hasController,
  required bool appConnected,
  required bool hasTrainer,
  required bool trainerAppConnected,
}) =>
    onboardingDoneState(
      hasController: hasController,
      appConnected: appConnected,
      hasTrainer: hasTrainer,
      trainerAppConnected: trainerAppConnected,
    ) ==
    OnboardingDoneState.ready;

/// Whether the done step offers the gear overlay: the app draws its own gear
/// number, a bridged trainer is held by the app, the overlay can be shown
/// here ([overlayOffered]: platform, same device, a virtual-shifting
/// session), and the rider hasn't already turned it on or declined it.
bool onboardingDoneOffersOverlay({
  required SupportedApp app,
  required bool trainerBridged,
  required bool trainerAppConnected,
  required bool overlayOffered,
  required bool overlayEnabled,
  required bool overlayDeclined,
}) =>
    app.showsOwnGear &&
    trainerBridged &&
    trainerAppConnected &&
    overlayOffered &&
    !overlayEnabled &&
    !overlayDeclined;

Widget onboardingDoneBody(
  BuildContext context, {
  required SupportedApp app,
  required String? controllerName,
  required String? trainerName,
  required bool appConnected,
  required bool trainerAppConnected,
  required bool reduceMotion,
  required bool showTestMode,
  VoidCallback? onPairController,
  VoidCallback? onRunTrainerCheck,
  bool waitingOnNetworkMethod = false,
  VoidCallback? onTestNetwork,
  bool offerOverlay = false,
  VoidCallback? onShowOverlay,
}) {
  final hasController = controllerName != null;
  final state = onboardingDoneState(
    hasController: hasController,
    appConnected: appConnected,
    hasTrainer: trainerName != null,
    trainerAppConnected: trainerAppConnected,
  );
  final allReady = state == OnboardingDoneState.ready;
  final title = switch (state) {
    OnboardingDoneState.ready => context.i18n.onboardingDoneTitle,
    OnboardingDoneState.noController => context.i18n.onboardingDoneNoControllerTitle,
    OnboardingDoneState.waitingForApp => context.i18n.onboardingAlmostThereTitle,
    OnboardingDoneState.waitingForTrainerPickup => context.i18n.onboardingDonePickTrainerTitle,
  };
  final subtitle = switch (state) {
    OnboardingDoneState.ready =>
      trainerName != null
          ? context.i18n.onboardingDoneSubtitleBridged(controllerName!, app.name)
          : context.i18n.onboardingDoneSubtitle(controllerName!, app.name),
    OnboardingDoneState.noController => context.i18n.onboardingDoneNoControllerSubtitle(app.name),
    OnboardingDoneState.waitingForApp => context.i18n.onboardingAlmostThereSubtitle(app.name),
    OnboardingDoneState.waitingForTrainerPickup => context.i18n.onboardingDonePickTrainerSubtitle(app.name),
  };
  // (icon, title, status, ok, action) — a bridge whose virtual trainer the app
  // hasn't picked up yet is honest about it instead of claiming "Bridged".
  final rows = <(IconData, String, String, bool, Widget?)>[
    hasController
        ? (LucideIcons.gamepad2, controllerName, context.i18n.onboardingDeviceConnected, true, null)
        : (
            LucideIcons.gamepad2,
            context.i18n.onboardingYourController,
            context.i18n.onboardingSummaryNotPaired,
            false,
            onPairController == null
                ? null
                : Button.outline(
                    key: const ValueKey('onboarding-done-pair-controller'),
                    style: ButtonStyle.outline(size: ButtonSize.small),
                    onPressed: onPairController,
                    child: Text(context.i18n.onboardingPairControllerAction),
                  ),
          ),
    appConnected
        ? (LucideIcons.monitor, app.name, context.i18n.onboardingDeviceConnected, true, null)
        : (LucideIcons.monitor, app.name, context.i18n.onboardingSummaryWaitingFor(app.name), false, null),
    if (trainerName != null)
      trainerAppConnected
          ? (LucideIcons.bike, trainerName, context.i18n.onboardingSummaryTrainerInApp(app.name), true, null)
          : (LucideIcons.bike, trainerName, context.i18n.onboardingSummaryWaitingFor(app.name), false, null),
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: onboardingReveal([
      Gap(24),
      _SuccessBurst(reduceMotion: reduceMotion, ready: allReady),
      Gap(24),
      OnboardingHeadline(title, textAlign: TextAlign.center),
      Gap(8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(subtitle, textAlign: TextAlign.center).small.muted,
      ),
      Gap(28),
      BkGroupedSection(
        children: [
          for (final (icon, title, sub, ok, action) in rows)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    BkIconTile(icon: icon),
                    Gap(12),
                    Expanded(flex: 3, child: Text(title).small.semiBold),
                    Gap(8),
                    // Flexible so a long "Waiting for {app}…" or the Pair
                    // button can't push the name off.
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: BkStatusDot(label: sub, tone: ok ? BkStatusTone.success : BkStatusTone.neutral),
                      ),
                    ),
                    if (action != null) ...[Gap(10), action],
                  ],
                ),
              ),
            ),
        ],
      ),
      Gap(4),
      // The check needs the app to hold the trainer; until then it would
      // only report what the pickup card below already says.
      if (onRunTrainerCheck != null && trainerName != null && trainerAppConnected)
        Align(
          alignment: Alignment.centerLeft,
          child: Button.ghost(
            key: const ValueKey('onboarding-done-trainer-check'),
            onPressed: onRunTrainerCheck,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.activity, size: 15),
                Gap(8),
                Flexible(child: Text(context.i18n.onboardingRunTrainerCheck).small),
                Gap(4),
                Icon(LucideIcons.chevronRight, size: 14),
              ],
            ),
          ),
        ),
      if (offerOverlay && onShowOverlay != null) ...[
        Gap(10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.layers, size: 17, color: Theme.of(context).colorScheme.primary),
                  Gap(10),
                  Expanded(child: Text(context.i18n.onboardingDoneOverlayNote(app.name)).small),
                ],
              ),
              Gap(10),
              Button.outline(
                key: const ValueKey('onboarding-done-show-overlay'),
                onPressed: onShowOverlay,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.layers, size: 15),
                    Gap(8),
                    Flexible(child: Text(context.i18n.onboardingDoneShowOverlay).small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      // Waiting on the app: show what to do in it, right here — the previous
      // page with these steps is no longer on screen.
      if (!appConnected) ...[
        Gap(10),
        OnboardingAppGuideCard(app: app),
        if (waitingOnNetworkMethod && onTestNetwork != null)
          _StillWaitingNetworkHint(reduceMotion: reduceMotion, onTestNetwork: onTestNetwork),
      ],
      // The app is connected but still on the bare trainer (or none): show
      // which entry to pick in its trainer selection.
      if (state == OnboardingDoneState.waitingForTrainerPickup) ...[
        Gap(10),
        OnboardingPairAsTrainerCard(app: app, trainerName: trainerName),
      ],
      if (showTestMode) ...[
        Gap(10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BkIconTile(icon: LucideIcons.clock, color: bkAccentText(context)),
              Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.i18n.onboardingTestModeTitle).small.semiBold,
                    Gap(4),
                    Text(
                      trainerName != null
                          ? context.i18n.onboardingTestModeBodyVs(
                              '${IAPManager.dailyCommandLimit}',
                              '${core.bridgeUsageTracker.dailyLimit.inMinutes}',
                            )
                          : context.i18n.onboardingTestModeBody('${IAPManager.dailyCommandLimit}'),
                    ).xSmall.muted,
                    Gap(6),
                    // What the rider would pay for, given what they set up: the
                    // trainer bridge is BikeControl's virtual shifting (Pro
                    // only); without one, the trial's limit is the daily
                    // command budget, which Base lifts as well.
                    Text(
                      trainerName != null ? context.i18n.onboardingTrialKeepVs : context.i18n.onboardingTrialUnlimited,
                    ).xSmall.semiBold,
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ]),
  );
}

/// "Still not connected? Test your network" — held back for
/// [stillWaitingDelay] so it doesn't suggest something is wrong while the
/// rider is still working through the steps in their app.
const Duration stillWaitingDelay = Duration(seconds: 30);

class _StillWaitingNetworkHint extends StatefulWidget {
  const _StillWaitingNetworkHint({required this.reduceMotion, required this.onTestNetwork});

  final bool reduceMotion;
  final VoidCallback onTestNetwork;

  @override
  State<_StillWaitingNetworkHint> createState() => _StillWaitingNetworkHintState();
}

class _StillWaitingNetworkHintState extends State<_StillWaitingNetworkHint> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(stillWaitingDelay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _show
        ? Padding(
            key: const ValueKey('still-waiting-shown'),
            padding: const EdgeInsets.only(top: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Button.outline(
                key: const ValueKey('onboarding-done-test-network'),
                onPressed: widget.onTestNetwork,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.radioTower, size: 15),
                    Gap(8),
                    Flexible(child: Text(context.i18n.onboardingStillNotConnected).small),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink(key: ValueKey('still-waiting-hidden'));
    return AnimatedSwitcher(
      duration: widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      child: child,
    );
  }
}

/// Green success circle shown at the top of the "done" step. Pops in with a
/// spring-like scale (mirrors [StageBadge] in `guided_operation_sheet.dart`)
/// unless [reduceMotion] is set, in which case it renders statically.
class _SuccessBurst extends StatelessWidget {
  const _SuccessBurst({required this.reduceMotion, this.ready = true});
  final bool reduceMotion;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    // Contrast-pinned status fills, with their own glyph colour on top.
    final status = BkStatusColors.of(context);
    final color = ready ? status.success : status.warning;
    final glyph = ready ? status.successForeground : status.warningForeground;
    final badge = Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Icon(ready ? LucideIcons.check : LucideIcons.clock, size: 44, color: glyph),
    );
    if (reduceMotion) return badge;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: badge,
    );
  }
}
