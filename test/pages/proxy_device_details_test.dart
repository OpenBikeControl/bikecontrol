// Devices → Smart Trainer: the trainer's hardware page. Is it connected, how,
// over which control protocol, and is it healthy — plus one link out to its
// virtual shifting settings, which live in Settings now. Gears, live metrics,
// the Mini Workout and the overlay are not here any more.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show OtherLocalizationsDelegate;
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/pages/proxy_device_details/control_protocol_section.dart';
import 'package:bike_control/pages/proxy_device_details/need_help_card.dart';
import 'package:bike_control/pages/proxy_device_details/self_test_card.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

import '../helpers/live_trainer.dart';

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));
  final l = AppLocalizations.current;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  tearDown(() => core.connection.devices.clear());

  Future<void> pumpPage(WidgetTester tester, ProxyDevice device) async {
    tester.view.physicalSize = const Size(430, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          const OtherLocalizationsDelegate(),
          AppLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: ProxyDeviceDetailsPage(device: device),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders header with Smart Trainer title', (tester) async {
    final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));

    await pumpPage(tester, device);

    expect(find.text(l.smartTrainer), findsOneWidget);
    expect(find.text(l.disconnectAndForgetForThisSession), findsOneWidget);
    expect(find.text(l.disconnectAndForget), findsOneWidget);
  });

  testWidgets('a shifting trainer: connection, protocol, health, one link out, disconnect', (tester) async {
    final (:proxy, :definition) = attachLiveTrainer();
    await pumpPage(tester, proxy);

    double top(Finder f) => tester.getTopLeft(f).dy;
    final connection = find.byType(ConnectionCard);
    final protocol = find.byType(ControlProtocolSection);
    final selfTest = find.byType(SelfTestCard);
    final needHelp = find.byType(NeedHelpCard);
    final link = find.byKey(const ValueKey('trainer-vs-settings'));
    final disconnect = find.text(l.disconnectAndForgetForThisSession);
    for (final f in [connection, protocol, selfTest, needHelp, link, disconnect]) {
      expect(f, findsOneWidget);
    }
    expect(top(connection), lessThan(top(protocol)));
    expect(top(protocol), lessThanOrEqualTo(top(selfTest)));
    expect(top(selfTest), lessThan(top(needHelp)));
    expect(top(needHelp), lessThan(top(link)));
    expect(top(link), lessThan(top(disconnect)));

    // What moved away: the gear hero and its drivetrain (Ride), the settings
    // and overlay (Settings), the live metrics and the Mini Workout (Ride).
    expect(find.byType(DrivetrainView), findsNothing);
    expect(find.text(l.overlaySection), findsNothing);
    expect(find.text(l.miniWorkout), findsNothing);
    expect(find.text(l.bikeWeight), findsNothing);
    expect(find.text(l.gearSettings), findsNothing);
    expect(tester.takeException(), isNull);

    // Need help? is the secondary action; the self-test keeps the primary.
    final help = tester.widget<Button>(find.byKey(const ValueKey('need-help-open')));
    expect(help.style, ButtonVariance.secondary);
  });

  testWidgets('Virtual Shifting Settings opens the settings page', (tester) async {
    final (:proxy, :definition) = attachLiveTrainer();
    await pumpPage(tester, proxy);

    final link = find.byKey(const ValueKey('trainer-vs-settings'));
    expect(find.descendant(of: link, matching: find.text(l.virtualShiftingSettings)), findsOneWidget);
    await tester.tap(link);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VirtualShiftingSettingsPage), findsOneWidget);
    // Opening the settings pushes the active config to the definition, which
    // opens its one-shot control-write pacing window; let it close.
    await tester.pump(FitnessBikeDefinition.minControlWriteInterval);
  });

  testWidgets('FTMS warning appearing does not remount ConnectionCard (accordion survives)', (tester) async {
    final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));

    await pumpPage(tester, device);

    final warning = l.trainerMissingFtmsWarning(device.name);
    expect(find.text(warning), findsNothing);
    final stateBefore = tester.state(find.byType(ConnectionCard));

    // Connect a trainer that lacks FTMS VS support (no fitnessBike) so the
    // warning appears directly above the ConnectionCard. setRetrofitMode drives
    // the page rebuild via the retrofitMode listener.
    device.isConnected = true;
    device.setRetrofitMode(RetrofitMode.wifi);
    await tester.pump();

    expect(find.text(warning), findsOneWidget);
    final stateAfter = tester.state(find.byType(ConnectionCard));
    expect(identical(stateBefore, stateAfter), isTrue);
  });

  testWidgets('ConnectionCard carries a stable key so connection-state reflows cannot remount it', (tester) async {
    final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));

    await pumpPage(tester, device);

    expect(tester.widget(find.byType(ConnectionCard)).key, const ValueKey('connection-card'));
  });
}
