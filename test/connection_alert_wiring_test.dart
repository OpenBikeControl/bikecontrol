import 'package:bike_control/bluetooth/devices/zwift/rouvy_mdns_emulator.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'trainer_app': 'Zwift'});
    core.settings.prefs = await SharedPreferences.getInstance();
  });

  group('RouvyMdnsEmulator connection alerts', () {
    test('signals "Connected to <app>" tagged with the WiFi transport on connect', () async {
      final click = ClickEmulator();
      final emulator = RouvyMdnsEmulator(clickEmulator: click);
      addTearDown(emulator.stop);

      final alerts = <AlertNotification>[];
      final sub = core.connection.actionStream
          .where((n) => n is AlertNotification)
          .cast<AlertNotification>()
          .listen(alerts.add);
      addTearDown(sub.cancel);

      click.isConnected.value = true;
      await pumpEventQueue();

      expect(alerts, isNotEmpty);
      expect(alerts.last.alertMessage, 'Connected to Zwift');
      expect(alerts.last.connectionType, ConnectionMethodType.network);
    });

    test('signals "Disconnected from <app>" tagged with the WiFi transport on disconnect', () async {
      final click = ClickEmulator();
      final emulator = RouvyMdnsEmulator(clickEmulator: click);
      addTearDown(emulator.stop);

      final alerts = <AlertNotification>[];
      final sub = core.connection.actionStream
          .where((n) => n is AlertNotification)
          .cast<AlertNotification>()
          .listen(alerts.add);
      addTearDown(sub.cancel);

      click.isConnected.value = true;
      await pumpEventQueue();
      click.isConnected.value = false;
      await pumpEventQueue();

      expect(alerts.last.alertMessage, 'Disconnected from Zwift');
      expect(alerts.last.connectionType, ConnectionMethodType.network);
    });
  });
}
