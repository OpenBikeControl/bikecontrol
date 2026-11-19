import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/steps/step_controller.dart';
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_group_label.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_headline.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_note.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/pages/onboarding/widgets/vs_stage.dart';
import 'package:bike_control/pages/onboarding/zwift_controller_expectation.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/home/your_buttons.dart' show ControllerPress;
import 'package:bike_control/widgets/ignored_devices_nearby_hint.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart' show BkIconTile;
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/devices/trainer_metrics_strip.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The trainer the gear step's primary button connects: the only one found
/// that isn't bridged or connecting yet. Null with none — or with several,
/// where the rider picks one in the list.
ProxyDevice? onboardingGearTrainerToConnect(List<ProxyDevice> trainers) {
  if (trainers.any((t) => t.isBridged || t.isStarting.value)) return null;
  return trainers.length == 1 ? trainers.single : null;
}

/// Step 2: the controller and the smart trainer on one screen. Connecting the
/// trainer through BikeControl is the way this step expects to be left —
/// virtual shifting is shown, not listed, right under it, and skipping is the
/// footer's text link.
///
/// [controllerPhase] is never [ControllerPhase.permission] here: that phase
/// is its own screen (see [onboardingControllerBody]).
Widget onboardingGearBody(
  BuildContext context, {
  required ControllerPhase controllerPhase,
  required List<BaseDevice> controllers,
  required SupportedApp app,
  required List<ProxyDevice> trainers,
  required void Function(ProxyDevice) onPickTrainer,
  VoidCallback? onRescanTrainers,
  VoidCallback? onScanControllersAgain,
  Map<String, ControllerButton> pressedButtons = const {},
  Map<String, int> pressGenerations = const {},
  Map<String, ValueListenable<ControllerPress>> presses = const {},
  void Function(BaseDevice)? onSetupDevice,
  VoidCallback? onUpdate,
  bool virtualShiftingBlocked = false,
  bool needsSecondDevice = false,
  int? vsDailyMinutesWithoutPro,
}) {
  final bridged = trainers.any((t) => t.isBridged);
  final zwiftExpectation = zwiftControllerExpectation(devices: controllers, app: app);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: onboardingReveal([
      OnboardingHeadline(context.i18n.onboardingGearTitle),
      Gap(6),
      Text(context.i18n.onboardingGearSubtitle).small.muted,
      Gap(18),
      OnboardingGroupLabel(context.i18n.onboardingStepController),
      ..._controllerSection(
        context,
        phase: controllerPhase,
        controllers: controllers,
        pressedButtons: pressedButtons,
        pressGenerations: pressGenerations,
        presses: presses,
        onSetupDevice: onSetupDevice,
        onScanAgain: onScanControllersAgain,
        onUpdate: onUpdate,
      ),
      Gap(10),
      OnboardingGroupLabel(context.i18n.smartTrainer, trailing: const ProBadge()),
      if (!bridged && virtualShiftingBlocked)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: onboardingVsBlockedDetails(context, app))
      else ...[
        if (needsSecondDevice && !bridged) ...[onboardingSecondDeviceWarning(context, app), Gap(12)],
        _TrainerCard(trainers: trainers, onPick: onPickTrainer, onRescan: onRescanTrainers),
        if (!bridged && vsDailyMinutesWithoutPro != null) ...[
          Gap(10),
          Text(
            context.i18n.onboardingVsDailyWithoutPro('$vsDailyMinutesWithoutPro'),
            textAlign: TextAlign.center,
          ).xSmall.muted,
        ],
      ],
      // A Zwift-made controller works best in Zwift. Say what it can do in
      // the app the rider picked — after the trainer, which is this step's job.
      if (zwiftExpectation != null) ...[
        Gap(16),
        OnboardingNote(zwiftExpectation.text(context.i18n, deviceName: zwiftExpectation.device.displayName(context))),
      ],
    ]),
  );
}

List<Widget> _controllerSection(
  BuildContext context, {
  required ControllerPhase phase,
  required List<BaseDevice> controllers,
  required Map<String, ControllerButton> pressedButtons,
  required Map<String, int> pressGenerations,
  required Map<String, ValueListenable<ControllerPress>> presses,
  void Function(BaseDevice)? onSetupDevice,
  VoidCallback? onScanAgain,
  VoidCallback? onUpdate,
}) {
  if (controllers.isEmpty) {
    return [_NoController(empty: phase == ControllerPhase.empty, onScanAgain: onScanAgain)];
  }
  return [
    for (final d in controllers)
      if (d.isConnected && d.controllerLayout != null && !onboardingDeviceNeedsSetup(d))
        onboardingControllerCompactCard(
          context,
          d,
          pressedButtons: pressedButtons,
          pressGenerations: pressGenerations,
          presses: presses[d.uniqueId],
          onUpdate: onUpdate,
        )
      else
        onboardingDeviceRow(
          context,
          d,
          needsSetup: onboardingDeviceNeedsSetup(d),
          onSetup: onSetupDevice == null ? null : () => onSetupDevice(d),
        ),
  ];
}

/// No controller yet: still looking, or the scan came back empty. The tips
/// for the empty case fold away under "Can't find your controller?" — open,
/// they pushed the trainer card far below the fold.
class _NoController extends StatefulWidget {
  const _NoController({required this.empty, this.onScanAgain});

  final bool empty;
  final VoidCallback? onScanAgain;

  @override
  State<_NoController> createState() => _NoControllerState();
}

class _NoControllerState extends State<_NoController> {
  bool _tips = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = widget.empty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: ValueKey('onboarding-controller-${empty ? 'empty' : 'scanning'}'),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              empty
                  ? const BkIconTile(icon: LucideIcons.searchX)
                  : const SizedBox(width: 40, height: 40, child: Center(child: CircularProgressIndicator(size: 20))),
              Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(empty ? context.i18n.onboardingScanEmptyTitle : context.i18n.onboardingScanTitle)
                        .small
                        .semiBold,
                    Text(context.i18n.onboardingScanSubtitle).xSmall.muted,
                  ],
                ),
              ),
              if (empty && widget.onScanAgain != null) ...[
                Gap(8),
                Button.outline(
                  style: ButtonStyle.outline(size: ButtonSize.small),
                  onPressed: widget.onScanAgain,
                  child: Text(context.i18n.onboardingScanAgain),
                ),
              ],
            ],
          ),
        ),
        // The controller may be here and simply on the ignore list.
        const IgnoredDevicesNearbyHint(padding: EdgeInsets.only(top: 10)),
        if (empty) ...[
          Button.ghost(
            key: const ValueKey('onboarding-controller-tips'),
            style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4)),
            onPressed: () => setState(() => _tips = !_tips),
            child: Row(
              children: [
                Expanded(child: Text(context.i18n.onboardingCantFindController).small.semiBold),
                Icon(_tips ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 15),
              ],
            ),
          ),
          if (_tips) ...[Gap(4), ...onboardingControllerTips(context)],
        ],
      ],
    );
  }
}

/// The trainer card: the scan or the trainers it found, and — until one is
/// connected — what BikeControl's virtual shifting does, drawn right on the
/// card.
class _TrainerCard extends StatelessWidget {
  const _TrainerCard({required this.trainers, required this.onPick, this.onRescan});

  final List<ProxyDevice> trainers;
  final void Function(ProxyDevice) onPick;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bridged = trainers.any((t) => t.isBridged);
    final divider = BoxDecoration(border: Border(top: BorderSide(color: cs.border)));
    return Container(
      key: const ValueKey('onboarding-trainer-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trainers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  const OnboardingTrainerRadar(),
                  Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.i18n.lookingForSmartTrainers).small.semiBold,
                        Text(context.i18n.onboardingTrainerWakeHint).xSmall.muted,
                      ],
                    ),
                  ),
                  if (onRescan != null)
                    BkIconButton.ghost(
                      icon: Icon(LucideIcons.refreshCw, size: 15),
                      label: context.i18n.a11yRefresh,
                      onPressed: onRescan,
                    ),
                ],
              ),
            ),
          for (final (i, t) in trainers.indexed) ...[
            Container(
              decoration: i == 0 ? null : divider,
              child: _TrainerRow(trainer: t, onPick: onPick),
            ),
            // Connected: its live numbers, so the rider sees it working (and
            // the gear) before going on.
            if (t.isBridged)
              ValueListenableBuilder<FitnessBikeDefinition?>(
                valueListenable: t.fitnessBikeListenable,
                builder: (context, definition, _) => definition == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey('onboarding-trainer-metrics-${t.uniqueId}'),
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: TrainerMetricsStrip(definition: definition),
                      ),
              ),
          ],
          if (!bridged)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              decoration: divider,
              child: VirtualShiftingStage(
                flat: true,
                zwiftReadyNearby: trainers.any((t) => onboardingAdvertisesZwiftService(t.scanResult.services)),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrainerRow extends StatelessWidget {
  const _TrainerRow({required this.trainer, required this.onPick});

  final ProxyDevice trainer;
  final void Function(ProxyDevice) onPick;

  @override
  Widget build(BuildContext context) {
    final t = trainer;
    final status = BkStatusColors.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: t.isStarting,
      builder: (context, starting, _) => Padding(
        key: ValueKey('onboarding-trainer-${t.uniqueId}'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            BkIconTile(icon: onboardingTrainerIcon(t), color: t.isBridged ? status.success : null),
            Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, maxLines: 2, overflow: TextOverflow.ellipsis).small.semiBold,
                  Text(
                    t.isBridged
                        ? context.i18n.onboardingTrainerVsByBikeControl
                        : onboardingTrainerSubtitleFor(context, t),
                  ).xSmall.muted,
                ],
              ),
            ),
            Gap(10),
            if (t.isBridged)
              BkStatusDot(label: context.i18n.onboardingDeviceConnected)
            else if (starting) ...[
              Text(context.i18n.onboardingDeviceConnecting).xSmall.muted,
              Gap(8),
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(size: 16)),
            ] else
              BkPillButton(expand: false, onPressed: () => onPick(t), child: Text(context.i18n.connect)),
          ],
        ),
      ),
    );
  }
}
