import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/elite/elite_rizer.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_rizer_protocol.dart';
import 'package:bike_control/bluetooth/incline/incline_controller.dart';
import 'package:bike_control/bluetooth/incline/incline_manual_state.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
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

  test('a write the Rizer refuses is not recorded as applied', () async {
    await rizer.writeInclineRaw(300);
    rizer.debugWriteSink = (b) async {
      writes.add(b);
      await rizer.processCharacteristic(eliteRizerStatusCharacteristicUuid, Uint8List.fromList([0x80, 0x0a, 0x05]));
    };
    expect(await rizer.writeInclineRaw(500), isFalse);
    expect(rizer.inclineApplied.value, 300);
  });

  test('a write the Rizer confirms is recorded as applied', () async {
    rizer.debugWriteSink = (b) async {
      writes.add(b);
      await rizer.processCharacteristic(eliteRizerStatusCharacteristicUuid, Uint8List.fromList([0x80, 0x0a, 0x02]));
    };
    expect(await rizer.writeInclineRaw(500), isTrue);
    expect(rizer.inclineApplied.value, 500);
  });

  test('"command not accessible" marks the Rizer locked, once, until a write goes through', () async {
    final logs = <String>[];
    final sub = rizer.actionStream.listen((n) {
      if (n is LogNotification) logs.add(n.message);
    });
    addTearDown(sub.cancel);
    var reply = 0x05;
    rizer.debugWriteSink = (b) async {
      writes.add(b);
      await rizer.processCharacteristic(eliteRizerStatusCharacteristicUuid, Uint8List.fromList([0x80, 0x0a, reply]));
    };
    expect(rizer.inclineLocked.value, isFalse);

    for (final grade in [100, 200, 300]) {
      expect(await rizer.writeInclineRaw(grade), isFalse);
    }
    await pumpEventQueue();
    expect(rizer.inclineLocked.value, isTrue);
    expect(logs.where((m) => m.contains('locked')), hasLength(1), reason: 'one line, not one per write');

    reply = 0x02;
    expect(await rizer.writeInclineRaw(400), isTrue);
    await pumpEventQueue();
    expect(rizer.inclineLocked.value, isFalse);
    expect(logs.where((m) => m.contains('unlocked')), hasLength(1));
  });

  test('the first incline the Rizer reports is written back once, so a lock shows without a gradient', () async {
    rizer.debugWriteSink = (b) async {
      writes.add(b);
      await rizer.processCharacteristic(eliteRizerStatusCharacteristicUuid, Uint8List.fromList([0x80, 0x0a, 0x05]));
    };
    final report = Uint8List.fromList([0xff, 0x6d, 0x81, 0x64]); // 4.5%
    await rizer.processCharacteristic(eliteRizerInclineCharacteristicUuid, report);
    await pumpEventQueue();
    expect(writes.single, [0x0a, 45, 0], reason: 'the incline it is at, so it does not move');
    expect(rizer.inclineLocked.value, isTrue);

    await rizer.processCharacteristic(eliteRizerInclineCharacteristicUuid, report);
    await pumpEventQueue();
    expect(writes, hasLength(1), reason: 'only once per connection');
  });

  test('no write-back once something was already written', () async {
    await rizer.writeInclineRaw(300);
    await rizer.processCharacteristic(
      eliteRizerInclineCharacteristicUuid,
      Uint8List.fromList([0xff, 0x6d, 0x81, 0x64]),
    );
    await pumpEventQueue();
    expect(writes, hasLength(1));
  });

  test('another refusal does not mark the Rizer locked', () async {
    rizer.debugWriteSink = (b) async {
      await rizer.processCharacteristic(eliteRizerStatusCharacteristicUuid, Uint8List.fromList([0x80, 0x0a, 0x01]));
    };
    expect(await rizer.writeInclineRaw(500), isFalse);
    expect(rizer.inclineLocked.value, isFalse);
  });

  test('the incline the Rizer reports is shown over the one it was told', () async {
    await rizer.writeInclineRaw(1000);
    expect(rizer.inclineShown, 1000);
    await rizer.processCharacteristic(
      eliteRizerInclineCharacteristicUuid,
      Uint8List.fromList([0xff, 0x6d, 0x81, 0x64]),
    );
    expect(rizer.inclineReported.value, 450);
    expect(rizer.inclineShown, 450);
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
