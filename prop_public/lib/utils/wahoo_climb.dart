//INFO: This is a stub - contact me if you need the full implementation.
//
// FAKE placeholder values — the real Wahoo Climb UUIDs / opcodes and the
// incline encoder live in the full package.

import 'dart:typed_data';

const String wahooClimbServiceUuid = '00000000-0000-0000-0000-0000000000b0';
const String wahooClimbCharacteristicUuid = '00000000-0000-0000-0000-0000000000b1';

const int wahooClimbSetInclineOpcode = 0x00;
const int wahooClimbRequestControlOpcode = 0x01;
const int wahooClimbGetTiltModeOpcode = 0x02;

const int kWahooClimbMinGrade001 = -1000;
const int kWahooClimbMaxGrade001 = 2000;

/// Stubbed: returns an empty command.
Uint8List wahooClimbInclineToBytes(int grade001Pct) => Uint8List(0);
