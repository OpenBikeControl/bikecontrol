import 'dart:typed_data';

/// Elite Rizer proprietary incline control (reverse-engineered; described on its
/// own terms). The Rizer is a standalone incline + steering BLE device.
const String eliteRizerServiceUuid = '347b0001-7635-408b-8918-8ff3949ce592';
const String eliteRizerWriteCharacteristicUuid = '347b0020-7635-408b-8918-8ff3949ce592';
const String eliteRizerStatusCharacteristicUuid = '347b0021-7635-408b-8918-8ff3949ce592';
const String eliteRizerInclineCharacteristicUuid = '347b0022-7635-408b-8918-8ff3949ce592';
const String eliteRizerSteeringCharacteristicUuid = '347b0030-7635-408b-8918-8ff3949ce592';

const int eliteRizerSetInclineOpcode = 0x0a;

/// Rizer tilt range in 0.01% units (-10% .. +20%).
const int kEliteRizerMinGrade001 = -1000;
const int kEliteRizerMaxGrade001 = 2000;

/// Encodes an incline (0.01% signed) into `[0x0a, lo, hi]`, int16 LE of
/// tenths-of-a-percent (percent * 10). Clamped to the Rizer range. Gain = 1.0.
Uint8List rizerInclineToBytes(int grade001Pct) {
  final clamped = grade001Pct.clamp(kEliteRizerMinGrade001, kEliteRizerMaxGrade001);
  final tenths = (clamped / 10).round(); // 0.01% -> 0.1%
  final u = tenths & 0xFFFF;
  return Uint8List.fromList([eliteRizerSetInclineOpcode, u & 0xFF, (u >> 8) & 0xFF]);
}

/// Status code in the Rizer's reply to a command (`[0x80, opcode, code]` on
/// the status characteristic).
const int kEliteRizerAckSuccess = 0x02;

/// "Command not accessible": the Rizer is locked (red LED) and refuses
/// incline commands until it is unlocked.
const int kEliteRizerAckNotAccessible = 0x05;

/// The status code the Rizer sent for [opcode], or null when [bytes] is not
/// its reply to that command.
int? rizerAckCode(Uint8List bytes, {int opcode = eliteRizerSetInclineOpcode}) {
  if (bytes.length < 3 || bytes[0] != 0x80 || bytes[1] != opcode) return null;
  return bytes[2];
}

/// Readable name of a Rizer status code, for logs.
String rizerAckName(int code) => switch (code) {
  0 => 'wrong parameters',
  1 => 'out of range',
  2 => 'success',
  3 => 'wrong',
  4 => 'fail',
  5 => 'command not accessible',
  _ => 'unknown ($code)',
};

/// The incline the Rizer reports it is at (0.01%), from its incline
/// characteristic: byte 1 is 100 + 2 × percent (0x64 = 0%, 0x6e = +5%,
/// 0x50 = -10%). Null for a frame too short to carry it.
int? rizerReportedIncline001(Uint8List bytes) {
  if (bytes.length < 2) return null;
  return (bytes[1] - 100) * 50;
}
