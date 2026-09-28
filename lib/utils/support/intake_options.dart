/// Stable IDs for the support-chat intake form.
///
/// These IDs travel from the Flutter form to Supabase (stored as JSONB in
/// `support_messages.intake_answers`) and back from the server when the
/// `issues` table is filtered by `problem_categories` / `problem_subcategories`.
/// The IDs are also referenced by the seed migration
/// `supabase/migrations/20260517070000_seed_intake_help_issues.sql` — keep
/// them in sync.
///
/// **Convention**: trainer-app IDs are the display names exposed by
/// `SupportedApp.name` (e.g. "MyWhoosh", "TrainingPeaks Virtual") because
/// the existing `issues.trainer_apps` filter already uses those values.
/// Controller / smart-trainer / account IDs are stable lowercase snake-case
/// slugs.
library;

import '../../bluetooth/devices/base_device.dart';
import '../../bluetooth/devices/cycplus/cycplus_bc2.dart';
import '../../bluetooth/devices/elite/elite_square.dart';
import '../../bluetooth/devices/elite/elite_sterzo.dart';
import '../../bluetooth/devices/gamepad/gamepad_device.dart';
import '../../bluetooth/devices/gyroscope/gyroscope_steering.dart';
import '../../bluetooth/devices/hid/hid_device.dart';
import '../../bluetooth/devices/shimano/shimano_di2.dart';
import '../../bluetooth/devices/sram/sram_axs.dart';
import '../../bluetooth/devices/thinkrider/thinkrider_vs200.dart';
import '../../bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import '../../bluetooth/devices/zwift/constants.dart';
import '../../bluetooth/devices/zwift/zwift_click.dart';
import '../../bluetooth/devices/zwift/zwift_clickv2.dart';
import '../../bluetooth/devices/zwift/zwift_play.dart';
import '../../bluetooth/devices/zwift/zwift_ride.dart';
import '../../gen/l10n.dart';
import '../keymap/apps/supported_app.dart';

enum IntakeCategory {
  trainerApp('trainer_app'),
  controller('controller'),
  smartTrainer('smart_trainer'),
  account('account'),
  somethingElse('something_else');

  final String id;
  const IntakeCategory(this.id);
}

/// Controller follow-up options ("Which controller?"). The IDs must match the
/// `problem_subcategories` slugs in the seed migration. Only the id is sent;
/// the label shown is [controllerOptionLabel].
class ControllerOption {
  final String id;
  const ControllerOption(this.id);
}

const controllerOptions = <ControllerOption>[
  ControllerOption('zwift_click'),
  ControllerOption('zwift_click_v2'),
  ControllerOption('zwift_play_left'),
  ControllerOption('zwift_play_right'),
  ControllerOption('zwift_ride'),
  ControllerOption('shimano_di2'),
  ControllerOption('sram_axs'),
  ControllerOption('wahoo'),
  ControllerOption('cycplus'),
  ControllerOption('elite'),
  ControllerOption('thinkrider'),
  ControllerOption('gamepad'),
  ControllerOption('hid_keyboard'),
  ControllerOption('gyroscope'),
  ControllerOption('other'),
];

/// The label shown for a controller option. Brand names stay as they are;
/// everything else is localized. Unknown ids are shown as-is.
String controllerOptionLabel(AppLocalizations l, String id) => switch (id) {
  'zwift_click' => 'Zwift Click',
  'zwift_click_v2' => 'Zwift Click V2',
  'zwift_play_left' => l.intakeControllerPlayLeft,
  'zwift_play_right' => l.intakeControllerPlayRight,
  'zwift_ride' => 'Zwift Ride',
  'shimano_di2' => 'Shimano Di2',
  'sram_axs' => 'SRAM AXS',
  'wahoo' => 'Wahoo',
  'cycplus' => 'Cycplus',
  'elite' => 'Elite',
  'thinkrider' => 'ThinkRider',
  'gamepad' => l.intakeControllerGamepad,
  'hid_keyboard' => l.intakeControllerHidKeyboard,
  'gyroscope' => l.intakeControllerGyroscope,
  'other' => l.intakeControllerOther,
  _ => id,
};

/// A "What's happening?" option. Only the id is sent; the label shown is
/// [symptomLabel].
class SymptomOption {
  final String id;
  const SymptomOption(this.id);
}

/// Controller symptom dropdown ("What's happening?").
const controllerSymptoms = <SymptomOption>[
  SymptomOption('no_pairing'),
  SymptomOption('no_response'),
  SymptomOption('buttons_partial'),
  SymptomOption('dropouts'),
  SymptomOption('other'),
];

/// Trainer-app symptom dropdown ("What's happening?").
const trainerAppSymptoms = <SymptomOption>[
  SymptomOption('shifts_not_recognized'),
  SymptomOption('network_bridge_fails'),
  SymptomOption('no_pairing'),
  SymptomOption('gear_indicator_not_updating'),
  SymptomOption('other'),
];

/// Smart trainer symptom dropdown ("What's happening?").
const smartTrainerSymptoms = <SymptomOption>[
  SymptomOption('no_resistance_change'),
  SymptomOption('wrong_resistance'),
  SymptomOption('gear_shift_not_working'),
  SymptomOption('no_pairing'),
  SymptomOption('dropouts'),
  SymptomOption('no_data'),
  SymptomOption('not_supported'),
  SymptomOption('other'),
];

/// Account / purchase follow-up dropdown.
const accountSymptoms = <SymptomOption>[
  SymptomOption('purchase_not_restored'),
  SymptomOption('trial_expired_after_purchase'),
  SymptomOption('wrong_plan_shown'),
  SymptomOption('refund_request'),
  SymptomOption('other'),
];

/// The localized label for a symptom id within [category]. The same id can
/// mean different things per branch ("no_pairing"), hence the category.
/// Unknown ids are shown as-is.
String symptomLabel(AppLocalizations l, IntakeCategory category, String id) {
  if (id == 'other') return l.intakeSomethingElse;
  return switch ((category, id)) {
    (IntakeCategory.controller, 'no_pairing') => l.intakeControllerNoPairing,
    (IntakeCategory.controller, 'no_response') => l.intakeControllerNoResponse,
    (IntakeCategory.controller, 'buttons_partial') => l.intakeControllerButtonsPartial,
    (IntakeCategory.controller, 'dropouts') => l.intakeControllerDropouts,
    (IntakeCategory.trainerApp, 'shifts_not_recognized') => l.intakeAppShiftsNotRecognized,
    (IntakeCategory.trainerApp, 'network_bridge_fails') => l.intakeAppNetworkBridgeFails,
    (IntakeCategory.trainerApp, 'no_pairing') => l.intakeAppNoPairing,
    (IntakeCategory.trainerApp, 'gear_indicator_not_updating') => l.intakeAppGearIndicator,
    (IntakeCategory.smartTrainer, 'no_resistance_change') => l.intakeTrainerNoResistanceChange,
    (IntakeCategory.smartTrainer, 'wrong_resistance') => l.intakeTrainerWrongResistance,
    (IntakeCategory.smartTrainer, 'gear_shift_not_working') => l.intakeTrainerGearShiftNotWorking,
    (IntakeCategory.smartTrainer, 'no_pairing') => l.intakeTrainerNoPairing,
    (IntakeCategory.smartTrainer, 'dropouts') => l.intakeTrainerDropouts,
    (IntakeCategory.smartTrainer, 'no_data') => l.intakeTrainerNoData,
    (IntakeCategory.smartTrainer, 'not_supported') => l.intakeTrainerNotSupported,
    (IntakeCategory.account, 'purchase_not_restored') => l.intakeAccountPurchaseNotRestored,
    (IntakeCategory.account, 'trial_expired_after_purchase') => l.intakeAccountTrialExpiredAfterPurchase,
    (IntakeCategory.account, 'wrong_plan_shown') => l.intakeAccountWrongPlan,
    (IntakeCategory.account, 'refund_request') => l.intakeAccountRefund,
    _ => id,
  };
}

/// Map a paired device to its intake-form controller option id, so we can
/// narrow the "Which controller?" dropdown to controllers the user actually
/// has paired. Returns `null` when the device doesn't correspond to a
/// controller option (e.g. a smart trainer proxy device).
///
/// `ZwiftClickV2 extends ZwiftRide` — keep the V2 check first.
String? controllerOptionIdFor(BaseDevice device) {
  if (device is ZwiftClickV2) return 'zwift_click_v2';
  if (device is ZwiftClick) return 'zwift_click';
  if (device is ZwiftPlay) {
    return device.deviceType == ZwiftDeviceType.playLeft
        ? 'zwift_play_left'
        : 'zwift_play_right';
  }
  if (device is ZwiftRide) return 'zwift_ride';
  if (device is ShimanoDi2) return 'shimano_di2';
  if (device is SramAxs) return 'sram_axs';
  if (device is WahooKickrBikeShift) return 'wahoo';
  if (device is CycplusBc2) return 'cycplus';
  if (device is EliteSquare || device is EliteSterzo) return 'elite';
  if (device is ThinkRiderVs200) return 'thinkrider';
  if (device is GamepadDevice) return 'gamepad';
  if (device is HidDevice) return 'hid_keyboard';
  if (device is GyroscopeSteering) return 'gyroscope';
  return null;
}

/// Trainer-app dropdown ("Which app?") — pulled from `SupportedApp.supportedApps`
/// so the IDs are the same display names already stored in
/// `support_messages.trainer_app` and `issues.trainer_apps`.
List<({String id, String label})> trainerAppOptions() {
  return SupportedApp.supportedApps
      .map((app) => (id: app.name, label: app.name))
      .toList(growable: false);
}

/// In-memory snapshot of the form selection, serialized into `intake_answers`.
class IntakeAnswers {
  final IntakeCategory category;

  /// What the [subcategoryValue] represents in this branch:
  /// - 'device' for controllers, 'app' for trainer-apps, 'issue' for smart-trainer/account.
  final String? subcategory;

  /// E.g. 'zwift_click_v2', 'MyWhoosh', 'no_resistance_change', 'purchase_not_restored'.
  final String? subcategoryValue;

  /// Secondary "what's happening?" answer — only present on the controller and
  /// trainer-app branches.
  final String? symptom;

  const IntakeAnswers({
    required this.category,
    this.subcategory,
    this.subcategoryValue,
    this.symptom,
  });

  Map<String, dynamic> toJson() => {
        'v': 1,
        'category': category.id,
        if (subcategory != null) 'subcategory': subcategory,
        if (subcategoryValue != null) 'subcategory_value': subcategoryValue,
        if (symptom != null) 'symptom': symptom,
      };
}
