import 'dart:async' show TimeoutException;

import 'package:bike_control/gen/l10n.dart';
import 'package:universal_ble/universal_ble.dart';

/// Why a connect failed, in words a rider can act on — for the alert and the
/// Activity log, which used to show the Bluetooth library's raw exception
/// ("UniversalBleException: Code: UniversalBleErrorCode.deviceNotFound, …").
///
/// The library's codes fold into the few things that differ for the rider:
/// out of range, Bluetooth off, not allowed, no answer, refused, pairing, a
/// drop mid-connect. Anything else gets a plain "something went wrong"; the
/// raw error still goes to the log for support. [retrying] adds that
/// BikeControl tries again — only said when it has scheduled another attempt.
String connectErrorReason(AppLocalizations l, Object error, {bool retrying = false}) {
  final reason = _reason(l, error);
  return retrying ? '$reason ${l.connectErrorRetrying}' : reason;
}

String _reason(AppLocalizations l, Object error) {
  if (error is TimeoutException) return l.connectErrorTimeout;
  if (error is! UniversalBleException) return l.connectErrorUnknown;
  return switch (error.code) {
    UniversalBleErrorCode.deviceNotFound => l.connectErrorNotFound,
    UniversalBleErrorCode.bluetoothNotAvailable || UniversalBleErrorCode.bluetoothNotEnabled => l.connectErrorBluetoothOff,
    UniversalBleErrorCode.bluetoothNotAllowed ||
    UniversalBleErrorCode.bluetoothUnauthorized ||
    UniversalBleErrorCode.accessDenied => l.connectErrorNotAllowed,
    UniversalBleErrorCode.connectionTimeout || UniversalBleErrorCode.operationTimeout => l.connectErrorTimeout,
    UniversalBleErrorCode.connectionRejected ||
    UniversalBleErrorCode.connectionLimitExceeded ||
    UniversalBleErrorCode.connectionAlreadyExists => l.connectErrorRefused,
    UniversalBleErrorCode.notPaired ||
    UniversalBleErrorCode.notPairable ||
    UniversalBleErrorCode.pairingFailed ||
    UniversalBleErrorCode.pairingCancelled ||
    UniversalBleErrorCode.pairingTimeout ||
    UniversalBleErrorCode.pairingNotAllowed ||
    UniversalBleErrorCode.authenticationFailure ||
    UniversalBleErrorCode.insufficientAuthentication ||
    UniversalBleErrorCode.insufficientAuthorization ||
    UniversalBleErrorCode.insufficientEncryption ||
    UniversalBleErrorCode.insufficientKeySize ||
    UniversalBleErrorCode.protectionLevelNotMet => l.connectErrorPairing,
    UniversalBleErrorCode.deviceDisconnected ||
    UniversalBleErrorCode.connectionTerminated ||
    UniversalBleErrorCode.connectionFailed => l.connectErrorDropped,
    _ => l.connectErrorUnknown,
  };
}
