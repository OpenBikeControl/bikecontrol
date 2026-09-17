import 'dart:async';

import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/services/sensors/sensor_sink_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/composite_ble_definition.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/sensor_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:universal_ble/universal_ble.dart';

// Stand-in for the previous, ungated "standalone serves everything over
// Bluetooth" behaviour — used by the tests below that only care about the
// bridge/standalone/none state machine, not about which transport or
// quantities are requested.
const _fullStandalone = StandaloneRequest(
  transport: RetrofitMode.bluetooth,
  exposed: {SensorQuantity.heartRate, SensorQuantity.cadence, SensorQuantity.power},
);

void main() {
  late List<String> log;
  late List<({SensorDefinition definition, RetrofitMode transport})> startCalls;
  late SensorDefinition definition;
  late SensorSinkController controller;

  setUp(() {
    log = [];
    startCalls = [];
    definition = SensorDefinition();
    controller = SensorSinkController(
      definition: definition,
      attach: (_) async => log.add('attach'),
      detach: (_) async => log.add('detach'),
      startStandalone: (def, transport) async {
        startCalls.add((definition: def, transport: transport));
        log.add('start');
      },
      stopStandalone: () async => log.add('stop'),
    );
  });

  test('attaches to the composite in bridge mode', () async {
    await controller.onSinkStateChanged(mode: SensorSinkMode.bridge);

    expect(controller.attachedToComposite, isTrue);
    expect(controller.standaloneRunning, isFalse);
    expect(log, ['attach']);
  });

  test('starts a standalone emulator in standalone mode', () async {
    await controller.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);

    expect(controller.standaloneRunning, isTrue);
    expect(controller.attachedToComposite, isFalse);
    expect(log, ['start']);
  });

  test('a transition detaches before starting, never running both', () async {
    await controller.onSinkStateChanged(mode: SensorSinkMode.bridge);
    log.clear();

    await controller.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);

    expect(log, ['detach', 'start']);
    expect(controller.attachedToComposite, isFalse);
    expect(controller.standaloneRunning, isTrue);
  });

  test('a transition back to bridge mode stops the standalone emulator first', () async {
    await controller.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);
    log.clear();

    await controller.onSinkStateChanged(mode: SensorSinkMode.bridge);

    expect(log, ['stop', 'attach']);
    expect(controller.standaloneRunning, isFalse);
    expect(controller.attachedToComposite, isTrue);
  });

  test('repeating the same state is idempotent', () async {
    await controller.onSinkStateChanged(mode: SensorSinkMode.bridge);
    log.clear();

    await controller.onSinkStateChanged(mode: SensorSinkMode.bridge);

    expect(log, isEmpty);
  });

  // The regression this guards against: an earlier version folded "no source
  // selected" into bridge mode, which left SensorDefinition permanently
  // attached to the shared trainer-bridge composite and prevented
  // ProxyDevice._stopFtmsEmulatorIfUnused from ever stopping it.
  test('none detaches from the composite when it was previously attached', () async {
    await controller.onSinkStateChanged(mode: SensorSinkMode.bridge);
    log.clear();

    await controller.onSinkStateChanged(mode: SensorSinkMode.none);

    expect(log, ['detach']);
    expect(controller.attachedToComposite, isFalse);
    expect(controller.standaloneRunning, isFalse);
  });

  test('none stops the standalone emulator when it was previously running', () async {
    await controller.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);
    log.clear();

    await controller.onSinkStateChanged(mode: SensorSinkMode.none);

    expect(log, ['stop']);
    expect(controller.attachedToComposite, isFalse);
    expect(controller.standaloneRunning, isFalse);
  });

  test('concurrent calls are serialized to maintain invariant', () async {
    late Completer<void> startCompleter;

    controller = SensorSinkController(
      definition: SensorDefinition(),
      attach: (_) async => log.add('attach'),
      detach: (_) async => log.add('detach'),
      startStandalone: (_, __) async {
        startCompleter = Completer<void>();
        log.add('start');
        await startCompleter.future;
      },
      stopStandalone: () async => log.add('stop'),
    );

    // Start a call to standalone mode (will suspend at startStandalone)
    final future1 = controller.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);

    // Let it reach the await point
    await Future.delayed(Duration(milliseconds: 100));

    // While suspended, call with bridge mode
    final future2 = controller.onSinkStateChanged(mode: SensorSinkMode.bridge);

    // Resume the first call
    startCompleter.complete();

    // Wait for both to finish
    await future1;
    await future2;

    // The invariant: never both attached AND standalone
    expect(controller.attachedToComposite && controller.standaloneRunning, isFalse);

    // Call sequence should be legal: either bridge→standalone or standalone→bridge
    // With the fix, we expect: detach, start, stop, attach (two transitions)
    // Without serialization, we might get: detach, attach, start (broken)
    expect(log.contains('attach'), isTrue);
    expect(log.contains('start'), isTrue);
  });

  test('failed transition is retried on next call with same state', () async {
    int startAttempts = 0;

    controller = SensorSinkController(
      definition: SensorDefinition(),
      attach: (_) async => log.add('attach'),
      detach: (_) async => log.add('detach'),
      startStandalone: (_, __) async {
        startAttempts++;
        if (startAttempts == 1) {
          log.add('start-fail');
          throw Exception('Simulated failure');
        }
        log.add('start-success');
      },
      stopStandalone: () async => log.add('stop'),
    );

    // First call fails
    try {
      await controller.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);
    } catch (_) {
      // Exception is caught and recorded by recordError
    }

    // Controller should still be in the old state; the sink is served NOWHERE
    expect(controller.standaloneRunning, isFalse);
    expect(controller.attachedToComposite, isFalse);

    // Reset the mock
    log.clear();

    // Second call with the SAME state should retry
    try {
      await controller.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);
    } catch (_) {}

    // This time it should succeed
    expect(startAttempts, 2); // Both attempts were made
    expect(controller.standaloneRunning, isTrue);
    expect(log.contains('start-success'), isTrue);
  });

  test('failed transition to standalone does not strand when attaching after', () async {
    int attemptCount = 0;

    controller = SensorSinkController(
      definition: SensorDefinition(),
      attach: (_) async => log.add('attach'),
      detach: (_) async => log.add('detach'),
      startStandalone: (_, __) async {
        attemptCount++;
        if (attemptCount == 1) {
          log.add('start-fail');
          throw Exception('Standalone startup failed');
        }
        log.add('start-success');
      },
      stopStandalone: () async => log.add('stop'),
    );

    // Transition to attached (this succeeds and sets _lastMode = bridge)
    await controller.onSinkStateChanged(mode: SensorSinkMode.bridge);
    expect(controller.attachedToComposite, isTrue);
    log.clear();

    // Attempt transition to standalone: startStandalone throws
    // Without the fix: _lastMode is still 'bridge' after the exception
    // because the assignment was at the end of try and never reached.
    // With the fix: _lastMode is null because it's set on entry.
    try {
      await controller.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);
    } catch (_) {}

    expect(controller.attachedToComposite, isFalse);
    expect(controller.standaloneRunning, isFalse);
    log.clear();

    // Now attempt to re-attach. Without the fix, _lastMode is still
    // 'bridge' from the original attach, so the guard check `if (_lastMode
    // == mode) return` silently no-ops and attach never runs, leaving
    // the sink stranded. With the fix, _lastMode is null, so the guard
    // passes and attach runs.
    await controller.onSinkStateChanged(mode: SensorSinkMode.bridge);

    expect(log, contains('attach'));
    expect(controller.attachedToComposite, isTrue);
  });

  // Coordinator fix-round-1: a real transition, not the trivial call-recording
  // fakes above. attach/detach here really mutate a real bridge
  // CompositeBleDefinition (as connection.dart's ftmsEmulator.attachDefinition
  // does), so this actually proves what a trainer app would see on the wire.
  group('cadence/power must not leak across a mode transition (T5-A follow-up)', () {
    FitnessBikeDefinition bridgedFbd() => FitnessBikeDefinition(
      connectedDevice: BleDevice(deviceId: 't', name: 'T'),
      connectedDeviceServices: const <BleService>[],
      data: ValueNotifier<String>(''),
    );

    test(
      'cadence served while standalone must not reach the bridge composite after a real transition to bridge',
      () async {
        final bridgeComposite = CompositeBleDefinition(initial: [bridgedFbd()]);
        final definition = SensorDefinition();
        final realController = SensorSinkController(
          definition: definition,
          attach: (def) async => bridgeComposite.attach(def),
          detach: (def) async => bridgeComposite.detach(def),
          startStandalone: (_, __) async {},
          stopStandalone: () async {},
        );

        // Standalone with a cadence source: CSC really is being served.
        await realController.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);
        definition.setCadence(90);
        expect(definition.serviceUUIDs, contains(SensorDefinition.CYCLING_SPEED_CADENCE_SERVICE_UUID));

        // A trainer connects: the sink moves to bridge mode, exactly like
        // connection.dart does when ftmsEmulator.isStarted flips true.
        await realController.onSinkStateChanged(mode: SensorSinkMode.bridge);

        // A2 (fix-wave-A): this used to compare against a baseline built from
        // a bare, fresh `SensorDefinition()` standing in for "heart rate
        // only". That comparison relied on CSC/Cycling Power being gated on
        // "ever served" — a bare definition had neither, so it doubled as a
        // stand-in for "retracted". Now that CSC/Cycling Power are
        // unconditional except while retracted (see SensorDefinition's own
        // doc comment), a bare, non-retracted `SensorDefinition()` exposes
        // both, so it no longer represents that baseline — asserting
        // directly on the real, retracted composite is the meaningful check
        // here, and always was the one that actually mattered.
        expect(bridgeComposite.serviceUUIDs, isNot(contains(SensorDefinition.CYCLING_SPEED_CADENCE_SERVICE_UUID)));
        expect(bridgeComposite.serviceUUIDs, isNot(contains(SensorDefinition.CYCLING_POWER_SERVICE_UUID)));
      },
    );

    test('cadence is restored once the sink returns to standalone after the bridge stint', () async {
      final bridgeComposite = CompositeBleDefinition(initial: [bridgedFbd()]);
      final definition = SensorDefinition();
      final realController = SensorSinkController(
        definition: definition,
        attach: (def) async => bridgeComposite.attach(def),
        detach: (def) async => bridgeComposite.detach(def),
        startStandalone: (_, __) async {},
        stopStandalone: () async {},
      );

      await realController.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);
      definition.setCadence(90);
      await realController.onSinkStateChanged(mode: SensorSinkMode.bridge);
      expect(definition.serviceUUIDs, isNot(contains(SensorDefinition.CYCLING_SPEED_CADENCE_SERVICE_UUID)));

      // The trainer disconnects; cadence is still selected, so the sink goes
      // back to standalone with the SAME long-lived definition — a rider
      // must not silently lose cadence just because their trainer dropped.
      await realController.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: _fullStandalone);

      expect(definition.serviceUUIDs, contains(SensorDefinition.CYCLING_SPEED_CADENCE_SERVICE_UUID));
      expect(definition.cadenceRpm, 90);
    });
  });

  group('standalone request', () {
    test('starts with the requested transport and exposes only the requested quantities', () async {
      await controller.onSinkStateChanged(
        mode: SensorSinkMode.standalone,
        standalone: const StandaloneRequest(transport: RetrofitMode.wifi, exposed: {SensorQuantity.heartRate}),
      );
      expect(startCalls.single.transport, RetrofitMode.wifi);
      expect(definition.exposesHeartRate, isTrue);
      expect(definition.exposesCadence, isFalse);
      expect(definition.exposesPower, isFalse);
    });

    test('a changed transport while running restarts standalone (stop then start)', () async {
      await controller.onSinkStateChanged(
        mode: SensorSinkMode.standalone,
        standalone: const StandaloneRequest(transport: RetrofitMode.bluetooth, exposed: {SensorQuantity.heartRate}),
      );
      await controller.onSinkStateChanged(
        mode: SensorSinkMode.standalone,
        standalone: const StandaloneRequest(transport: RetrofitMode.wifi, exposed: {SensorQuantity.heartRate}),
      );
      expect(log, ['start', 'stop', 'start']);
      expect(startCalls.last.transport, RetrofitMode.wifi);
    });

    test('a grown exposed set while running restarts standalone', () async {
      await controller.onSinkStateChanged(
        mode: SensorSinkMode.standalone,
        standalone: const StandaloneRequest(transport: RetrofitMode.bluetooth, exposed: {SensorQuantity.heartRate}),
      );
      await controller.onSinkStateChanged(
        mode: SensorSinkMode.standalone,
        standalone: const StandaloneRequest(
          transport: RetrofitMode.bluetooth,
          exposed: {SensorQuantity.heartRate, SensorQuantity.cadence},
        ),
      );
      expect(log, ['start', 'stop', 'start']);
      expect(definition.exposesCadence, isTrue);
    });

    test('an identical request is a no-op', () async {
      const req = StandaloneRequest(transport: RetrofitMode.bluetooth, exposed: {SensorQuantity.heartRate});
      await controller.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: req);
      await controller.onSinkStateChanged(mode: SensorSinkMode.standalone, standalone: req);
      expect(log, ['start']);
    });

    test('bridge still exposes heart rate only', () async {
      await controller.onSinkStateChanged(mode: SensorSinkMode.bridge);
      expect(definition.exposesHeartRate, isTrue);
      expect(definition.exposesCadence, isFalse);
      expect(definition.exposesPower, isFalse);
    });
  });
}
