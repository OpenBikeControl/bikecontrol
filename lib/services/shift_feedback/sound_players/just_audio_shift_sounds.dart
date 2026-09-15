import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/services/shift_feedback/sound_players/shift_sound_assets.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// iOS / Android / macOS clip player: one preloaded [AudioPlayer] per cue so a
/// shift only costs a seek-to-zero and play.
///
/// The audio session is configured for short, mixing sound effects: the
/// trainer app's own audio (same device, e.g. Zwift on the iPad) must never be
/// interrupted or ducked, and on iOS the ringer switch is ignored because the
/// rider explicitly turned sounds on. `handleAudioSessionActivation: false`
/// keeps just_audio from requesting Android audio focus on every click, which
/// would duck the other app for the duration of each cue.
class JustAudioShiftSounds implements ShiftSoundPlayer {
  final Map<ShiftCue, AudioPlayer> _players = {};

  @override
  Future<void> preload() async {
    await _configureSession();
    for (final cue in ShiftCue.values) {
      final player = AudioPlayer(handleAudioSessionActivation: false);
      await player.setAsset(shiftSoundAsset(cue));
      _players[cue] = player;
    }
  }

  @override
  Future<void> play(ShiftCue cue) async {
    final player = _players[cue];
    if (player == null) return;
    await player.seek(Duration.zero);
    // play() resolves when the clip finishes; don't hold the shift path.
    unawaited(player.play());
  }

  @override
  Future<void> dispose() async {
    final players = _players.values.toList();
    _players.clear();
    for (final player in players) {
      await player.dispose();
    }
  }

  Future<void> _configureSession() async {
    if (kIsWeb) return;
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.assistanceSonification,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ),
    );
    // AVPlayer activates the session implicitly, but do it once up front so
    // the first cue after enabling isn't swallowed. mixWithOthers makes this
    // side-effect free for whatever else is playing.
    if (Platform.isIOS) {
      await session.setActive(true);
    }
  }
}
