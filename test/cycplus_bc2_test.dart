import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load(const Locale('en'));

  group('CYCPLUS BC2 Virtual Shifter Tests', () {
    late StubActions stubActions;
    late CycplusBc2 device;

    setUp(() {
      core.actionHandler = StubActions();
      stubActions = core.actionHandler as StubActions;
      device = CycplusBc2(BleDevice(deviceId: 'deviceId', name: 'CYCPLUS BC2 57344'));
    });

    Future<void> send(String hex) =>
        device.processCharacteristic(CycplusBc2Constants.TX_CHARACTERISTIC_UUID, _hexToUint8List(hex));

    test('alternating up/down presses from a real capture produce one tap each', () async {
      // Up and down pressed alternately; every press and every release is a
      // separate notification that bumps that lever's counter.
      const capture = [
        'FEEFFFEE0206010397565E000155',
        'FEEFFFEE0206030398565E000158',
        'FEEFFFEE0206030198575E000157',
        'FEEFFFEE0206030398585E00015A',
        'FEEFFFEE0206010399585E000159',
        'FEEFFFEE020603039A585E00015C',
        'FEEFFFEE020603019A595E00015B',
        'FEEFFFEE020603039A5A5E00015E',
        'FEEFFFEE020601039B5A5E00015D',
        'FEEFFFEE020603039C5A5E000160',
        'FEEFFFEE020603019C5B5E00015F',
        'FEEFFFEE020603039C5C5E000162',
        'FEEFFFEE020601039D5C5E000161',
        'FEEFFFEE020603039E5C5D000163',
        'FEEFFFEE020603019E5D5D000162',
        'FEEFFFEE020603039E5E5D000165',
        'FEEFFFEE020601039F5E5D000164',
        'FEEFFFEE02060303A05E5D000167',
        'FEEFFFEE02060301A05F5D000166',
        'FEEFFFEE02060302A0605D000168',
        'FEEFFFEE02060102A1605D000167',
        'FEEFFFEE02060302A2605D00016A',
        'FEEFFFEE02060301A2615D00016A',
        'FEEFFFEE02060303A2625D00016D',
      ];
      for (final packet in capture) {
        await send(packet);
      }

      final taps = stubActions.performedActions.where((a) => a.isUp).map((a) => a.button.name).toList();
      expect(taps, [
        for (var i = 0; i < 6; i++) ...[CycplusBc2Buttons.shiftUp.name, CycplusBc2Buttons.shiftDown.name],
      ]);
    });

    test('a long-press state keeps the lever held until its release', () async {
      await send('FEEFFFEE0206010397565E000155'); // + pressed
      await send('FEEFFFEE0206040398565E000158'); // + still held (long press)
      expect(stubActions.performedActions.where((a) => a.isUp), isEmpty);

      await send('FEEFFFEE0206050399565E000158'); // + released after long press
      expect(
        stubActions.performedActions.where((a) => a.isUp && a.button.name == CycplusBc2Buttons.shiftUp.name),
        isNotEmpty,
      );
    });

    test('a repeated notification without a counter change is ignored', () async {
      await send('FEEFFFEE0206010397565E000155'); // + pressed
      await send('FEEFFFEE0206010397565E000155'); // same packet again
      await send('FEEFFFEE0206030398565E000158'); // + released

      final taps = stubActions.performedActions.where((a) => a.isUp).toList();
      expect(taps.length, 1);
      expect(taps.single.button.name, CycplusBc2Buttons.shiftUp.name);
    });

    test('a state change on one lever does not re-trigger the other', () async {
      await send('FEEFFFEE0206010397565E000155'); // + pressed
      await send('FEEFFFEE0206030398565E000158'); // + released
      stubActions.performedActions.clear();

      // − pressed and released; byte 6 still reports the old + state.
      await send('FEEFFFEE0206030198575E000157');
      await send('FEEFFFEE0206030398585E00015A');

      final taps = stubActions.performedActions.where((a) => a.isUp).map((a) => a.button.name).toList();
      expect(taps, [CycplusBc2Buttons.shiftDown.name]);
    });

    test('a too-short packet triggers nothing', () async {
      await send('FEEFFFEE020601');
      expect(stubActions.performedActions, isEmpty);
    });
  });
}

Uint8List _hexToUint8List(String seq) {
  return Uint8List.fromList(
    List.generate(
      seq.length ~/ 2,
      (i) => int.parse(seq.substring(i * 2, i * 2 + 2), radix: 16),
    ),
  );
}
