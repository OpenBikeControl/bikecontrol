import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/elite/elite_rizer.dart';
import 'package:bike_control/bluetooth/devices/gamepad/gamepad_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// The settings page an accessory card opens.
///
/// Its reason to exist for an accessory is the forget action: that is the only
/// route onto the ignore list, and therefore the only way to get rid of a
/// Headwind that belongs to the neighbour rather than the rider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The page's Pro badge reaches IAPManager, which reaches Supabase.instance;
  // give it an offline dummy instance (no session, so no request is made).
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'accessory-settings-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    await AppLocalizations.load(const Locale('en'));
    // `core` is a process-wide singleton, so each case starts from an empty
    // device list rather than inheriting the previous one's controller.
    core.connection.devices.clear();
  });

  tearDown(() => core.connection.devices.clear());

  Future<void> pumpSettings(WidgetTester tester, BluetoothDevice device) async {
    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: ControllerSettingsPage(device: device),
      ),
    );
    // Not pumpAndSettle: a disconnected device's StatusIcon spins forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  WahooKickrHeadwind headwind() => WahooKickrHeadwind(BleDevice(deviceId: 'hw-1', name: 'HEADWIND F123'));

  testWidgets('offers the forget action that puts the accessory on the ignore list', (tester) async {
    await pumpSettings(tester, headwind());

    expect(find.text(AppLocalizations.current.disconnectAndForget), findsOneWidget);
  });

  testWidgets('is titled for a device, not a controller', (tester) async {
    await pumpSettings(tester, headwind());

    expect(find.text(AppLocalizations.current.deviceSettings), findsOneWidget);
    expect(find.text(AppLocalizations.current.controllerSettings), findsNothing);
  });

  // A fan has no buttons, so a mapping table would be an empty promise.
  testWidgets('drops the button-mapping section for an accessory', (tester) async {
    await pumpSettings(tester, headwind());

    expect(find.text(AppLocalizations.current.buttonMapping), findsNothing);
  });

  // What replaces it: the fan's actions live on a *controller's* buttons, so
  // the page names them and points at the controller that can carry them.
  group('assignable actions', () {
    testWidgets('lists what the accessory can be told to do', (tester) async {
      await pumpSettings(tester, headwind());

      expect(find.text(InGameAction.headwindSpeed.title), findsOneWidget);
      expect(find.text(InGameAction.headwindSpeedInc.title), findsOneWidget);
      expect(find.text(InGameAction.headwindHeartRateMode.title), findsOneWidget);
    });

    testWidgets('points at the connected controller that can carry them', (tester) async {
      core.connection.devices.add(GamepadDevice('Pro Controller', id: 'pad-1')..isConnected = true);

      await pumpSettings(tester, headwind());

      expect(
        find.text(AppLocalizations.current.accessorySetUpOnController('Pro Controller')),
        findsOneWidget,
      );
    });

    testWidgets('names the actions even with no controller to send them to', (tester) async {
      await pumpSettings(tester, headwind());

      expect(find.text(InGameAction.headwindSpeed.title), findsOneWidget);
      expect(find.textContaining(AppLocalizations.current.accessoryNoControllerYet), findsOneWidget);
    });
  });

  // The fan is driven straight from its page too, not only from a controller.
  group('direct control', () {
    WahooKickrHeadwind recording(List<List<int>> writes) =>
        headwind()..debugWriteSink = (Uint8List bytes) async => writes.add(bytes.toList());

    testWidgets('a speed button switches to manual mode and sets that speed', (tester) async {
      final writes = <List<int>>[];
      final device = recording(writes);
      await pumpSettings(tester, device);

      await tester.ensureVisible(find.byKey(const ValueKey('headwind-speed-50')));
      await tester.tap(find.byKey(const ValueKey('headwind-speed-50')));
      await tester.pump();

      expect(writes, [
        [0x04, 0x04],
        [0x02, 50],
      ]);
      expect(device.mode.value, HeadwindMode.manual);
      expect(device.speed.value, 50);
      expect(
        find.descendant(of: find.byKey(const ValueKey('headwind-current')), matching: find.text('50%')),
        findsOneWidget,
      );
    });

    testWidgets('the heart-rate switch puts the fan into heart-rate mode', (tester) async {
      final writes = <List<int>>[];
      final device = recording(writes);
      await pumpSettings(tester, device);

      await tester.ensureVisible(find.byKey(const ValueKey('headwind-heart-rate')));
      await tester.tap(find.byKey(const ValueKey('headwind-heart-rate')));
      await tester.pump();

      expect(writes, [
        [0x04, 0x02],
      ]);
      expect(device.mode.value, HeadwindMode.heartRate);
    });

    testWidgets('reflects the state the fan reports', (tester) async {
      final device = headwind();
      await pumpSettings(tester, device);

      await device.processCharacteristic('', Uint8List.fromList([0xFD, 0x01, 75, 0x04]));
      await tester.pump();

      expect(
        find.descendant(of: find.byKey(const ValueKey('headwind-current')), matching: find.text('75%')),
        findsOneWidget,
      );
    });
  });

  // The Rizer gives incline and steering, not buttons: it is listed with the
  // accessories, not with the controllers.
  group('Elite Rizer', () {
    EliteRizer rizer() => EliteRizer(BleDevice(deviceId: 'rizer-1', name: 'RIZER'));

    test('counts as an accessory, not a controller', () {
      final device = rizer();
      core.connection.devices.add(device);

      expect(core.connection.allAccessories, contains(device));
      expect(core.connection.controllerDevices, isNot(contains(device)));
    });

    testWidgets('its page is titled for a device', (tester) async {
      await pumpSettings(tester, rizer());

      expect(find.text(AppLocalizations.current.deviceSettings), findsOneWidget);
    });
  });
}
