import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({'trainer_app': 'MyWhoosh'});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  testWidgets('renders both Proxy and Virtual Shifting rows', (tester) async {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'x',
        name: 'Wahoo KICKR',
        services: const [FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID],
      ),
    );

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: ConnectionCard(device: device)),
      ),
    );
    await tester.pump();

    expect(find.text('Proxy'), findsOneWidget);
    expect(find.text('Virtual Shifting'), findsOneWidget);
    // No transport is enabled in this test (no TrainerConnection switched on),
    // so the missing-transport hint must surface on the VS row.
    expect(
      find.textContaining('Enable a Bluetooth or WiFi Trainer Connection'),
      findsOneWidget,
    );
  });

  testWidgets('exposes both Bluetooth and WiFi VS rows when target is otherDevice', (tester) async {
    SharedPreferences.setMockInitialValues({
      'trainer_app': 'MyWhoosh',
      'last_target': 'otherDevice',
    });
    core.settings.prefs = await SharedPreferences.getInstance();

    final device = ProxyDevice(
      BleDevice(
        deviceId: 'x',
        name: 'Wahoo KICKR',
        services: const [FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID],
      ),
    );

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: ConnectionCard(device: device)),
      ),
    );
    await tester.pump();

    // Two VS labels appear, distinguished by their transport-specific hints.
    expect(find.text('Virtual Shifting'), findsNWidgets(2));
    expect(find.text('Proxy'), findsOneWidget);
    expect(find.textContaining('Bluetooth-advertised trainer'), findsOneWidget);
    expect(find.textContaining('WiFi-advertised trainer'), findsOneWidget);
    // Target.otherDevice is enough to consider transport "usable", so the
    // missing-transport hint must NOT appear even with no TrainerConnection on.
    expect(
      find.textContaining('Enable a Bluetooth or WiFi Trainer Connection'),
      findsNothing,
    );
  });
}
