import 'package:bike_control/services/review_prompt_service.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    settings.prefs = await SharedPreferences.getInstance();
  });

  group('ReviewPromptService', () {
    test('does not show banner before threshold', () async {
      final trainer = ValueNotifier(false);
      final service = ReviewPromptService(
        settings: settings,
        trainerConnections: [trainer],
        isMobilePlatform: true,
      );
      service.start();

      trainer.value = true;
      await Future.value();

      expect(settings.getReviewSessionCount(), 1);
      expect(service.shouldShowBanner.value, false);

      service.dispose();
    });

    test('counts at most once per app launch even if connection toggles', () async {
      final trainer = ValueNotifier(false);
      final service = ReviewPromptService(
        settings: settings,
        trainerConnections: [trainer],
        isMobilePlatform: true,
      );
      service.start();

      trainer.value = true;
      trainer.value = false;
      trainer.value = true;
      trainer.value = false;
      trainer.value = true;
      await Future.value();

      expect(settings.getReviewSessionCount(), 1);

      service.dispose();
    });

    test('shows banner once threshold reached on a fresh launch', () async {
      await settings.setReviewSessionCount(2);

      final trainer = ValueNotifier(false);
      final service = ReviewPromptService(
        settings: settings,
        trainerConnections: [trainer],
        isMobilePlatform: true,
      );
      service.start();

      trainer.value = true;
      await Future.value();

      expect(settings.getReviewSessionCount(), 3);
      expect(service.shouldShowBanner.value, true);

      service.dispose();
    });

    test('does not show banner on non-mobile platforms', () async {
      await settings.setReviewSessionCount(10);

      final trainer = ValueNotifier(true);
      final service = ReviewPromptService(
        settings: settings,
        trainerConnections: [trainer],
        isMobilePlatform: false,
      );
      service.start();
      await Future.value();

      expect(service.shouldShowBanner.value, false);

      service.dispose();
    });

    test('markCompleted hides banner forever', () async {
      await settings.setReviewSessionCount(3);

      final trainer = ValueNotifier(false);
      final service = ReviewPromptService(
        settings: settings,
        trainerConnections: [trainer],
        isMobilePlatform: true,
      );
      service.start();
      trainer.value = true;
      await Future.value();
      expect(service.shouldShowBanner.value, true);

      await service.markCompleted();

      expect(service.shouldShowBanner.value, false);
      expect(settings.getReviewCompleted(), true);

      service.dispose();
      final next = ReviewPromptService(
        settings: settings,
        trainerConnections: [ValueNotifier(true)],
        isMobilePlatform: true,
      );
      next.start();
      await Future.value();
      expect(next.shouldShowBanner.value, false);
      next.dispose();
    });

    test('dismiss snoozes for 10 sessions then re-shows', () async {
      await settings.setReviewSessionCount(3);

      final trainer = ValueNotifier(false);
      final service = ReviewPromptService(
        settings: settings,
        trainerConnections: [trainer],
        isMobilePlatform: true,
      );
      service.start();
      trainer.value = true;
      await Future.value();
      expect(service.shouldShowBanner.value, true);

      await service.dismiss();
      expect(service.shouldShowBanner.value, false);
      expect(settings.getReviewDismissedAtSessionCount(), 4);

      service.dispose();

      await settings.setReviewSessionCount(13);
      var snoozed = ReviewPromptService(
        settings: settings,
        trainerConnections: [ValueNotifier(true)],
        isMobilePlatform: true,
      );
      snoozed.start();
      await Future.value();
      expect(snoozed.shouldShowBanner.value, false);
      snoozed.dispose();

      await settings.setReviewSessionCount(14);
      var reshown = ReviewPromptService(
        settings: settings,
        trainerConnections: [ValueNotifier(true)],
        isMobilePlatform: true,
      );
      reshown.start();
      await Future.value();
      expect(reshown.shouldShowBanner.value, true);
      reshown.dispose();
    });

    test('no trainer connection in this launch leaves session count untouched', () async {
      await settings.setReviewSessionCount(2);

      final trainer = ValueNotifier(false);
      final service = ReviewPromptService(
        settings: settings,
        trainerConnections: [trainer],
        isMobilePlatform: true,
      );
      service.start();
      await Future.value();

      expect(settings.getReviewSessionCount(), 2);
      expect(service.shouldShowBanner.value, false);

      service.dispose();
    });
  });
}
