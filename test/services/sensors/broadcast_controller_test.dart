import 'package:bike_control/main.dart' show installLoggerErrorListener;
import 'package:bike_control/services/sensors/broadcast_controller.dart';
import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:prop/utils/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SensorHub hub;
  late Settings settings;
  late ValueNotifier<bool> bridge;
  late List<String> log;
  late BroadcastController controller;
  Object? connectError;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings()..prefs = await SharedPreferences.getInstance(); // match how other tests build Settings
    hub = SensorHub();
    bridge = ValueNotifier(false);
    log = [];
    connectError = null;
    controller = BroadcastController(
      hub: hub,
      settings: settings,
      isBridgeRunning: bridge,
      connectSource: (id) async {
        log.add('connect:$id');
        if (connectError != null) throw connectError!;
      },
      disconnectSource: (id) async => log.add('disconnect:$id'),
    )..start();
    hub.register(FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate}));
    hub.register(FakeSensorSource(id: 'meter', displayName: 'Meter', provides: {SensorQuantity.cadence, SensorQuantity.power}));
  });

  tearDown(() => controller.dispose());

  test('off by default, transport defaults to bluetooth, nothing wanted', () {
    expect(controller.isOn.value, isFalse);
    expect(controller.transport.value, RetrofitMode.bluetooth);
    expect(controller.wantsStandalone, isFalse);
  });

  test('turnOn connects every distinct selected source once, then wants standalone', () async {
    hub.select(SensorQuantity.heartRate, 'strap');
    hub.select(SensorQuantity.cadence, 'meter');
    hub.select(SensorQuantity.power, 'meter');
    var changed = 0;
    controller.onChanged = () => changed++;
    await controller.turnOn();
    expect(log, ['connect:strap', 'connect:meter']);
    expect(controller.isOn.value, isTrue);
    expect(controller.wantsStandalone, isTrue);
    expect(controller.selectedQuantities, {SensorQuantity.heartRate, SensorQuantity.cadence, SensorQuantity.power});
    expect(changed, 1);
  });

  test('turnOn with nothing selected stays off', () async {
    await controller.turnOn();
    expect(controller.isOn.value, isFalse);
    expect(log, isEmpty);
  });

  test('turnOff notifies first (sink stops), then disconnects', () async {
    hub.select(SensorQuantity.heartRate, 'strap');
    await controller.turnOn();
    log.clear();
    controller.onChanged = () => log.add('changed');
    await controller.turnOff();
    expect(log, ['changed', 'disconnect:strap']);
    expect(controller.isOn.value, isFalse);
  });

  test('a connect failure rolls back: switch stays off, already-connected sources are disconnected, error rethrown', () async {
    hub.select(SensorQuantity.heartRate, 'strap');
    hub.select(SensorQuantity.cadence, 'meter');
    connectError = StateError('meter refused');
    // recordError() -> installLoggerErrorListener() only assigns
    // Logger.onRecordError the first time it runs in this isolate; trip
    // that guard here (before overriding the listener below) so the no-op
    // below isn't clobbered by the production listener on the first
    // recordError() call, keeping `flutter test` output pristine.
    installLoggerErrorListener();
    Logger.onRecordError = (_, _, _) {};
    addTearDown(() => Logger.onRecordError = null);
    // First connect succeeds (strap), second throws (meter) — order the fake accordingly.
    var calls = 0;
    controller = BroadcastController(
      hub: hub,
      settings: settings,
      isBridgeRunning: bridge,
      connectSource: (id) async {
        log.add('connect:$id');
        if (++calls == 2) throw StateError('meter refused');
      },
      disconnectSource: (id) async => log.add('disconnect:$id'),
    )..start();
    await expectLater(controller.turnOn(), throwsStateError);
    expect(controller.isOn.value, isFalse);
    expect(log, ['connect:strap', 'connect:meter', 'disconnect:strap']);
  });

  test('deselecting the last source while on turns off', () async {
    hub.select(SensorQuantity.heartRate, 'strap');
    await controller.turnOn();
    hub.select(SensorQuantity.heartRate, null);
    await Future<void>.delayed(Duration.zero);
    expect(controller.isOn.value, isFalse);
    expect(log.last, 'disconnect:strap');
  });

  test('selecting another source while on connects it immediately', () async {
    hub.select(SensorQuantity.heartRate, 'strap');
    await controller.turnOn();
    hub.select(SensorQuantity.cadence, 'meter');
    await Future<void>.delayed(Duration.zero);
    expect(log.last, 'connect:meter');
  });

  test('setTransport persists and notifies', () async {
    await controller.setTransport(RetrofitMode.wifi);
    expect(controller.transport.value, RetrofitMode.wifi);
    expect(settings.getSensorsTransport(), RetrofitMode.wifi);
    expect(
      BroadcastController(
        hub: hub,
        settings: settings,
        isBridgeRunning: bridge,
        connectSource: (_) async {},
        disconnectSource: (_) async {},
      ).transport.value,
      RetrofitMode.wifi,
    );
  });

  test('bridge starts: switch goes off without disconnecting (sources ride on the trainer); bridge stops: resumes', () async {
    hub.select(SensorQuantity.heartRate, 'strap');
    await controller.turnOn();
    log.clear();
    bridge.value = true;
    await Future<void>.delayed(Duration.zero);
    expect(controller.isOn.value, isFalse);
    expect(controller.wantsStandalone, isFalse);
    expect(log, isEmpty);
    bridge.value = false;
    await Future<void>.delayed(Duration.zero);
    expect(controller.isOn.value, isTrue);
    // 'strap' is still tracked in `_connectedIds` from before the bridge —
    // nothing to reconnect.
    expect(log, isEmpty);
  });

  test('bridge stops without a prior broadcast: stays off', () async {
    bridge.value = true;
    await Future<void>.delayed(Duration.zero);
    bridge.value = false;
    await Future<void>.delayed(Duration.zero);
    expect(controller.isOn.value, isFalse);
  });

  test('start() is idempotent: a second call does not double-wire the bridge listener, resume still fires once', () async {
    hub.select(SensorQuantity.heartRate, 'strap');
    await controller.turnOn();
    controller.start(); // second call — must be a no-op, not a second listener/hook
    log.clear();
    bridge.value = true;
    await Future<void>.delayed(Duration.zero);
    expect(controller.isOn.value, isFalse);
    bridge.value = false;
    await Future<void>.delayed(Duration.zero);
    // A double-wired listener would fire _onBridgeChanged twice per edge,
    // which clobbers `_resumeAfterBridge` back to false before resume ever
    // runs (see the fix report) — so `isOn` would wrongly stay false here.
    expect(controller.isOn.value, isTrue);
    expect(log, isEmpty); // 'strap' still tracked in `_connectedIds` — nothing to reconnect
  });

  test('a connectSource failure on a live selection change is recorded, not unhandled, and the switch stays on with the previous sources', () async {
    hub.select(SensorQuantity.heartRate, 'strap');
    await controller.turnOn();
    // Same pristine-output stub as the rollback test above.
    installLoggerErrorListener();
    Object? recordedError;
    Logger.onRecordError = (_, error, _) => recordedError = error;
    addTearDown(() => Logger.onRecordError = null);
    log.clear();
    connectError = StateError('meter refused');
    hub.select(SensorQuantity.cadence, 'meter'); // fires the chained hook fire-and-forget
    await Future<void>.delayed(Duration.zero);
    // No unhandled-error failure reaches the test zone: the chained hook's
    // `.catchError` funnels it through recordError instead.
    expect(recordedError, isA<StateError>());
    expect(log, ['connect:meter']); // attempted; never added to `_connectedIds` since it threw
    expect(controller.isOn.value, isTrue); // the switch never lies — 'strap' is still up
  });
}
