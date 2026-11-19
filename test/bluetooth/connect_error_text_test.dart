// A failed connect used to put the Bluetooth library's raw exception in the
// alert and the Activity log ("UniversalBleException: Code:
// UniversalBleErrorCode.deviceNotFound, Message: Unknown deviceId …"). The
// rider now gets the reason in words.
import 'dart:async';

import 'package:bike_control/bluetooth/connect_error_text.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  late AppLocalizations l;
  setUpAll(() async => l = await AppLocalizations.load(const Locale('en')));

  UniversalBleException ble(UniversalBleErrorCode code) =>
      UniversalBleException(code: code, message: 'Unknown deviceId: C3:8F:C4:9A:2E:7E', details: 'DEVICE_NOT_FOUND');

  test('each code reads as what the rider can do about it', () {
    expect(connectErrorReason(l, ble(UniversalBleErrorCode.deviceNotFound)), l.connectErrorNotFound);
    expect(connectErrorReason(l, ble(UniversalBleErrorCode.bluetoothNotEnabled)), l.connectErrorBluetoothOff);
    expect(connectErrorReason(l, ble(UniversalBleErrorCode.bluetoothUnauthorized)), l.connectErrorNotAllowed);
    expect(connectErrorReason(l, ble(UniversalBleErrorCode.connectionTimeout)), l.connectErrorTimeout);
    expect(connectErrorReason(l, TimeoutException('connect')), l.connectErrorTimeout);
    expect(connectErrorReason(l, ble(UniversalBleErrorCode.connectionRejected)), l.connectErrorRefused);
    expect(connectErrorReason(l, ble(UniversalBleErrorCode.pairingFailed)), l.connectErrorPairing);
    expect(connectErrorReason(l, ble(UniversalBleErrorCode.connectionTerminated)), l.connectErrorDropped);
    expect(connectErrorReason(l, ble(UniversalBleErrorCode.unknownError)), l.connectErrorUnknown);
    expect(connectErrorReason(l, StateError('boom')), l.connectErrorUnknown);
  });

  test('never the raw exception', () {
    for (final code in UniversalBleErrorCode.values) {
      final text = connectErrorReason(l, ble(code));
      expect(text, isNot(contains('UniversalBle')), reason: '$code');
      expect(text, isNot(contains('deviceId')), reason: '$code');
    }
  });

  test('says BikeControl tries again only when it does', () {
    final error = ble(UniversalBleErrorCode.deviceNotFound);
    expect(connectErrorReason(l, error, retrying: true), '${l.connectErrorNotFound} ${l.connectErrorRetrying}');
    expect(connectErrorReason(l, error), isNot(contains(l.connectErrorRetrying)));
  });
}
