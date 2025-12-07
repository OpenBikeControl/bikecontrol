class SMTCWindows {
  SMTCWindows({required MusicMetadata metadata, required PlaybackTimeline timeline, required SMTCConfig config}) {}

  get buttonPressStream => null;

  void disableSmtc() {}

  static Future<void> initialize() async {}
}

enum PressedButton { play, pause, next, previous, fastForward, rewind, stop, record, channelUp, channelDown }

class MusicMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? thumbnail;

  const MusicMetadata({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.thumbnail,
  });
}

class PlaybackTimeline {
  final int startTimeMs;
  final int endTimeMs;
  final int positionMs;
  final int? minSeekTimeMs;
  final int? maxSeekTimeMs;

  const PlaybackTimeline({
    required this.startTimeMs,
    required this.endTimeMs,
    required this.positionMs,
    this.minSeekTimeMs,
    this.maxSeekTimeMs,
  });
}

class SMTCConfig {
  final bool playEnabled;
  final bool pauseEnabled;
  final bool stopEnabled;
  final bool nextEnabled;
  final bool prevEnabled;
  final bool fastForwardEnabled;
  final bool rewindEnabled;

  const SMTCConfig({
    required this.playEnabled,
    required this.pauseEnabled,
    required this.stopEnabled,
    required this.nextEnabled,
    required this.prevEnabled,
    required this.fastForwardEnabled,
    required this.rewindEnabled,
  });
}
