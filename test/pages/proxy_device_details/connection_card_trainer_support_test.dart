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

  Future<void> pumpCard(WidgetTester tester, ProxyDevice device) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: ConnectionCard(device: device)),
      ),
    );
    await tester.pump();
  }

  // Power-meter-only device: not a smart trainer.
  ProxyDevice powerMeter() => ProxyDevice(
    BleDevice(
      deviceId: 'x',
      name: 'Wahoo KICKR',
      services: const [FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID],
    ),
  );

  // FTMS device: a smart trainer (Virtual Shifting takeover applies).
  ProxyDevice smartTrainer() => ProxyDevice(
    BleDevice(
      deviceId: 'y',
      name: 'KICKR CORE',
      services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
    ),
  );

  testWidgets('disconnected card shows Virtual Shifting, Proxy and No connection rows', (tester) async {
    await pumpCard(tester, powerMeter());

    expect(find.text('Virtual Shifting'), findsOneWidget);
    expect(find.text('Proxy'), findsOneWidget);
    expect(find.text('No connection'), findsOneWidget);
    // No transport is enabled and the target is not otherDevice, so the
    // missing-transport hint must surface on the VS row.
    expect(
      find.textContaining('Enable a Bluetooth or WiFi Trainer Connection'),
      findsOneWidget,
    );
  });

  testWidgets('consolidates Virtual Shifting into a single row for otherDevice', (tester) async {
    SharedPreferences.setMockInitialValues({
      'trainer_app': 'MyWhoosh',
      'last_target': 'otherDevice',
    });
    core.settings.prefs = await SharedPreferences.getInstance();

    await pumpCard(tester, powerMeter());

    // Task 4: a single consolidated VS row — the WiFi/BT toggle only appears
    // once VS is the active selection — not the old two-row BT + WiFi split.
    expect(find.text('Virtual Shifting'), findsOneWidget);
    expect(find.text('Proxy'), findsOneWidget);
    expect(find.text('No connection'), findsOneWidget);
    // Target.otherDevice always has a usable transport, so the missing-transport
    // hint must NOT appear even with no TrainerConnection enabled.
    expect(
      find.textContaining('Enable a Bluetooth or WiFi Trainer Connection'),
      findsNothing,
    );
  });

  testWidgets('No connection row carries the trainer-app subtitle', (tester) async {
    await pumpCard(tester, powerMeter());

    expect(
      find.textContaining('Let MyWhoosh handle virtual shifting'),
      findsOneWidget,
    );
  });

  testWidgets('accordion stays expanded after connecting from the picker', (tester) async {
    final device = smartTrainer();
    await pumpCard(tester, device);

    // Disconnected: the picker is expanded so the options are visible.
    expect(tester.widget<AccordionItem>(find.byType(AccordionItem)).expanded, isTrue);

    // Simulate the connect transition: a brief "connecting" state (which tears
    // the accordion down) followed by a connected state.
    device.isConnected = true;
    device.isStarting.value = true;
    await tester.pump();
    device.isStarting.value = false;
    await tester.pump();

    // Connected, but the picker must remain expanded (not collapse to the
    // bridge-status summary) — it was opened by the user to connect.
    expect(tester.widget<AccordionItem>(find.byType(AccordionItem)).expanded, isTrue);
  });

  testWidgets('selecting a connection mode on a smart trainer shows the consent dialog', (tester) async {
    await pumpCard(tester, smartTrainer());

    await tester.tap(find.text('Virtual Shifting'));
    await tester.pumpAndSettle();

    // Task 5: the consent gate fires when an entry other than "No connection"
    // is picked (the auto-connect-on-tap path is gone).
    expect(find.text('Connecting to KICKR CORE'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Cancelling leaves the device disconnected — back to the picker.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Connecting to KICKR CORE'), findsNothing);
    expect(find.text('No connection'), findsOneWidget);
  });
}
