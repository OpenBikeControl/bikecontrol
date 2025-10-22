import 'package:flutter/material.dart';

enum InGameAction {
  shiftUp('Shift Up'),
  shiftDown('Shift Down'),
  navigateLeft('Navigate Left'),
  navigateRight('Navigate Right'),
  increaseResistance('Increase Resistance'),
  decreaseResistance('Decrease Resistance'),
  toggleUi('Toggle UI'),
  cameraAngle('Change Camera Angle', possibleValues: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
  emote('Emote', possibleValues: [1, 2, 3, 4, 5, 6]),
  uturn('U-Turn'),
  steerLeft('Steer Left'),
  steerRight('Steer Right');

  final String title;
  final List<int>? possibleValues;

  const InGameAction(this.title, {this.possibleValues});

  @override
  String toString() {
    return title;
  }
}

enum ControllerButton {
  // left controller
  navigationUp._(null, icon: Icons.keyboard_arrow_up, color: Colors.black),
  navigationDown._(InGameAction.uturn, icon: Icons.keyboard_arrow_down, color: Colors.black),
  navigationLeft._(InGameAction.navigateLeft, icon: Icons.keyboard_arrow_left, color: Colors.black),
  navigationRight._(InGameAction.navigateRight, icon: Icons.keyboard_arrow_right, color: Colors.black),
  onOffLeft._(InGameAction.toggleUi),
  sideButtonLeft._(InGameAction.shiftDown),
  paddleLeft._(InGameAction.shiftDown),

  // zwift ride only
  shiftUpLeft._(InGameAction.shiftDown, icon: Icons.remove, color: Colors.black),
  shiftDownLeft._(InGameAction.shiftDown, icon: Icons.remove, color: Colors.black),
  powerUpLeft._(InGameAction.shiftDown),

  // right controller
  a._(null, color: Colors.lightGreen),
  b._(null, color: Colors.pinkAccent),
  z._(null, color: Colors.deepOrangeAccent),
  y._(null, color: Colors.lightBlue),
  onOffRight._(InGameAction.toggleUi),
  sideButtonRight._(InGameAction.shiftUp),
  paddleRight._(InGameAction.shiftUp),

  // zwift ride only
  shiftUpRight._(InGameAction.shiftUp, icon: Icons.add, color: Colors.black),
  shiftDownRight._(InGameAction.shiftUp),
  powerUpRight._(InGameAction.shiftUp),

  // elite square only
  campagnoloLeft._(InGameAction.shiftDown),
  campagnoloRight._(InGameAction.shiftUp);

  final InGameAction? action;
  final Color? color;
  final IconData? icon;
  const ControllerButton._(this.action, {this.color, this.icon});

  @override
  String toString() {
    return name;
  }
}
