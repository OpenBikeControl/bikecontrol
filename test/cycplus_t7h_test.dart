import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:bike_control/bluetooth/devices/cycplus/cycplus_t7h.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load(const Locale('en'));

  group('CYCPLUS T7 shifters', () {
    late StubActions stubActions;

    setUp(() {
      core.actionHandler = StubActions();
      stubActions = core.actionHandler as StubActions;
    });

    CycplusT7h shifter(String name) => CycplusT7h(BleDevice(deviceId: name, name: name));

    Future<void> send(CycplusT7h device, String hex) =>
        device.processCharacteristic(CycplusBc2Constants.TX_CHARACTERISTIC_UUID, _hex(hex));

    List<String> taps() => stubActions.performedActions.where((a) => a.isUp).map((a) => a.button.name).toList();

    test('left rear arrow: repeats while held, one tap on release', () async {
      final left = shifter('T7H-L1234');
      for (var i = 0; i < 5; i++) {
        await send(left, 'AA4508F7');
      }
      expect(taps(), isEmpty);
      await send(left, 'AA4500EF');
      expect(taps(), [CycplusT7hButtons.leftRearArrow.name]);
    });

    test('all four left buttons from the captures', () async {
      final left = shifter('T7H-L1234');
      for (final (press, button) in [
        ('AA4408F6', CycplusT7hButtons.leftRearArrow),
        ('AA4410FE', CycplusT7hButtons.leftFrontArrow),
        ('AA4501F0', CycplusT7hButtons.leftShiftUp),
        ('AA4502F1', CycplusT7hButtons.leftShiftDown),
      ]) {
        await send(left, press);
        await send(left, 'AA4500EF');
        expect(taps().last, button.name);
      }
      expect(taps(), hasLength(4));
    });

    test('right shifter releases with 0x80', () async {
      final right = shifter('T7H-R1234');
      await send(right, 'AA3F816A');
      await send(right, 'AA3F816A');
      await send(right, 'AA3F8069');
      await send(right, 'AA428874');
      await send(right, 'AA42806C');
      expect(taps(), [CycplusT7hButtons.rightShiftUp.name, CycplusT7hButtons.rightRearArrow.name]);
    });

    test('a frame with a bad checksum is ignored', () async {
      final left = shifter('T7H-L1234');
      await send(left, 'AA4508F8');
      await send(left, 'AA4500EF');
      expect(stubActions.performedActions, isEmpty);
    });

    test('defaults: left lever mirrors the right one, rear arrows steer', () {
      expect(CycplusT7hButtons.leftShiftDown.action, CycplusT7hButtons.rightShiftUp.action);
      expect(CycplusT7hButtons.leftShiftUp.action, CycplusT7hButtons.rightShiftDown.action);
      expect(CycplusT7hButtons.leftRearArrow.action, InGameAction.steerLeft);
      expect(CycplusT7hButtons.rightRearArrow.action, InGameAction.steerRight);
    });
  });
}

Uint8List _hex(String hex) =>
    Uint8List.fromList([for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);
