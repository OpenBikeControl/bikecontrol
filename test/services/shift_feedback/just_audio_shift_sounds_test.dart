import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/services/shift_feedback/sound_players/just_audio_shift_sounds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

/// Records the calls [JustAudioShiftSounds] makes instead of touching the
/// platform player. The base constructor is pure Dart once interruption
/// handling (which resolves [AudioSession.instance]) is off, so this is safe
/// in a unit test as long as nothing reaches the method channel.
class _RecordingPlayer extends AudioPlayer {
  _RecordingPlayer() : super(handleAudioSessionActivation: false, handleInterruptions: false);

  final List<String> calls = [];

  @override
  Future<Duration?> setAsset(
    String assetPath, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async {
    calls.add('setAsset:$assetPath');
    return null;
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('setVolume:$volume');
  }
}

void main() {
  test('preload sets every cue player to the shift sound volume after loading the asset', () async {
    final players = <_RecordingPlayer>[];
    final sounds = JustAudioShiftSounds(
      createPlayer: () {
        final player = _RecordingPlayer();
        players.add(player);
        return player;
      },
      configureSession: () async {},
    );

    await sounds.preload();

    expect(players, hasLength(ShiftCue.values.length));
    for (final player in players) {
      final setAsset = player.calls.indexWhere((c) => c.startsWith('setAsset:'));
      final setVolume = player.calls.indexOf('setVolume:${JustAudioShiftSounds.shiftSoundVolume}');
      expect(setAsset, isNot(-1), reason: 'asset must be loaded: ${player.calls}');
      expect(setVolume, greaterThan(setAsset), reason: 'volume must be set after the asset: ${player.calls}');
    }
    expect(JustAudioShiftSounds.shiftSoundVolume, 0.3);

    await sounds.dispose();
  });
}
