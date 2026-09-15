import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_heart_rate_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_power_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show navigatorKey;
import 'package:bike_control/pages/proxy_device_details/live_metrics_section.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/fake_health_kit_channel.dart';
import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// No-op local-notifications backend — `Connection._connect` posts a
/// "connected" notification on success, and the plugin's static platform
/// instance is only set by real plugin registration. Mirrors
/// `test/integration/harness/test_env.dart`'s own fake (and the deleted
/// `sensor_source_picker_test.dart`'s, which this file's connect-ordering
/// tests are ported from).
class _FakeLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

/// The signals grid: decoupled from `ProxyDevice` (standalone mode) and, per
/// the Claude Design system spec (and direct author feedback that a picker
/// sheet was the wrong shape), the app's ONE sensor surface — each of the
/// power/heart/cadence tiles lists its sources INLINE as a segmented control,
/// no dropdown, no sheet. Mounts the REAL `core.sensors` — the same singleton
/// `Connection` registers into — so this proves the section reacts to the
/// actual hub, not a double. Every test that touches it cleans up via
/// `addTearDown` so later tests start from a clean selection/registration.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'live-metrics-section-test-anon-key',
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
    core.connection.devices.clear();
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
    IAPManager.instance.setProForTesting(enabled: false);
  });

  tearDown(() {
    // NOT `core.connection.stop()` here: most tests in this file never set a
    // fake `UniversalBle` instance, and `stop()` calls
    // `getBluetoothAvailabilityState()`, which throws with no platform
    // channel to answer it. The tests that DO drive a real (dis)connect
    // through `Connection` call `stop()` themselves, inside the test body —
    // see their own comment on why it has to happen there.
    core.connection.devices.clear();
    IAPManager.instance.setProForTesting(enabled: false);
  });

  Future<void> pump(WidgetTester tester, {ProxyDevice? device, bool hideWhenDeviceHasNoMetrics = false}) async {
    await tester.pumpWidget(
      ShadcnApp(
        // Wired to the app's real navigatorKey — `buildToast` reads
        // navigatorKey.currentContext, and the Apple Health denied-toast
        // group below needs it to render (see
        // proxy_device_details_feedback_test.dart's identical setup).
        navigatorKey: navigatorKey,
        localizationsDelegates: [
          ...ShadcnLocalizations.localizationsDelegates,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          child: LiveMetricsSection(device: device, hideWhenDeviceHasNoMetrics: hideWhenDeviceHasNoMetrics),
        ),
      ),
    );
    await tester.pump();
  }

  Finder controlIn(String quantityName) => find.descendant(
    of: find.byKey(Key('metric-card-$quantityName')),
    matching: find.byKey(const Key('metric-card-source-control')),
  );

  Finder segmentIn(String quantityName, String id) => find.descendant(
    of: find.byKey(Key('metric-card-$quantityName')),
    matching: find.byKey(Key('metric-card-source-option-$id')),
  );

  Color? dotColor(WidgetTester tester, String quantityName, String id) {
    final finder = find.descendant(
      of: find.byKey(Key('metric-card-$quantityName')),
      matching: find.byKey(Key('metric-card-source-dot-$id')),
    );
    final container = tester.widget<Container>(finder);
    return (container.decoration as BoxDecoration?)?.color;
  }

  FakePeripheral strapPeripheral({required String deviceId, String name = 'TICKR 1234'}) => FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: [BleSensorSource.heartRateServiceUuid],
    services: [
      BleService(BleSensorSource.heartRateServiceUuid, [
        BleCharacteristic(BleSensorSource.heartRateMeasurementUuid, [CharacteristicProperty.notify], const []),
      ]),
    ],
  );

  // A combo power meter — `BlePowerDevice.provides` is `{power, cadence}` —
  // used to prove the multi-quantity guard: a sensor selected for two
  // quantities must not be disconnected just because ONE of them switches
  // back to Trainer.
  FakePeripheral powerPeripheral({required String deviceId, String name = 'ASSIOMA DUO'}) => FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: [BleSensorSource.cyclingPowerServiceUuid],
    services: [
      BleService(BleSensorSource.cyclingPowerServiceUuid, [
        BleCharacteristic(BleSensorSource.cyclingPowerMeasurementUuid, [CharacteristicProperty.notify], const []),
      ]),
    ],
  );

  group('THE INVARIANT: no external sensors at all', () {
    testWidgets('standalone (no device): every tile shows "--" and no tile has a source control', (tester) async {
      await pump(tester);

      expect(find.byKey(const Key('metric-card-power')), findsOneWidget);
      expect(find.byKey(const Key('metric-card-heartRate')), findsOneWidget);
      expect(find.byKey(const Key('metric-card-cadence')), findsOneWidget);
      expect(find.byKey(const Key('metric-card-speed')), findsOneWidget);
      expect(find.text('--'), findsNWidgets(4));
      expect(controlIn('power'), findsNothing);
      expect(controlIn('heartRate'), findsNothing);
      expect(controlIn('cadence'), findsNothing);
      expect(controlIn('speed'), findsNothing);

      // The equal-height fix must be a no-op here: with no card growing a
      // source list, all four tiles were already the same height before
      // this feature existed, and must stay exactly that way — see
      // `_EqualHeightRow`'s own doc comment on why it only re-lays out a
      // child that is SHORTER than its row.
      final powerHeight = tester.getSize(find.byKey(const Key('metric-card-power'))).height;
      final heartHeight = tester.getSize(find.byKey(const Key('metric-card-heartRate'))).height;
      final cadenceHeight = tester.getSize(find.byKey(const Key('metric-card-cadence'))).height;
      final speedHeight = tester.getSize(find.byKey(const Key('metric-card-speed'))).height;
      expect(powerHeight, heartHeight);
      expect(cadenceHeight, speedHeight);
    });
  });

  group('equal-height rows (direct author feedback: "otherwise it looks odd")', () {
    testWidgets(
      'a card with a source list and its short row-mate render the SAME height, top-aligned content',
      (tester) async {
        // A nearby, not-yet-connected sensor is enough to grow HEART's
        // inline source list (Trainer + the sensor itself) — POWER has no
        // candidate at all, so it stays the short, list-less card. Exactly
        // the mismatch from the author's screenshot.
        final device = BleHeartRateDevice(BleDevice(deviceId: 'equal-height-hr', name: 'TICKR 5555'));
        core.connection.devices.add(device);
        addTearDown(() => core.connection.devices.clear());

        await pump(tester);

        // The fixture actually reproduces the reported mismatch — HEART
        // really does carry extra content POWER doesn't.
        expect(controlIn('heartRate'), findsOneWidget);
        expect(controlIn('power'), findsNothing);

        final powerCard = find.byKey(const Key('metric-card-power'));
        final heartCard = find.byKey(const Key('metric-card-heartRate'));
        expect(tester.getSize(powerCard).height, tester.getSize(heartCard).height);

        // Top-aligned, not centred: POWER's label sits at the same y as
        // HEART's label, even though POWER's container is now taller than
        // its own (short) content.
        final powerLabelTop = tester.getTopLeft(find.descendant(of: powerCard, matching: find.text('POWER'))).dy;
        final heartLabelTop = tester.getTopLeft(find.descendant(of: heartCard, matching: find.text('HEART'))).dy;
        expect(powerLabelTop, heartLabelTop);
      },
    );

    testWidgets(
      "when BOTH cards grow a list of different lengths, the shorter card's list is pinned to the "
      'top — not centred or bottom-weighted by the extra stretched height',
      (tester) async {
        // POWER: one candidate (Trainer + the meter) — the shorter list,
        // whose card ends up stretched to HEART's height below.
        final powerMeter = BlePowerDevice(BleDevice(deviceId: 'equal-height-power', name: 'ASSIOMA DUO'));
        core.connection.devices.add(powerMeter);
        // HEART: two candidates (Trainer + both straps) — the taller list,
        // driving the row's own height.
        final hr1 = BleHeartRateDevice(BleDevice(deviceId: 'equal-height-hr-1', name: 'TICKR 5555'));
        final hr2 = BleHeartRateDevice(BleDevice(deviceId: 'equal-height-hr-2', name: 'TICKR 6666'));
        core.connection.devices.add(hr1);
        core.connection.devices.add(hr2);
        addTearDown(() => core.connection.devices.clear());

        await pump(tester);

        expect(controlIn('power'), findsOneWidget);
        expect(controlIn('heartRate'), findsOneWidget);

        final powerCard = find.byKey(const Key('metric-card-power'));
        final heartCard = find.byKey(const Key('metric-card-heartRate'));
        final powerCardRect = tester.getRect(powerCard);
        final heartCardRect = tester.getRect(heartCard);
        // The fixture actually reproduces the mismatch: HEART's list really
        // is longer, so POWER's card is the one equalised (stretched) here.
        expect(powerCardRect.height, heartCardRect.height);

        // The header (and so the whole list under it) sits at the SAME y in
        // both cards — level with where the value column ends, regardless
        // of which card's own list is shorter and got stretched to fit a
        // taller row-mate.
        final powerHeaderTop = tester
            .getTopLeft(
              find.descendant(of: powerCard, matching: find.byKey(const Key('metric-card-source-header'))),
            )
            .dy;
        final heartHeaderTop = tester
            .getTopLeft(
              find.descendant(of: heartCard, matching: find.byKey(const Key('metric-card-source-header'))),
            )
            .dy;
        expect(powerHeaderTop, heartHeaderTop);

        // And the spare height from equalisation lands BELOW POWER's
        // (shorter) list, not squeezed above it or spread invisibly through
        // it — the list's own bottom edge sits above the card's own bottom
        // padding edge, with room to spare.
        final powerListBottom = tester
            .getBottomLeft(
              find.descendant(of: powerCard, matching: find.byKey(const Key('metric-card-source-control'))),
            )
            .dy;
        final powerCardContentBottom = powerCardRect.bottom - 14; // the card's own 14px padding
        expect(powerCardContentBottom - powerListBottom, greaterThan(8));
      },
    );

    testWidgets('renders without throwing when laid out with unbounded height (inside a scroll view)', (
      tester,
    ) async {
      // The trap: a naive `IntrinsicHeight` + `CrossAxisAlignment.stretch`
      // fix throws under an unbounded incoming height. Both of this
      // section's real call sites (`ProxyDeviceDetailsPage`, the home page)
      // render it inside a scroll view, so this is the shape that matters —
      // an unconstrained `Column` inside a `SingleChildScrollView`, never a
      // tightly-bounded `Scaffold` body like every other test in this file
      // uses.
      final device = BleHeartRateDevice(BleDevice(deviceId: 'unbounded-hr', name: 'TICKR 6666'));
      core.connection.devices.add(device);
      addTearDown(() => core.connection.devices.clear());

      await tester.pumpWidget(
        ShadcnApp(
          localizationsDelegates: [
            ...ShadcnLocalizations.localizationsDelegates,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            child: SingleChildScrollView(
              child: Column(
                children: const [LiveMetricsSection()],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Still renders correctly once unbounded height is survived — not
      // just "didn't crash".
      expect(find.byKey(const Key('metric-card-power')), findsOneWidget);
      expect(find.byKey(const Key('metric-card-heartRate')), findsOneWidget);
    });
  });

  group('a nearby, not-yet-connected sensor', () {
    testWidgets('lists Trainer (selected, quiet) AND the sensor itself (not connected) inline — no sheet needed', (
      tester,
    ) async {
      final device = BleHeartRateDevice(BleDevice(deviceId: 'nearby-hr', name: 'TICKR 1234'));
      core.connection.devices.add(device);

      await pump(tester);

      expect(controlIn('heartRate'), findsOneWidget);
      expect(segmentIn('heartRate', 'trainer'), findsOneWidget);
      expect(segmentIn('heartRate', device.source.id), findsOneWidget);
      expect(
        find.descendant(
          of: segmentIn('heartRate', 'trainer'),
          matching: find.text(AppLocalizations.current.sensorSourceTrainer),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: segmentIn('heartRate', device.source.id), matching: find.text('TICKR 1234')),
        findsOneWidget,
      );
      // Each row carries its own subtitle explaining what it means —
      // the whole point of the list redesign.
      expect(
        find.descendant(
          of: segmentIn('heartRate', 'trainer'),
          matching: find.text(AppLocalizations.current.sensorSourceTrainerSubtitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: segmentIn('heartRate', device.source.id),
          matching: find.text(AppLocalizations.current.sensorSourceNotConnectedSubtitle),
        ),
        findsOneWidget,
      );
      expect(
        dotColor(tester, 'heartRate', 'trainer'),
        Theme.of(tester.element(controlIn('heartRate'))).colorScheme.mutedForeground,
      );
      // A heart rate strap doesn't provide power or cadence.
      expect(controlIn('power'), findsNothing);
      expect(controlIn('cadence'), findsNothing);
    });
  });

  group('a selected, registered, fresh source', () {
    testWidgets('connected: green dot on its own segment, the source\'s own display name, and its live value', (
      tester,
    ) async {
      final source = FakeSensorSource(
        id: 'hr-connected',
        displayName: 'HR6 0050789',
        provides: {
          SensorQuantity.heartRate,
        },
      );
      core.sensors.register(source);
      core.sensors.select(SensorQuantity.heartRate, source.id);
      source.emit(SensorQuantity.heartRate, 142);
      addTearDown(() {
        core.sensors.unregister(source.id);
        core.sensors.select(SensorQuantity.heartRate, null);
      });

      await pump(tester);

      expect(
        find.descendant(of: segmentIn('heartRate', source.id), matching: find.text('HR6 0050789')),
        findsOneWidget,
      );
      // Selected AND streaming: the "connected" subtitle reads as active,
      // not merely "linked somewhere else" (see the DIFFERENT-quantity test
      // below for that other half of the same state).
      expect(
        find.descendant(
          of: segmentIn('heartRate', source.id),
          matching: find.text(AppLocalizations.current.sensorSourceConnectedSubtitle),
        ),
        findsOneWidget,
      );
      expect(dotColor(tester, 'heartRate', source.id), const Color(0xFF22C55E));
      // The value/unit rows are unchanged from before this feature — a raw
      // "142", not the combined "142 bpm" the deleted picker's subtitle used.
      expect(
        find.descendant(of: find.byKey(const Key('metric-card-heartRate')), matching: find.text('142')),
        findsOneWidget,
      );
    });

    testWidgets('a source registered for a DIFFERENT quantity still shows connected (green) here when unselected', (
      tester,
    ) async {
      // A combo sensor: selected for POWER already, never touched for
      // CADENCE. Its own BLE link is genuinely up — the CADENCE tile's
      // segment for it must say so, even though CADENCE is still on Trainer.
      final source = FakeSensorSource(
        id: 'combo-1',
        displayName: 'Combo meter',
        provides: {
          SensorQuantity.power,
          SensorQuantity.cadence,
        },
      );
      core.sensors.register(source);
      core.sensors.select(SensorQuantity.power, source.id);
      addTearDown(() {
        core.sensors.unregister(source.id);
        core.sensors.select(SensorQuantity.power, null);
      });

      await pump(tester);

      expect(segmentIn('cadence', 'trainer'), findsOneWidget);
      expect(
        find.descendant(
          of: segmentIn('cadence', 'trainer'),
          matching: find.text(AppLocalizations.current.sensorSourceTrainer),
        ),
        findsOneWidget,
      );
      expect(dotColor(tester, 'cadence', source.id), const Color(0xFF22C55E));
      // Connected, but not CADENCE's own pick — a different subtitle from
      // the "streaming its own reading" one above: this row means "tap to
      // use it here too", not "this is already your source".
      expect(
        find.descendant(
          of: segmentIn('cadence', source.id),
          matching: find.text(AppLocalizations.current.sensorSourceConnectedElsewhereSubtitle),
        ),
        findsOneWidget,
      );
    });
  });

  group('a selected source not yet registered', () {
    testWidgets('ghost segment: amber dot, "Connecting…", alongside Trainer', (tester) async {
      core.sensors.select(SensorQuantity.cadence, 'ghost-cadence-source');
      addTearDown(() => core.sensors.select(SensorQuantity.cadence, null));

      await pump(tester);

      expect(controlIn('cadence'), findsOneWidget);
      expect(segmentIn('cadence', 'trainer'), findsOneWidget);
      expect(segmentIn('cadence', 'ghost-cadence-source'), findsOneWidget);
      expect(
        find.descendant(
          of: segmentIn('cadence', 'ghost-cadence-source'),
          matching: find.text(AppLocalizations.current.sensorConnecting),
        ),
        findsOneWidget,
      );
      // No real candidate to attach a live "connecting" state to — the
      // subtitle says so explicitly, distinct from a real in-flight BLE
      // handshake's own subtitle (see the waiting-for-first-reading group).
      expect(
        find.descendant(
          of: segmentIn('cadence', 'ghost-cadence-source'),
          matching: find.text(AppLocalizations.current.sensorSourceConnectingGhostSubtitle),
        ),
        findsOneWidget,
      );
      expect(dotColor(tester, 'cadence', 'ghost-cadence-source'), const Color(0xFFF59E0B));
    });
  });

  group('a selected, registered source with no reading yet', () {
    testWidgets('waiting for first reading: amber dot on its own segment — the label stays the source\'s own name', (
      tester,
    ) async {
      final source = FakeSensorSource(
        id: 'pwr-waiting',
        displayName: 'Power meter',
        provides: {
          SensorQuantity.power,
        },
      );
      core.sensors.register(source);
      core.sensors.select(SensorQuantity.power, source.id);
      addTearDown(() {
        core.sensors.unregister(source.id);
        core.sensors.select(SensorQuantity.power, null);
      });

      await pump(tester);

      // Unlike the deleted single-row design, a real candidate's label is
      // always its own name — only the dot carries "waiting" here; there is
      // no separate ghost/no-name segment involved (that only happens when
      // the selection matches no known candidate at all — see the
      // "not yet registered" group above).
      expect(
        find.descendant(of: segmentIn('power', source.id), matching: find.text('Power meter')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: segmentIn('power', source.id),
          matching: find.text(AppLocalizations.current.sensorAwaitingFirstReading),
        ),
        findsOneWidget,
      );
      expect(dotColor(tester, 'power', source.id), const Color(0xFFF59E0B));
    });
  });

  group('a selected, registered source that stops reporting', () {
    testWidgets('lost: red dot on its own segment — falls back to the trainer value', (tester) async {
      final source = FakeSensorSource(
        id: 'hr-lost',
        displayName: 'TICKR 1234',
        provides: {
          SensorQuantity.heartRate,
        },
      );
      core.sensors.register(source);
      core.sensors.select(SensorQuantity.heartRate, source.id);
      // Reported before, but the only reading on record is already stale —
      // `everReported` (raw value non-null) is true while `droppedOut` is
      // also true, which is exactly the "lost" branch.
      source.emit(SensorQuantity.heartRate, 150, at: DateTime.now().subtract(const Duration(seconds: 30)));
      addTearDown(() {
        core.sensors.unregister(source.id);
        core.sensors.select(SensorQuantity.heartRate, null);
      });

      await pump(tester);

      expect(dotColor(tester, 'heartRate', source.id), const Color(0xFFEF4444));
      // The subtitle names exactly what happened and what the rider is
      // seeing instead — this is the "value has fallen back to the trainer"
      // case the row has to spell out, not leave to the dot colour alone.
      expect(
        find.descendant(
          of: segmentIn('heartRate', source.id),
          matching: find.text(AppLocalizations.current.sensorDroppedOut),
        ),
        findsOneWidget,
      );
      // Fallen back to the trainer: no external value survives to the tile.
      expect(
        find.descendant(of: find.byKey(const Key('metric-card-heartRate')), matching: find.text('--')),
        findsOneWidget,
      );
    });
  });

  group('SPEED', () {
    testWidgets('never shows a source control, even with a selected, connected "speed" source', (tester) async {
      final source = FakeSensorSource(id: 'spd', displayName: 'Speed sensor', provides: {SensorQuantity.speed});
      core.sensors.register(source);
      core.sensors.select(SensorQuantity.speed, source.id);
      source.emit(SensorQuantity.speed, 32);
      addTearDown(() {
        core.sensors.unregister(source.id);
        core.sensors.select(SensorQuantity.speed, null);
      });

      await pump(tester);

      expect(controlIn('speed'), findsNothing);
    });
  });

  group('hideWhenDeviceHasNoMetrics (ProxyDeviceDetailsPage\'s own pixel-fidelity case)', () {
    testWidgets('true + a device with nothing to report yet: renders nothing at all', (tester) async {
      final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));
      expect(device.fitnessBike, isNull);

      await pump(tester, device: device, hideWhenDeviceHasNoMetrics: true);

      expect(find.byType(MetricCard), findsNothing);
    });

    testWidgets('false (home page\'s default): the same device still renders the grid', (tester) async {
      final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));

      await pump(tester, device: device);

      expect(find.byType(MetricCard), findsNWidgets(4));
    });
  });

  testWidgets('tapping a source segment selects it directly — no sheet, no picker opens', (tester) async {
    // Already registered (no BLE connect step needed on tap) — the real
    // connect-through-a-tap path, with its BLE machinery, is the dedicated
    // "CRITICAL — connect ordering" group below.
    final source = FakeSensorSource(
      id: 'hr-direct-select',
      displayName: 'TICKR 9999',
      provides: {
        SensorQuantity.heartRate,
      },
    );
    core.sensors.register(source);
    IAPManager.instance.setProForTesting(enabled: true);
    addTearDown(() {
      core.sensors.unregister(source.id);
      core.sensors.select(SensorQuantity.heartRate, null);
    });

    await pump(tester);
    // The segmented control scrolls horizontally (`MetricCard._sourceControl`)
    // for a quantity with enough sources that they cannot all fit — bring the
    // target into the viewport first so the tap cannot silently miss it.
    await tester.ensureVisible(segmentIn('heartRate', source.id));
    await tester.tap(segmentIn('heartRate', source.id));
    await tester.pumpAndSettle();

    expect(core.sensors.selectionFor(SensorQuantity.heartRate), source.id);
  });

  testWidgets('a sensor discovered after the section is already mounted flips its own segment live', (tester) async {
    await pump(tester);
    expect(controlIn('heartRate'), findsNothing);

    final device = BleHeartRateDevice(BleDevice(deviceId: 'hr-live', name: 'Live TICKR'));
    core.connection.devices.add(device);
    core.connection.signalChange(device);
    await tester.pumpAndSettle();

    // Discovered but not yet connected: Trainer plus the sensor's own
    // segment appear — no remount of the section was needed for it to show.
    expect(segmentIn('heartRate', 'trainer'), findsOneWidget);
    expect(segmentIn('heartRate', device.source.id), findsOneWidget);
  });

  group('Pro gating', () {
    testWidgets('selecting Trainer clears the selection, with no BLE side effect and no Pro gate', (tester) async {
      IAPManager.instance.setProForTesting(enabled: false);
      core.sensors.select(SensorQuantity.heartRate, 'was-something');
      addTearDown(() => core.sensors.select(SensorQuantity.heartRate, null));

      await pump(tester);
      await tester.ensureVisible(segmentIn('heartRate', 'trainer'));
      await tester.tap(segmentIn('heartRate', 'trainer'));
      await tester.pumpAndSettle();

      expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
    });
  });

  group('CRITICAL — connect ordering', () {
    testWidgets(
      'tapping a not-yet-connected sensor\'s segment persists consent BEFORE connecting, '
      'then drives the device to a real connected state',
      (tester) async {
        IAPManager.instance.setProForTesting(enabled: true);
        final ble = FakeUniversalBlePlatform();
        UniversalBle.setInstance(ble);
        final peripheral = strapPeripheral(deviceId: 'hr-pick-3');
        ble.addPeripheral(peripheral);
        final device = BleHeartRateDevice(peripheral.scanResult);
        core.connection.devices.add(device);
        addTearDown(() {
          core.sensors.unregister(device.source.id);
          core.sensors.select(SensorQuantity.heartRate, null);
        });
        expect(device.shouldAutoConnect, isFalse);

        await pump(tester);
        await tester.ensureVisible(segmentIn('heartRate', device.source.id));
        await tester.tap(segmentIn('heartRate', device.source.id));
        await tester.pumpAndSettle();

        expect(device.isConnected, isTrue);
        // Persisted, not just in-memory — AND proof of the load-bearing
        // ordering: had the flag been written after calling connect() instead
        // of before, `shouldAutoConnect` would have read false at connect()
        // time, `connect()` would have early-returned, and `isConnected` above
        // would still be false no matter what the flag reads now.
        expect(core.settings.getSensorAutoConnect(device.device.deviceId), isTrue);
        expect(core.sensors.selectionFor(SensorQuantity.heartRate), device.source.id);

        // `Connection`'s BLE connection-state listener re-evaluates on every
        // (dis)connect and would otherwise leave a periodic gamepad-search
        // timer pending past this test's end (`performScanning`'s doc
        // comment) — `flutter_test`'s pending-timer check runs at the end of
        // the test body itself, before any `tearDown`/`addTearDown` gets a
        // turn, so this has to happen here rather than in either of those.
        await core.connection.stop();
      },
    );

    // Deliberately no automated widget test drives a FAILED connect through
    // the real `Connection`/`FakeUniversalBlePlatform` stack, and no test
    // drives the Pro-denied dialog path to completion — both are pre-existing
    // gaps this file inherits from the deleted `sensor_source_picker_test
    // .dart`, which carried the same limitation for the same reason: under
    // `testWidgets`' FakeAsync zone, a rejected `device.connect()` does not
    // resolve within any bounded number of `pump()`/`pumpAndSettle()` calls,
    // independent of which error it rejects with, and `showGoProDialog` pulls
    // in the full purchase-flow UI. Both paths are covered by code review
    // instead: `_select`'s catch block forwards through `recordError` before
    // rethrowing (verified above the fold), and the Pro gate
    // (`sourceId != null && !isProEnabledForCurrentDevice`) is exercised for
    // its "does not apply to Trainer" half by the test above.
  });

  group('disconnect', () {
    testWidgets(
      'long-pressing the selected, connected segment clears the consent flag BEFORE disconnecting, '
      'and the selection falls back to Trainer',
      (tester) async {
        IAPManager.instance.setProForTesting(enabled: true);
        final ble = FakeUniversalBlePlatform();
        UniversalBle.setInstance(ble);
        final peripheral = strapPeripheral(deviceId: 'hr-pick-4');
        ble.addPeripheral(peripheral);
        final device = BleHeartRateDevice(peripheral.scanResult);
        core.connection.devices.add(device);
        addTearDown(() {
          core.sensors.unregister(device.source.id);
          core.sensors.select(SensorQuantity.heartRate, null);
        });

        // Get to a genuinely connected+registered+selected state first, via
        // the same tap the connect-ordering test above proves.
        await pump(tester);
        await tester.ensureVisible(segmentIn('heartRate', device.source.id));
        await tester.tap(segmentIn('heartRate', device.source.id));
        await tester.pumpAndSettle();
        expect(device.isConnected, isTrue);
        expect(core.sensors.selectionFor(SensorQuantity.heartRate), device.source.id);

        await tester.ensureVisible(segmentIn('heartRate', device.source.id));
        await tester.longPress(segmentIn('heartRate', device.source.id));
        await tester.pumpAndSettle();

        expect(core.settings.getSensorAutoConnect(device.device.deviceId), isFalse);
        expect(device.isConnected, isFalse);
        // `forget: true` cascades: the quantity selection that pointed at this
        // source falls back to Trainer rather than being left dangling.
        expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
        // `persistForget: false`: not on the permanent ignore list, so it stays
        // reconnectable — proven indirectly here by the flag call above using
        // exactly that pair of arguments (see `LiveMetricsSection._disconnect`'s
        // doc comment); asserting the ignore list itself is
        // `ignored_devices_dialog`/`Settings.getIgnoredDevices` territory, out
        // of scope for this file.

        // See the connect-ordering test's own comment on why this has to run
        // here, inside the test body, rather than in a teardown hook.
        await core.connection.stop();
      },
    );

    testWidgets('long-pressing Trainer does nothing (no onDisconnect wired)', (tester) async {
      // A bare "nothing selected, nothing nearby" tile renders no control at
      // all (THE INVARIANT) — a nearby sensor is the minimal setup that
      // makes the Trainer segment itself exist to long-press.
      final nearby = BleHeartRateDevice(BleDevice(deviceId: 'nearby-hr-3', name: 'TICKR 0001'));
      core.connection.devices.add(nearby);

      await pump(tester);

      await tester.ensureVisible(segmentIn('heartRate', 'trainer'));
      await tester.longPress(segmentIn('heartRate', 'trainer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
    });
  });

  group('selecting Trainer disconnects the now-idle sensor (direct author feedback)', () {
    testWidgets(
      'a sensor serving only this quantity: selecting Trainer disconnects it and clears its consent flag',
      (tester) async {
        IAPManager.instance.setProForTesting(enabled: true);
        final ble = FakeUniversalBlePlatform();
        UniversalBle.setInstance(ble);
        final peripheral = strapPeripheral(deviceId: 'hr-trainer-back-1');
        ble.addPeripheral(peripheral);
        final device = BleHeartRateDevice(peripheral.scanResult);
        core.connection.devices.add(device);
        addTearDown(() {
          core.sensors.unregister(device.source.id);
          core.sensors.select(SensorQuantity.heartRate, null);
        });

        await pump(tester);
        await tester.ensureVisible(segmentIn('heartRate', device.source.id));
        await tester.tap(segmentIn('heartRate', device.source.id));
        await tester.pumpAndSettle();
        expect(device.isConnected, isTrue);
        expect(core.sensors.selectionFor(SensorQuantity.heartRate), device.source.id);

        await tester.ensureVisible(segmentIn('heartRate', 'trainer'));
        await tester.tap(segmentIn('heartRate', 'trainer'));
        await tester.pumpAndSettle();

        expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
        expect(device.isConnected, isFalse);
        expect(core.settings.getSensorAutoConnect(device.device.deviceId), isFalse);

        // See the connect-ordering test's own comment on why this has to run
        // here, inside the test body, rather than in a teardown hook.
        await core.connection.stop();
      },
    );

    // THE REGRESSION direct author feedback caught: "it now disconnects the
    // sensor, but it also [dis]appears from the sensors list for a few
    // seconds - should remain selectable". A rider who taps Trainer must see
    // the sensor's own row stay put, not vanish until the next scan
    // rediscovers it.
    testWidgets(
      'the disconnected sensor stays listed and selectable — it must not vanish while out of range',
      (tester) async {
        IAPManager.instance.setProForTesting(enabled: true);
        final ble = FakeUniversalBlePlatform();
        UniversalBle.setInstance(ble);
        final peripheral = strapPeripheral(deviceId: 'hr-stays-listed-1');
        ble.addPeripheral(peripheral);
        final device = BleHeartRateDevice(peripheral.scanResult);
        core.connection.devices.add(device);
        addTearDown(() {
          core.sensors.unregister(device.source.id);
          core.sensors.select(SensorQuantity.heartRate, null);
        });

        await pump(tester);
        await tester.ensureVisible(segmentIn('heartRate', device.source.id));
        await tester.tap(segmentIn('heartRate', device.source.id));
        await tester.pumpAndSettle();
        expect(device.isConnected, isTrue);

        await tester.ensureVisible(segmentIn('heartRate', 'trainer'));
        await tester.tap(segmentIn('heartRate', 'trainer'));
        await tester.pumpAndSettle();

        // THE REGRESSION: right after the disconnect settles — no rescan,
        // no delay — the sensor's own row must still be present.
        expect(core.connection.devices.contains(device), isTrue);
        expect(segmentIn('heartRate', device.source.id), findsOneWidget);

        // ...and selectable again: tapping it reconnects the very same
        // device object (never rediscovered, never rebuilt).
        await tester.ensureVisible(segmentIn('heartRate', device.source.id));
        await tester.tap(segmentIn('heartRate', device.source.id));
        await tester.pumpAndSettle();

        expect(device.isConnected, isTrue);
        expect(core.sensors.selectionFor(SensorQuantity.heartRate), device.source.id);

        await core.connection.stop();
      },
    );

    // THE CASE THAT MUST BE GOT RIGHT: a combo power meter serving BOTH
    // power and cadence (`BlePowerDevice.provides`). Switching POWER back to
    // Trainer must NOT drop the meter — it is still CADENCE's live source. A
    // naive "always disconnect on Trainer" implementation passes every other
    // test in this file and still fails this one.
    testWidgets(
      'a sensor selected for TWO quantities stays connected when only ONE switches back to Trainer',
      (tester) async {
        IAPManager.instance.setProForTesting(enabled: true);
        final ble = FakeUniversalBlePlatform();
        UniversalBle.setInstance(ble);
        final peripheral = powerPeripheral(deviceId: 'combo-power-1');
        ble.addPeripheral(peripheral);
        final device = BlePowerDevice(peripheral.scanResult);
        core.connection.devices.add(device);
        addTearDown(() {
          core.sensors.unregister(device.source.id);
          core.sensors.select(SensorQuantity.power, null);
          core.sensors.select(SensorQuantity.cadence, null);
        });

        await pump(tester);
        // Select it for POWER first — the real connect-through-a-tap path.
        await tester.ensureVisible(segmentIn('power', device.source.id));
        await tester.tap(segmentIn('power', device.source.id));
        await tester.pumpAndSettle();
        expect(device.isConnected, isTrue);
        expect(core.sensors.selectionFor(SensorQuantity.power), device.source.id);

        // Already registered and connected — selecting it for CADENCE too
        // just binds the hub, exactly like a rider using the same combo
        // meter for both readings.
        await tester.ensureVisible(segmentIn('cadence', device.source.id));
        await tester.tap(segmentIn('cadence', device.source.id));
        await tester.pumpAndSettle();
        expect(core.sensors.selectionFor(SensorQuantity.cadence), device.source.id);

        // Switch POWER back to Trainer.
        await tester.ensureVisible(segmentIn('power', 'trainer'));
        await tester.tap(segmentIn('power', 'trainer'));
        await tester.pumpAndSettle();

        expect(core.sensors.selectionFor(SensorQuantity.power), isNull);
        // CADENCE's own selection is untouched.
        expect(core.sensors.selectionFor(SensorQuantity.cadence), device.source.id);
        // Still connected — it is still serving CADENCE.
        expect(device.isConnected, isTrue);
        // Consent flag left exactly as it was — no disconnect was attempted.
        expect(core.settings.getSensorAutoConnect(device.device.deviceId), isTrue);

        await core.connection.stop();
      },
    );

    // Finding 1, fix round 1: the back-to-Trainer walk used to gate on
    // `previous.isConnected` — true only for a REGISTERED source — so a
    // selection still pointing at a nearby, never-registered strap (its own
    // `connectDevice` still in flight, or failed outright) skipped the
    // disconnect call entirely and left that strap's per-device
    // auto-connect consent flag set to `true` forever, ready to
    // auto-reconnect an unused strap on the next scan.
    testWidgets(
      'a nearby strap selected but never registered still has its consent flag revoked on Trainer',
      (tester) async {
        final device = BleHeartRateDevice(BleDevice(deviceId: 'never-registered-hr', name: 'TICKR 9999'));
        core.connection.devices.add(device);
        addTearDown(() => core.sensors.select(SensorQuantity.heartRate, null));

        // Mirrors the state a failed/in-flight `connectDevice` leaves
        // behind: selection and consent both set, but the source was never
        // registered in the hub (so `_candidatesFor` lists it with
        // `isConnected: false`) — set up directly rather than through a tap,
        // since driving an actual connect failure isn't worth the fixture
        // cost here.
        core.sensors.select(SensorQuantity.heartRate, device.source.id);
        await core.settings.setSensorAutoConnect(device.device.deviceId, true);
        expect(core.settings.getSensorAutoConnect(device.device.deviceId), isTrue);

        await pump(tester);
        await tester.ensureVisible(segmentIn('heartRate', 'trainer'));
        await tester.tap(segmentIn('heartRate', 'trainer'));
        await tester.pumpAndSettle();

        expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
        expect(core.settings.getSensorAutoConnect(device.device.deviceId), isFalse);
      },
    );

    testWidgets('Trainer already selected: selecting it again attempts no disconnect and writes no flag', (
      tester,
    ) async {
      // A nearby, unregistered strap makes the Trainer segment exist to tap
      // (THE INVARIANT: no candidates at all means no control renders) while
      // leaving Trainer itself already selected for heartRate.
      final nearby = BleHeartRateDevice(BleDevice(deviceId: 'nearby-hr-trainer-noop', name: 'TICKR 0002'));
      core.connection.devices.add(nearby);
      expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
      expect(core.settings.getSensorAutoConnect(nearby.device.deviceId), isFalse);

      await pump(tester);
      await tester.ensureVisible(segmentIn('heartRate', 'trainer'));
      await tester.tap(segmentIn('heartRate', 'trainer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
      // No disconnect was ever attempted against the nearby, unrelated
      // device — its consent flag is untouched.
      expect(core.settings.getSensorAutoConnect(nearby.device.deviceId), isFalse);
    });
  });

  group('Apple Health (HealthKit) candidate', () {
    late FakeHealthKitChannel channel;

    setUp(() {
      channel = FakeHealthKitChannel();
      core.connection.healthKitSource = HealthKitSensorSource(channel: channel);
      IAPManager.instance.setProForTesting(enabled: true);
    });

    tearDown(() async {
      await core.connection.disconnectHealthKit(forget: true);
      core.connection.healthKitSource = null;
    });

    testWidgets('absent when Connection has no HealthKit source (every non-iOS platform)', (tester) async {
      core.connection.healthKitSource = null;
      await pump(tester);
      expect(controlIn('heartRate'), findsNothing);
    });

    testWidgets('present, grey, not connected — under Trainer — as soon as the source exists', (tester) async {
      await pump(tester);

      expect(controlIn('heartRate'), findsOneWidget);
      expect(segmentIn('heartRate', 'trainer'), findsOneWidget);
      expect(segmentIn('heartRate', 'healthkit'), findsOneWidget);
      expect(find.text('Apple Health'), findsOneWidget);
      expect(find.text(AppLocalizations.current.sensorSourceHealthKitSubtitle), findsOneWidget);
      // Only heart rate: cadence/power get no control from it.
      expect(controlIn('cadence'), findsNothing);
      expect(controlIn('power'), findsNothing);
    });

    testWidgets('tapping it authorizes, registers, starts, and selects it', (tester) async {
      await pump(tester);
      await tester.tap(segmentIn('heartRate', 'healthkit'));
      await tester.pumpAndSettle();

      expect(channel.authorizeCalls, 1);
      expect(channel.startCalls, 1);
      expect(core.sensors.selectionFor(SensorQuantity.heartRate), 'healthkit');
      expect(core.connection.isHealthKitConnected, isTrue);
    });

    testWidgets('denied: toast, selection never committed, nothing started', (tester) async {
      channel.authorization = HealthKitAuthorization.denied;
      final previousOnSelectionChanged = core.sensors.onSelectionChanged;
      var selectionChangedCalls = 0;
      core.sensors.onSelectionChanged = () {
        selectionChangedCalls++;
        previousOnSelectionChanged?.call();
      };
      addTearDown(() => core.sensors.onSelectionChanged = previousOnSelectionChanged);

      await pump(tester);
      await tester.tap(segmentIn('heartRate', 'healthkit'));
      await tester.pump();

      expect(find.text(AppLocalizations.current.sensorHealthKitDenied), findsOneWidget);
      // Not `pumpAndSettle()`: the toast's own auto-dismiss timer (5 s at
      // `LogLevel.LOGLEVEL_WARNING`) fires on a real `Timer`, which
      // `flutter_test`'s fake clock only advances on an explicit `pump`
      // duration — leaving it pending past test end fails the framework's
      // own "no pending timers" invariant. Pump past the full 5 s so it
      // actually fires and the toast tears itself down.
      await tester.pump(const Duration(seconds: 6));
      // Authorization now runs BEFORE `core.sensors.select` — a denial means
      // the selection is never touched at all (not "set then reverted"), so
      // `onSelectionChanged` never fires either.
      expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
      expect(selectionChangedCalls, 0);
      expect(channel.startCalls, 0);
    });

    testWidgets(
      'authorization is requested BEFORE the selection changes '
      '(the sheet must not race the transport restart)',
      (tester) async {
        await pump(tester);

        int? selectionChangedAt;
        final previousOnSelectionChanged = core.sensors.onSelectionChanged;
        core.sensors.onSelectionChanged = () {
          selectionChangedAt = channel.authorizeCalls;
          previousOnSelectionChanged?.call();
        };
        addTearDown(() => core.sensors.onSelectionChanged = previousOnSelectionChanged);

        await tester.tap(segmentIn('heartRate', 'healthkit'));
        await tester.pumpAndSettle();

        // Authorization had already happened by the time the hub's
        // selection changed — the exact ordering the device-confirmed bug
        // needed (a selection change restarts the BLE/DIRCON transport,
        // which starves the permission sheet if it races it).
        expect(selectionChangedAt, 1);
        // And it is not called again on the connect path that follows —
        // `Connection.connectHealthKit` deliberately never authorizes.
        expect(channel.authorizeCalls, 1);
      },
    );

    testWidgets('connected + session mode: green dot and the live value', (tester) async {
      await pump(tester);
      await tester.tap(segmentIn('heartRate', 'healthkit'));
      await tester.pumpAndSettle();
      channel.emitSample(147, at: DateTime.now());
      await tester.pumpAndSettle();

      expect(find.text(AppLocalizations.current.sensorSourceConnectedSubtitle), findsOneWidget);
      expect(find.text('147'), findsOneWidget);
    });

    testWidgets('connected + passive mode: explains that a Fitness workout is needed', (tester) async {
      await pump(tester);
      await tester.tap(segmentIn('heartRate', 'healthkit'));
      await tester.pumpAndSettle();
      channel.emitMode(HealthKitMode.passive);
      await tester.pumpAndSettle();

      expect(find.text(AppLocalizations.current.sensorSourceHealthKitPassiveSubtitle), findsOneWidget);
    });

    testWidgets('selecting Trainer again stops the session and unregisters', (tester) async {
      await pump(tester);
      await tester.tap(segmentIn('heartRate', 'healthkit'));
      await tester.pumpAndSettle();
      await tester.tap(segmentIn('heartRate', 'trainer'));
      // `tester.runAsync`, not another `pump`/`pumpAndSettle`: a
      // `StreamSubscription.cancel()` with no `onCancel` handler (our fake
      // `_events` broadcast controller has none) completes via a Future
      // that resolves outside `FakeAsync`'s controlled queue regardless of
      // which zone built the controller — so `HealthKitSensorSource.stop`'s
      // `await subscription.cancel()`, reached here via this tap, never
      // settles no matter how many fake frames get pumped afterward
      // (confirmed empirically: it stays pending past `pumpAndSettle`'s
      // whole 10-minute fake-clock budget). Stepping into the real zone
      // briefly lets that pending completion actually fire; the follow-up
      // `pumpAndSettle` then finishes the now-unblocked rebuild.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(channel.stopCalls, 1);
      expect(core.connection.isHealthKitConnected, isFalse);
      expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
      // Still selectable afterwards.
      expect(segmentIn('heartRate', 'healthkit'), findsOneWidget);
    });

    testWidgets('a BLE strap and Apple Health are listed together, each selectable', (tester) async {
      final device = BleHeartRateDevice(BleDevice(deviceId: 'strap-1', name: 'TICKR 1234'));
      core.connection.devices.add(device);
      await pump(tester);

      expect(segmentIn('heartRate', 'healthkit'), findsOneWidget);
      expect(segmentIn('heartRate', device.source.id), findsOneWidget);
    });
  });
}
