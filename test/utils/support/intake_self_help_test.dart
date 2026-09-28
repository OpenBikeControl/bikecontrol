// The intake form used to jump straight from "what's wrong" to the composer.
// For the questions the help center already answers, the matching answer now
// shows inline first — the mapping from intake choice to answer is pinned
// here.
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/utils/support/intake_self_help.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntakeSelfHelp? help(IntakeCategory category, {String? value, String? symptom}) =>
      intakeSelfHelpFor(IntakeAnswers(category: category, subcategoryValue: value, symptom: symptom));

  test('controller: not pairing -> not found; dropping -> keeps disconnecting', () {
    expect(help(IntakeCategory.controller, symptom: 'no_pairing'), IntakeSelfHelp.controllerNotFound);
    expect(help(IntakeCategory.controller, symptom: 'dropouts'), IntakeSelfHelp.controllerDisconnecting);
    expect(help(IntakeCategory.controller, symptom: 'buttons_partial'), isNull);
  });

  test('trainer app: no reaction -> connection first; gear display -> the gear answer; connection -> network test', () {
    expect(help(IntakeCategory.trainerApp, symptom: 'shifts_not_recognized'), IntakeSelfHelp.appNotReacting);
    expect(help(IntakeCategory.trainerApp, symptom: 'gear_indicator_not_updating'), IntakeSelfHelp.trainerAppGear);
    expect(help(IntakeCategory.trainerApp, symptom: 'network_bridge_fails'), IntakeSelfHelp.networkTest);
    expect(help(IntakeCategory.trainerApp, symptom: 'no_pairing'), IntakeSelfHelp.networkTest);
    expect(help(IntakeCategory.trainerApp, symptom: 'other'), isNull);
  });

  test('smart trainer: resistance and shifting symptoms -> run the self-test', () {
    for (final value in ['no_resistance_change', 'wrong_resistance', 'gear_shift_not_working']) {
      expect(help(IntakeCategory.smartTrainer, value: value), IntakeSelfHelp.trainerSelfTest, reason: value);
    }
    expect(help(IntakeCategory.smartTrainer, value: 'no_pairing'), isNull);
  });

  test('nothing to offer before a symptom is picked, or for account questions', () {
    expect(help(IntakeCategory.controller), isNull);
    expect(help(IntakeCategory.account, value: 'purchase_not_restored'), isNull);
    expect(help(IntakeCategory.somethingElse), isNull);
  });
}
