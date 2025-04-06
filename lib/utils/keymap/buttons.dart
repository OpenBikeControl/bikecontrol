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
  navigationUp._(InGameAction.increaseResistance),
  navigationDown._(InGameAction.decreaseResistance),
  navigationLeft._(InGameAction.navigateLeft),
  navigationRight._(InGameAction.navigateRight),
  onOffLeft._(InGameAction.toggleUi),
  sideButtonLeft._(InGameAction.shiftDown),
  paddleLeft._(InGameAction.shiftDown),

  // zwift ride only
  shiftUpLeft._(InGameAction.shiftDown),
  shiftDownLeft._(InGameAction.shiftDown),
  powerUpLeft._(InGameAction.shiftDown),

  // right controller
  a._(null),
  b._(null),
  z._(null),
  y._(null),
  onOffRight._(InGameAction.toggleUi),
  sideButtonRight._(InGameAction.shiftUp),
  paddleRight._(InGameAction.shiftUp),

  // zwift ride only
  shiftUpRight._(InGameAction.shiftUp),
  shiftDownRight._(InGameAction.shiftUp),
  powerUpRight._(InGameAction.shiftUp);

  final InGameAction? action;
  const ZwiftButton._(this.action);

  @override
  String toString() {
    return name;
  }
}
