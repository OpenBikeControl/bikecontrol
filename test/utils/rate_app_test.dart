import 'package:bike_control/services/feedback_prompt_service.dart';
import 'package:bike_control/utils/rate_app.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.britannio.in_app_review');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'isAvailable' ? true : null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('Android opens the Play Store listing, never the quota-limited sheet', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await requestAppRating();
    expect(calls, ['openStoreListing']);
  });

  test('iOS asks for the in-app review sheet when available', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await requestAppRating();
    expect(calls, ['isAvailable', 'requestReview']);
  });

  group('requestAppRatingSheet (the automatic prompt)', () {
    test('asks for the sheet on Android too, never the store listing', () async {
      // The opposite of the tap path above: nobody asked for this, so being
      // thrown out of the app into the Play Store would be worse than the
      // sheet quietly showing nothing.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await requestAppRatingSheet(), isTrue);
      expect(calls, ['isAvailable', 'requestReview']);
    });

    test('does nothing, and reports so, when the sheet is unavailable', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'isAvailable' ? false : null;
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await requestAppRatingSheet(), isFalse);
      expect(calls, ['isAvailable'], reason: 'no requestReview, and no store listing either');
    });
  });

  group('showAutomaticRatingPrompt', () {
    Future<FeedbackPromptService> service() async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      settings.prefs = await SharedPreferences.getInstance();
      return FeedbackPromptService(
        settings: settings,
        trainerConnections: [ValueNotifier(false)],
        ownsPaidTier: () => true,
      );
    }

    test('goes straight to the sheet and never asks again once it was shown', () async {
      final s = await service();
      var asked = 0;
      await showAutomaticRatingPrompt(
        s,
        requestSheet: () async {
          asked++;
          return true;
        },
      );
      expect(asked, 1);
      expect(s.settings.getReviewCompleted(), isTrue);
      s.dispose();
    });

    test('a sheet that never appeared does not burn the one ask', () async {
      final s = await service();
      await showAutomaticRatingPrompt(s, requestSheet: () async => false);
      expect(
        s.settings.getReviewCompleted(),
        isFalse,
        reason: 'nothing was shown, so a later launch must be free to try again',
      );
      s.dispose();
    });

    test('a failing store API does not mark the ask as done', () async {
      final s = await service();
      await showAutomaticRatingPrompt(s, requestSheet: () async => throw PlatformException(code: 'boom'));
      expect(s.settings.getReviewCompleted(), isFalse);
      s.dispose();
    });
  });
}
