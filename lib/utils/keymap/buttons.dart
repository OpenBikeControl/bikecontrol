import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:swift_control/bluetooth/devices/elite/elite_square.dart';
import 'package:swift_control/bluetooth/devices/elite/elite_sterzo.dart';
import 'package:swift_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';

enum InGameAction {
  shiftUp('Shift Up'),
  shiftDown('Shift Down'),
  uturn('U-Turn'),
  steerLeft('Steer Left'),
  steerRight('Steer Right'),

  // mywhoosh
  cameraAngle('Change Camera Angle', possibleValues: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
  emote('Emote', possibleValues: [1, 2, 3, 4, 5, 6]),
  toggleUi('Toggle UI'),
  navigateLeft('Navigate Left'),
  navigateRight('Navigate Right'),
  increaseResistance('Increase Resistance'),
  decreaseResistance('Decrease Resistance'),

  // zwift
  openActionBar('Open Action Bar'),
  usePowerUp('Use Power-Up'),
  select('Select'),
  back('Back'),
  rideOnBomb('Ride On Bomb');

  final String title;
  final List<int>? possibleValues;

  const InGameAction(this.title, {this.possibleValues});

  @override
  String toString() {
    return title;
  }
}

class ControllerButton {
  final String name;
  final InGameAction? action;
  final Color? color;
  final IconData? icon;

  const ControllerButton(
    this.name, {
    this.color,
    this.icon,
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
          action == other.action &&
          color == other.color &&
          icon == other.icon;

  @override
  int get hashCode => Object.hash(name, action, color, icon);

  static List<ControllerButton> get values => [
    ...SterzoButtons.values,
    ...ZwiftButtons.values,
    ...EliteSquareButtons.values,
    ...WahooKickrShiftButtons.values,
    ...CycplusBc2Buttons.values,
  ].distinct().toList();
}
