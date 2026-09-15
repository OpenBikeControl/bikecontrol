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
  /// [createPlayer] / [configureSession] exist so tests can substitute a
  /// recording player and skip the platform audio session.
  JustAudioShiftSounds({AudioPlayer Function()? createPlayer, Future<void> Function()? configureSession})
    : _createPlayer = createPlayer ?? _defaultCreatePlayer,
      _configureSession = configureSession ?? _defaultConfigureSession;

  final AudioPlayer Function() _createPlayer;
  final Future<void> Function() _configureSession;
  final Map<ShiftCue, AudioPlayer> _players = {};

  /// Multiplier on the device media volume: the generated clips are
  /// full-scale and far too loud next to the trainer app's own audio.
  static const double shiftSoundVolume = 0.3;

  static AudioPlayer _defaultCreatePlayer() => AudioPlayer(handleAudioSessionActivation: false);

  @override
  Future<void> preload() async {
    await _configureSession();
    for (final cue in ShiftCue.values) {
      final player = _createPlayer();
      await player.setAsset(shiftSoundAsset(cue));
      await player.setVolume(shiftSoundVolume);
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

  static Future<void> _defaultConfigureSession() async {
    if (kIsWeb) return;
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        // usage.media → STREAM_MUSIC: follows the media volume like the
        // trainer app's own audio. (assistanceSonification lands on
        // STREAM_SYSTEM, which the ringer's silent/vibrate mode mutes.)
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.media,
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
