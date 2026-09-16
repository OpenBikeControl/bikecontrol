import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
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

  testWidgets('disconnected bridge row shows "Not connected", not the connect instruction', (tester) async {
    await pumpCard(tester, powerMeter());

    // While disconnected ("No connection" selected) the bridge isn't advertising,
    // so the "Choose BikeControl in the connection screen" instruction is wrong —
    // it must read "Not connected" instead.
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.textContaining('Choose BikeControl in the connection screen'), findsNothing);
  });

  testWidgets('connecting keeps the bridge accordion and shows no "Connecting in … mode" card', (tester) async {
    final device = smartTrainer();
    await pumpCard(tester, device);

    device.isStarting.value = true;
    await tester.pump();

    // The bridge accordion view must remain — progress is shown inline (a spinner
    // in the status icon), not by swapping the whole card for a placeholder.
    expect(find.byType(AccordionItem), findsOneWidget);
    expect(find.textContaining('Connecting in'), findsNothing);
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

  // Reproduces the proxy_device_details Column reconciliation: on (dis)connect,
  // conditional widgets toggle both ABOVE (FTMS warning) and BELOW (gear /
  // settings / VS-notice) the ConnectionCard in the same frame. A widget
  // trapped between two toggling siblings lands in the *middle* of the child
  // list, which Flutter deactivates and re-inflates (no key to match) — so the
  // card is remounted and its accordion collapses. A stable key prevents this.
  Widget reflowHarness({required Key? cardKey, required ValueNotifier<bool> connected, required ProxyDevice device}) {
    return ShadcnApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(
        child: ValueListenableBuilder<bool>(
          valueListenable: connected,
          builder: (context, c, _) => Column(
            children: [
              if (c) const Text('warning-above'),
              ConnectionCard(key: cardKey, device: device),
              if (c) const Text('notice-below'),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('unkeyed ConnectionCard trapped between toggling siblings is remounted (the bug)', (tester) async {
    final connected = ValueNotifier(true);
    await tester.pumpWidget(reflowHarness(cardKey: null, connected: connected, device: powerMeter()));
    await tester.pump();
    final before = tester.state(find.byType(ConnectionCard));

    connected.value = false; // both the above and below siblings vanish at once
    await tester.pump();
    final after = tester.state(find.byType(ConnectionCard));

    expect(identical(before, after), isFalse);
  });

  testWidgets('keyed ConnectionCard is reused across the reflow → accordion state survives (the fix)', (tester) async {
    final connected = ValueNotifier(true);
    await tester.pumpWidget(
      reflowHarness(cardKey: const ValueKey('connection-card'), connected: connected, device: powerMeter()),
    );
    await tester.pump();
    final before = tester.state(find.byType(ConnectionCard));

    connected.value = false;
    await tester.pump();
    final after = tester.state(find.byType(ConnectionCard));

    expect(identical(before, after), isTrue);
  });

  // Twins (the same trainer listed over Bluetooth and WiFi) both bridge through
  // the one shared ftmsEmulator. The bridge status row used to read that
  // emulator's state directly, so the page of the entry that was released in a
  // path switch showed the *other* entry's green "connected" dot next to its
  // own "No connection" radio — two trainer pages both claiming the bridge.
  testWidgets('a released twin does not show the live twin\'s bridge as its own', (tester) async {
    // A Virtual Shifting session over WiFi, then released in place (the path
    // switch): wrappers reset and detached, the mode left as it was. The
    // teardown awaits real transport/emulator futures, hence runAsync.
    final released = smartTrainer()..setRetrofitMode(RetrofitMode.wifi);
    await tester.runAsync(() => released.disconnect());
    expect(released.isBridged, isFalse);

    // The other entry's bridge is live on the shared emulator.
    ftmsEmulator.isStarted.value = true;
    ftmsEmulator.isConnected.value = true;
    addTearDown(() {
      ftmsEmulator.isStarted.value = false;
      ftmsEmulator.isConnected.value = false;
    });

    await pumpCard(tester, released);

    final status = tester.widget<StatusIcon>(find.byType(StatusIcon));
    expect(status.status, isFalse, reason: 'the green dot belongs to the other entry');
    expect(status.started, isFalse);
    expect(find.text('Not connected'), findsOneWidget);
  });

  // The virtual-shifting takeover explainer that used to gate this tap is gone:
  // picking a mode is the rider's decision, and acting on it immediately is the
  // point. There is no widget test for its absence because there is nothing left
  // to assert against — showSmartTrainerConsentDialog no longer exists, so
  // bringing the gate back could not compile. What the gate actually affected —
  // whether a smart trainer may auto-connect on intent alone — is covered in
  // test/integration/virtual_shifting_connection_logic_test.dart.
}
