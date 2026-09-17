import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';

/// Asset key for each cue. WAV on purpose: the Windows backend hands the file
/// to winmm, which only plays WAV. See `assets/sounds/README.md` for the
/// format constraints and how to regenerate these from source.
String shiftSoundAsset(ShiftCue cue) => switch (cue) {
  ShiftCue.up => 'assets/sounds/shift_up.wav',
  ShiftCue.down => 'assets/sounds/shift_down.wav',
  ShiftCue.limit => 'assets/sounds/shift_limit.wav',
};
