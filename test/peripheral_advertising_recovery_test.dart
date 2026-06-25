import 'package:bike_control/bluetooth/peripheral_advertising_recovery.dart';
import 'package:bike_control/bluetooth/peripheral_server.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [PeripheralServer] whose advertising calls are recorded instead of hitting
/// the real CoreBluetooth/universal_ble platform. The recovery mixin only ever
/// calls [stopAdvertising], so that is all we override (never calling `super`,
/// which would touch the global peripheral platform).
class _FakePeripheralServer extends PeripheralServer {
  _FakePeripheralServer(this._log);
  final List<String> _log;
  int stopAdvertisingCalls = 0;

  @override
  Future<void> stopAdvertising() async {
    stopAdvertisingCalls++;
    _log.add('stop');
  }
}

/// Minimal host mixing in the recovery behaviour. Records each service
/// (re)start and can optionally re-enter recovery mid-restart to exercise the
/// re-entrancy guard.
class _RecoveryHost with PeripheralAdvertisingRecovery {
  _RecoveryHost(this._server, this._log);
  final PeripheralServer _server;
  final List<String> _log;

  int startServiceCalls = 0;

  /// If set, invoked while a restart is in flight (i.e. while recovery still
  /// holds its guard) — used to prove a nested recovery is rejected.
  Future<void> Function()? duringStart;

  @override
  PeripheralServer get advertisingServer => _server;

  @override
  Future<void> startServiceAdvertising() async {
    startServiceCalls++;
    _log.add('start');
    final hook = duringStart;
    if (hook != null) await hook();
  }
}

void main() {
  late List<String> log;
  late _FakePeripheralServer server;
  late _RecoveryHost host;

  setUp(() {
    log = [];
    server = _FakePeripheralServer(log);
    host = _RecoveryHost(server, log);
  });

  group('recoverIfAlreadyAdvertising', () {
    test('ignores a null error', () async {
      expect(await host.recoverIfAlreadyAdvertising(null), isFalse);
      expect(server.stopAdvertisingCalls, 0);
      expect(host.startServiceCalls, 0);
    });

    test('ignores an unrelated error (no "already")', () async {
      // e.g. the Zwift "Data too large" advertise failure must NOT be treated
      // as an already-advertising collision.
      expect(await host.recoverIfAlreadyAdvertising('Data too large'), isFalse);
      expect(log, isEmpty);
    });

    test('recovers an "already started" error: stop then restart, exactly once', () async {
      final handled = await host.recoverIfAlreadyAdvertising('Advertising has already started');

      expect(handled, isTrue, reason: 'caller should then NOT also warn');
      expect(server.stopAdvertisingCalls, 1);
      expect(host.startServiceCalls, 1);
      expect(log, ['stop', 'start'], reason: 'must stop the stale advertisement before restarting ours');
    });

    test('matches "already" case-insensitively', () async {
      expect(await host.recoverIfAlreadyAdvertising('ALREADY ADVERTISING'), isTrue);
      expect(log, ['stop', 'start']);
    });

    test('is re-entrancy guarded: a nested recovery while restarting is rejected', () async {
      bool? nested;
      host.duringStart = () async {
        // Runs while the first recovery still holds the guard — a persistent
        // error re-firing here must not trigger a second stop/restart loop.
        nested = await host.recoverIfAlreadyAdvertising('already started');
      };

      final outer = await host.recoverIfAlreadyAdvertising('already started');

      expect(outer, isTrue);
      expect(nested, isFalse, reason: 'a recovery already in flight must not re-enter');
      expect(server.stopAdvertisingCalls, 1, reason: 'guard prevents a second stop');
      expect(host.startServiceCalls, 1, reason: 'guard prevents a second restart');
    });

    test('releases the guard after recovery, so a later error recovers again', () async {
      await host.recoverIfAlreadyAdvertising('already started');
      final second = await host.recoverIfAlreadyAdvertising('already started');

      expect(second, isTrue);
      expect(server.stopAdvertisingCalls, 2);
      expect(host.startServiceCalls, 2);
    });
  });

  group('restartAdvertising', () {
    test('unconditionally stops the stale advertisement then restarts ours', () async {
      await host.restartAdvertising();
      expect(log, ['stop', 'start']);
    });
  });
}
