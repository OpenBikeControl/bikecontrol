import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// D-Fly channel reports as a Di2 sends them: a first press is `0x1N`, every
/// press that follows quickly is `0x4N`; the low nibble counts presses.
Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));
  SharedPreferences.setMockInitialValues({});
  await core.settings.init();

  late StubActions stub;
  late ShimanoDi2 di2;

  Future<void> report(int seq, int ch1) =>
      di2.processCharacteristic(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, Uint8List.fromList([seq, ch1, 0xf0, 0xf0, 0xf0]));

  setUp(() async {
    stub = StubActions();
    core.actionHandler = stub;
    di2 = ShimanoDi2(BleDevice(name: 'RDR7150', deviceId: 'di2'));
    // Not the first report of the link: only tells where the channels are.
    await report(0x21, 0x16);
    final ch1 = di2.availableButtons.firstWhere((b) => b.name == 'D-Fly Channel 1');
    final app = CustomApp(profileName: 'Di2');
    app.keymap.addKeyPair(
      KeyPair(buttons: [ch1], physicalKey: null, logicalKey: null, inGameAction: InGameAction.shiftUp),
    );
    core.actionHandler.init(app);
  });

  tearDown(() => di2.disconnect());

  int shifts() => stub.performedActions.where((a) => a.trigger == ButtonTrigger.singleClick).length;

  test('one press shifts once', () async {
    await report(0x22, 0x17);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(shifts(), 1);
  });

  test('two quick presses shift twice', () async {
    await report(0x22, 0x17);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await report(0x23, 0x48);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(shifts(), 2);
  });

  test('three quick presses shift three times', () async {
    await report(0x22, 0x17);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await report(0x23, 0x48);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await report(0x24, 0x49);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(shifts(), 3);
  });
}
