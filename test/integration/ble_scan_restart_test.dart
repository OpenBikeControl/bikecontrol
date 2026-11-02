import 'dart:async';

import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/test_env.dart';

/// Android downgrades an unfiltered BLE scan that runs longer than 30 minutes
/// to opportunistic (no results) and pauses it while the screen is off. A
/// controller that drops after that is never seen again unless the scan is
/// restarted — on a drop and periodically.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    final stubActions = StubActions();
    stubActions.supportedApp = Zwift();
    core.actionHandler = stubActions;
    debugHostPlatformOverride = TargetPlatform.android;
    core.connection.bleScanRestartDebounce = const Duration(milliseconds: 50);
    core.connection.bleScanRestartInterval = const Duration(minutes: 25);
  });

  tearDown(() async {
    debugHostPlatformOverride = null;
    await env.resetConnection();
  });

  final restartLogs = <String>[];
  core.connection.actionStream.listen((event) {
    if (event is LogNotification && event.message.startsWith('BLE scan restarted')) restartLogs.add(event.message);
  });
  setUp(restartLogs.clear);

  group('a dropped controller', () {
    test('restarts the running BLE scan once and is rediscovered', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().any((d) => d.isConnected),
        description: 'the Click to connect',
      );
      expect(env.ble.startScanCalls, 1);

      // The platform reports a drop twice in the same moment.
      env.ble.dropConnection(click.deviceId);
      env.ble.dropConnection(click.deviceId);

      await IntegrationEnv.waitFor(() => env.ble.startScanCalls == 2, description: 'the BLE scan to restart');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(env.ble.stopScanCalls, 1);
      expect(env.ble.startScanCalls, 2);
      expect(restartLogs, hasLength(1));
      expect(restartLogs.single, startsWith('BLE scan restarted (device dropped: '));

      // The restarted scan reports the controller again and it reconnects.
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().any((d) => d.isConnected),
        description: 'the Click to reconnect',
      );
    });

    test('a restart that fails to start the scan does not break the drop', () async {
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().any((d) => d.isConnected),
        description: 'the Click to connect',
      );

      env.ble.startScanError = StateError('scan throttled');
      env.ble.dropConnection(click.deviceId);

      await IntegrationEnv.waitFor(() => env.ble.startScanCalls == 2, description: 'the restart attempt');
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().isEmpty,
        description: 'the dropped Click to be removed',
      );
      expect(restartLogs, isEmpty);
      expect(core.connection.isScanning.value, isTrue);
    });

    test('does not restart the scan off Android', () async {
      debugHostPlatformOverride = TargetPlatform.iOS;
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftClick>().any((d) => d.isConnected),
        description: 'the Click to connect',
      );

      env.ble.dropConnection(click.deviceId);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(env.ble.stopScanCalls, 0);
      expect(env.ble.startScanCalls, 1);
      expect(restartLogs, isEmpty);
    });
  });

  group('periodic restart', () {
    test('fires at the interval and not before', () {
      fakeAsync((async) {
        core.connection.performScanning();
        async.flushMicrotasks();
        expect(env.ble.startScanCalls, 1);

        async.elapse(const Duration(minutes: 24, seconds: 59));
        expect(env.ble.stopScanCalls, 0);
        expect(env.ble.startScanCalls, 1);

        async.elapse(const Duration(seconds: 1));
        expect(env.ble.stopScanCalls, 1);
        expect(env.ble.startScanCalls, 2);
        expect(restartLogs, ['BLE scan restarted (periodic)']);

        // And again one interval after the restart.
        async.elapse(const Duration(minutes: 25));
        expect(env.ble.startScanCalls, 3);

        core.connection.stop();
        async.flushMicrotasks();
      });
    });

    test('never fires off Android', () {
      debugHostPlatformOverride = TargetPlatform.windows;
      fakeAsync((async) {
        core.connection.performScanning();
        async.elapse(const Duration(hours: 1));
        expect(env.ble.stopScanCalls, 0);
        expect(env.ble.startScanCalls, 1);
        core.connection.stop();
        async.flushMicrotasks();
      });
    });

    test('stop() cancels it and a stop/scan cycle does not stack timers', () {
      fakeAsync((async) {
        core.connection.performScanning();
        async.flushMicrotasks();
        core.connection.stop();
        async.flushMicrotasks();
        final stopsAfterStop = env.ble.stopScanCalls;

        // Stopped: nothing restarts.
        async.elapse(const Duration(minutes: 30));
        expect(env.ble.stopScanCalls, stopsAfterStop);
        expect(env.ble.startScanCalls, 1);

        // Three stop/scan cycles in a row, then one interval: one restart.
        for (var i = 0; i < 3; i++) {
          core.connection.performScanning();
          async.flushMicrotasks();
          if (i < 2) {
            core.connection.stop();
            async.flushMicrotasks();
          }
        }
        final startsBefore = env.ble.startScanCalls;
        final stopsBefore = env.ble.stopScanCalls;
        async.elapse(const Duration(minutes: 25));
        expect(env.ble.startScanCalls, startsBefore + 1);
        expect(env.ble.stopScanCalls, stopsBefore + 1);
        expect(restartLogs, hasLength(1));

        core.connection.stop();
        async.flushMicrotasks();
      });
    });
  });

  group('restart edge cases', () {
    test('stop() while a restart is still starting the scan leaves it stopped', () {
      fakeAsync((async) {
        core.connection.performScanning();
        async.flushMicrotasks();

        // The restart's start is deferred (Android's scan rate limiter).
        final gate = Completer<void>();
        env.ble.startScanGate = gate;
        async.elapse(const Duration(minutes: 25));
        expect(env.ble.startScanCalls, 2);

        core.connection.stop();
        async.flushMicrotasks();
        gate.complete();
        async.flushMicrotasks();

        expect(env.ble.scanning, isFalse);
        expect(core.connection.describeBleScan(), 'not running');
        expect(restartLogs, isEmpty);

        // Nothing re-arms behind stop()'s back.
        final starts = env.ble.startScanCalls;
        async.elapse(const Duration(hours: 1));
        expect(env.ble.startScanCalls, starts);
      });
    });

    test('a failed restart is retried soon, not after a whole interval', () {
      fakeAsync((async) {
        core.connection.performScanning();
        async.flushMicrotasks();

        env.ble.startScanError = StateError('scan throttled');
        async.elapse(const Duration(minutes: 25));
        expect(env.ble.startScanCalls, 2);
        // The native scan is stopped now — the bundle must not claim otherwise.
        expect(core.connection.describeBleScan(), startsWith('not running (restart failed'));

        env.ble.startScanError = null;
        async.elapse(const Duration(seconds: 29));
        expect(env.ble.startScanCalls, 2);
        async.elapse(const Duration(seconds: 1));
        expect(env.ble.startScanCalls, 3);
        expect(restartLogs, ['BLE scan restarted (retry after failed restart)']);
        expect(core.connection.describeBleScan(), startsWith('running since'));

        // Back on the regular interval afterwards.
        async.elapse(const Duration(minutes: 25));
        expect(env.ble.startScanCalls, 4);

        core.connection.stop();
        async.flushMicrotasks();
      });
    });

    test('quick retries are bounded, then the regular interval takes over', () {
      fakeAsync((async) {
        core.connection.performScanning();
        async.flushMicrotasks();

        env.ble.startScanError = StateError('scan throttled');
        async.elapse(const Duration(minutes: 25));
        expect(env.ble.startScanCalls, 2);
        async.elapse(const Duration(seconds: 90));
        expect(env.ble.startScanCalls, 5);
        async.elapse(const Duration(minutes: 24));
        expect(env.ble.startScanCalls, 5);
        async.elapse(const Duration(minutes: 1, seconds: 30));
        expect(env.ble.startScanCalls, 6);

        core.connection.stop();
        async.flushMicrotasks();
      });
    });
  });

  group('support bundle', () {
    test('says when the BLE scan is not running', () async {
      debugDiagnosticsGatherOverride = ({bool includeDiscovery = true}) => Future.error(StateError('not under test'));
      addTearDown(() => debugDiagnosticsGatherOverride = null);

      final text = await debugText(includeDiscovery: false);

      expect(text, contains('\nBLE scan: not running\n'));
    });

    test('names when the running BLE scan started and how often it restarted', () async {
      debugDiagnosticsGatherOverride = ({bool includeDiscovery = true}) => Future.error(StateError('not under test'));
      addTearDown(() => debugDiagnosticsGatherOverride = null);

      await core.connection.performScanning();
      final text = await debugText(includeDiscovery: false);

      expect(
        text,
        matches(RegExp(r'^BLE scan: running since \d\d:\d\d:\d\d \(0 min, restarts: 0\)$', multiLine: true)),
      );
    });
  });
}
