// Phone vibration for shift cues. Android must NOT go through Flutter's
// HapticFeedback (View.performHapticFeedback obeys the system "touch
// feedback" setting and is a no-op when the app isn't the focused window —
// exactly the state BikeControl is in mid-ride); it uses a dedicated channel
// into the Vibrator service instead. iOS keeps the impact generators.
import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/services/shift_feedback/shift_haptics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> vibratorCalls;
  late List<MethodCall> systemCalls;

  setUp(() {
    vibratorCalls = [];
    systemCalls = [];
    messenger.setMockMethodCallHandler(PlatformShiftHaptics.channel, (call) async {
      vibratorCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      systemCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(PlatformShiftHaptics.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('Android: every cue goes to the Vibrator channel by name, never to HapticFeedback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const haptics = PlatformShiftHaptics();

    await haptics.play(ShiftCue.up);
    await haptics.play(ShiftCue.down);
    await haptics.play(ShiftCue.limit);

    expect(vibratorCalls.map((c) => c.method), ['vibrate', 'vibrate', 'vibrate']);
    expect(vibratorCalls.map((c) => c.arguments), ['up', 'down', 'limit']);
    expect(systemCalls, isEmpty);
  });

  test('iOS: cues use the impact generators via HapticFeedback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const haptics = PlatformShiftHaptics();

    await haptics.play(ShiftCue.up);
    await haptics.play(ShiftCue.limit);

    expect(vibratorCalls, isEmpty);
    expect(systemCalls.map((c) => c.method), everyElement('HapticFeedback.vibrate'));
    // up = one impact, limit = two
    expect(systemCalls, hasLength(3));
  });

  test('desktop: no-op on both channels', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await const PlatformShiftHaptics().play(ShiftCue.up);

    expect(vibratorCalls, isEmpty);
    expect(systemCalls, isEmpty);
  });
}
