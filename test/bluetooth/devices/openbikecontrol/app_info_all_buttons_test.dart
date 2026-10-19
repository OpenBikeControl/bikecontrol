// OpenBikeControl BLE.md: "Button_Count 0 indicates the app supports all button
// types". Biketerra sends 0 to keep the write inside the 23-byte MTU; reading it
// as "no buttons" dropped every press.
import 'dart:convert';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _appInfo(List<int> buttonIds) {
  final id = utf8.encode('biketerra');
  final version = utf8.encode('1.0');
  return Uint8List.fromList([
    OpenBikeProtocolParser.MSG_TYPE_APP_INFO,
    0x01,
    id.length,
    ...id,
    version.length,
    ...version,
    buttonIds.length,
    ...buttonIds,
  ]);
}

void main() {
  test('button count 0 means every action is supported', () {
    final info = OpenBikeProtocolParser.parseAppInfo(_appInfo(const []));

    expect(
      info.supportedActions.toSet(),
      OpenBikeProtocolParser.BUTTON_NAMES.values.map((b) => b.action).whereType<InGameAction>().toSet(),
    );
  });

  test('button count 0 maps each action to one button', () {
    // A press sends every supported button of its action: "camera" must not
    // press Camera View and Camera 1-3 at once.
    final info = OpenBikeProtocolParser.parseAppInfo(_appInfo(const []));

    expect(info.supportedButtons.where((b) => b.action == InGameAction.cameraAngle).map((b) => b.identifier), [0x40]);
    expect(info.supportedButtons.where((b) => b.action == InGameAction.usePowerUp).map((b) => b.identifier), [0x50]);
  });

  test('button count 0 does not opt into the steering angle', () {
    // 0x1B is a value, not a button: steering buttons would otherwise only be
    // sent as an angle the app may not read.
    final info = OpenBikeProtocolParser.parseAppInfo(_appInfo(const []));

    expect(info.supportsSteeringAngle, isFalse);
  });

  test('an explicit list is taken as is', () {
    final info = OpenBikeProtocolParser.parseAppInfo(_appInfo(const [0x01, 0x02]));

    expect(info.supportedActions, [InGameAction.shiftUp, InGameAction.shiftDown]);
  });
}
