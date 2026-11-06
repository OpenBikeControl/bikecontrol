/// The rules of the daily virtual shifting trial, as pure functions.
///
/// Without Pro, BikeControl's own virtual shifting runs for a daily budget
/// (see `BridgeUsageTracker`). When it runs out, BikeControl stops
/// advertising the trainer: a trainer app already connected keeps its
/// connection — the ride goes on — but once it lets go it cannot find the
/// trainer through BikeControl again until tomorrow.
library;

import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;

/// How long before the budget runs out the rider hears about it.
const Duration vsTrialHeadsUp = Duration(minutes: 2);

/// Whether today's trial is over for a trainer shifting in [mode]. Only
/// BikeControl's own virtual shifting counts against the budget; with the
/// trainer app doing the shifting itself ([RetrofitMode.proxy]) or with Pro,
/// there is no trial to be over.
bool vsTrialOver({required RetrofitMode mode, required bool isPro, required bool exhausted}) {
  if (mode == RetrofitMode.proxy) return false;
  if (isPro) return false;
  return exhausted;
}

/// Whether to tell the rider that today's trial is about to end: once, with
/// [vsTrialHeadsUp] or less left, and not when it is already over — that has
/// its own message.
bool vsTrialEndingSoon({required Duration remaining, required bool alreadyWarned}) {
  if (alreadyWarned) return false;
  return remaining > Duration.zero && remaining <= vsTrialHeadsUp;
}

/// What happens when a rider connects a trainer in a given mode.
enum TrainerConnectGate {
  /// Go ahead and connect.
  allow,

  /// Locked: offer Pro.
  goPro,

  /// Today's virtual shifting trial is used up: say so, and offer Pro.
  vsTrialOverToday,
}

/// Whether a rider may connect a trainer in [mode].
///
/// Virtual shifting ([RetrofitMode.wifi] / [RetrofitMode.bluetooth]) runs on
/// the daily trial for everyone without Pro — within the trial period, after
/// it, and with Base — until [vsBudgetExhausted]. Proxy mode needs Pro once
/// the trial period is over ([trialExpired]).
TrainerConnectGate trainerConnectGate({
  required RetrofitMode mode,
  required bool isPro,
  required bool trialExpired,
  required bool vsBudgetExhausted,
}) {
  if (isPro) return TrainerConnectGate.allow;
  if (mode == RetrofitMode.proxy) {
    return trialExpired ? TrainerConnectGate.goPro : TrainerConnectGate.allow;
  }
  return vsBudgetExhausted ? TrainerConnectGate.vsTrialOverToday : TrainerConnectGate.allow;
}
