/// Which help-center answer, if any, matches a support-intake choice. The
/// intake form shows it inline before the composer: a good share of chats ask
/// questions the help center already answers.
library;

import 'intake_options.dart';

enum IntakeSelfHelp {
  /// "My controller isn't found".
  controllerNotFound,

  /// "My controller keeps disconnecting".
  controllerDisconnecting,

  /// "Shifting works, but the gear doesn't change" — plus the network test.
  trainerAppGear,

  /// "BikeControl shifts, the app doesn't react": the connection check
  /// first, the gear display second.
  appNotReacting,

  /// The trainer app can't find or reach BikeControl: the network test.
  networkTest,

  /// Resistance or shifting feels wrong on a bridged trainer: the self-test.
  trainerSelfTest,

  /// Paid, but the app still shows Base or the daily virtual-shifting trial:
  /// what Base and Pro cover, and how Pro gets active on this device.
  planNotActive,

  /// Restore purchases doesn't bring a purchase back: the right store
  /// account, signing in for Pro, and that Base stays with its store.
  purchaseNotRestored,

  /// A refund: the store it was bought in handles it.
  refundThroughStore,
}

IntakeSelfHelp? intakeSelfHelpFor(IntakeAnswers answers) => switch (answers.category) {
  IntakeCategory.controller => switch (answers.symptom) {
    'no_pairing' => IntakeSelfHelp.controllerNotFound,
    'dropouts' => IntakeSelfHelp.controllerDisconnecting,
    _ => null,
  },
  IntakeCategory.trainerApp => switch (answers.symptom) {
    'shifts_not_recognized' => IntakeSelfHelp.appNotReacting,
    'gear_indicator_not_updating' => IntakeSelfHelp.trainerAppGear,
    'network_bridge_fails' || 'no_pairing' => IntakeSelfHelp.networkTest,
    _ => null,
  },
  // The smart-trainer branch carries its symptom in subcategoryValue.
  IntakeCategory.smartTrainer => switch (answers.subcategoryValue) {
    'no_resistance_change' || 'wrong_resistance' || 'gear_shift_not_working' => IntakeSelfHelp.trainerSelfTest,
    _ => null,
  },
  // The account branch, like the smart-trainer one, uses subcategoryValue.
  IntakeCategory.account => switch (answers.subcategoryValue) {
    'wrong_plan_shown' || 'trial_expired_after_purchase' => IntakeSelfHelp.planNotActive,
    'purchase_not_restored' => IntakeSelfHelp.purchaseNotRestored,
    'refund_request' => IntakeSelfHelp.refundThroughStore,
    _ => null,
  },
  IntakeCategory.somethingElse => null,
};
