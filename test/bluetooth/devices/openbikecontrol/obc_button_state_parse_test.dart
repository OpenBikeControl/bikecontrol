// BikeControl receiving from an OpenBikeControl controller: a button-state
// message with an ID this version doesn't know (e.g. the 0x1B steering angle)
// keeps the IDs it does know, as the protocol asks of parsers.
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the steering angle next to Steer Left: Steer Left still comes through', () {
    final buttons = OpenBikeProtocolParser.parseButtonState(Uint8List.fromList([0x01, 0x1B, 0x94, 0x18, 0x01]));
    expect(buttons.map((b) => (b.button.action, b.state)), [(InGameAction.steerLeft, 0x01)]);
  });

  test('an ID no version knows yet is skipped, not fatal', () {
    final buttons = OpenBikeProtocolParser.parseButtonState(Uint8List.fromList([0x01, 0x7E, 0x01, 0x19, 0x00]));
    expect(buttons.map((b) => (b.button.action, b.state)), [(InGameAction.steerRight, 0x00)]);
  });
}
