import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/services/sensors/sensor_sink_controller.dart';
import 'package:bike_control/services/sensors/sensor_sink_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/sensor_definition.dart';

void main() {
  late List<String> calls;
  late SensorHub hub;
  late ValueNotifier<bool> isBridgeRunning;
  late SensorSinkController sink;
  late SensorSinkSync sync;

  setUp(() {
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
    sync = SensorSinkSync(hub: hub, isBridgeRunning: isBridgeRunning, sink: sink);
  });

  tearDown(() => sync.dispose());

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

  test('a selected source starts the standalone sink when the bridge is not running', () async {
    final source = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');

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

  // T5-B regression: sync() used to ask specifically about
  // SensorQuantity.heartRate. A rider who picks a cadence (or power) source
  // and never touches heart rate must still get a sink — otherwise the
  // definition is attached nowhere and the selection silently does nothing.
  group('a selection on a quantity other than heart rate', () {
    test('a cadence-only selection starts the standalone sink when the bridge is not running', () async {
      final source = FakeSensorSource(id: 'cad', displayName: 'Cadence sensor', provides: {SensorQuantity.cadence});
      hub.register(source);
      hub.select(SensorQuantity.cadence, 'cad');

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

  test('start() re-syncs automatically when a source is selected afterwards', () async {
    sync.start();
    // Settle the initial sync triggered by start(): cold start, no source
    // selected, so the sink is attached nowhere — no calls at all.
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);

    final source = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    // select() invokes the onSelectionChanged hook synchronously; let the
    // resulting onSinkStateChanged transition settle. Nothing was attached
    // before, so this is a plain none -> standalone transition: no detach.
    await Future<void>.delayed(Duration.zero);

    expect(calls, ['start']);
    expect(sink.standaloneRunning, isTrue);
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
