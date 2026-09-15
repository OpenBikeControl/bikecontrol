import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/utils/settings/settings.dart';

/// Drop-in for `core.shiftFeedback` that records what the call sites report
/// instead of vibrating / playing anything.
class RecordingShiftFeedback extends ShiftFeedbackService {
  RecordingShiftFeedback()
    : super(
        settings: Settings(),
        haptics: _NoHaptics(),
        createSoundPlayer: _NoSounds.new,
        onError: (_, _, _) {},
      );

  final cues = <ShiftCue>[];

  /// `(setting, enabled)` pairs the UI asked for, e.g. `('sound', true)`.
  final toggles = <(String, bool)>[];

  @override
  Future<void> shifted({required bool up}) async => cues.add(up ? ShiftCue.up : ShiftCue.down);

  @override
  Future<void> atLimit() async => cues.add(ShiftCue.limit);

  @override
  Future<void> setHapticsEnabled(bool enabled) async => toggles.add(('haptics', enabled));

  @override
  Future<void> setSoundEnabled(bool enabled) async => toggles.add(('sound', enabled));
}

class _NoHaptics implements ShiftHaptics {
  @override
  Future<void> play(ShiftCue cue) async {}
}

class _NoSounds implements ShiftSoundPlayer {
  @override
  Future<void> preload() async {}
  @override
  Future<void> play(ShiftCue cue) async {}
  @override
  Future<void> dispose() async {}
}
