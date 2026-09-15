import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/pages/onboarding/onboarding_app_guides.dart';
import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/pages/onboarding/steps/step_trainer.dart';
import 'package:bike_control/utils/trainer_connect.dart';
import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:bike_control/pages/onboarding/onboarding_sheets.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/guided_operation_sheet.dart';
import 'package:bike_control/widgets/scan.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The instruction sheets a chain card's active step opens.
///
/// These deliberately route into content that already exists — the onboarding
/// help sheets and the per-app setup guides — rather than growing a second,
/// parallel help system that would drift out of sync with the first.

Widget _frame(BuildContext context, Widget child) {
  return Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  );
}

/// Pairing a controller for the first time. The scanner is embedded rather than
/// described, so the next action is on screen instead of a page away.
Future<void> openControllerSetupSheet(BuildContext context) {
  return openSheet<void>(
    context: context,
    position: OverlayPosition.bottom,
    builder: (sheetContext) => _frame(
      sheetContext,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StageBadge(
            icon: LucideIcons.bluetooth,
            tone: Theme.of(sheetContext).colorScheme.primary,
            wash: Theme.of(sheetContext).colorScheme.primary.withValues(alpha: 0.1),
            reduceMotion: MediaQuery.of(sheetContext).disableAnimations,
          ),
          const Gap(14),
          Text(sheetContext.i18n.connectControllers).h4,
          const Gap(6),
          Text(sheetContext.i18n.chainStepControllerPairedHint).small.muted,
          const Gap(14),
          const ScanWidget(),
          const Gap(14),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              onPressed: () => closeSheet(sheetContext),
              child: Text(sheetContext.i18n.close),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Get your controller back" — the reconnect checklist. Routed on the card's
/// state, never on step wording, so a never-paired controller gets the pairing
/// flow above and a dropped one gets this.
Future<void> openControllerHelpSheet(BuildContext context) {
  return openOnboardingHelpSheet(context, OnboardingStep.controller);
}

Future<void> openTrainerHelpSheet(BuildContext context) {
  return openOnboardingHelpSheet(context, OnboardingStep.virtualShifting);
}

/// The per-app "then in {app}" guide — the same numbered steps, screenshots and
/// guide link the onboarding connection step shows. Falls back to the generic
/// connection help when no app has been chosen yet.
Future<void> openAppGuideSheet(BuildContext context) {
  final app = core.settings.getTrainerApp();
  if (app == null) return openOnboardingHelpSheet(context, OnboardingStep.connection);

  return openSheet<void>(
    context: context,
    position: OverlayPosition.bottom,
    builder: (sheetContext) => _frame(sheetContext, _AppGuide(app: app)),
  );
}

class _AppGuide extends StatelessWidget {
  const _AppGuide({required this.app});

  final SupportedApp app;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StageBadge(
          icon: LucideIcons.monitor,
          tone: scheme.primary,
          wash: scheme.primary.withValues(alpha: 0.1),
          reduceMotion: MediaQuery.of(context).disableAnimations,
        ),
        const Gap(14),
        Text(context.i18n.onboardingThenInApp(app.name)).h4,
        const Gap(12),
        // The very card the wizard showed during setup — same numbered steps,
        // same screenshots, same link. A rider who lost the connection should
        // not be handed a different, thinner set of instructions than the ones
        // that got them connected in the first place.
        OnboardingAppGuideCard(app: app, bordered: false),
        const Gap(16),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            onPressed: () => closeSheet(context),
            child: Text(context.i18n.close),
          ),
        ),
      ],
    );
  }
}

/// "Pair BikeControl as your trainer" — shown when the bridge is running but the
/// trainer app hasn't picked the virtual trainer up yet. That is a different
/// problem from "no trainer connected", and it wants the onboarding connection
/// step's pairing instructions, not the trainer picker.
Future<void> openPairAsTrainerSheet(BuildContext context, {required String? trainerName}) {
  final app = core.settings.getTrainerApp();
  if (app == null) return openOnboardingHelpSheet(context, OnboardingStep.connection);

  return openSheet<void>(
    context: context,
    position: OverlayPosition.bottom,
    builder: (sheetContext) => _frame(
      sheetContext,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StageBadge(
            icon: LucideIcons.radio,
            tone: Theme.of(sheetContext).colorScheme.primary,
            wash: Theme.of(sheetContext).colorScheme.primary.withValues(alpha: 0.1),
            reduceMotion: MediaQuery.of(sheetContext).disableAnimations,
          ),
          const Gap(14),
          Text(sheetContext.i18n.onboardingPairAsTrainer).h4,
          const Gap(12),
          OnboardingPairAsTrainerCard(app: app, trainerName: trainerName),
          const Gap(16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              onPressed: () => closeSheet(sheetContext),
              child: Text(sheetContext.i18n.close),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Picking a smart trainer to bridge — the onboarding trainer step, reached
/// from the home screen's trainer card. Riders who skipped the trainer during
/// setup, or bought one later, get the same list and the same explanation of
/// what bridging buys them.
///
/// The picker deliberately does not require a trainer app: a rider who skipped
/// onboarding has none selected yet, but the trainer card already lists a
/// discovered trainer with a Connect button — that tap must open the list,
/// not a generic help sheet. The app only refines the copy (next-step note,
/// MyWhoosh-on-Android caveat), so it is passed through as optional.
Future<void> openTrainerConnectSheet(BuildContext context) {
  return openSheet<void>(
    context: context,
    position: OverlayPosition.bottom,
    builder: (sheetContext) => _frame(sheetContext, _TrainerPicker(app: core.settings.getTrainerApp())),
  );
}

class _TrainerPicker extends StatefulWidget {
  const _TrainerPicker({required this.app});

  final SupportedApp? app;

  @override
  State<_TrainerPicker> createState() => _TrainerPickerState();
}

class _TrainerPickerState extends State<_TrainerPicker> {
  StreamSubscription<BaseDevice>? _connectionListener;

  @override
  void initState() {
    super.initState();
    // The list is live: a trainer that wakes up mid-sheet should appear, and
    // one that finishes connecting should flip to its connected state without
    // the rider closing and reopening the sheet.
    _connectionListener = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        onboardingTrainerBody(
          context,
          app: app,
          trainers: core.connection.proxyDevices,
          onPick: (device) async {
            await connectTrainerFromPicker(context, device);
            if (mounted) setState(() {});
          },
          onRescan: () {
            core.connection.performScanning();
            setState(() {});
          },
          // The block is a MyWhoosh-specific caveat — with no app chosen yet
          // there is nothing to block on.
          virtualShiftingBlocked: app != null && onboardingVirtualShiftingBlocked(app),
        ),
        const Gap(16),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            onPressed: () => closeSheet(context),
            child: Text(context.i18n.close),
          ),
        ),
      ],
    );
  }
}
