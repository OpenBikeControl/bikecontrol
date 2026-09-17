import 'dart:async';

import 'package:bike_control/services/sensors/broadcast_controller.dart';
import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/services/sensors/sensor_sink_controller.dart';
import 'package:bike_control/services/sensors/sensor_sink_sync.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/sensor_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<String> calls;
  late SensorHub hub;
  late ValueNotifier<bool> isBridgeRunning;
  late SensorSinkController sink;
  late Settings settings;
  late BroadcastController broadcast;
  late SensorSinkSync sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings()..prefs = await SharedPreferences.getInstance();
    calls = [];
    hub = SensorHub();
    isBridgeRunning = ValueNotifier<bool>(false);
    sink = SensorSinkController(
      definition: SensorDefinition(),
      attach: (_) async => calls.add('attach'),
      detach: (_) async => calls.add('detach'),
      startStandalone: (_, __) async => calls.add('start'),
      stopStandalone: () async => calls.add('stop'),
    );
    // Broadcast off by default (see BroadcastController's own doc comment) —
    // exactly the gate this class exists to enforce, so most tests below
    // turn it on explicitly wherever the scenario needs a standalone stint.
    broadcast = BroadcastController(
      hub: hub,
      settings: settings,
      isBridgeRunning: isBridgeRunning,
      isStandaloneRunning: () => true,
      connectSource: (_) async {},
      disconnectSource: (_) async {},
    );
    sync = SensorSinkSync(hub: hub, isBridgeRunning: isBridgeRunning, sink: sink, broadcast: broadcast);
  });

  tearDown(() {
    sync.dispose();
    broadcast.dispose();
  });

  // "No source" maps to SensorSinkMode.none (see SensorSinkSync's doc
  // comment) — attached NOWHERE, not folded into bridge mode. This is the
  // regression this test guards: an earlier version attached the definition
  // to the bridge composite even with nothing selected, which kept the
  // shared trainer bridge from ever seeing itself as unused.
  test('with no source selected, no standalone start is attempted at all', () async {
    await sync.sync();

    expect(calls, isEmpty);
    expect(sink.standaloneRunning, isFalse);
    expect(sink.attachedToComposite, isFalse);
  });

  // T4 regression: a selection alone used to be enough to start a standalone
  // stint. Now the Broadcast switch must be on too.
  test('a selection with Broadcast off resolves to none (no standalone)', () async {
    final source = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');

    await sync.sync();

    expect(sink.lastMode, SensorSinkMode.none);
    expect(calls, isEmpty);
  });

  test(
    'Broadcast on + selection + no bridge → standalone with the broadcast transport and the selected quantities',
    () async {
      final source = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
      hub.register(source);
      hub.select(SensorQuantity.heartRate, 'strap');
      await broadcast.setTransport(RetrofitMode.wifi);
      await broadcast.turnOn();

      await sync.sync();

      expect(sink.lastMode, SensorSinkMode.standalone);
      expect(sink.lastRequest, const StandaloneRequest(transport: RetrofitMode.wifi, exposed: {SensorQuantity.heartRate}));
      expect(calls, ['start']);
    },
  );

  test('a selected source starts the standalone sink when the bridge is not running and Broadcast is on', () async {
    final source = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    await broadcast.turnOn();

    await sync.sync();

    expect(calls, ['start']);
    expect(sink.standaloneRunning, isTrue);
  });

  test('a selected source attaches to the composite when the bridge is running', () async {
    final source = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    isBridgeRunning.value = true;

    await sync.sync();

    expect(calls, ['attach']);
    expect(sink.attachedToComposite, isTrue);
  });

  // Bridge wins outright, regardless of the switch: even with Broadcast on,
  // a running bridge must still win the attachment — see SensorSinkSync's
  // own doc comment for why the two are not interchangeable.
  test('bridge running wins regardless of the switch', () async {
    final source = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    await broadcast.turnOn();
    isBridgeRunning.value = true;

    await sync.sync();

    expect(sink.lastMode, SensorSinkMode.bridge);
    expect(calls, ['attach']);
  });

  // T5-B regression: sync() used to ask specifically about
  // SensorQuantity.heartRate. A rider who picks a cadence (or power) source
  // and never touches heart rate must still get a sink — otherwise the
  // definition is attached nowhere and the selection silently does nothing.
  group('a selection on a quantity other than heart rate', () {
    test('a cadence-only selection starts the standalone sink when the bridge is not running and Broadcast is on', () async {
      final source = FakeSensorSource(id: 'cad', displayName: 'Cadence sensor', provides: {SensorQuantity.cadence});
      hub.register(source);
      hub.select(SensorQuantity.cadence, 'cad');
      await broadcast.turnOn();

      await sync.sync();

      expect(calls, ['start']);
      expect(sink.standaloneRunning, isTrue);
    });

    test('a power-only selection attaches to the composite when the bridge is running', () async {
      final source = FakeSensorSource(id: 'pwr', displayName: 'Power meter', provides: {SensorQuantity.power});
      hub.register(source);
      hub.select(SensorQuantity.power, 'pwr');
      isBridgeRunning.value = true;

      await sync.sync();

      expect(calls, ['attach']);
      expect(sink.attachedToComposite, isTrue);
    });
  });

  // Mirrors the production wiring in Connection.initialize: `broadcast
  // .onChanged` is what re-syncs the sink on turnOn/turnOff/setTransport —
  // SensorSinkSync itself never listens to BroadcastController directly.
  test('broadcast.onChanged re-syncs', () async {
    final source = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');

    Future<void>? pending;
    broadcast.onChanged = () => pending = sync.sync();

    await broadcast.turnOn();
    await pending;

    expect(sink.lastMode, SensorSinkMode.standalone);
    expect(calls, ['start']);
  });

  test('start() re-syncs automatically when the bridge starts running', () async {
    final source = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    sync.start();
    // Settle the initial sync triggered by start(): Broadcast is off, so
    // nothing is attached yet despite the selection.
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);

    isBridgeRunning.value = true;
    await Future<void>.delayed(Duration.zero);

    expect(calls, ['attach']);
    expect(sink.attachedToComposite, isTrue);
  });

  test('dispose stops re-syncing on selection changes', () async {
    sync.start();
    await Future<void>.delayed(Duration.zero);
    sync.dispose();
    calls.clear();

    final source = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    await Future<void>.delayed(Duration.zero);

    expect(calls, isEmpty);
  });
}
