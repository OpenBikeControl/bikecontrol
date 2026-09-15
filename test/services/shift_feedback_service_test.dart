// ShiftFeedbackService turns "a shift happened / hit the end of the cassette"
// into phone haptics and/or a short sound, gated by two settings. The two
// sinks are injected so this covers the decision logic without touching
// HapticFeedback or an audio player.
import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHaptics implements ShiftHaptics {
  final cues = <ShiftCue>[];
  Object? throwOnPlay;

  @override
  Future<void> play(ShiftCue cue) async {
    if (throwOnPlay != null) throw throwOnPlay!;
    cues.add(cue);
  }
}

class _FakeSounds implements ShiftSoundPlayer {
  final cues = <ShiftCue>[];
  int preloads = 0;
  int disposes = 0;
  Object? throwOnPlay;

  @override
  Future<void> preload() async => preloads++;

  @override
  Future<void> play(ShiftCue cue) async {
    if (throwOnPlay != null) throw throwOnPlay!;
    cues.add(cue);
  }

  @override
  Future<void> dispose() async => disposes++;
}

void main() {
  late Settings settings;
  late _FakeHaptics haptics;
  late _FakeSounds sounds;
  late int soundPlayersCreated;
  late List<String> recordedErrors;

  ShiftFeedbackService build() => ShiftFeedbackService(
    settings: settings,
    haptics: haptics,
    createSoundPlayer: () {
      soundPlayersCreated++;
      return sounds;
    },
    onError: (context, e, s) => recordedErrors.add(context),
  );

  Future<void> seed({bool haptics = false, bool sound = false}) async {
    SharedPreferences.setMockInitialValues({
      'shift_haptics_enabled': haptics,
      'shift_sound_enabled': sound,
    });
    settings = Settings();
    settings.prefs = await SharedPreferences.getInstance();
  }

  setUp(() async {
    haptics = _FakeHaptics();
    sounds = _FakeSounds();
    soundPlayersCreated = 0;
    recordedErrors = [];
    await seed();
  });

  test('both settings default to off and nothing fires', () async {
    final service = build();
    await service.shifted(up: true);
    await service.shifted(up: false);
    await service.atLimit();

    expect(haptics.cues, isEmpty);
    expect(sounds.cues, isEmpty);
    expect(soundPlayersCreated, 0);
  });

  test('haptics only: cues map to up / down / limit, no sound player is ever created', () async {
    await seed(haptics: true);
    final service = build();

    await service.shifted(up: true);
    await service.shifted(up: false);
    await service.atLimit();

    expect(haptics.cues, [ShiftCue.up, ShiftCue.down, ShiftCue.limit]);
    expect(sounds.cues, isEmpty);
    expect(soundPlayersCreated, 0);
  });

  test('sound only: player is created and preloaded lazily on the first cue', () async {
    await seed(sound: true);
    final service = build();
    expect(soundPlayersCreated, 0);

    await service.shifted(up: false);
    await service.atLimit();

    expect(soundPlayersCreated, 1);
    expect(sounds.preloads, 1);
    expect(sounds.cues, [ShiftCue.down, ShiftCue.limit]);
    expect(haptics.cues, isEmpty);
  });

  test('prepare() preloads eagerly when sound is enabled, and not otherwise', () async {
    await seed(sound: true);
    await build().prepare();
    expect(sounds.preloads, 1);

    await seed(sound: false);
    await build().prepare();
    expect(sounds.preloads, 1, reason: 'no second preload when sound is off');
  });

  test('setSoundEnabled(true) persists, preloads and plays an "up" preview', () async {
    final service = build();
    await service.setSoundEnabled(true);

    expect(settings.getShiftSoundEnabled(), isTrue);
    expect(sounds.preloads, 1);
    expect(sounds.cues, [ShiftCue.up]);
  });

  test('setSoundEnabled(false) persists, disposes the player and later cues stay silent', () async {
    await seed(sound: true);
    final service = build();
    await service.shifted(up: true);
    expect(sounds.cues, [ShiftCue.up]);

    await service.setSoundEnabled(false);
    expect(settings.getShiftSoundEnabled(), isFalse);
    expect(sounds.disposes, 1);

    await service.shifted(up: true);
    expect(sounds.cues, [ShiftCue.up], reason: 'no new cue after disabling');
    expect(soundPlayersCreated, 1, reason: 'not re-created while disabled');
  });

  test('setHapticsEnabled(true) persists and plays an "up" preview', () async {
    final service = build();
    await service.setHapticsEnabled(true);

    expect(settings.getShiftHapticsEnabled(), isTrue);
    expect(haptics.cues, [ShiftCue.up]);

    await service.setHapticsEnabled(false);
    await service.shifted(up: true);
    expect(haptics.cues, [ShiftCue.up]);
  });

  test('uninitialised settings (before Settings.init) count as off', () async {
    settings = Settings();
    final service = build();
    await expectLater(service.shifted(up: true), completes);
    expect(haptics.cues, isEmpty);
    expect(soundPlayersCreated, 0);
  });

  test('a failing sink is recorded and never throws into the shift path', () async {
    await seed(haptics: true, sound: true);
    haptics.throwOnPlay = StateError('no vibrator');
    sounds.throwOnPlay = StateError('no audio');
    final service = build();

    await expectLater(service.shifted(up: true), completes);
    expect(recordedErrors, hasLength(2));
    expect(recordedErrors, everyElement(startsWith('ShiftFeedback')));
  });
}
