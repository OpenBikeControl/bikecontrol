import 'package:bike_control/pages/overview.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowConnectionAlertToast', () {
    bool show({
      bool screenshotMode = false,
      bool frontmost = true,
      double width = 400,
      AppSection section = AppSection.ride,
      required bool connection,
    }) => shouldShowConnectionAlertToast(
      screenshotMode: screenshotMode,
      overviewFrontmost: frontmost,
      screenWidth: width,
      section: section,
      isConnectionAlert: connection,
    );

    test('connection alert on Ride is suppressed: the connection card already shows it', () {
      expect(show(connection: true), isFalse);
      expect(show(connection: true, width: 1000), isFalse);
    });

    test('non-connection alert on a phone Ride still shows', () {
      expect(show(connection: false), isTrue);
    });

    test('non-connection alert on a tablet Ride still shows', () {
      expect(show(connection: false, width: 1000), isTrue);
    });

    test('connection alert while another route is pushed still shows', () {
      expect(show(connection: true, frontmost: false), isTrue);
    });

    test('connection alert on Devices or Settings shows: the card is not on screen', () {
      expect(show(connection: true, section: AppSection.devices), isTrue);
      expect(show(connection: true, section: AppSection.settings), isTrue);
    });

    test('nothing is toasted while the activity log itself is on screen', () {
      expect(show(connection: true, section: AppSection.activity), isFalse);
      expect(show(connection: false, section: AppSection.activity), isFalse);
    });

    test('Ride in a wide window has no activity log beside it: an error still toasts', () {
      expect(show(connection: false, width: 1300), isTrue);
      expect(show(connection: false, width: 1600), isTrue);
    });

    test('screenshot mode never shows a toast', () {
      expect(show(connection: false, screenshotMode: true, frontmost: false), isFalse);
    });
  });
}
