import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    settings.prefs = await SharedPreferences.getInstance();
  });

  group('Review prompt settings', () {
    test('session count defaults to 0', () {
      expect(settings.getReviewSessionCount(), 0);
    });

    test('session count round-trips', () async {
      await settings.setReviewSessionCount(3);
      expect(settings.getReviewSessionCount(), 3);
    });

    test('completed flag defaults to false', () {
      expect(settings.getReviewCompleted(), false);
    });

    test('completed flag round-trips', () async {
      await settings.setReviewCompleted(true);
      expect(settings.getReviewCompleted(), true);
    });

    test('dismissed-at session count defaults to null', () {
      expect(settings.getReviewDismissedAtSessionCount(), null);
    });

    test('dismissed-at session count round-trips', () async {
      await settings.setReviewDismissedAtSessionCount(5);
      expect(settings.getReviewDismissedAtSessionCount(), 5);
    });

    test('clearing dismissed-at removes the key', () async {
      await settings.setReviewDismissedAtSessionCount(5);
      await settings.setReviewDismissedAtSessionCount(null);
      expect(settings.getReviewDismissedAtSessionCount(), null);
    });
  });
}
