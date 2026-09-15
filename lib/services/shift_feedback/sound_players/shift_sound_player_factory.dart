import 'dart:io';

import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/services/shift_feedback/sound_players/just_audio_shift_sounds.dart';
import 'package:bike_control/services/shift_feedback/sound_players/silent_shift_sounds.dart';
import 'package:bike_control/services/shift_feedback/sound_players/winmm_shift_sounds.dart';
import 'package:flutter/foundation.dart';

/// Picks the clip backend for this OS. just_audio has no Windows
/// implementation in this tree, hence the winmm path there.
ShiftSoundPlayer createShiftSoundPlayer() {
  if (kIsWeb) return SilentShiftSounds();
  if (Platform.isWindows) return WinmmShiftSounds();
  if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) return JustAudioShiftSounds();
  return SilentShiftSounds();
}
