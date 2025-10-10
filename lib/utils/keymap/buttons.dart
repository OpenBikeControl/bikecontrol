import 'package:flutter/material.dart';

enum InGameAction {
  shiftUp,
  shiftDown,
  navigateLeft,
  navigateRight,
  toggleUi,
  increaseResistance,
  decreaseResistance;

  @override
  String toString() {
    return name;
  }
}

enum ZwiftButton {
  // left controller
  navigationUp._(InGameAction.increaseResistance, icon: Icons.keyboard_arrow_up, color: Colors.black),
  navigationDown._(InGameAction.decreaseResistance, icon: Icons.keyboard_arrow_down, color: Colors.black),
  navigationLeft._(InGameAction.navigateLeft, icon: Icons.keyboard_arrow_left, color: Colors.black),
  navigationRight._(InGameAction.navigateRight, icon: Icons.keyboard_arrow_right, color: Colors.black),
  onOffLeft._(InGameAction.toggleUi),
  sideButtonLeft._(InGameAction.shiftDown),
  paddleLeft._(InGameAction.shiftDown),

  // zwift ride only
  shiftUpLeft._(InGameAction.shiftDown, icon: Icons.minimize_rounded, color: Colors.black),
  shiftDownLeft._(InGameAction.shiftDown, icon: Icons.minimize_rounded, color: Colors.black),
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
  powerUpRight._(InGameAction.shiftUp);

  final InGameAction? action;
  final Color? color;
  final IconData? icon;
  const ZwiftButton._(this.action, {this.color, this.icon});

  @override
  String toString() {
    return name;
  }
}
