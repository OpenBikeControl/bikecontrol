import 'package:bike_control/bluetooth/native_ble_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

/// universal_ble's native errors reach the support log, without a failing
/// callback flooding it (GH #451).
void main() {
  late List<String> lines;
  late DateTime now;
  late NativeBleLog log;

  setUp(() {
    lines = [];
    now = DateTime(2026, 11, 9, 12);
    log = NativeBleLog(sink: lines.add, clock: () => now);
  });

  test('writes an error and a warning with their level', () {
    log.handle(BleLogLevel.error, 'PERIPHERAL_READ_REQ response hresult_error hr=-2147483629');
    log.handle(BleLogLevel.warning, 'DisposeConnection: failed to close Bluetooth device');

    expect(lines, [
      'BLE native error: PERIPHERAL_READ_REQ response hresult_error hr=-2147483629',
      'BLE native warning: DisposeConnection: failed to close Bluetooth device',
    ]);
  });

  test('holds back a repeat within the window and counts it when it comes back', () {
    for (var i = 0; i < 5; i++) {
      log.handle(BleLogLevel.error, 'boom');
      now = now.add(const Duration(seconds: 1));
    }
    expect(lines, ['BLE native error: boom']);

    now = now.add(const Duration(seconds: 30));
    log.handle(BleLogLevel.error, 'boom');

    expect(lines, ['BLE native error: boom', 'BLE native error: boom (+4 more since last logged)']);
  });

  test('different messages are not held back by each other', () {
    log.handle(BleLogLevel.error, 'a');
    log.handle(BleLogLevel.error, 'b');

    expect(lines, ['BLE native error: a', 'BLE native error: b']);
  });

  test('tracks a bounded number of messages', () {
    for (var i = 0; i < 150; i++) {
      log.handle(BleLogLevel.error, 'msg $i');
    }
    expect(lines, hasLength(150));
    // The oldest were evicted, so they are written again rather than held.
    log.handle(BleLogLevel.error, 'msg 0');
    expect(lines.last, 'BLE native error: msg 0');
  });
}
