import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show Locale, LucideIcons;

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  group('AlertNotification.connection', () {
    test('names the trainer app and tags the WiFi transport on connect', () {
      final notification = AlertNotification.connection(
        connected: true,
        type: ConnectionMethodType.network,
        appName: 'Zwift',
      );

      expect(notification.alertMessage, 'Connected to Zwift');
      expect(notification.connectionType, ConnectionMethodType.network);
      expect(notification.level, LogLevel.LOGLEVEL_INFO);
    });

    test('names the trainer app and tags the Bluetooth transport on disconnect', () {
      final notification = AlertNotification.connection(
        connected: false,
        type: ConnectionMethodType.bluetooth,
        appName: 'Rouvy',
      );

      expect(notification.alertMessage, 'Disconnected from Rouvy');
      expect(notification.connectionType, ConnectionMethodType.bluetooth);
    });

    test('falls back to plain copy when the trainer app is unknown', () {
      final connected = AlertNotification.connection(
        connected: true,
        type: ConnectionMethodType.network,
        appName: null,
      );
      final disconnected = AlertNotification.connection(
        connected: false,
        type: ConnectionMethodType.network,
        appName: null,
      );

      expect(connected.alertMessage, 'Connected');
      expect(disconnected.alertMessage, 'Disconnected');
      // Still tagged with the transport so the activity icon is correct.
      expect(connected.connectionType, ConnectionMethodType.network);
    });
  });

  group('ConnectionMethodType.activityIcon', () {
    test('network maps to the WiFi icon', () {
      expect(ConnectionMethodType.network.activityIcon, LucideIcons.wifi);
    });

    test('bluetooth maps to the Bluetooth icon', () {
      expect(ConnectionMethodType.bluetooth.activityIcon, LucideIcons.bluetooth);
    });
  });
}
