import 'package:bike_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_square.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

enum InGameAction {
  shiftUp('Shift Up', icon: BootstrapIcons.patchPlus),
  shiftDown('Shift Down', icon: BootstrapIcons.patchMinus),
  uturn('U-Turn', alternativeTitle: 'Down', icon: BootstrapIcons.arrowDownUp),
  steerLeft('Steer Left', alternativeTitle: 'Left', icon: RadixIcons.doubleArrowLeft),
  steerRight('Steer Right', alternativeTitle: 'Right', icon: RadixIcons.doubleArrowRight),

  // mywhoosh
  cameraAngle('Change Camera Angle', possibleValues: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], icon: BootstrapIcons.camera),
  emote('Emote', possibleValues: [1, 2, 3, 4, 5, 6], icon: BootstrapIcons.personRaisedHand),
  toggleUi('Toggle UI', icon: RadixIcons.iconSwitch),
  navigateLeft('Navigate Left', icon: BootstrapIcons.signTurnLeft),
  navigateRight('Navigate Right', icon: BootstrapIcons.signTurnRight),
  increaseResistance('Increase Resistance', icon: LucideIcons.chartNoAxesColumnIncreasing),
  decreaseResistance('Decrease Resistance', icon: LucideIcons.chartNoAxesColumnDecreasing),

  // zwift
  openActionBar('Open Action Bar', alternativeTitle: 'Up', icon: BootstrapIcons.menuApp),
  usePowerUp('Use Power-Up', icon: Icons.flash_on_outlined),
  select('Select', icon: LucideIcons.mousePointerClick),
  back('Back', icon: BootstrapIcons.arrowLeft),
  rideOnBomb('Ride On Bomb', icon: LucideIcons.bomb),

  // headwind
  headwindSpeed('Headwind Speed', possibleValues: [0, 25, 50, 75, 100]),
  headwindHeartRateMode('Headwind HR Mode');

  final String title;
  final IconData? icon;
  final String? alternativeTitle;
  final List<int>? possibleValues;

  const InGameAction(this.title, {this.possibleValues, this.alternativeTitle, this.icon});

  @override
  String toString() {
    return title;
  }
}

class ControllerButton {
  final String name;
  final int? identifier;
  final InGameAction? action;
  final Color? color;
  final IconData? icon;

  const ControllerButton(
    this.name, {
    this.color,
    this.icon,
    this.identifier,
    this.action,
  });

  @override
  String toString() {
    return name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ControllerButton &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          identifier == other.identifier &&
          action == other.action &&
          color == other.color &&
          icon == other.icon;

  @override
  int get hashCode => Object.hash(name, action, identifier, color, icon);

  static List<ControllerButton> get values => [
    ...SterzoButtons.values,
    ...GyroscopeSteeringButtons.values,
    ...ZwiftButtons.values,
    ...EliteSquareButtons.values,
    ...WahooKickrShiftButtons.values,
    ...CycplusBc2Buttons.values,
    ...OpenBikeProtocolParser.BUTTON_NAMES.values,
  ].distinct().toList();
}
