import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  testWidgets('renders header with Smart Trainer title', (tester) async {
    final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: ProxyDeviceDetailsPage(device: device),
      ),
    );
    await tester.pump();

    expect(find.text('Smart Trainer'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Disconnect & forget'), findsOneWidget);
  });

  testWidgets('FTMS warning appearing does not remount ConnectionCard (accordion survives)', (tester) async {
    final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: ProxyDeviceDetailsPage(device: device),
      ),
    );
    await tester.pump();

    // Disconnected → no FTMS warning above the ConnectionCard.
    expect(find.textContaining('does not advertise the FTMS service'), findsNothing);
    final stateBefore = tester.state(find.byType(ConnectionCard));

    // Connect a trainer that lacks FTMS VS support (no fitnessBike) so the
    // warning appears directly above the ConnectionCard. setRetrofitMode drives
    // the page rebuild via the retrofitMode listener.
    device.isConnected = true;
    device.setRetrofitMode(RetrofitMode.wifi);
    await tester.pump();

    // The warning is now shown above the card…
    expect(find.textContaining('does not advertise the FTMS service'), findsOneWidget);
    // …but the ConnectionCard must NOT have been torn down and rebuilt — its
    // State (and the accordion's open/closed state) has to survive the insertion
    // of a sibling above it.
    final stateAfter = tester.state(find.byType(ConnectionCard));
    expect(identical(stateBefore, stateAfter), isTrue);
  });

  testWidgets('ConnectionCard carries a stable key so connection-state reflows cannot remount it', (tester) async {
    // On (dis)connect, conditional siblings appear/disappear both ABOVE
    // (FTMS warning) and BELOW (gear/settings/VS-notice) the ConnectionCard.
    // When both toggle in one frame an *unkeyed* card falls into the middle of
    // the Column's child list, which Flutter deactivates and re-inflates —
    // remounting it and collapsing the accordion. A stable key keeps its
    // Element (and accordion state) across the reflow.
    final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: ProxyDeviceDetailsPage(device: device),
      ),
    );
    await tester.pump();

    expect(tester.widget(find.byType(ConnectionCard)).key, const ValueKey('connection-card'));
  });
}
