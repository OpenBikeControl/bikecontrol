import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // performInGameAction → handleTrainerAction reads AppLocalizations.current for
  // its result messages, so we initialise the EN bundle once before any test.
  await AppLocalizations.load(const Locale('en'));

  // performInGameAction → IAPManager.incrementCommandCount reaches
  // Supabase.instance on the free-tier hot path; give it an offline dummy
  // instance (no session, so no network request is ever made).
  setUpAll(() async {
    // Supabase's gotrue async storage reads SharedPreferences during
    // initialize(); mock it before so the channel call resolves.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'front-shift-combo-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  late StubActions actions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    await core.shiftingConfigs.init();
    core.connection.devices.clear();
    actions = StubActions();
    core.actionHandler = actions;
  });

  group('noteShiftAndCheckCoincidence (window)', () {
    test('opposite shift within 120ms → coincidence on the second', () {
      var t = DateTime(2026, 1, 1);
      actions.nowFn = () => t;

      // shiftDown at t=0 → no coincidence yet.
      expect(actions.noteShiftAndCheckCoincidence(InGameAction.shiftDown), isFalse);

      // shiftUp at t=100ms → opposite shift within the window → coincidence.
      t = t.add(const Duration(milliseconds: 100));
      expect(actions.noteShiftAndCheckCoincidence(InGameAction.shiftUp), isTrue);
    });

    test('opposite shift 300ms apart → NO coincidence', () {
      var t = DateTime(2026, 1, 1);
      actions.nowFn = () => t;

      expect(actions.noteShiftAndCheckCoincidence(InGameAction.shiftDown), isFalse);

      t = t.add(const Duration(milliseconds: 300));
      expect(actions.noteShiftAndCheckCoincidence(InGameAction.shiftUp), isFalse);
    });

    test('a hit resets the window so it does not re-trigger', () {
      var t = DateTime(2026, 1, 1);
      actions.nowFn = () => t;

      actions.noteShiftAndCheckCoincidence(InGameAction.shiftDown);
      t = t.add(const Duration(milliseconds: 50));
      expect(actions.noteShiftAndCheckCoincidence(InGameAction.shiftUp), isTrue);

      // A lone shiftUp right after the reset must not coincide with the
      // already-consumed shiftDown.
      t = t.add(const Duration(milliseconds: 10));
      expect(actions.noteShiftAndCheckCoincidence(InGameAction.shiftUp), isFalse);
    });
  });

  group('frontShiftComboEnabled', () {
    test('false when no proxy is connected', () {
      expect(actions.frontShiftComboEnabled, isFalse);
    });

    test('reflects the active ShiftingConfig.frontShiftEnabled of a connected proxy', () async {
      final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'KICKR'));
      device.isConnected = true;
      core.connection.devices.add(device);

      // No config yet → defaults → disabled.
      expect(actions.frontShiftComboEnabled, isFalse);

      await core.shiftingConfigs.upsert(
        ShiftingConfig.defaults(trainerKey: device.trainerKey).copyWith(frontShiftEnabled: true),
      );
      expect(actions.frontShiftComboEnabled, isTrue);
    });
  });

  group('performInGameAction(frontShift)', () {
    test('toggles the connected proxy front ring and returns Success', () async {
      final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'KICKR'));
      device.isConnected = true;
      core.connection.devices.add(device);

      final def = FitnessBikeDefinition(
        connectedDevice: device.scanResult,
        connectedDeviceServices: const [],
        data: ValueNotifier<String>(''),
      );
      device.emulator.debugSetActiveDefinition(def);
      def.setChainringTeeth(34, 50);
      def.setFrontShiftEnabled(true);
      def.setTargetGear(12); // sim mode (non-ERG)

      expect(def.frontRing.value, FrontRing.small); // precondition

      final result = await actions.performInGameAction(InGameAction.frontShift);

      expect(result, isA<Success>());
      expect(def.frontRing.value, FrontRing.large);
    });
  });
}
