// Support pitfall: riders whose trainer app runs on this same device set the
// Virtual Shifting transport to Bluetooth — a bridge that can never be found,
// because a BLE peripheral is invisible to a central on the same adapter. Under
// Target.thisDevice the card must not offer that transport at all, and a
// Bluetooth choice saved earlier (or under another target) is folded into WiFi
// with a note saying so. Target.otherDevice keeps both transports.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  /// Seeds the prefs the card reads: the trainer app, where it runs, and the
  /// transport the rider last picked for this trainer (`retrofit_mode_<key>`).
  Future<void> seed({required String target, String? savedMode}) async {
    SharedPreferences.setMockInitialValues({
      'trainer_app': 'MyWhoosh',
      'last_target': target,
      if (savedMode != null) 'retrofit_mode_KICKR CORE': savedMode,
    });
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  }

  ProxyDevice smartTrainer() => ProxyDevice(
    BleDevice(
      deviceId: 'y',
      name: 'KICKR CORE',
      services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
    ),
  );

  /// A trainer bridged in Virtual Shifting over [mode] — the state in which the
  /// card renders the inline WiFi/Bluetooth toggle.
  ProxyDevice bridgedTrainer(RetrofitMode mode) => smartTrainer()
    ..setRetrofitMode(mode)
    ..isConnected = true;

  Future<void> pumpCard(WidgetTester tester, ProxyDevice device) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: SizedBox(width: 400, child: ConnectionCard(device: device))),
      ),
    );
    await tester.pump();
  }

  // The toggle's own button labels are the exact strings; every other mention
  // of a transport in the card is part of a longer sentence.
  final wifiButton = find.text('WiFi');
  final bluetoothButton = find.text('Bluetooth');
  final sameDeviceNote = find.textContaining("Bluetooth can't reach an app on this same device");

  group('trainer app on this device', () {
    testWidgets('the transport toggle offers WiFi only', (tester) async {
      await seed(target: 'thisDevice', savedMode: 'wifi');

      await pumpCard(tester, bridgedTrainer(RetrofitMode.wifi));

      expect(wifiButton, findsOneWidget);
      expect(bluetoothButton, findsNothing);
      // Nothing was folded, so there is nothing to explain.
      expect(sameDeviceNote, findsNothing);
    });

    testWidgets('a saved Bluetooth transport is folded into WiFi, and the card says so', (tester) async {
      await seed(target: 'thisDevice', savedMode: 'bluetooth');

      await pumpCard(tester, bridgedTrainer(RetrofitMode.wifi));

      expect(bluetoothButton, findsNothing);
      expect(wifiButton, findsOneWidget);
      expect(sameDeviceNote, findsOneWidget);
    });

    testWidgets('a bridge already live over Bluetooth is shown as such, with WiFi as the way out', (tester) async {
      // The target moved to this device mid-session, with the Bluetooth bridge
      // still up. The toggle must not claim WiFi — and must not say "using
      // WiFi" — while offering the switch.
      await seed(target: 'thisDevice', savedMode: 'bluetooth');

      await pumpCard(tester, bridgedTrainer(RetrofitMode.bluetooth));

      expect(bluetoothButton, findsOneWidget);
      expect(wifiButton, findsOneWidget);
      expect(sameDeviceNote, findsNothing);
    });

    testWidgets('the note already shows on the disconnected picker', (tester) async {
      // The rider has not connected yet; picking Virtual Shifting will start
      // over WiFi rather than their saved Bluetooth, and the card explains why
      // before they tap rather than after.
      await seed(target: 'thisDevice', savedMode: 'bluetooth');

      await pumpCard(tester, smartTrainer());

      expect(sameDeviceNote, findsOneWidget);
    });
  });

  group('trainer app on another device', () {
    testWidgets('both transports are offered and a saved Bluetooth choice stays', (tester) async {
      await seed(target: 'otherDevice', savedMode: 'bluetooth');

      await pumpCard(tester, bridgedTrainer(RetrofitMode.bluetooth));

      expect(wifiButton, findsOneWidget);
      expect(bluetoothButton, findsOneWidget);
      expect(sameDeviceNote, findsNothing);
    });

    testWidgets('no target chosen yet keeps both transports', (tester) async {
      // A rider who skipped onboarding has no target saved at all — that is
      // not "this device", so nothing is taken away.
      SharedPreferences.setMockInitialValues({'trainer_app': 'MyWhoosh'});
      core.settings.prefs = await SharedPreferences.getInstance();
      core.actionHandler = StubActions();

      await pumpCard(tester, bridgedTrainer(RetrofitMode.wifi));

      expect(wifiButton, findsOneWidget);
      expect(bluetoothButton, findsOneWidget);
      expect(sameDeviceNote, findsNothing);
    });
  });
}
