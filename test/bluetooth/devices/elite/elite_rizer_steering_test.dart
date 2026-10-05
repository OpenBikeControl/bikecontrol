import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/elite/elite_rizer.dart';
import 'package:bike_control/bluetooth/devices/elite/elite_rizer_protocol.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  test('recalibrate clears the old center and learns a new one', () async {
    final device = EliteRizer(BleDevice(name: 'RIZER', deviceId: 'test-rizer'));

    Future<void> sendAngle(double degrees) {
      final bytes = ByteData(4)..setFloat32(0, degrees, Endian.little);
      return device.processCharacteristic(eliteRizerSteeringCharacteristicUuid, bytes.buffer.asUint8List());
    }

    for (var i = 0; i < 10; i++) {
      await sendAngle(2);
    }
    await sendAngle(7);
    expect(device.steeringCalibrated.value, isTrue);
    expect(device.steeringAngle.value, -5);

    device.recalibrate();
    expect(device.steeringCalibrated.value, isFalse);
    expect(device.steeringAngle.value, 0);

    for (var i = 0; i < 10; i++) {
      await sendAngle(7);
    }
    await sendAngle(7);
    expect(device.steeringCalibrated.value, isTrue);
    expect(device.steeringAngle.value, 0);
  });

  test('recalibrate cancels pending steering presses', () async {
    final device = EliteRizer(BleDevice(name: 'RIZER', deviceId: 'test-rizer'));
    final presses = <ButtonNotification>[];
    final subscription = device.actionStream
        .where((event) => event is ButtonNotification)
        .cast<ButtonNotification>()
        .listen(presses.add);

    Future<void> sendAngle(double degrees) {
      final bytes = ByteData(4)..setFloat32(0, degrees, Endian.little);
      return device.processCharacteristic(eliteRizerSteeringCharacteristicUuid, bytes.buffer.asUint8List());
    }

    for (var i = 0; i < 10; i++) {
      await sendAngle(0);
    }
    await sendAngle(50);
    device.recalibrate();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(presses, isEmpty);
    await subscription.cancel();
  });

  group('rizerSteerDecision', () {
    test('below threshold => center (null)', () {
      expect(rizerSteerDecision(5), null);
      expect(rizerSteerDecision(-9), null);
    });
    test('beyond +threshold => right, -threshold => left', () {
      expect(rizerSteerDecision(15)?.right, true);
      expect(rizerSteerDecision(-15)?.right, false);
    });
    test('levels scale with magnitude, clamped 1..MAX', () {
      expect(rizerSteerDecision(15)?.levels, 1);
      expect(rizerSteerDecision(100)?.levels, 5); // clamp to MAX
    });
  });
}
