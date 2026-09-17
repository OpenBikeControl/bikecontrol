import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:bike_control/bluetooth/devices/ltwoo/ltwoo_erx.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show installLoggerErrorListener;
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' show Logger, bytesToHex;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

/// Records click emits (bypassing the base device's keymap timing) and captures
/// outgoing protocol writes so no BLE platform channel is needed.
class _RecordingLtwooErx extends LtwooErx {
  _RecordingLtwooErx({String deviceId = 'dev1'}) : super(BleDevice(deviceId: deviceId, name: 'LTOED2501AB12'));

  final List<List<String>> emitted = [];
  final List<Uint8List> written = [];

  /// Optional per-write completion behavior; the default completes right away.
  /// The request bytes are always recorded in [written] first.
  Future<void> Function()? writeBehavior;

  @override
  Future<void> handleButtonsClicked(List<ControllerButton>? buttons, {bool longPress = false}) async {
    emitted.add(buttons == null ? ['<null>'] : buttons.map((b) => b.name).toList());
  }

  @override
  Future<void> writeRequest(Uint8List data) {
    written.add(data);
    return writeBehavior?.call() ?? Future.value();
  }
}

// Request frames are 0xA5 + PIN(3) + "FFF"(3) + opcode…, so the opcode starts
// at byte 7.
bool _isRearRequest(Uint8List w) => w.length >= 9 && w[7] == 0x09 && w[8] == 0x00;

// Remote-shift request opcodes are 3 bytes: 0x00/0x01 + 0x01 + 0x00.
bool _isShiftRawIncrease(Uint8List w) => w.length >= 10 && w[7] == 0x00 && w[8] == 0x01 && w[9] == 0x00;
bool _isShiftRawDecrease(Uint8List w) => w.length >= 10 && w[7] == 0x01 && w[8] == 0x01 && w[9] == 0x00;
bool _isShiftCmd(Uint8List w) => _isShiftRawIncrease(w) || _isShiftRawDecrease(w);
bool _isFrontRequest(Uint8List w) => w.length >= 9 && w[7] == 0x11 && w[8] == 0x00;
bool _isBatteryRequest(Uint8List w) => w.length >= 9 && w[7] == 0x0A && w[8] == 0x00;
bool _isHelloRequest(Uint8List w) => w.length >= 9 && w[7] == 0x20 && w[8] == 0x01;

/// Captures [Logger.onRecordError] messages for the test, replacing the app's
/// persist listener (which would touch platform channels).
List<String> _captureRecordedErrors() {
  installLoggerErrorListener();
  final previous = Logger.onRecordError;
  final recorded = <String>[];
  Logger.onRecordError = (message, error, stack) => recorded.add(message);
  addTearDown(() => Logger.onRecordError = previous);
  return recorded;
}

/// Appends the XOR checksum to [body].
Uint8List _frame(List<int> body) => Uint8List.fromList([...body, body.fold(0, (a, b) => a ^ b)]);

Future<void> _feed(LtwooErx d, List<int> body) =>
    d.processCharacteristic(LtwooErxConstants.TX_CHARACTERISTIC_UUID, _frame(body));

Future<void> _feedRear(LtwooErx d, int raw, {List<int> opcode = const [0x09, 0x00]}) =>
    _feed(d, [0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, ...opcode, raw]);

Future<void> _feedFront(LtwooErx d, int raw) => _feed(d, [0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x11, 0x00, raw]);

Future<void> _feedHello(LtwooErx d, int numSpeeds) =>
    _feed(d, [0x5A, 0x30, 0x30, 0x30, 0x46, 0x46, 0x46, 0x20, 0x01, numSpeeds]);

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final stubActions = StubActions();
  stubActions.supportedApp = OpenBikeControl();

  SharedPreferences.setMockInitialValues({});
  await core.settings.init();
  await AppLocalizations.load(const Locale('en'));
  core.actionHandler = stubActions;

  group('LtwooErx gear -> button behavior', () {
    test('hello response sets numSpeeds', () async {
      final d = _RecordingLtwooErx();
      expect(d.debugNumSpeeds, isNull);
      await _feedHello(d, 12);
      expect(d.debugNumSpeeds, 12);
    });

    test('first rear-gear reading initializes silently', () async {
      final d = _RecordingLtwooErx();
      await _feedRear(d, 5);
      expect(d.emitted, isEmpty);
    });

    test('raw 5 -> 4 emits exactly one Shift Up click', () async {
      final d = _RecordingLtwooErx();
      await _feedRear(d, 5);
      await _feedRear(d, 4);
      expect(d.emitted, [
        [LtwooErx.shiftUpButtonName],
        <String>[],
      ]);
    });

    test('raw 4 -> 5 emits one Shift Down click', () async {
      final d = _RecordingLtwooErx();
      await _feedRear(d, 4);
      await _feedRear(d, 5);
      expect(d.emitted, [
        [LtwooErx.shiftDownButtonName],
        <String>[],
      ]);
    });

    test('repeated same gear emits nothing', () async {
      final d = _RecordingLtwooErx();
      await _feedRear(d, 5);
      await _feedRear(d, 5);
      await _feedRear(d, 5);
      expect(d.emitted, isEmpty);
    });

    test('raw 8 -> 5 emits three Shift Up clicks', () async {
      final d = _RecordingLtwooErx();
      await _feedRear(d, 8);
      await _feedRear(d, 5);
      expect(d.emitted, [
        [LtwooErx.shiftUpButtonName],
        <String>[],
        [LtwooErx.shiftUpButtonName],
        <String>[],
        [LtwooErx.shiftUpButtonName],
        <String>[],
      ]);
    });

    test('raw 12 -> 5 is capped at three clicks', () async {
      final d = _RecordingLtwooErx();
      await _feedRear(d, 12);
      await _feedRear(d, 5);
      expect(d.emitted, hasLength(6));
      expect(d.emitted.first, [LtwooErx.shiftUpButtonName]);
    });

    test('event-frame opcode variant (0x00 0x09) drives the same path', () async {
      final d = _RecordingLtwooErx();
      await _feedRear(d, 5, opcode: const [0x00, 0x09]);
      expect(d.emitted, isEmpty); // init
      await _feedRear(d, 4, opcode: const [0x00, 0x09]);
      expect(d.emitted, [
        [LtwooErx.shiftUpButtonName],
        <String>[],
      ]);
    });

    test('invalid frame (bad XOR) is dropped', () async {
      final d = _RecordingLtwooErx();
      await _feedRear(d, 5);
      final bad = _frame([0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x09, 0x00, 0x04]);
      bad[bad.length - 1] ^= 0x01;
      await d.processCharacteristic(LtwooErxConstants.TX_CHARACTERISTIC_UUID, bad);
      expect(d.emitted, isEmpty);
    });

    test('reset makes the next rear reading initialize silently again', () async {
      final d = _RecordingLtwooErx();
      await _feedRear(d, 5);
      d.resetConnectionState();
      await _feedRear(d, 3);
      expect(d.emitted, isEmpty);
    });
  });

  group('LtwooErx front gear', () {
    test('first front observation registers the Front Shift button silently', () async {
      final d = _RecordingLtwooErx();
      expect(d.availableButtons.map((b) => b.name), isNot(contains(LtwooErx.frontShiftButtonName)));
      await _feedFront(d, 1);
      expect(d.emitted, isEmpty);
      expect(d.availableButtons.map((b) => b.name), contains(LtwooErx.frontShiftButtonName));
    });

    test('front gear change clicks the Front Shift button', () async {
      final d = _RecordingLtwooErx();
      await _feedFront(d, 1);
      await _feedFront(d, 2);
      expect(d.emitted, [
        [LtwooErx.frontShiftButtonName],
        <String>[],
      ]);
    });
  });

  group('LtwooErx button registration', () {
    test('shift buttons are pre-registered with default actions and sourceDeviceId', () {
      final d = _RecordingLtwooErx();
      d.registerShiftButtons();

      final up = d.availableButtons.firstWhere((b) => b.name == LtwooErx.shiftUpButtonName);
      expect(up.action, InGameAction.shiftUp);
      expect(up.sourceDeviceId, 'dev1');

      final down = d.availableButtons.firstWhere((b) => b.name == LtwooErx.shiftDownButtonName);
      expect(down.action, InGameAction.shiftDown);
      expect(down.sourceDeviceId, 'dev1');
    });

    test('Front Shift button defaults to the frontShift action', () async {
      final d = _RecordingLtwooErx();
      await _feedFront(d, 1);
      final front = d.availableButtons.firstWhere((b) => b.name == LtwooErx.frontShiftButtonName);
      expect(front.action, InGameAction.frontShift);
      expect(front.sourceDeviceId, 'dev1');
    });
  });

  group('LtwooErx wrong PIN', () {
    test('one AlertNotification per connection, not repeated', () async {
      final d = _RecordingLtwooErx();
      final alerts = <AlertNotification>[];
      final sub = core.connection.actionStream.listen((n) {
        if (n is AlertNotification) alerts.add(n);
      });

      await _feed(d, [0x5A, 0xEE, 0xEE, 0xEE, 0x46, 0x46, 0x46]);
      await Future<void>.delayed(Duration.zero);
      expect(alerts, hasLength(1));

      await _feed(d, [0x5A, 0xEE, 0xEE, 0xEE, 0x46, 0x46, 0x46]);
      await Future<void>.delayed(Duration.zero);
      expect(alerts, hasLength(1));

      await sub.cancel();
    });
  });

  group('LtwooErx battery', () {
    test('battery response updates batteryLevel', () async {
      final d = _RecordingLtwooErx();
      await _feed(d, [0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x0A, 0x01, 0x63]);
      expect(d.batteryLevel, 99);
    });
  });

  group('LtwooErx polling and PIN', () {
    test('poll timer sends rear-gear requests every 500 ms until reset', () {
      fakeAsync((async) {
        final d = _RecordingLtwooErx();
        d.startPolling();
        // The hello is sent immediately on startPolling.
        final helloCount = d.written.length;
        expect(helloCount, greaterThanOrEqualTo(1));

        async.elapse(const Duration(milliseconds: 1600));
        final rearRequests = d.written.where((w) => w.length >= 9 && w[7] == 0x09 && w[8] == 0x00);
        expect(rearRequests.length, 3);

        d.resetConnectionState();
        final countAfterReset = d.written.length;
        async.elapse(const Duration(seconds: 5));
        expect(d.written.length, countAfterReset);
      });
    });

    test('support logging: wire trace masks the PIN in both directions', () async {
      final lines = <String>[];
      Logger.onTrace = lines.add;
      addTearDown(() => Logger.onTrace = null);

      final d = _RecordingLtwooErx();
      await _feedRear(d, 5);

      // startPolling sends the hello synchronously (the connect-time battery
      // request is serialized behind it); resetConnectionState immediately
      // stops the scheduler and aborts anything still queued.
      d.startPolling();
      d.resetConnectionState();

      final received = lines.where((l) => l.startsWith('ltwoo< ')).toList();
      expect(received, isNotEmpty);
      // pwd field (bytes 1-3) masked, rest of the rear frame intact.
      expect(received.first, contains('5a??????4646460900'));

      final sent = lines.where((l) => l.startsWith('ltwoo> ')).toList();
      expect(sent, isNotEmpty);
      expect(sent.first, matches(RegExp(r'^ltwoo> a5\?{6}464646')));

      // The configured PIN's ASCII hex must never appear in any trace line.
      final pinHex = bytesToHex(core.settings.getLtwooPin('dev1').codeUnits);
      for (final line in lines.where((l) => l.startsWith('ltwoo'))) {
        expect(line, isNot(contains(pinHex)));
      }
    });

    test('support logging: a rear gear change emits exactly one descriptive LogNotification', () async {
      final d = _RecordingLtwooErx();
      final logs = <String>[];
      final sub = d.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });
      addTearDown(sub.cancel);

      await _feedHello(d, 12);
      await Future<void>.delayed(Duration.zero);
      expect(logs, contains(contains('12 speeds')));

      await _feedRear(d, 5);
      await Future<void>.delayed(Duration.zero);
      logs.clear();

      await _feedRear(d, 4);
      await Future<void>.delayed(Duration.zero);
      expect(logs, hasLength(1));
      expect(logs.single, contains('5→4'));
      expect(logs.single, contains('8→9'));
      expect(logs.single, contains('Shift Up'));
    });

    test('support logging: bad-XOR frames log once per connection, again after reconnect', () async {
      final d = _RecordingLtwooErx();
      final logs = <String>[];
      final sub = d.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });
      addTearDown(sub.cancel);

      Uint8List bad() {
        final b = _frame([0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x09, 0x00, 0x04]);
        b[b.length - 1] ^= 0x01;
        return b;
      }

      await d.processCharacteristic(LtwooErxConstants.TX_CHARACTERISTIC_UUID, bad());
      await d.processCharacteristic(LtwooErxConstants.TX_CHARACTERISTIC_UUID, bad());
      await Future<void>.delayed(Duration.zero);
      expect(logs, hasLength(1));
      expect(logs.single.toLowerCase(), contains('malformed'));

      // handleServices runs resetConnectionState on every (re)connect.
      d.resetConnectionState();
      await d.processCharacteristic(LtwooErxConstants.TX_CHARACTERISTIC_UUID, bad());
      await Future<void>.delayed(Duration.zero);
      expect(logs, hasLength(2));
    });

    test('support logging: unrecognized opcode logs once with hex, then is suppressed', () async {
      final d = _RecordingLtwooErx();
      final logs = <String>[];
      final sub = d.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });
      addTearDown(sub.cancel);

      await _feed(d, [0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x30, 0x00, 0x01]);
      await _feed(d, [0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x30, 0x00, 0x01]);
      await Future<void>.delayed(Duration.zero);
      expect(logs, hasLength(1));
      expect(logs.single, contains('3000'));
    });

    test('support logging: battery and front-gear changes log on change only', () async {
      final d = _RecordingLtwooErx();
      final logs = <String>[];
      final sub = d.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });
      addTearDown(sub.cancel);

      await _feed(d, [0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x0A, 0x01, 0x63]);
      await _feed(d, [0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x0A, 0x01, 0x63]);
      await Future<void>.delayed(Duration.zero);
      expect(logs.where((l) => l.contains('battery')), hasLength(1));

      await _feed(d, [0x5A, 0xFF, 0xFF, 0xFF, 0x46, 0x46, 0x46, 0x0A, 0x01, 0x62]);
      await Future<void>.delayed(Duration.zero);
      expect(logs.where((l) => l.contains('battery')), hasLength(2));

      await _feedFront(d, 1);
      await _feedFront(d, 1);
      await Future<void>.delayed(Duration.zero);
      expect(logs.where((l) => l.contains('front')), isEmpty);

      await _feedFront(d, 2);
      await Future<void>.delayed(Duration.zero);
      expect(logs.where((l) => l.contains('front')), hasLength(1));
      expect(logs.singleWhere((l) => l.contains('front')), contains('1→2'));
    });

    test('changing the PIN re-sends the hello with the new PIN bytes', () async {
      final d = _RecordingLtwooErx();
      await d.setPin('199');
      expect(core.settings.getLtwooPin('dev1'), '199');
      expect(d.written, isNotEmpty);
      final hello = d.written.last;
      // 0xA5 + PIN "199" + FFF + hello opcode.
      expect(hello.sublist(0, 7), [0xA5, 0x31, 0x39, 0x39, 0x46, 0x46, 0x46]);
      expect(hello.sublist(7, 10), [0x20, 0x01, 0x00]);
    });
  });

  group('LtwooErx poll serialization', () {
    test('a tick during an in-flight write sends nothing; the next tick after completion sends', () {
      fakeAsync((async) {
        final traced = <String>[];
        Logger.onTrace = traced.add;
        addTearDown(() => Logger.onTrace = null);

        final d = _RecordingLtwooErx();
        final gates = <Completer<void>>[];
        d.writeBehavior = () {
          final gate = Completer<void>();
          gates.add(gate);
          return gate.future;
        };

        d.startPolling();
        expect(d.written, hasLength(1)); // hello, in flight
        expect(_isHelloRequest(d.written.single), isTrue);

        // Two ticks while the hello write is still in flight: skipped, never
        // queued — nothing goes out when the write completes either.
        async.elapse(const Duration(milliseconds: 1000));
        expect(d.written, hasLength(1));

        gates[0].complete();
        async.flushMicrotasks();
        // The connect-time battery request was serialized behind the hello.
        expect(d.written, hasLength(2));
        expect(_isBatteryRequest(d.written.last), isTrue);

        async.elapse(const Duration(milliseconds: 1000));
        expect(d.written, hasLength(2)); // battery still in flight: ticks skipped

        gates[1].complete();
        async.flushMicrotasks();
        expect(d.written, hasLength(2)); // completion alone sends nothing

        async.elapse(const Duration(milliseconds: 500));
        expect(d.written, hasLength(3)); // next idle tick polls the rear gear
        expect(_isRearRequest(d.written.last), isTrue);

        // Skipped ticks must not log: one `ltwoo>` line per actual write.
        expect(traced.where((l) => l.startsWith('ltwoo> ')).length, d.written.length);

        d.resetConnectionState();
      });
    });

    test('a write failure records once, pauses polling ~5 s, then resumes; repeats are not re-recorded', () {
      fakeAsync((async) {
        final recorded = _captureRecordedErrors();

        final d = _RecordingLtwooErx();
        var failWrites = true;
        d.writeBehavior = () => failWrites ? Future.error(Exception('GATT busy')) : Future<void>.value();

        d.startPolling();
        async.flushMicrotasks();
        // Hello + connect-time battery both failed: recorded exactly once.
        expect(d.written, hasLength(2));
        expect(recorded, hasLength(1));

        // Backoff: no poll attempts while paused.
        async.elapse(const Duration(milliseconds: 4900));
        expect(d.written, hasLength(2));

        // Resumes after ~5 s; the retry fails again but is not re-recorded.
        async.elapse(const Duration(milliseconds: 700));
        expect(d.written, hasLength(3));
        expect(_isRearRequest(d.written.last), isTrue);
        expect(recorded, hasLength(1));

        // Once writes succeed again, steady polling resumes after the backoff.
        failWrites = false;
        async.elapse(const Duration(milliseconds: 6000));
        expect(d.written.length, greaterThanOrEqualTo(4));

        d.resetConnectionState();
      });
    });

    test('a hung write releases the in-flight guard after the timeout and polling continues', () {
      fakeAsync((async) {
        final recorded = _captureRecordedErrors();

        final d = _RecordingLtwooErx();
        var hangNextWrite = true;
        d.writeBehavior = () {
          if (hangNextWrite) {
            hangNextWrite = false;
            return Completer<void>().future; // never completes
          }
          return Future<void>.value();
        };

        d.startPolling();
        expect(d.written, hasLength(1)); // hello, hung

        // All ticks are skipped while the write is wedged.
        async.elapse(const Duration(milliseconds: 11500));
        expect(d.written, hasLength(1));

        // The guard timeout fires and frees the queued battery request.
        async.elapse(const Duration(milliseconds: 500));
        expect(d.written, hasLength(2));
        expect(_isBatteryRequest(d.written.last), isTrue);
        expect(recorded, hasLength(1));

        // The timeout counts as a failure: backoff, then polling resumes.
        async.elapse(const Duration(milliseconds: 4000));
        expect(d.written, hasLength(2));
        async.elapse(const Duration(milliseconds: 1500));
        expect(d.written.length, greaterThanOrEqualTo(3));
        expect(_isRearRequest(d.written.last), isTrue);

        d.resetConnectionState();
      });
    });

    test('idle cadence: rear every 500 ms, front every 4th tick, battery on connect + every 60 s', () {
      fakeAsync((async) {
        final d = _RecordingLtwooErx();
        d.startPolling();
        async.flushMicrotasks();

        expect(d.written, hasLength(2));
        expect(_isHelloRequest(d.written[0]), isTrue);
        expect(_isBatteryRequest(d.written[1]), isTrue);

        async.elapse(const Duration(seconds: 60));
        final polls = d.written.skip(2).toList();
        expect(polls, hasLength(120));

        // First 2 s: three rear polls, then a front poll on the 4th tick.
        expect(polls.take(4).map(_isRearRequest), [true, true, true, false]);
        expect(_isFrontRequest(polls[3]), isTrue);

        expect(polls.where(_isRearRequest).length, 90);
        expect(polls.where(_isFrontRequest).length, 29);
        expect(polls.where(_isBatteryRequest).length, 1);

        d.resetConnectionState();
      });
    });
  });

  group('LtwooErx anchor gear mode', () {
    /// Fresh device with the anchor toggle already ON for its own settings key.
    Future<_RecordingLtwooErx> anchoredDevice(String id) async {
      await core.settings.setLtwooAnchorGearEnabled(id, true);
      return _RecordingLtwooErx(deviceId: id);
    }

    /// Collects LogNotification messages from [d]'s action stream.
    List<String> collectLogs(LtwooErx d) {
      final logs = <String>[];
      final sub = d.actionStream.listen((n) {
        if (n is LogNotification) logs.add(n.message);
      });
      addTearDown(sub.cancel);
      return logs;
    }

    test('mode off: a gear change emits clicks and writes NO shift command', () async {
      final d = _RecordingLtwooErx(); // dev1 — anchor mode defaults to off
      await _feedRear(d, 7);
      await _feedRear(d, 6);
      expect(d.emitted, [
        [LtwooErx.shiftUpButtonName],
        <String>[],
      ]);
      expect(d.written.where(_isShiftCmd), isEmpty);
    });

    test('mode on: rider shift emits one click plus one counter command; the return delta is swallowed', () async {
      final d = await anchoredDevice('anchor-basic');
      fakeAsync((async) {
        unawaited(_feedRear(d, 7)); // anchors at raw 7
        async.flushMicrotasks();
        expect(d.emitted, isEmpty);

        unawaited(_feedRear(d, 6)); // rider shift: raw −1 = Shift Up
        async.flushMicrotasks();
        expect(d.emitted, [
          [LtwooErx.shiftUpButtonName],
          <String>[],
        ]);
        // Default mapping: raw 6→7 needs a raw-increase = 0x00 0x01 0x00.
        expect(d.written.where(_isShiftCmd), hasLength(1));
        expect(_isShiftRawIncrease(d.written.singleWhere(_isShiftCmd)), isTrue);

        // The counter-shift's own rear-status echo emits NO click.
        unawaited(_feedRear(d, 7, opcode: const [0x00, 0x09]));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(2));

        // Back to idle: a further rider shift emits again.
        async.elapse(const Duration(milliseconds: 300));
        unawaited(_feedRear(d, 6));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(4));
        expect(d.emitted[2], [LtwooErx.shiftUpButtonName]);

        d.resetConnectionState();
      });
    });

    test('two-step rider jump: two clicks, two counter commands >=200 ms apart, both echoes swallowed', () async {
      final d = await anchoredDevice('anchor-two-step');
      fakeAsync((async) {
        unawaited(_feedRear(d, 7));
        async.flushMicrotasks();
        unawaited(_feedRear(d, 5));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(4)); // two Shift Up clicks
        expect(d.emitted[0], [LtwooErx.shiftUpButtonName]);
        expect(d.emitted[2], [LtwooErx.shiftUpButtonName]);
        // Only ONE command goes out immediately; the next waits for the echo
        // AND the 200 ms spacing.
        expect(d.written.where(_isShiftCmd), hasLength(1));

        unawaited(_feedRear(d, 6, opcode: const [0x00, 0x09]));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(4)); // echo swallowed
        expect(d.written.where(_isShiftCmd), hasLength(1)); // still inside the 200 ms window

        async.elapse(const Duration(milliseconds: 200));
        expect(d.written.where(_isShiftCmd), hasLength(2));

        unawaited(_feedRear(d, 7, opcode: const [0x00, 0x09]));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(4)); // second echo swallowed too

        d.resetConnectionState();
      });
    });

    test('a rider press during correction emits its click and the correction still converges', () async {
      final d = await anchoredDevice('anchor-mid-press');
      fakeAsync((async) {
        unawaited(_feedRear(d, 7));
        async.flushMicrotasks();
        unawaited(_feedRear(d, 5)); // rider jump: 2 clicks, correction starts
        async.flushMicrotasks();
        unawaited(_feedRear(d, 6, opcode: const [0x00, 0x09])); // first echo, swallowed
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 200)); // second command out
        expect(d.written.where(_isShiftCmd), hasLength(2));
        expect(d.emitted, hasLength(4));

        // Rider presses again before the second echo arrives: 6 → 5.
        unawaited(_feedRear(d, 5));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(6)); // the extra press emits its click
        expect(d.emitted[4], [LtwooErx.shiftUpButtonName]);

        // Second command's echo: swallowed, still converging on the anchor.
        unawaited(_feedRear(d, 6, opcode: const [0x00, 0x09]));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(6));

        async.elapse(const Duration(milliseconds: 200)); // third command out
        expect(d.written.where(_isShiftCmd), hasLength(3));
        unawaited(_feedRear(d, 7, opcode: const [0x00, 0x09]));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(6)); // final echo swallowed — converged

        d.resetConnectionState();
      });
    });

    test('orientation self-check: an inverted derailleur flips the mapping, logs once, persists, converges', () async {
      const id = 'anchor-inverted';
      final d = await anchoredDevice(id);
      final logs = collectLogs(d);
      fakeAsync((async) {
        unawaited(_feedRear(d, 7));
        async.flushMicrotasks();
        unawaited(_feedRear(d, 6)); // rider shift; default raw-increase command
        async.flushMicrotasks();
        expect(d.written.where(_isShiftCmd), hasLength(1));
        expect(_isShiftRawIncrease(d.written.singleWhere(_isShiftCmd)), isTrue);

        // Inverted hardware: the echo moves AWAY from the anchor (6 → 5).
        unawaited(_feedRear(d, 5, opcode: const [0x00, 0x09]));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(2)); // the misdirected echo emits no click

        // Corrective commands use the flipped opcode and converge on raw 7.
        async.elapse(const Duration(milliseconds: 200));
        expect(d.written.where(_isShiftCmd), hasLength(2));
        expect(_isShiftRawDecrease(d.written.where(_isShiftCmd).last), isTrue);
        unawaited(_feedRear(d, 6, opcode: const [0x00, 0x09]));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 200));
        expect(d.written.where(_isShiftCmd), hasLength(3));
        expect(_isShiftRawDecrease(d.written.where(_isShiftCmd).last), isTrue);
        unawaited(_feedRear(d, 7, opcode: const [0x00, 0x09]));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(2)); // all correction echoes swallowed

        d.resetConnectionState();
      });
      await Future<void>.delayed(Duration.zero);
      expect(logs.where((l) => l.contains('orientation inverted')), hasLength(1));
      expect(core.settings.getLtwooShiftOrientationInverted(id), isTrue);
    });

    test('give-up guard: commands stop after the cap, one re-anchor log, next rider shift works', () async {
      const id = 'anchor-give-up';
      final d = await anchoredDevice(id);
      final logs = collectLogs(d);
      fakeAsync((async) {
        unawaited(_feedRear(d, 7));
        async.flushMicrotasks();
        unawaited(_feedRear(d, 6)); // rider shift: 1 step → budget = 1 + 2 = 3 commands
        async.flushMicrotasks();
        expect(d.emitted, hasLength(2));

        // The gear never moves back: every reading shows raw 6.
        for (var i = 0; i < 10; i++) {
          unawaited(_feedRear(d, 6, opcode: const [0x00, 0x09]));
          async.flushMicrotasks();
          async.elapse(const Duration(milliseconds: 200));
        }
        expect(d.written.where(_isShiftCmd), hasLength(3)); // steps + 2, then stop
        expect(d.debugAnchorRawGear, 6); // re-anchored at the current gear

        // Long idle: nothing else goes out.
        async.elapse(const Duration(seconds: 10));
        expect(d.written.where(_isShiftCmd), hasLength(3));

        // The next rider shift works normally against the new anchor.
        unawaited(_feedRear(d, 5));
        async.flushMicrotasks();
        expect(d.emitted, hasLength(4));
        expect(d.emitted[2], [LtwooErx.shiftUpButtonName]);
        expect(d.written.where(_isShiftCmd), hasLength(4));

        d.resetConnectionState();
      });
      await Future<void>.delayed(Duration.zero);
      expect(logs.where((l) => l.contains('re-anchoring at 6')), hasLength(1));
    });

    test('toggling the mode on re-anchors at the current gear', () async {
      const id = 'anchor-toggle';
      final d = _RecordingLtwooErx(deviceId: id);
      await _feedRear(d, 7);
      await _feedRear(d, 5); // mode off: clicks only, no commands
      expect(d.written.where(_isShiftCmd), isEmpty);
      expect(d.debugAnchorRawGear, isNull);

      await d.setAnchorGearEnabled(true);
      expect(d.debugAnchorRawGear, 5);

      fakeAsync((async) {
        unawaited(_feedRear(d, 4));
        async.flushMicrotasks();
        // Corrects back toward the toggle-time anchor (raw 5): raw-increase.
        expect(d.written.where(_isShiftCmd), hasLength(1));
        expect(_isShiftRawIncrease(d.written.singleWhere(_isShiftCmd)), isTrue);
        d.resetConnectionState();
      });

      await d.setAnchorGearEnabled(false);
      expect(d.debugAnchorRawGear, isNull);
    });
  });
}
