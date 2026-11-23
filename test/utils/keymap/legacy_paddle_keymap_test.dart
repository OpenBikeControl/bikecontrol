// Keymaps saved before the paddles were split into inward/outward hold
// `paddleLeft` / `paddleRight`. Loading one must map both directions of that
// paddle the way the single paddle was mapped.
import 'dart:convert';

import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const deviceId = 'aa:bb:cc:dd:ee:ff';

  String legacyPair(List<dynamic> actions, String inGameAction) => jsonEncode({
    'actions': actions,
    'trigger': 'singleClick',
    'inGameAction': inGameAction,
  });

  test('paddleLeft with a deviceId maps both left directions, keeping action and device', () {
    final pair = KeyPair.decode(
      legacyPair([
        {'name': 'paddleLeft', 'deviceId': deviceId},
      ], 'shiftUp'),
    )!;

    expect(pair.buttons, [
      ZwiftButtons.paddleLeftInward.copyWith(sourceDeviceId: deviceId),
      ZwiftButtons.paddleLeftOutward.copyWith(sourceDeviceId: deviceId),
    ]);
    expect(pair.inGameAction, InGameAction.shiftUp);
  });

  test('a bare paddleRight name maps both right directions', () {
    final pair = KeyPair.decode(legacyPair(['paddleRight'], 'shiftDown'))!;

    expect(pair.buttons, [ZwiftButtons.paddleRightInward, ZwiftButtons.paddleRightOutward]);
    expect(pair.inGameAction, InGameAction.shiftDown);
  });

  test('a custom keymap keeps the mapping on both directions across save and reload', () {
    final app = CustomApp(profileName: 'Old')
      ..decodeKeymap([
        legacyPair([
          {'name': 'paddleLeft', 'deviceId': deviceId},
        ], 'uturn'),
        legacyPair(['a'], 'select'),
      ]);

    final saved = app.encodeKeymap();
    expect(saved.join(), isNot(contains('"paddleLeft"')));

    final reloaded = CustomApp(profileName: 'Old')..decodeKeymap(saved);
    for (final button in [ZwiftButtons.paddleLeftInward, ZwiftButtons.paddleLeftOutward]) {
      final pair = reloaded.keymap.getKeyPair(button.copyWith(sourceDeviceId: deviceId));
      expect(pair?.inGameAction, InGameAction.uturn, reason: button.name);
    }
    expect(reloaded.keymap.getKeyPair(ZwiftButtons.a)?.inGameAction, InGameAction.select);
    expect(reloaded.keymap.keyPairs, hasLength(2));
  });

  test('the built-in Zwift keymap maps both directions as the paddle was', () {
    final keymap = Zwift().keymap;
    expect(keymap.getKeyPair(ZwiftButtons.paddleLeftInward)?.inGameAction, InGameAction.shiftDown);
    expect(keymap.getKeyPair(ZwiftButtons.paddleLeftOutward)?.inGameAction, InGameAction.shiftDown);
    expect(keymap.getKeyPair(ZwiftButtons.paddleRightInward)?.inGameAction, InGameAction.shiftUp);
    expect(keymap.getKeyPair(ZwiftButtons.paddleRightOutward)?.inGameAction, InGameAction.shiftUp);
  });
}
