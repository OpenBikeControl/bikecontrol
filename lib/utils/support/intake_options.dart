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

import '../keymap/apps/supported_app.dart';

enum IntakeCategory {
  trainerApp('trainer_app'),
  controller('controller'),
  smartTrainer('smart_trainer'),
  account('account');

  final String id;
  const IntakeCategory(this.id);
}

/// Controller follow-up options ("Which controller?"). The IDs must match the
/// `problem_subcategories` slugs in the seed migration.
class ControllerOption {
  final String id;
  final String label;
  const ControllerOption(this.id, this.label);
}

const controllerOptions = <ControllerOption>[
  ControllerOption('zwift_click', 'Zwift Click'),
  ControllerOption('zwift_click_v2', 'Zwift Click V2'),
  ControllerOption('zwift_play_left', 'Zwift Play (Left)'),
  ControllerOption('zwift_play_right', 'Zwift Play (Right)'),
  ControllerOption('zwift_ride', 'Zwift Ride'),
  ControllerOption('shimano_di2', 'Shimano Di2'),
  ControllerOption('sram_axs', 'SRAM AXS'),
  ControllerOption('wahoo', 'Wahoo'),
  ControllerOption('cycplus', 'Cycplus'),
  ControllerOption('elite', 'Elite'),
  ControllerOption('thinkrider', 'ThinkRider'),
  ControllerOption('gamepad', 'Gamepad'),
  ControllerOption('hid_keyboard', 'HID keyboard'),
  ControllerOption('gyroscope', 'Gyroscope'),
  ControllerOption('other', 'Other / not listed'),
];

/// Controller symptom dropdown ("What's happening?").
class SymptomOption {
  final String id;
  final String label;
  const SymptomOption(this.id, this.label);
}

const controllerSymptoms = <SymptomOption>[
  SymptomOption('no_pairing', 'Not pairing'),
  SymptomOption('no_response', "Pairs but button presses do nothing"),
  SymptomOption('buttons_partial', 'Only some buttons work'),
  SymptomOption('dropouts', 'Disconnects mid-ride'),
  SymptomOption('other', 'Something else'),
];

/// Trainer-app symptom dropdown ("What's happening?").
const trainerAppSymptoms = <SymptomOption>[
  SymptomOption('shifts_not_recognized', "BikeControl shifts, app doesn't react"),
  SymptomOption('network_bridge_fails', 'Network bridge stuck on "Waiting"'),
  SymptomOption('no_pairing', 'Can\'t pair from the app'),
  SymptomOption('gear_indicator_not_updating', 'Gear number stuck on screen'),
  SymptomOption('other', 'Something else'),
];

/// Smart trainer symptom dropdown ("What's happening?").
const smartTrainerSymptoms = <SymptomOption>[
  SymptomOption('no_resistance_change', 'No resistance change when shifting'),
  SymptomOption('wrong_resistance', 'Resistance feels wrong / random'),
  SymptomOption('gear_shift_not_working', 'Gear shift not working'),
  SymptomOption('no_pairing', 'Trainer not pairing'),
  SymptomOption('dropouts', 'Drops mid-ride'),
  SymptomOption('no_data', 'No power / cadence / heart rate'),
  SymptomOption('not_supported', "Trainer not detected / FTMS missing"),
  SymptomOption('other', 'Something else'),
];

/// Account / purchase follow-up dropdown.
const accountSymptoms = <SymptomOption>[
  SymptomOption('purchase_not_restored', "Can't restore purchase"),
  SymptomOption('trial_expired_after_purchase', 'Trial expired even though I paid'),
  SymptomOption('wrong_plan_shown', 'App shows wrong plan'),
  SymptomOption('refund_request', 'Refund request'),
  SymptomOption('other', 'Something else'),
];

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
