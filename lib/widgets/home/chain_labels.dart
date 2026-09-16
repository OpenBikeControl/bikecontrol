import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A checklist step's words.
///
/// Steps read differently depending on whether they are done: a finished step
/// states a fact ("Paired over Bluetooth"), an unfinished one asks for
/// something ("Find your controller"). Keeping both wordings against one
/// [SetupStepId] means the chain model never has to carry sentences, and the
/// rider never reads an instruction for something they have already done.
class ChainStepText {
  const ChainStepText(this.label, [this.hint]);

  final String label;
  final String? hint;
}

ChainStepText chainStepText(BuildContext context, SetupStep step, {String? appName}) {
  final l = context.i18n;
  final app = appName ?? l.chainAppTitle;

  return switch (step.id) {
    SetupStepId.controllerBluetoothReady => step.done
        ? ChainStepText(l.chainStepBluetoothReady)
        : ChainStepText(l.chainStepBluetoothReadyPending, l.chainStepBluetoothReadyHint),
    SetupStepId.controllerPaired => step.done
        ? ChainStepText(l.chainStepControllerPaired)
        : ChainStepText(l.chainStepControllerPairedPending, l.chainStepControllerPairedHint),
    SetupStepId.controllerButtonsMapped => step.done
        ? ChainStepText(l.chainStepButtonsMapped)
        : ChainStepText(l.chainStepButtonsMappedPending, l.chainStepButtonsMappedHint),
    SetupStepId.controllerInRange => step.done
        ? ChainStepText(l.chainStepInRange)
        : ChainStepText(l.chainStepInRangePending, l.chainStepInRangeHint),
    // The one done step that says more than "done". An unlock expires, so the
    // deadline is the useful part — a bare tick would hide the fact that this
    // one comes back tomorrow.
    SetupStepId.controllerUnlocked => step.done
        ? ChainStepText(
            step.hintArg == null
                ? l.chainStepUnlocked
                : step.uncertain
                ? l.chainStepUnlockedLikelyUntil(step.hintArg!)
                : l.chainStepUnlockedUntil(step.hintArg!),
          )
        : ChainStepText(l.chainStepUnlockedPending, l.chainStepUnlockedHint),
    // Only ever emitted while outstanding — once the rider has chosen, the step
    // disappears rather than sitting ticked forever on every Click V2 card.
    SetupStepId.controllerClickV2Setup => ChainStepText(
      l.chainStepClickV2Setup,
      l.chainStepClickV2SetupHint,
    ),
    // Optional, so it is only ever emitted while outstanding — the hint carries
    // the whole point, since "switch the left side on" makes no sense without
    // the reason.
    SetupStepId.controllerClickV2KeepAwake => ChainStepText(
      l.chainStepClickV2KeepAwake,
      l.chainStepClickV2KeepAwakeHint,
    ),
    SetupStepId.controllerSramSetup => step.done
        ? ChainStepText(l.chainStepSramSetup)
        : ChainStepText(l.sramSetup, l.chainStepSramSetupHint),
    // Optional, so it is only ever emitted while outstanding (restore clears the
    // backup, so it can never sit ticked). The hint is the whole offer — that
    // the derailleur's own shifting comes back — since "restore" alone says
    // nothing about what is being restored.
    SetupStepId.controllerSramRestore => ChainStepText(l.sramRestore, l.sramRestoreIntro),
    SetupStepId.trainerPaired => step.done
        ? ChainStepText(l.chainStepTrainerPaired)
        : ChainStepText(l.chainStepTrainerPairedPending),
    // Whether the trainer app has actually picked the bridge up. The hint names
    // the exact entry to look for, which is the thing riders miss.
    SetupStepId.trainerAppBridged => step.done
        ? ChainStepText(l.chainStepTrainerBridged(app))
        : ChainStepText(
            l.chainStepTrainerBridgedPending(app),
            l.chainStepTrainerBridgedHint(step.hintArg ?? 'BikeControl', app),
          ),
    // The hint carries the whole reason this step exists — that the number the
    // trainer app draws is its own, not the one BikeControl computes — so it
    // shows even before the step is the active one.
    SetupStepId.trainerGearOverlay => step.done
        ? ChainStepText(l.chainStepOverlayDone)
        : ChainStepText(l.chainStepOverlay, l.chainStepOverlayHint(app)),
    SetupStepId.appSelected => step.done
        ? ChainStepText(l.chainStepAppSelected)
        : ChainStepText(l.chainStepAppSelectedPending, l.chainStepAppSelectedHint),
    SetupStepId.appConnectionMethod => step.done
        ? ChainStepText(l.chainStepAppConnectionMethod)
        : ChainStepText(l.chainStepAppConnectionMethodPending, l.chainStepAppConnectionMethodHint),
    // The hint carries the whole point: "Local Network" is an OS phrase that
    // says nothing about cycling, and the failure it causes is invisible —
    // the bridge looks switched on and simply never appears.
    SetupStepId.appLocalNetwork => step.done
        ? ChainStepText(l.chainStepAppLocalNetwork)
        : ChainStepText(l.chainStepAppLocalNetworkPending, l.chainStepAppLocalNetworkHint),
    SetupStepId.appConnected => step.done
        ? ChainStepText(l.chainStepAppConnected(app))
        : ChainStepText(l.chainStepAppConnectedPending(app), l.chainStepAppConnectedHint),
    // Like the overlay step, the hint is the offer: "Local control" means
    // nothing on its own, and what it buys — keyboard and mouse actions on a
    // button — is the only reason to read the line at all.
    SetupStepId.appLocalControl => step.done
        ? ChainStepText(l.chainStepLocalControlDone)
        : ChainStepText(l.chainStepLocalControl, l.chainStepLocalControlHint(app)),
  };
}

/// The name the banner uses for a link when it has to talk about it in a
/// sentence — "Controller and Trainer app still need setting up".
String chainLinkName(BuildContext context, ChainLinkKey key) {
  return switch (key) {
    ChainLinkKey.controller => context.i18n.chainControllerTitle,
    ChainLinkKey.trainer => context.i18n.chainTrainerTitle,
    ChainLinkKey.sensors => context.i18n.sensorsChainEyebrow,
    ChainLinkKey.app => context.i18n.chainAppTitle,
  };
}
