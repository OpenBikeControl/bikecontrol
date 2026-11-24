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
    void Function(ShimanoWiredSwitchEvent event)? onWiredSwitch,
    void Function(Uint8List frame)? onUnknownFrame,
    required void Function(String step, Object error, StackTrace stack) onStepError,
    ShimanoShifterSides? sides,
  }) =>
      throw UnsupportedError('Shimano Di2 button mode is not available in this build');

  /// The pause [writeSwitches] waits after the last press before writing.
  static const switchWriteQuiet = Duration(milliseconds: 400);

  /// Writes [switches] to its shifter and waits for the shifter to confirm.
  static Future<void> writeSwitches(
    ShimanoTransport transport,
    ShimanoShifterSwitches switches, {
    Duration quiet = switchWriteQuiet,
    Duration timeout = const Duration(minutes: 2),
    int rejectAfterPresses = 3,
    Duration rejectGrace = const Duration(seconds: 3),
    void Function(Uint8List command)? onWrite,
  }) =>
      throw UnsupportedError('Shimano Di2 switch setup is not available in this build');
}

/// Decodes the paddle presses a Di2 relays. The stub never finds any.
class ShimanoButtons {
  static List<ShimanoPaddleEvent> decode(Uint8List frame, {ShimanoShifterSides? sides}) => const [];
}

/// A press of a wired switch, reported by the Di2.
class ShimanoWiredSwitchEvent {
  const ShimanoWiredSwitchEvent(this.input, this.switchNo, this.state);

  final int input;
  final int switchNo;
  final ShimanoPaddleState state;

  /// The stub never decodes one.
  static ShimanoWiredSwitchEvent? decode(Uint8List frame) => null;
}

/// What a switch on a wireless shifter does.
enum ShimanoSwitchFunction {
  fdUp,
  fdDown,
  rdUp,
  rdUp2,
  rdDown,
  rdDown2,
  cycleComputerLeft,
  cycleComputerRight,
  assistUp,
  assistDown,
  suspensionFirmer,
  suspensionSofter,
  dflyCh1,
  dflyCh2,
  dflyCh3,
  dflyCh4,
  none,
  rdFunction,
  lamp,
  frontShiftNext,
  shiftAdjust,
  multiPurposeCh1;

  static ShimanoSwitchFunction? fromName(String name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// Which shifter is on which pairing slot. The stub learns nothing: slot 0 is
/// the left.
class ShimanoShifterSides {
  ShimanoShifter of(int slot) => slot == 0 ? ShimanoShifter.left : ShimanoShifter.right;

  void learn(ShimanoShifterSwitches switches) {}

  void learnAll(Iterable<ShimanoShifterSwitches> switches) {}

  void learnFrame(Uint8List frame) {}
}

/// The four switches of one wireless shifter, by its pairing [slot].
class ShimanoShifterSwitches {
  const ShimanoShifterSwitches({
    required this.slot,
    required this.a,
    required this.b,
    required this.c,
    required this.s,
  });

  final int slot;
  final ShimanoSwitchFunction a;
  final ShimanoSwitchFunction b;
  final ShimanoSwitchFunction c;
  final ShimanoSwitchFunction s;

  /// The stub never reads switches from a Di2.
  static ShimanoShifterSwitches? fromTelemetry(Uint8List frame) => null;

  (ShimanoSwitchFunction, ShimanoSwitchFunction) get dflyPaddles => slot == 0
      ? (ShimanoSwitchFunction.dflyCh1, ShimanoSwitchFunction.dflyCh2)
      : (ShimanoSwitchFunction.dflyCh3, ShimanoSwitchFunction.dflyCh4);

  bool get paddlesOnDfly => (a, b) == dflyPaddles;

  ShimanoShifterSwitches withDflyPaddles({ShimanoShifter? side}) {
    final (pa, pb) = dflyPaddles;
    return ShimanoShifterSwitches(slot: slot, a: pa, b: pb, c: c, s: s);
  }

  Map<String, dynamic> toJson() => {'slot': slot, 'a': a.name, 'b': b.name, 'c': c.name, 's': s.name};

  static ShimanoShifterSwitches? fromJson(Map<String, dynamic> json) {
    final [a, b, c, s] = [for (final k in ['a', 'b', 'c', 's']) ShimanoSwitchFunction.fromName('${json[k]}')];
    final slot = json['slot'];
    if (slot is! int || a == null || b == null || c == null || s == null) return null;
    return ShimanoShifterSwitches(slot: slot, a: a, b: b, c: c, s: s);
  }

  @override
  bool operator ==(Object other) =>
      other is ShimanoShifterSwitches &&
      other.slot == slot &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.s == s;

  @override
  int get hashCode => Object.hash(slot, a, b, c, s);

  @override
  String toString() => 'ShimanoShifterSwitches($slot: ${a.name}, ${b.name}, ${c.name}, ${s.name})';
}

class ShimanoSwitchWriteException implements Exception {
  ShimanoSwitchWriteException(this.message);
  final String message;

  @override
  String toString() => 'ShimanoSwitchWriteException: $message';
}

class ShimanoSwitchWriteRejectedException implements Exception {
  ShimanoSwitchWriteRejectedException(this.message);
  final String message;

  @override
  String toString() => 'ShimanoSwitchWriteRejectedException: $message';
}
