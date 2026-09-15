import 'dart:ffi';
import 'dart:io';

import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/services/shift_feedback/sound_players/shift_sound_assets.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows clip player on winmm's `PlaySound`: no audio plugin, no decoder
/// setup, ~zero latency for a bundled WAV. Flutter lays assets out next to the
/// executable under `data/flutter_assets/`, so the asset key maps straight to
/// a file path.
///
/// The wide strings are allocated once and kept for the player's lifetime —
/// `SND_ASYNC` returns before playback ends and the buffer has to outlive it.
class WinmmShiftSounds implements ShiftSoundPlayer {
  final Map<ShiftCue, Pointer<Utf16>> _paths = {};

  static String assetPath(ShiftCue cue) {
    final sep = Platform.pathSeparator;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return [exeDir, 'data', 'flutter_assets', ...shiftSoundAsset(cue).split('/')].join(sep);
  }

  @override
  Future<void> preload() async {
    for (final cue in ShiftCue.values) {
      final path = assetPath(cue);
      if (!File(path).existsSync()) {
        throw StateError('shift sound missing: $path');
      }
      _paths[cue] = path.toNativeUtf16();
    }
  }

  @override
  Future<void> play(ShiftCue cue) async {
    final path = _paths[cue];
    if (path == null) return;
    PlaySound(path, 0, SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
  }

  @override
  Future<void> dispose() async {
    // Stop anything still playing before freeing the buffers it may read.
    PlaySound(nullptr, 0, 0);
    for (final ptr in _paths.values) {
      calloc.free(ptr);
    }
    _paths.clear();
  }
}
