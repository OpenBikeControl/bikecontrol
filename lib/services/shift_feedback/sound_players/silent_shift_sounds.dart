import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';

/// Platforms without a clip backend (web, Linux): sounds toggle is a no-op.
class SilentShiftSounds implements ShiftSoundPlayer {
  @override
  Future<void> preload() async {}

  @override
  Future<void> play(ShiftCue cue) async {}

  @override
  Future<void> dispose() async {}
}
