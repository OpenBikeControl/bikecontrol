import 'dart:typed_data';

/// Pure frame codec for the L-TWOO eRX/eR9 electronic-shifting BLE protocol.
///
/// Protocol source: https://github.com/eternal-flame-AD/ltwooShifting
/// (Apache-2.0). The rear derailleur is the only BLE endpoint; it speaks a
/// simple request/response protocol over the Nordic UART Service.
///
/// Request:  0xA5 + PIN (3 ASCII bytes) + device id "FFF" + opcode/payload
///           bytes + XOR of all preceding bytes.
/// Response: 0x5A + 3 pwd-field bytes (opaque: may echo the PIN or be
///           0xFF 0xFF 0xFF on unsolicited frames) + "FFF" + 2-byte big-endian
///           opcode + payload + XOR of all preceding bytes.
class LtwooProtocol {
  LtwooProtocol._();

  static const int requestHeader = 0xA5;
  static const int responseHeader = 0x5A;

  /// The fixed device-id field, ASCII "FFF".
  static const List<int> deviceIdField = [0x46, 0x46, 0x46];

  /// Hello/init: the response's payload[0] is the total number of rear gears.
  static const List<int> opcodeHello = [0x20, 0x01, 0x00];

  /// Get rear status: the response's payload[0] is the RAW rear gear index.
  static const List<int> opcodeGetRearGear = [0x09, 0x00];

  /// Get front status: the response's payload[0] is the raw front gear (1 or 2).
  static const List<int> opcodeGetFrontGear = [0x11, 0x00];

  /// Battery: the response's payload[0] is the charge percentage.
  static const List<int> opcodeGetBattery = [0x0A, 0x00];

  /// Rear remote shift, one step. Best-evidence mapping: RAW gear +1 (toward
  /// the LARGER cog, display gear down). The mapping is not certain on all
  /// hardware, so LtwooErx verifies it at runtime against the first observed
  /// counter-shift echo and flips it when the derailleur moves the other way.
  /// The response is a rear-status frame carrying the resulting raw gear.
  static const List<int> opcodeShiftRearRawIncrease = [0x00, 0x01, 0x00];

  /// Rear remote shift, one step, opposite direction: RAW gear −1 (toward the
  /// smaller cog, display gear up). Same runtime verification as
  /// [opcodeShiftRearRawIncrease].
  static const List<int> opcodeShiftRearRawDecrease = [0x01, 0x01, 0x00];

  /// Builds a request frame for [opcode] using the 3-digit ASCII [pin].
  static Uint8List buildRequest(String pin, List<int> opcode) {
    final pinBytes = pin.codeUnits;
    final body = <int>[requestHeader, ...pinBytes, ...deviceIdField, ...opcode];
    return Uint8List.fromList([...body, body.fold(0, (a, b) => a ^ b)]);
  }

  /// Parses a response frame, or returns null when [bytes] is not a valid
  /// frame (wrong header, wrong device-id field, bad XOR, too short).
  ///
  /// A frame containing the wrong-PIN marker (0xEE 0xEE 0xEE) is recognized
  /// BEFORE structural validation — its exact layout is not specified, so the
  /// header plus the marker alone yield an [LtwooResponse.wrongPin].
  static LtwooResponse? parseResponse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.first != responseHeader) return null;

    for (var i = 1; i + 2 < bytes.length; i++) {
      if (bytes[i] == 0xEE && bytes[i + 1] == 0xEE && bytes[i + 2] == 0xEE) {
        return const LtwooResponse.wrongPin();
      }
    }

    // header + pwd(3) + "FFF"(3) + opcode(2) + xor = 10 bytes minimum.
    if (bytes.length < 10) return null;

    // XOR of all bytes including the trailing checksum must cancel out to 0.
    if (bytes.fold(0, (a, b) => a ^ b) != 0) return null;

    // Bytes 1..3 are the opaque pwd field — skipped, not validated.
    if (bytes[4] != deviceIdField[0] || bytes[5] != deviceIdField[1] || bytes[6] != deviceIdField[2]) {
      return null;
    }

    final opcode = (bytes[7] << 8) | bytes[8];
    return LtwooResponse(opcode, Uint8List.sublistView(bytes, 9, bytes.length - 1));
  }

  /// RAW rear gear counts from the LARGEST cog; the display gear counts from
  /// the smallest: display = numSpeeds − raw + 1.
  static int displayGear({required int numSpeeds, required int rawGear}) => numSpeeds - rawGear + 1;
}

/// One parsed response frame.
class LtwooResponse {
  const LtwooResponse(this.opcode, this.payload) : isWrongPin = false;

  const LtwooResponse.wrongPin()
      : opcode = 0,
        payload = const [],
        isWrongPin = true;

  /// The 2-byte big-endian opcode.
  final int opcode;

  final List<int> payload;

  /// True when the derailleur rejected the request PIN (0xEE 0xEE 0xEE marker).
  final bool isWrongPin;

  /// Hello/init reply: high opcode byte 0x20; payload[0] = numSpeeds.
  bool get isHello => !isWrongPin && (opcode >> 8) == 0x20;

  /// Rear-gear frame: either a poll reply (opcode 0x09NN) or an unsolicited
  /// event frame (opcode 0xNN09 with a high byte of 0x00–0x06); in both,
  /// payload[0] is the raw rear gear.
  bool get isRearGear =>
      !isWrongPin && ((opcode >> 8) == 0x09 || ((opcode & 0xFF) == 0x09 && (opcode >> 8) <= 0x06));

  /// Front-gear frame: high opcode byte 0x11; payload[0] = raw front gear.
  bool get isFrontGear => !isWrongPin && (opcode >> 8) == 0x11;

  /// Battery reply: opcode 0x0A01; payload[0] = percent.
  bool get isBattery => !isWrongPin && opcode == 0x0A01;
}
