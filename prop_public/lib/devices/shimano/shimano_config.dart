//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation authenticates with a Shimano Di2 junction and
// switches it into button mode. This stub keeps the static surface so the app
// compiles.

import 'dart:async';
import 'dart:typed_data';

/// BLE seam for the Shimano protocol code. The app supplies a `universal_ble`
/// backed implementation; tests supply a fake.
abstract class ShimanoTransport {
  Future<void> subscribe(String characteristic);
  Future<void> write(String characteristic, Uint8List data, {bool withoutResponse = false});
  Future<Uint8List> read(String characteristic);

  /// Notifications delivered on [characteristic] after [subscribe].
  Stream<Uint8List> notifications(String characteristic);
}

/// Characteristics of the Di2 config service. FAKE placeholder UUIDs.
class ShimanoDi2Config {
  static const String pceResponseChar = '00000000-0000-0000-0000-0000000000d1';
  static const String authControlChar = '00000000-0000-0000-0000-0000000000d2';
  static const String pceAuxNotify1 = '00000000-0000-0000-0000-0000000000d3';
  static const String pceAuxNotify2 = '00000000-0000-0000-0000-0000000000d4';
}

class ShimanoAuth {
  static const String defaultPasskey = '000000';
}

class ShimanoAuthException implements Exception {
  ShimanoAuthException(this.message);

  final String message;

  @override
  String toString() => 'ShimanoAuthException: $message';
}

class ShimanoPasskeyRejectedException implements Exception {}

enum ShimanoShifter { left, right }

enum ShimanoPaddle { big, small, hood, satellite }

enum ShimanoPaddleState { down, released, held }

class ShimanoPaddleEvent {
  const ShimanoPaddleEvent(this.shifter, this.paddle, this.state);

  final ShimanoShifter shifter;
  final ShimanoPaddle paddle;
  final ShimanoPaddleState state;
}

/// A running button-mode session; [close] ends it.
class ShimanoButtonSession {
  Future<void> close() async {}
}

class ShimanoConfig {
  static Future<void> authenticate(ShimanoTransport transport, {required String passkey}) =>
      throw UnsupportedError('Shimano Di2 button mode is not available in this build');

  static Future<ShimanoButtonSession> enterButtonMode(
    ShimanoTransport transport, {
    required void Function(ShimanoPaddleEvent event) onPaddle,
    void Function(Uint8List frame)? onUnknownFrame,
    void Function(int step, Object error, StackTrace stackTrace)? onStepError,
  }) =>
      throw UnsupportedError('Shimano Di2 button mode is not available in this build');
}
