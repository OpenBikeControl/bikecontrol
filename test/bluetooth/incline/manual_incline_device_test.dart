import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/elite/elite_rizer.dart';
import 'package:bike_control/bluetooth/incline/incline_controller.dart';
import 'package:bike_control/bluetooth/incline/incline_manual_state.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  late EliteRizer rizer;
  late List<Uint8List> writes;

  setUp(() {
    writes = [];
    rizer = EliteRizer(BleDevice(name: 'RIZER', deviceId: 'rizer'))..debugWriteSink = (b) async => writes.add(b);
  });

  test('a write records the applied incline', () async {
    expect(rizer.inclineApplied.value, isNull);
    await rizer.writeInclineRaw(450);
    expect(rizer.inclineApplied.value, 450);
    expect(writes.single, [0x0a, 45, 0]);
  });

  test('a step out of auto starts from the incline the grade had set', () async {
    await rizer.writeInclineRaw(800);
    await rizer.applyInclineAction(InGameAction.inclineIncrease);
    expect(rizer.inclineState.mode, InclineMode.manual);
    expect(rizer.inclineApplied.value, 900);
  });

  test('flatten holds 0%, auto hands it back to the grade', () async {
    final controller = InclineController(gradeProvider: () => 600, sinkProvider: () => rizer);
    await controller.tick();
    expect(rizer.inclineApplied.value, 600);

    await rizer.applyInclineAction(InGameAction.inclineZero);
    expect(rizer.inclineApplied.value, 0);
    await controller.tick();
    expect(rizer.inclineApplied.value, 0, reason: 'manual hold ignores the grade');

    await rizer.applyInclineAction(InGameAction.inclineAutoMode);
    await controller.tick();
    expect(rizer.inclineApplied.value, 600);
  });

  test('the controller exposes the grade it read', () async {
    int? grade;
    final controller = InclineController(gradeProvider: () => grade, sinkProvider: () => null);
    await controller.tick();
    expect(controller.sourceGrade.value, isNull);
    grade = 350;
    await controller.tick();
    expect(controller.sourceGrade.value, 350);
  });
}
