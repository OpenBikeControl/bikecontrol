import 'package:bike_control/utils/keymap/buttons.dart';

/// What an action is for, the way a rider looks for it in the action picker:
/// by intent, not by the connection that carries it.
enum ActionGroup {
  gears,
  trainer,
  workout,
  ride,
  navigate,
  view,
  controller,
  system;

  static ActionGroup of(InGameAction action) => switch (action) {
    InGameAction.shiftUp ||
    InGameAction.shiftDown ||
    InGameAction.frontShift ||
    InGameAction.gearSet => ActionGroup.gears,
    InGameAction.trainerSwitchMode ||
    InGameAction.trainerIntensityUp ||
    InGameAction.trainerIntensityDown ||
    InGameAction.increaseResistance ||
    InGameAction.decreaseResistance ||
    InGameAction.changeMode => ActionGroup.trainer,
    InGameAction.workoutPauseResume ||
    InGameAction.skipInterval ||
    InGameAction.previousInterval ||
    InGameAction.lap ||
    InGameAction.pause ||
    InGameAction.resume ||
    InGameAction.takeBreak => ActionGroup.workout,
    InGameAction.steerLeft ||
    InGameAction.steerRight ||
    InGameAction.uturn ||
    InGameAction.tuck ||
    InGameAction.brake ||
    InGameAction.usePowerUp ||
    InGameAction.rideOnBomb ||
    InGameAction.kudos ||
    InGameAction.emote ||
    InGameAction.pushToTalk ||
    InGameAction.joinRider ||
    InGameAction.spectateRider ||
    InGameAction.changeRoute => ActionGroup.ride,
    InGameAction.up ||
    InGameAction.down ||
    InGameAction.navigateLeft ||
    InGameAction.navigateRight ||
    InGameAction.select ||
    InGameAction.back ||
    InGameAction.openActionBar ||
    InGameAction.menu ||
    InGameAction.home => ActionGroup.navigate,
    InGameAction.cameraAngle || InGameAction.toggleUi || InGameAction.mapToggle => ActionGroup.view,
    InGameAction.leftDropButton ||
    InGameAction.rightDropButton ||
    InGameAction.leftShiftButton2 ||
    InGameAction.rightShiftButton2 => ActionGroup.controller,
    InGameAction.headwindSpeed ||
    InGameAction.headwindSpeedInc ||
    InGameAction.headwindSpeedDec ||
    InGameAction.headwindSpeedCyclicInc ||
    InGameAction.headwindSpeedCyclicDec ||
    InGameAction.headwindHeartRateMode ||
    InGameAction.inclineIncrease ||
    InGameAction.inclineDecrease ||
    InGameAction.inclineZero ||
    InGameAction.inclineAutoMode ||
    InGameAction.calibratePhoneSteering ||
    InGameAction.screenRecording => ActionGroup.system,
  };
}

/// Where an action sits inside its group; anything not listed keeps the
/// order it came in, after these. Navigation reads like a d-pad.
const _displayOrder = <InGameAction>[
  InGameAction.shiftUp,
  InGameAction.shiftDown,
  InGameAction.frontShift,
  InGameAction.gearSet,
  InGameAction.trainerSwitchMode,
  InGameAction.trainerIntensityUp,
  InGameAction.trainerIntensityDown,
  InGameAction.increaseResistance,
  InGameAction.decreaseResistance,
  InGameAction.changeMode,
  InGameAction.workoutPauseResume,
  InGameAction.pause,
  InGameAction.resume,
  InGameAction.skipInterval,
  InGameAction.previousInterval,
  InGameAction.lap,
  InGameAction.takeBreak,
  InGameAction.up,
  InGameAction.down,
  InGameAction.navigateLeft,
  InGameAction.navigateRight,
  InGameAction.select,
  InGameAction.back,
];

/// [actions] (possibly offered by several connections, so with repeats)
/// sorted into their [ActionGroup]s, each action once, empty groups left out.
List<({ActionGroup group, List<InGameAction> actions})> groupActions(Iterable<InGameAction> actions) {
  final unique = actions.toSet().toList();
  int rank(InGameAction a) {
    final i = _displayOrder.indexOf(a);
    return i == -1 ? _displayOrder.length + unique.indexOf(a) : i;
  }

  return [
    for (final group in ActionGroup.values)
      if (unique.where((a) => ActionGroup.of(a) == group).toList() case final members when members.isNotEmpty)
        (group: group, actions: members..sort((a, b) => rank(a).compareTo(rank(b)))),
  ];
}
